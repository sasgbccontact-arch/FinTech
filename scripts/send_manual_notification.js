#!/usr/bin/env node
/**
 * Envoi d'une notification push manuelle à tous les utilisateurs abonnés
 * au topic "all_users".
 *
 * Variables d'environnement (injectées par le workflow GitHub Actions) :
 *   FIREBASE_SERVICE_ACCOUNT  — JSON string du compte de service
 *   FIREBASE_PROJECT_ID       — ID du projet Firebase
 *   NOTIF_TITLE               — Titre de la notification
 *   NOTIF_BODY                — Corps du message
 */

import admin from 'firebase-admin';

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId           = process.env.FIREBASE_PROJECT_ID;
const title               = process.env.NOTIF_TITLE?.trim();
const body                = process.env.NOTIF_BODY?.trim();

if (!serviceAccountJson || !projectId) {
  console.error('[manual-notif] FIREBASE_SERVICE_ACCOUNT ou FIREBASE_PROJECT_ID manquant.');
  process.exit(1);
}
if (!title || !body) {
  console.error('[manual-notif] NOTIF_TITLE ou NOTIF_BODY manquant.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  projectId,
});

const db = admin.firestore();

const message = {
  topic: 'all_users',
  notification: { title, body },
  apns: {
    headers: {
      'apns-push-type': 'alert',
      'apns-priority': '10',
    },
    payload: { aps: { sound: 'default' } },
  },
  data: { type: 'manual' },
};

const response = await admin.messaging().send(message);

try {
  await db.collection('broadcasts').add({
    title,
    body,
    topic: 'all_users',
    type: 'manual',
    messageId: response,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
} catch (error) {
  console.warn('[manual-notif] Notification envoyee mais sauvegarde Firestore impossible:', error);
}

console.log(`[manual-notif] Notification envoyée : ${response}`);
console.log(`[manual-notif] Titre : "${title}"`);
console.log(`[manual-notif] Corps : "${body}"`);
