#!/usr/bin/env node
/**
 * Worker batch pour le système de duel hebdomadaire.
 *
 * Tâches :
 * - push ciblé des invitations en attente
 * - expiration des invitations après 48h
 * - notification des refus
 * - règlement des duels terminés
 * - notification des résultats
 *
 * Variables d'environnement :
 * FIREBASE_SERVICE_ACCOUNT  JSON string du compte de service
 * FIREBASE_PROJECT_ID       ID du projet Firebase
 */

import admin from 'firebase-admin';

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId = process.env.FIREBASE_PROJECT_ID;

if (!serviceAccountJson || !projectId) {
  console.error('[duels] FIREBASE_SERVICE_ACCOUNT ou FIREBASE_PROJECT_ID manquant.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  projectId,
});

const db = admin.firestore();
const messaging = admin.messaging();
const FieldValue = admin.firestore.FieldValue;
const quoteCache = new Map();
const minEligibleHoldingsValue = 10000;
const capitalTimelineSampleWindowMs = 6 * 60 * 60 * 1000;

function asNumber(value, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function asTimestampDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function relativeDiff(left, right) {
  const denom = Math.max(Math.abs(left), Math.abs(right), 1);
  return Math.abs(left - right) / denom;
}

function maxWeight(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  return holdings.reduce(
    (max, holding) => Math.max(max, holding.marketValue / holdingsValue),
    0,
  );
}

function marketZone(exchange, currency) {
  const merged = `${String(exchange || '').toUpperCase()} ${String(currency || '').toUpperCase()}`;
  if (merged.includes('PARIS') || merged.includes('EURONEXT') || merged.includes('EUR')) {
    return 'EU';
  }
  if (merged.includes('NASDAQ') || merged.includes('NYSE') || merged.includes('USD')) {
    return 'US';
  }
  if (merged.includes('TOKYO') || merged.includes('JPY')) {
    return 'JP';
  }
  if (merged.includes('HK') || merged.includes('HONG')) {
    return 'HK';
  }
  return merged.trim();
}

function structureBonus(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  let bonus = 0;
  if (holdings.length >= 5) {
    bonus += 2;
  } else if (holdings.length >= 3) {
    bonus += 1;
  }

  const concentration = maxWeight(holdings, holdingsValue);
  if (concentration <= 0.45) {
    bonus += 1;
  } else if (concentration <= 0.6) {
    bonus += 0.5;
  }

  const quoteTypes = new Set(
    holdings
      .map((holding) => String(holding.quoteType || '').trim().toUpperCase())
      .filter(Boolean),
  );
  if (quoteTypes.size >= 2) {
    bonus += 0.5;
  }

  const zones = new Set(
    holdings
      .map((holding) => marketZone(holding.exchange, holding.currency))
      .filter(Boolean),
  );
  if (zones.size >= 2) {
    bonus += 0.5;
  }

  return Math.min(Math.max(bonus, 0), 4);
}

function concentrationPenalty(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  const concentration = maxWeight(holdings, holdingsValue);
  if (concentration > 0.85) return 2;
  if (concentration > 0.7) return 1;
  return 0;
}

function deterministicIndex(seed, size) {
  if (size <= 0) return 0;
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = ((hash * 31) + seed.charCodeAt(i)) >>> 0;
  }
  return hash % size;
}

