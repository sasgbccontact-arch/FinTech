#!/usr/bin/env node
/**
 * Build the current weekly leaderboard from tracked user activity.
 *
 * Inputs:
 *   users/{uid}
 *   users/{uid}/activity_daily/{yyyyMMdd}
 *
 * Outputs:
 *   leaderboards/weekly
 *   leaderboards/weekly/entries/{uid}
 *   leaderboards_history/{weekKey}
 *   leaderboards_history/{weekKey}/entries/{uid}
 *
 * Environment variables:
 *   FIREBASE_SERVICE_ACCOUNT
 *   FIREBASE_PROJECT_ID
 */

import admin from 'firebase-admin';

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId = process.env.FIREBASE_PROJECT_ID;

if (!serviceAccountJson || !projectId) {
  console.error('Missing FIREBASE_SERVICE_ACCOUNT or FIREBASE_PROJECT_ID');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  projectId,
});

const db = admin.firestore();
const USERS_COLLECTION = 'users';
const CURRENT_LEADERBOARD_DOC = db.collection('leaderboards').doc('weekly');
const HISTORY_COLLECTION = db.collection('leaderboards_history');

function parisDateParts(date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  }).formatToParts(date);
  const map = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(map.year),
    month: Number(map.month),
    day: Number(map.day),
    weekday: map.weekday,
  };
}

function dateFromParts(parts) {
  return new Date(Date.UTC(parts.year, parts.month - 1, parts.day, 12, 0, 0));
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 86_400_000);
}

function formatIsoDate(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatDateKey(date) {
  return formatIsoDate(date).replaceAll('-', '');
}

function formatFrenchDate(date) {
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: '2-digit',
  }).format(date);
}

function weekMeta(now) {
  const parts = parisDateParts(now);
  const weekdayIndex = {
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
    Sun: 7,
  }[parts.weekday];

  const today = dateFromParts(parts);
  const monday = addDays(today, -(weekdayIndex - 1));
  const sunday = addDays(today, 7 - weekdayIndex);
  const previousMonday = addDays(monday, -7);
  const previousSunday = addDays(sunday, -7);

  return {
    today,
    weekKey: `${formatIsoDate(monday)}_${formatIsoDate(sunday)}`,
    previousWeekKey:
      `${formatIsoDate(previousMonday)}_${formatIsoDate(previousSunday)}`,
    startDate: monday,
    endDate: sunday,
    throughDate: today,
    throughDateKey: formatDateKey(today),
    label: `Semaine du ${formatFrenchDate(monday)} au ${formatFrenchDate(sunday)}`,
    throughLabel: formatFrenchDate(today),
    previousWeekLabel:
      `Semaine du ${formatFrenchDate(previousMonday)} au ${formatFrenchDate(previousSunday)}`,
  };
}

function buildDateKeys(startDate, endDate) {
  const keys = [];
  for (let cursor = startDate; cursor <= endDate; cursor = addDays(cursor, 1)) {
    keys.push(formatDateKey(cursor));
  }
  return keys;
}

function displayName(data) {
  const primary = typeof data.Name === 'string' ? data.Name.trim() : '';
  if (primary) return primary;
  const fallback = typeof data.name === 'string' ? data.name.trim() : '';
  if (fallback) return fallback;
  return 'Utilisateur';
}

function cleanList(value, limit = 4) {
  return (Array.isArray(value) ? value : [])
    .map((item) => String(item).trim())
    .filter(Boolean)
    .slice(0, limit);
}

function toInt(value) {
  return typeof value === 'number' ? Math.trunc(value) : 0;
}

function mergeCounters(sourceList) {
  const merged = {};
  for (const source of sourceList) {
    for (const [key, value] of Object.entries(source || {})) {
      merged[key] = (merged[key] || 0) + toInt(value);
    }
  }
  return merged;
}

async function loadPreviousEntries(previousWeekKey) {
  const snapshot = await HISTORY_COLLECTION.doc(previousWeekKey)
    .collection('entries')
    .get();
  return new Map(snapshot.docs.map((doc) => [doc.id, doc.data()]));
}

async function loadWeeklyActivity(uid, dateKeys) {
  if (dateKeys.length === 0) {
    return {
      score: 0,
      eventsCount: 0,
      activityDays: 0,
      counters: {},
    };
  }

  const snapshot = await db
    .collection(USERS_COLLECTION)
    .doc(uid)
    .collection('activity_daily')
    .where('dateKey', 'in', dateKeys)
    .get();

  const docs = snapshot.docs.map((doc) => doc.data());
  const counters = mergeCounters(docs.map((data) => data.counters));

  let score = 0;
  let eventsCount = 0;
  let activityDays = 0;

  docs.forEach((data) => {
    score += toInt(data.score);
    eventsCount += toInt(data.eventsCount);
    if (toInt(data.eventsCount) > 0 || toInt(data.score) > 0) {
      activityDays += 1;
    }
  });

  return {
    score,
    eventsCount,
    activityDays,
    counters,
  };
}

