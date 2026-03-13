#!/usr/bin/env node
/**
 * Notification quotidienne des cours de l'or et du pétrole.
 * Déclenché par GitHub Actions plusieurs fois autour de 9h30 Paris.
 * Le script privilégie l'envoi dans [9h30, 10h00[, mais autorise une
 * fenêtre de rattrapage jusqu'à 11h00 Paris si GitHub exécute le cron en retard.
 * Les tests manuels n'occupent plus le "slot" automatique du jour.
 * SAUF si TRIGGER=workflow_dispatch (test manuel) → envoi immédiat sans vérification.
 *
 * Variables d'environnement :
 *   FIREBASE_SERVICE_ACCOUNT  — JSON string du compte de service
 *   FIREBASE_PROJECT_ID       — ID du projet Firebase
 *   TRIGGER                   — injecté par le workflow ("schedule" | "workflow_dispatch")
 */

import admin from 'firebase-admin';

// ─── 1. Fenêtre horaire Paris ───────────────────────────────────────────────

const isManual = process.env.TRIGGER === 'workflow_dispatch';
const now = new Date();
const parts = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris',
  hour: 'numeric',
  minute: 'numeric',
  hour12: false,
}).formatToParts(now);
const parisHour   = parseInt(parts.find(p => p.type === 'hour').value,   10);
const parisMinute = parseInt(parts.find(p => p.type === 'minute').value, 10);
const parisTotal  = parisHour * 60 + parisMinute;

const primaryStart = 9 * 60 + 30;
const primaryEnd = 10 * 60;
const catchUpEnd = 11 * 60;

if (!isManual && (parisTotal < primaryStart || parisTotal >= catchUpEnd)) {
  console.log(
    `[metals] Heure Paris : ${parisHour}h${String(parisMinute).padStart(2, '0')} — hors fenêtre 9h30-11h00, skip.`,
  );
  process.exit(0);
}

console.log(
  `[metals] Heure Paris : ${parisHour}h${String(parisMinute).padStart(2, '0')} — ${
    isManual
      ? 'test manuel, fenêtre ignorée'
      : parisTotal < primaryEnd
      ? 'dans la fenêtre principale'
      : 'fenêtre de rattrapage'
  }, vérifications en cours…`,
);

// ─── 2. Firebase ────────────────────────────────────────────────────────────

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId           = process.env.FIREBASE_PROJECT_ID;

if (!serviceAccountJson || !projectId) {
  console.error('[metals] FIREBASE_SERVICE_ACCOUNT ou FIREBASE_PROJECT_ID manquant.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  projectId,
});

const db = admin.firestore();
const MAX_BROADCASTS = 80;

// ─── 3. Clé date (Europe/Paris) ─────────────────────────────────────────────

function dateKey(date) {
  const p = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Europe/Paris',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const d = Object.fromEntries(p.map(x => [x.type, x.value]));
  return `${d.year}${d.month}${d.day}`;
}

const todayKey     = dateKey(now);
const yesterdayKey = dateKey(new Date(now.getTime() - 86_400_000));

// ─── 4. Fetch prix (Yahoo Finance) ──────────────────────────────────────────