async function fetchQuote(symbol) {
  const cached = quoteCache.get(symbol);
  if (cached) return cached;

  const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${encodeURIComponent(symbol)}`;
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'Mozilla/5.0 (compatible; fintech-duel-worker/1.0)',
    },
  });
  if (!response.ok) {
    throw new Error(`Yahoo ${symbol} -> HTTP ${response.status}`);
  }
  const json = await response.json();
  const result = json?.quoteResponse?.result?.[0];
  if (!result) {
    throw new Error(`Quote introuvable pour ${symbol}`);
  }

  const quote = {
    marketPrice: asNumber(result.regularMarketPrice, 0),
    displayName: String(result.longName || result.shortName || symbol),
    exchange: String(result.fullExchangeName || result.exchange || ''),
    currency: String(result.currency || ''),
    quoteType: String(result.quoteType || 'UNKNOWN'),
  };
  quoteCache.set(symbol, quote);
  return quote;
}

async function loadPortfolio(uid) {
  const userRef = db.collection('users').doc(uid);
  const positionsRef = userRef.collection('games').doc('portofolio').collection('positions');
  const [userDoc, positionsSnap] = await Promise.all([userRef.get(), positionsRef.get()]);

  const reserveCoins = asNumber(userDoc.data()?.coins, 0);
  const holdings = [];

  for (const doc of positionsSnap.docs) {
    const data = doc.data();
    const symbol = String(data.symbol || doc.id || '').trim();
    const quantity = asNumber(data.quantity, 0);
    if (!symbol || quantity <= 0) continue;

    let quote;
    try {
      quote = await fetchQuote(symbol);
    } catch (error) {
      console.warn(`[duels] Quote indisponible pour ${symbol}:`, error.message);
      quote = {
        marketPrice: asNumber(data.regularMarketPrice, asNumber(data.averagePrice, 0)),
        displayName: String(data.displayName || symbol),
        exchange: String(data.exchange || ''),
        currency: String(data.currency || ''),
        quoteType: String(data.quoteType || 'UNKNOWN'),
      };
    }

    const averagePrice = asNumber(data.averagePrice, 0);
    const marketPrice = quote.marketPrice || averagePrice;
    holdings.push({
      symbol,
      quantity,
      averagePrice,
      marketPrice,
      marketValue: marketPrice * quantity,
      displayName: quote.displayName || symbol,
      exchange: quote.exchange || '',
      currency: quote.currency || '',
      quoteType: quote.quoteType || 'UNKNOWN',
      raw: data,
    });
  }

  const holdingsValue = holdings.reduce((sum, holding) => sum + holding.marketValue, 0);
  return {
    uid,
    reserveCoins,
    holdings,
    holdingsValue,
    totalCapital: holdingsValue + reserveCoins,
    positionsCount: holdings.length,
  };
}

function computeMetrics(portfolio, startingTotalCapital) {
  const baseline = startingTotalCapital > 0 ? startingTotalCapital : Math.max(portfolio.totalCapital, 1);
  const returnPct = ((portfolio.totalCapital - baseline) / baseline) * 100;
  const bonus = structureBonus(portfolio.holdings, portfolio.holdingsValue);
  const penalty = concentrationPenalty(portfolio.holdings, portfolio.holdingsValue);
  return {
    pureReturnPct: returnPct,
    returnPct,
    structureBonus: bonus,
    concentrationPenalty: penalty,
    persistentConcentrationPenalty: 0,
    finalScore: returnPct + bonus - penalty,
    maxPositionWeight: maxWeight(portfolio.holdings, portfolio.holdingsValue),
  };
}

function normalizeDayList(raw) {
  return Array.isArray(raw)
    ? [...new Set(raw.map((value) => String(value || '').trim()).filter(Boolean))].sort()
    : [];
}

function dayKey(date) {
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

function updateHighConcentrationDays(existing, {now, maxPositionWeight}) {
  const next = normalizeDayList(existing);
  if (maxPositionWeight >= 0.85) {
    const todayKey = dayKey(now);
    if (!next.includes(todayKey)) {
      next.push(todayKey);
    }
  }
  return next.slice(-14);
}

function persistentConcentrationPenaltyFromDays(count) {
  if (count >= 4) return 1.5;
  if (count >= 3) return 1.0;
  if (count >= 2) return 0.5;
  return 0;
}

function normalizeCapitalTimeline(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((entry) => ({
      at: asTimestampDate(entry?.at),
      totalCapital: asNumber(entry?.totalCapital, 0),
      score: asNumber(entry?.score, 0),
      returnPct: asNumber(entry?.returnPct, 0),
    }))
    .filter((entry) => entry.at)
    .sort((left, right) => left.at - right.at);
}

function appendCapitalTimeline(existing, {now, totalCapital, score, returnPct}) {
  const next = normalizeCapitalTimeline(existing);
  const point = {
    at: now,
    totalCapital,
    score,
    returnPct,
  };
  if (!next.length) {
    return [point];
  }

  const last = next[next.length - 1];
  const shouldReplace =
    (now.getTime() - last.at.getTime()) < capitalTimelineSampleWindowMs &&
    dayKey(now) === dayKey(last.at);

  if (shouldReplace) {
    next[next.length - 1] = point;
  } else {
    next.push(point);
  }

  return next.slice(-32).map((entry) => ({
    at: admin.firestore.Timestamp.fromDate(entry.at),
    totalCapital: entry.totalCapital,
    score: entry.score,
    returnPct: entry.returnPct,
  }));
}

function compareScores(left, right) {
  if (left.finalScore !== right.finalScore) return left.finalScore - right.finalScore;
  if (left.returnPct !== right.returnPct) return left.returnPct - right.returnPct;
  if (left.structureBonus !== right.structureBonus) return left.structureBonus - right.structureBonus;
  if (left.maxPositionWeight !== right.maxPositionWeight) {
    return right.maxPositionWeight - left.maxPositionWeight;
  }
  return 0;
}

function pickTransferredHolding(holdings, seed) {
  if (!holdings.length) return null;
  const sorted = [...holdings].sort((left, right) => left.symbol.localeCompare(right.symbol));
  return sorted[deterministicIndex(seed, sorted.length)];
}

async function loadTokensForUser(uid) {
  const snap = await db.collection('users').doc(uid).collection('devices').get();
  return [
    ...new Set(
      snap.docs
        .map((doc) => doc.data())
        .filter((data) => data.notificationsEnabled !== false)
        .map((data) => String(data.fcmToken || '').trim())
        .filter(Boolean),
    ),
  ];
}

async function pushToUser(uid, {title, body, data = {}}) {
  const tokens = await loadTokensForUser(uid);
  if (!tokens.length) {
    console.log(`[duels] Aucun token FCM actif pour ${uid}`);
    return;
  }

  await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data,
    apns: {
      headers: {
        'apns-push-type': 'alert',
        'apns-priority': '10',
      },
      payload: {
        aps: {sound: 'default'},
      },
    },
  });
}

function profileEligible(profileData) {
  return asNumber(profileData?.holdingsValueEstimate, 0) >= minEligibleHoldingsValue &&
    asNumber(profileData?.positionsCount, 0) >= 1;
}

async function processPendingRequests() {
  const now = new Date();
  const snap = await db.collection('duel_requests').where('status', '==', 'pending_response').limit(60).get();

  for (const doc of snap.docs) {
    const data = doc.data();
    const responseDeadline = asTimestampDate(data.responseDeadline);
    const requestId = doc.id;
    const initiatorUid = String(data.initiatorUid || '');
    const targetUid = String(data.targetUid || '');

    if (responseDeadline && responseDeadline <= now) {
      let canNotify = false;
      await db.runTransaction(async (transaction) => {
        const freshRequest = await transaction.get(doc.ref);
        if (!freshRequest.exists || freshRequest.data()?.status !== 'pending_response') {
          return;
        }

        const initiatorProfileRef = db.collection('duel_profiles').doc(initiatorUid);
        const targetProfileRef = db.collection('duel_profiles').doc(targetUid);
        const [initiatorProfileSnap, targetProfileSnap] = await Promise.all([
          transaction.get(initiatorProfileRef),
          transaction.get(targetProfileRef),
        ]);

        transaction.set(doc.ref, {
          status: 'expired',
          expiredAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        transaction.set(initiatorProfileRef, {
          state: 'idle',
          currentRequestId: null,
          eligible: profileEligible(initiatorProfileSnap.data()),
        }, {merge: true});

        transaction.set(targetProfileRef, {
          state: 'idle',
          currentRequestId: null,
          eligible: profileEligible(targetProfileSnap.data()),
        }, {merge: true});

        transaction.set(
          db.collection('users').doc(initiatorUid).collection('inbox').doc(`expired_${requestId}`),
          {
            type: 'duel_expired',
            title: 'Invitation expirée',
            body: 'Ton adversaire n’a pas répondu sous 48h. Tu peux relancer un duel.',
            createdAt: FieldValue.serverTimestamp(),
            requestId,
            duelId: null,
            actorUid: targetUid,
            isRead: false,
          },
          {merge: true},
        );

        canNotify = true;
      });

      if (canNotify) {
        await pushToUser(initiatorUid, {
          title: 'Invitation expirée',
          body: 'Ton adversaire n’a pas répondu à temps. Tu peux relancer un duel.',
          data: {type: 'duel_expired', requestId},
        }).catch((error) => {
          console.warn(`[duels] Push expiration ${requestId} impossible:`, error.message);
        });
        await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
      }
      continue;
    }

    if (!data.invitePushSentAt) {
      await pushToUser(targetUid, {
        title: 'Nouveau duel FinHub',
        body: `${data.initiatorSnapshot?.displayName || 'Un joueur'} te provoque en duel hebdo.`,
        data: {type: 'duel_invite', requestId},
      }).catch((error) => {
        console.warn(`[duels] Push invitation ${requestId} impossible:`, error.message);
      });
      await doc.ref.set({invitePushSentAt: FieldValue.serverTimestamp()}, {merge: true});
    }
  }
}

async function processRefusedRequests() {
  const snap = await db.collection('duel_requests').where('status', '==', 'refused').limit(40).get();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resolutionNotifiedAt) continue;
    const initiatorUid = String(data.initiatorUid || '');
    const targetName = data.targetSnapshot?.displayName || 'Ton adversaire';
    await pushToUser(initiatorUid, {
      title: 'Duel refusé',
      body: `${targetName} a refusé le duel. Tu peux relancer un matchmaking.`,
      data: {type: 'duel_refused', requestId: doc.id},
    }).catch((error) => {
      console.warn(`[duels] Push refus ${doc.id} impossible:`, error.message);
    });
    await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
}

async function processConvertedRequests() {
  const snap = await db.collection('duel_requests').where('status', '==', 'converted').limit(40).get();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resolutionNotifiedAt || !data.duelId) continue;

    const initiatorUid = String(data.initiatorUid || '');
    const targetUid = String(data.targetUid || '');
    const initiatorName = data.initiatorSnapshot?.displayName || 'Ton adversaire';
    const targetName = data.targetSnapshot?.displayName || 'Ton adversaire';

    await Promise.all([
      pushToUser(initiatorUid, {
        title: 'Duel lancé',
        body: `${targetName} a accepté le duel. Ouvre le dashboard pour suivre la semaine.`,
        data: {type: 'duel_started', duelId: String(data.duelId), requestId: doc.id},
      }).catch((error) => {
        console.warn(`[duels] Push démarrage initiateur ${doc.id} impossible:`, error.message);
      }),
      pushToUser(targetUid, {
        title: 'Duel lancé',
        body: `Le duel contre ${initiatorName} a commencé. Ouvre le dashboard pour suivre la semaine.`,
        data: {type: 'duel_started', duelId: String(data.duelId), requestId: doc.id},
      }).catch((error) => {
        console.warn(`[duels] Push démarrage cible ${doc.id} impossible:`, error.message);
      }),
    ]);

    await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
}

async function refreshActiveDuelSnapshots() {
  const snap = await db
    .collection('duels')
    .where('status', '==', 'active')
    .limit(30)
    .get();

  for (const doc of snap.docs) {
    const duel = doc.data();
    const participantIds = Array.isArray(duel.participants) ? duel.participants : [];
    if (participantIds.length !== 2) continue;

    const participantRefs = participantIds.map((uid) => doc.ref.collection('participants').doc(uid));
    const participantSnaps = await Promise.all(participantRefs.map((ref) => ref.get()));
    const participantStates = Object.fromEntries(
      participantSnaps.map((snapItem, index) => [participantIds[index], snapItem.data() || {}]),
    );
    const portfolios = await Promise.all(participantIds.map((uid) => loadPortfolio(uid)));
    const portfolioByUid = Object.fromEntries(portfolios.map((portfolio) => [portfolio.uid, portfolio]));
    const now = new Date();

    await db.runTransaction(async (transaction) => {
      const freshDuel = await transaction.get(doc.ref);
      if (!freshDuel.exists || freshDuel.data()?.status !== 'active') {
        return;
      }

      for (const uid of participantIds) {
        const state = participantStates[uid] || {};
        const portfolio = portfolioByUid[uid];
        const metrics = computeMetrics(portfolio, asNumber(state.startingTotalCapital, 0));
        const highConcentrationDays = updateHighConcentrationDays(state.highConcentrationDays, {
          now,
          maxPositionWeight: metrics.maxPositionWeight,
        });
        const persistentPenalty = persistentConcentrationPenaltyFromDays(
          highConcentrationDays.length,
        );
        const adjustedScore =
          metrics.pureReturnPct +
          metrics.structureBonus -
          metrics.concentrationPenalty -
          persistentPenalty;
        const capitalTimeline = appendCapitalTimeline(state.capitalTimeline, {
          now,
          totalCapital: portfolio.totalCapital,
          score: adjustedScore,
          returnPct: metrics.returnPct,
        });
        const teaserHolding = pickTransferredHolding(portfolio.holdings, `${doc.id}:${uid}`);

        transaction.set(doc.ref.collection('participants').doc(uid), {
          currentReturnPctCache: metrics.returnPct,
          currentScoreCache: adjustedScore,
          currentHoldingsValueCache: portfolio.holdingsValue,
          currentReserveCoinsCache: portfolio.reserveCoins,
          currentTotalCapitalCache: portfolio.totalCapital,
          currentPositionsCountCache: portfolio.positionsCount,
          currentUpdatedAt: FieldValue.serverTimestamp(),
          teaserLine: teaserHolding || null,
          persistentConcentrationPenalty: persistentPenalty,
          highConcentrationDays,
          capitalTimeline,
        }, {merge: true});
      }
    });
  }
}

async function settleDuel(doc) {
  const duel = doc.data();
  if (duel.status !== 'active') return false;
  const participantIds = Array.isArray(duel.participants) ? duel.participants : [];
  if (participantIds.length !== 2) {
    console.warn(`[duels] Duel ${doc.id} invalide: participants incomplets.`);
    return false;
  }

  const participantRefs = participantIds.map((uid) => doc.ref.collection('participants').doc(uid));
  const participantSnaps = await Promise.all(participantRefs.map((ref) => ref.get()));
  const participantStates = Object.fromEntries(
    participantSnaps.map((snap, index) => [participantIds[index], snap.data() || {}]),
  );
  const portfolios = await Promise.all(participantIds.map((uid) => loadPortfolio(uid)));
  const portfolioByUid = Object.fromEntries(portfolios.map((portfolio) => [portfolio.uid, portfolio]));

  const resultByUid = Object.fromEntries(
    participantIds.map((uid) => {
      const baseline = asNumber(participantStates[uid]?.startingTotalCapital, 0);
      const metrics = computeMetrics(portfolioByUid[uid], baseline);
      const highConcentrationDays = updateHighConcentrationDays(
        participantStates[uid]?.highConcentrationDays,
        {
          now: new Date(),
          maxPositionWeight: metrics.maxPositionWeight,
        },
      );
      const persistentPenalty = persistentConcentrationPenaltyFromDays(
        highConcentrationDays.length,
      );
      return [uid, {
        ...metrics,
        persistentConcentrationPenalty: persistentPenalty,
        finalScore:
          metrics.pureReturnPct +
          metrics.structureBonus -
          metrics.concentrationPenalty -
          persistentPenalty,
      }];
    }),
  );

  const [firstUid, secondUid] = participantIds;
  const left = resultByUid[firstUid];
  const right = resultByUid[secondUid];
  const comparison = compareScores(left, right);
  const winnerUid = comparison >= 0 ? firstUid : secondUid;
  const loserUid = winnerUid === firstUid ? secondUid : firstUid;
  const winnerPortfolio = portfolioByUid[winnerUid];
  const loserPortfolio = portfolioByUid[loserUid];
  const transferred = pickTransferredHolding(loserPortfolio.holdings, doc.id);

  let notifiedAfterSettlement = false;

  await db.runTransaction(async (transaction) => {
    const freshDuel = await transaction.get(doc.ref);
    if (!freshDuel.exists || freshDuel.data()?.status !== 'active') {
      return;
    }

    let rewardPosition = null;
    let lossPosition = null;

    if (transferred) {
      const loserPosRef = db
        .collection('users')
        .doc(loserUid)
        .collection('games')
        .doc('portofolio')
        .collection('positions')
        .doc(transferred.symbol);
      const winnerPosRef = db
        .collection('users')
        .doc(winnerUid)
        .collection('games')
        .doc('portofolio')
        .collection('positions')
        .doc(transferred.symbol);

      const loserPosSnap = await transaction.get(loserPosRef);
      if (loserPosSnap.exists) {
        const loserData = loserPosSnap.data() || {};
        const quantity = asNumber(loserData.quantity, transferred.quantity);
        const averagePrice = asNumber(loserData.averagePrice, transferred.averagePrice);
        rewardPosition = {
          symbol: transferred.symbol,
          displayName: transferred.displayName,
          quantity,
          averagePrice,
          marketPrice: transferred.marketPrice,
          exchange: transferred.exchange,
          currency: transferred.currency,
          quoteType: transferred.quoteType,
        };
        lossPosition = rewardPosition;

        const winnerPosSnap = await transaction.get(winnerPosRef);
        if (winnerPosSnap.exists) {
          const winnerData = winnerPosSnap.data() || {};
          const winnerQty = asNumber(winnerData.quantity, 0);
          const winnerAvg = asNumber(winnerData.averagePrice, averagePrice);
          const newQty = winnerQty + quantity;
          const newAvg = newQty <= 0 ? averagePrice : (((winnerQty * winnerAvg) + (quantity * averagePrice)) / newQty);
          transaction.set(winnerPosRef, {
            ...winnerData,
            symbol: transferred.symbol,
            quantity: newQty,
            averagePrice: newAvg,
            displayName: winnerData.displayName || transferred.displayName,
            exchange: winnerData.exchange || transferred.exchange,
            currency: winnerData.currency || transferred.currency,
            quoteType: winnerData.quoteType || transferred.quoteType,
            lastUpdated: FieldValue.serverTimestamp(),
          }, {merge: true});
        } else {
          transaction.set(winnerPosRef, {
            ...loserData,
            symbol: transferred.symbol,
            quantity,
            averagePrice,
            displayName: loserData.displayName || transferred.displayName,
            exchange: loserData.exchange || transferred.exchange,
            currency: loserData.currency || transferred.currency,
            quoteType: loserData.quoteType || transferred.quoteType,
            lastUpdated: FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        transaction.delete(loserPosRef);
      }
    }

    transaction.set(doc.ref, {
      status: 'settled',
      settledAt: FieldValue.serverTimestamp(),
      winnerUid,
      loserUid,
      resultAnimationReady: true,
    }, {merge: true});

    for (const uid of participantIds) {
      const metrics = resultByUid[uid];
      const portfolio = portfolioByUid[uid];
      transaction.set(doc.ref.collection('participants').doc(uid), {
        currentReturnPctCache: metrics.returnPct,
        currentScoreCache: metrics.finalScore,
        finalReturnPct: metrics.returnPct,
        finalScore: metrics.finalScore,
        structureBonus: metrics.structureBonus,
        concentrationPenalty: metrics.concentrationPenalty,
        persistentConcentrationPenalty: metrics.persistentConcentrationPenalty,
        currentHoldingsValueCache: portfolio.holdingsValue,
        currentReserveCoinsCache: portfolio.reserveCoins,
        currentTotalCapitalCache: portfolio.totalCapital,
        result: uid === winnerUid ? 'win' : 'lose',
        rewardPosition: uid === winnerUid ? rewardPosition : null,
        lossPosition: uid === loserUid ? lossPosition : null,
      }, {merge: true});
    }

    transaction.set(
      db.collection('users').doc(winnerUid).collection('inbox').doc(`duel_finished_${doc.id}`),
      {
        type: 'duel_finished',
        title: 'Défi terminé',
        body: 'Le duel est terminé. Ouvre le dashboard pour découvrir le verdict.',
        createdAt: FieldValue.serverTimestamp(),
        requestId: null,
        duelId: doc.id,
        actorUid: loserUid,
        isRead: false,
      },
      {merge: true},
    );
    transaction.set(
      db.collection('users').doc(loserUid).collection('inbox').doc(`duel_finished_${doc.id}`),
      {
        type: 'duel_finished',
        title: 'Défi terminé',
        body: 'Le duel est terminé. Ouvre le dashboard pour découvrir le verdict.',
        createdAt: FieldValue.serverTimestamp(),
        requestId: null,
        duelId: doc.id,
        actorUid: winnerUid,
        isRead: false,
      },
      {merge: true},
    );

    notifiedAfterSettlement = !freshDuel.data()?.resultNotifiedAt;
  });

  if (notifiedAfterSettlement) {
    await notifySettledDuel(doc.id, {
      winnerUid,
      loserUid,
    });
  }

  console.log(`[duels] Duel ${doc.id} settled winner=${winnerUid} loser=${loserUid}`);
  return true;
}

async function notifySettledDuel(
  duelId,
  {winnerUid, loserUid},
) {
  await Promise.all([
    pushToUser(winnerUid, {
      title: 'Duel terminé',
      body: 'Le duel est terminé. Ouvre FinHub pour découvrir le verdict.',
      data: {type: 'duel_finished', duelId},
    }).catch((error) => {
      console.warn(`[duels] Push résultat gagnant ${duelId} impossible:`, error.message);
    }),
    pushToUser(loserUid, {
      title: 'Duel terminé',
      body: 'Le duel est terminé. Ouvre FinHub pour découvrir le verdict.',
      data: {type: 'duel_finished', duelId},
    }).catch((error) => {
      console.warn(`[duels] Push résultat perdant ${duelId} impossible:`, error.message);
    }),
  ]);

  await db.collection('duels').doc(duelId).set({
    resultNotifiedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function retryPendingResultNotifications() {
  const snap = await db
    .collection('duels')
    .where('status', 'in', ['settled', 'reward_revealed'])
    .limit(30)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resultNotifiedAt) continue;
    if (!data.winnerUid || !data.loserUid) continue;
    await notifySettledDuel(doc.id, {
      winnerUid: data.winnerUid,
      loserUid: data.loserUid,
    });
  }
}

async function processActiveDuels() {
  const now = new Date();
  const snap = await db
    .collection('duels')
    .where('status', '==', 'active')
    .where('endsAt', '<=', now)
    .limit(20)
    .get();

  for (const doc of snap.docs) {
    try {
      await settleDuel(doc);
    } catch (error) {
      console.error(`[duels] Erreur règlement ${doc.id}:`, error);
    }
  }
}

async function main() {
  console.log('[duels] Début du worker duel');
  await processPendingRequests();
  await processRefusedRequests();
  await processConvertedRequests();
  await refreshActiveDuelSnapshots();
  await processActiveDuels();
  await retryPendingResultNotifications();
  console.log('[duels] Worker duel terminé');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error('[duels] Erreur fatale:', error);
  process.exit(1);
});