function rankMovement(previousRank, currentRank) {
  if (!previousRank) return null;
  return previousRank - currentRank;
}

function toEntry({doc, meta, activity, previousEntry}) {
  const data = doc.data() ?? {};
  if (data.profile_public === false) return null;
  if (!displayName(data)) return null;
  if (activity.score <= 0 && activity.eventsCount <= 0) return null;

  const xp = toInt(data.xp);
  const streak = toInt(data.current_streak);
  const previousScore = previousEntry ? toInt(previousEntry.score) : null;

  return {
    uid: doc.id,
    name: displayName(data),
    avatar_id: typeof data.avatar_id === 'string' ? data.avatar_id : null,
    xp,
    current_streak: streak,
    profile_public: true,
    achievements_claimed: cleanList(data.achievements_claimed, 12),
    interests: cleanList(data.interests, 4),
    experience_level:
      typeof data.experience_level === 'string' ? data.experience_level : null,
    starter_path:
      typeof data.starter_path === 'string' ? data.starter_path : null,
    score: activity.score,
    eventsCount: activity.eventsCount,
    activityDays: activity.activityDays,
    weeklyBreakdown: activity.counters,
    previousScore,
    deltaVsLastWeek:
      previousScore == null ? null : activity.score - previousScore,
    previousRank: previousEntry ? toInt(previousEntry.rank) : null,
    weekKey: meta.weekKey,
    previousWeekKey: meta.previousWeekKey,
    throughDateKey: meta.throughDateKey,
    scoreFormula: 'sum(users/{uid}/activity_daily.score) for current Paris week',
  };
}

async function replaceEntries(parentDoc, entries, metaPayload) {
  const existing = await parentDoc.collection('entries').get();
  let batch = db.batch();
  let opCount = 0;

  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  batch.set(
    parentDoc,
    {
      ...metaPayload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  opCount += 1;

  for (const doc of existing.docs) {
    batch.delete(doc.ref);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }

  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const rank = index + 1;
    batch.set(parentDoc.collection('entries').doc(entry.uid), {
      ...entry,
      rank,
      rankMovement: rankMovement(entry.previousRank, rank),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }

  await flush();
}

async function main() {
  const meta = weekMeta(new Date());
  const dateKeys = buildDateKeys(meta.startDate, meta.throughDate);
  const usersSnapshot = await db.collection(USERS_COLLECTION).get();
  const previousEntries = await loadPreviousEntries(meta.previousWeekKey);

  const rawEntries = await Promise.all(
    usersSnapshot.docs.map(async (doc) => {
      const activity = await loadWeeklyActivity(doc.id, dateKeys);
      return toEntry({
        doc,
        meta,
        activity,
        previousEntry: previousEntries.get(doc.id) ?? null,
      });
    }),
  );

  const entries = rawEntries
    .filter(Boolean)
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (b.activityDays !== a.activityDays) {
        return b.activityDays - a.activityDays;
      }
      if (b.eventsCount !== a.eventsCount) {
        return b.eventsCount - a.eventsCount;
      }
      if (b.current_streak !== a.current_streak) {
        return b.current_streak - a.current_streak;
      }
      return b.xp - a.xp;
    })
    .slice(0, 200);

  const metaPayload = {
    weekKey: meta.weekKey,
    previousWeekKey: meta.previousWeekKey,
    label: meta.label,
    previousWeekLabel: meta.previousWeekLabel,
    mode: 'activity_week_live',
    formula: 'sum(activity_daily.score) + tie breaks on activity days, events, streak, xp',
    startsAt: admin.firestore.Timestamp.fromDate(meta.startDate),
    endsAt: admin.firestore.Timestamp.fromDate(meta.endDate),
    throughDateKey: meta.throughDateKey,
    throughLabel: meta.throughLabel,
    entryCount: entries.length,
  };

  await replaceEntries(CURRENT_LEADERBOARD_DOC, entries, metaPayload);
  await replaceEntries(HISTORY_COLLECTION.doc(meta.weekKey), entries, metaPayload);

  console.log(
    `[leaderboard] Updated ${entries.length} activity-based entries for ${meta.weekKey} through ${meta.throughDateKey}`,
  );
  if (entries.length > 0) {
    console.log(
      `[leaderboard] Top 3: ${entries
        .slice(0, 3)
        .map((entry) => `${entry.name} (${entry.score})`)
        .join(', ')}`,
    );
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error('[leaderboard] Failed:', error);
  process.exit(1);
});
