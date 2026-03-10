#!/usr/bin/env node
/**
 * Notification quotidienne des cours de l'or et de l'argent.
 * Déclenché par GitHub Actions (2 crons : 7h25 UTC et 8h25 UTC).
 * Le script vérifie que l'heure de Paris est dans [9h15, 9h55] avant d'envoyer,
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

if (!isManual && (parisTotal < 9 * 60 + 15 || parisTotal > 9 * 60 + 55)) {
  console.log(
    `[metals] Heure Paris : ${parisHour}h${String(parisMinute).padStart(2, '0')} — hors fenêtre 9h15-9h55, skip.`,
  );
  process.exit(0);
}

console.log(
  `[metals] Heure Paris : ${parisHour}h${String(parisMinute).padStart(2, '0')} — ${isManual ? 'test manuel, fenêtre ignorée' : 'dans la fenêtre'}, envoi en cours…`,
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

// ─── 6. Main ────────────────────────────────────────────────────────────────

async function main() {
  // Fetch simultané des deux cours
  const [gold, silver] = await Promise.all([
    fetchSpot('GC=F'),  // Or (Gold futures)
    fetchSpot('SI=F'),  // Argent (Silver futures)
  ]);

  console.log(`[metals] Prix bruts — Or: ${gold}, Argent: ${silver}`);

  // Lire les prix de la veille
  const prevDoc  = await db.collection('metalsPrices').doc(yesterdayKey).get();
  const prevGold   = prevDoc.data()?.gold   ?? null;
  const prevSilver = prevDoc.data()?.silver ?? null;

  const goldVar   = formatVariation(gold,   prevGold);
  const silverVar = formatVariation(silver, prevSilver);

  // Écrire les prix du jour
  await db.collection('metalsPrices').doc(todayKey).set({
    gold,
    silver,
    fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Heure Paris affichée dans la notif
  const timeStr = `${parisHour}h${String(parisMinute).padStart(2, '0')}`;

  const body =
    `🥇 Or : ${formatPrice(gold)} $/oz${goldVar}\n` +
    `🥈 Argent : ${formatPrice(silver, 3)} $/oz${silverVar}`;

  // Envoi FCM au topic
  const message = {
    topic: 'daily_metals',
    notification: {
      title: `Cours des métaux — ${timeStr}`,
      body,
    },
    apns: {
      payload: {
        aps: { sound: 'default' },
      },
    },
    data: {
      type:   'daily_metals',
      gold:   String(gold),
      silver: String(silver),
      date:   todayKey,
    },
  };

  const response = await admin.messaging().send(message);
  console.log(`[metals] Notification envoyée : ${response}`);
  console.log(`[metals] Or ${formatPrice(gold)}${goldVar} | Argent ${formatPrice(silver, 3)}${silverVar}`);
}

main().catch(err => {
  console.error('[metals] Erreur :', err);
  process.exit(1);
});
