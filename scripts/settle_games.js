#!/usr/bin/env node
/**
 * Worker de règlement des jeux communautaires.
 * - Lit les jeux community_games en state=open avec deadline dépassée
 * - Récupère le dernier cours Yahoo
 * - Détermine le camp gagnant et calcule les payouts
 * - Ferme le jeu et écrit le résultat + payouts dans participants
 *
 * Variables d'environnement attendues :
 * FIREBASE_SERVICE_ACCOUNT (JSON string du compte de service)
 * FIREBASE_PROJECT_ID
 */

import admin from 'firebase-admin';

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId = process.env.FIREBASE_PROJECT_ID;
if (!serviceAccountJson || !projectId) {
  console.error('Missing FIREBASE_SERVICE_ACCOUNT or FIREBASE_PROJECT_ID');
  process.exit(1);
}

const credentials = JSON.parse(serviceAccountJson);

admin.initializeApp({
  credential: admin.credential.cert(credentials),
  projectId,
});

const db = admin.firestore();

async function fetchPrice(ticker) {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(
    ticker,
  )}?range=5d&interval=1d`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const closes = data?.chart?.result?.[0]?.indicators?.quote?.[0]?.close;
  if (Array.isArray(closes)) {
    const last = closes.filter((v) => typeof v === 'number').pop();
    if (typeof last === 'number') return last;
  }
  throw new Error('No close price');
}

function pickWinner(game, price) {
  switch (game.type) {
    case 'target': {
      const target = game.targetPrice;
      const bandPct = game.bandPct ?? 0.01;
      if (target == null) return null;
      const lower = target * (1 - bandPct);
      const upper = target * (1 + bandPct);
      return price >= lower && price <= upper ? 'long' : 'short';
    }
    case 'duel': {
      const entry = game.entryPrice ?? targetPriceFallback(game);
      if (entry == null || entry === 0) return null;
      return price >= entry ? 'long' : 'short';
    }
    case 'range': {
      const low = game.rangeLow;
      const high = game.rangeHigh;
      if (low == null || high == null) return null;
      return price >= low && price <= high ? 'long' : 'short';
    }
    default:
      return null;
  }
}

function targetPriceFallback(game) {
  if (game.targetPrice) return game.targetPrice;
  return null;
}

async function settleGame(doc) {
  const data = doc.data();
  const game = {
    id: doc.id,
    type: data.type,
    ticker: data.ticker,
    targetPrice: data.targetPrice,
    bandPct: data.bandPct,
    entryPrice: data.entryPrice,
    rangeLow: data.rangeLow,
    rangeHigh: data.rangeHigh,
    longPool: data.longPool ?? 0,
    shortPool: data.shortPool ?? 0,
  };

  let price;
  try {
    price = await fetchPrice(game.ticker);
  } catch (e) {
    console.error(`Price fetch failed for ${game.ticker}:`, e);
    return;
  }

  const winner = pickWinner(game, price);
  if (!winner) {
    console.error(`No winner computed for game ${game.id}`);
    return;
  }

  const participantsSnap = await doc.ref.collection('participants').get();
  const participants = participantsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const winners = participants.filter((p) => p.side === winner);
  const losers = participants.filter((p) => p.side !== winner);
  const totalPool = (game.longPool || 0) + (game.shortPool || 0);
  const winningStake = winners.reduce((sum, p) => sum + (p.stake || 0), 0);

  const batch = db.batch();

  winners.forEach((p) => {
    const stake = p.stake || 0;
    const payout = winningStake > 0 ? (stake / winningStake) * totalPool : 0;
    batch.set(doc.ref.collection('participants').doc(p.id), { payout, result: 'win' }, { merge: true });
  });

  losers.forEach((p) => {
    batch.set(doc.ref.collection('participants').doc(p.id), { payout: 0, result: 'lose' }, { merge: true });
  });

  batch.update(doc.ref, {
    state: 'closed',
    settledAt: admin.firestore.FieldValue.serverTimestamp(),
    settlementPrice: price,
    winningSide: winner,
    totalPool,
    totalDistributed: totalPool,
    losersCount: losers.length,
    winnersCount: winners.length,
  });

  await batch.commit();
  console.log(`Settled game ${game.id} (${game.ticker}) winner=${winner} price=${price}`);
}

async function main() {
  const now = Date.now();
  const snap = await db
      .collection('community_games')
      .where('state', '==', 'open')
      .where('deadline', '<=', new Date(now))
      .limit(50)
      .get();

  if (snap.empty) {
    console.log('No games to settle.');
    return;
  }

  for (const doc of snap.docs) {
    try {
      await settleGame(doc);
    } catch (e) {
      console.error(`Error settling ${doc.id}:`, e);
    }
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