async function fetchSpot(symbol) {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=1d`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; fintech-bot/1.0)' },
  });
  if (!res.ok) throw new Error(`Yahoo Finance ${symbol} → HTTP ${res.status}`);
  const json = await res.json();
  const price = json?.chart?.result?.[0]?.meta?.regularMarketPrice;
  if (!price) throw new Error(`Prix introuvable pour ${symbol}`);
  return price;
}

// ─── 5. Formatage ───────────────────────────────────────────────────────────

function formatVariation(current, previous) {
  if (previous == null || previous === 0) return '';
  const pct = ((current - previous) / previous) * 100;
  const sign = pct >= 0 ? '+' : '';
  return ` (${sign}${pct.toFixed(2)}%)`;
}

function formatPrice(value, decimals = 2) {
  return value.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

async function pruneOldBroadcasts(limit = MAX_BROADCASTS) {
  const snap = await db.collection('broadcasts').get();
  if (snap.size <= limit) {
    return;
  }

  const overflow = [...snap.docs]
    .sort((left, right) => {
      const leftDate = left.data()?.createdAt?.toDate?.() ?? new Date(0);
      const rightDate = right.data()?.createdAt?.toDate?.() ?? new Date(0);
      return rightDate - leftDate;
    })
    .slice(limit);
  for (const doc of overflow) {
    await doc.ref.delete();
    console.log(`[metals] Broadcast supprime: ${doc.id}`);
  }
}

// ─── 6. Main ────────────────────────────────────────────────────────────────

async function main() {
  const todayRef = db.collection('metalsPrices').doc(todayKey);
  const todayDoc = await todayRef.get();
  const todayData = todayDoc.data() ?? {};

  if (!isManual && todayData.notificationSentAt) {
    console.log(`[metals] Notification déjà envoyée aujourd'hui (${todayKey}), skip.`);
    process.exit(0);
  }

  // Fetch simultané des deux cours
  const [gold, oil] = await Promise.all([
    fetchSpot('GC=F'),  // Or (Gold futures)
    fetchSpot('BZ=F'),  // Pétrole Brent
  ]);

  console.log(`[metals] Prix bruts — Or: ${gold}, Pétrole: ${oil}`);

  // Lire les prix de la veille
  const prevDoc  = await db.collection('metalsPrices').doc(yesterdayKey).get();
  const prevGold = prevDoc.data()?.gold ?? null;
  const prevOil = prevDoc.data()?.oil ?? null;

  const goldVar = formatVariation(gold, prevGold);
  const oilVar = formatVariation(oil, prevOil);

  // Écrire les prix du jour
  await todayRef.set({
    gold,
    oil,
    fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Heure Paris affichée dans la notif
  const timeStr = `${parisHour}h${String(parisMinute).padStart(2, '0')}`;

  const body =
    `🥇 Or : ${formatPrice(gold)} $/oz${goldVar}\n` +
    `🛢️ Pétrole : ${formatPrice(oil)} $/baril${oilVar}`;

  // Envoi FCM au topic
  const message = {
    topic: 'daily_metals',
    notification: {
      title: `Or & pétrole — ${timeStr}`,
      body,
    },
    apns: {
      headers: {
        'apns-push-type': 'alert',
        'apns-priority': '10',
      },
      payload: {
        aps: { sound: 'default' },
      },
    },
    data: {
      type:   'daily_metals',
      gold:   String(gold),
      oil:    String(oil),
      date:   todayKey,
    },
  };

  const response = await admin.messaging().send(message);
  await todayRef.set(
    isManual
      ? {
          manualTestSentAt: admin.firestore.FieldValue.serverTimestamp(),
          manualTestMessageId: response,
          manualTestTrigger: process.env.TRIGGER ?? 'unknown',
          manualTestHourParis: timeStr,
        }
      : {
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
          notificationMessageId: response,
          notificationTrigger: process.env.TRIGGER ?? 'unknown',
          notificationSentHourParis: timeStr,
        },
    { merge: true },
  );

  try {
    await db.collection('broadcasts').add({
      title: `Or & pétrole — ${timeStr}`,
      body,
      topic: 'daily_metals',
      type: 'daily_metals',
      trigger: process.env.TRIGGER ?? 'unknown',
      gold,
      oil,
      dateKey: todayKey,
      messageId: response,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await pruneOldBroadcasts();
  } catch (error) {
    console.warn('[metals] Notification envoyee mais sauvegarde Firestore impossible:', error);
  }
  console.log(`[metals] Notification envoyée : ${response}`);
  console.log(`[metals] Or ${formatPrice(gold)}${goldVar} | Pétrole ${formatPrice(oil)}${oilVar}`);
}

main().catch(err => {
  console.error('[metals] Erreur :', err);
  process.exit(1);
});
