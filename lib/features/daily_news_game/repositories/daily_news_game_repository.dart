import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fintech/services/activity_tracking_service.dart';

import '../models/news_article.dart';
import '../services/gdelt_news_service.dart';

enum DailyNewsGameMode { actus, monde }

extension DailyNewsGameModeX on DailyNewsGameMode {
  String get modeKey => this == DailyNewsGameMode.actus ? 'actus' : 'monde';

  String get sessionCollection =>
      this == DailyNewsGameMode.actus
          ? 'dailyNewsSessions'
          : 'countryNewsSessions';

  int get costGems => this == DailyNewsGameMode.actus ? 50 : 100;
}

class SessionStartResult {
  final bool success;
  final String? sessionId;
  final int currentGems;
  final int requiredGems;
  final int chargedGems;
  final bool usedFreeEntry;

  const SessionStartResult._({
    required this.success,
    required this.sessionId,
    required this.currentGems,
    required this.requiredGems,
    required this.chargedGems,
    required this.usedFreeEntry,
  });

  factory SessionStartResult.success({
    required String sessionId,
    required int currentGems,
    required int requiredGems,
    required int chargedGems,
    required bool usedFreeEntry,
  }) {
    return SessionStartResult._(
      success: true,
      sessionId: sessionId,
      currentGems: currentGems,
      requiredGems: requiredGems,
      chargedGems: chargedGems,
      usedFreeEntry: usedFreeEntry,
    );
  }

  factory SessionStartResult.insufficient({
    required int currentGems,
    required int requiredGems,
    required bool usedFreeEntry,
  }) {
    return SessionStartResult._(
      success: false,
      sessionId: null,
      currentGems: currentGems,
      requiredGems: requiredGems,
      chargedGems: 0,
      usedFreeEntry: usedFreeEntry,
    );
  }
}

class DailyArticlesResult {
  final List<NewsArticle> articles;
  final bool fetchFailed;
  final bool cacheHit;
  final String sourceType;
  final String lang;
  final List<String> queriesTried;

  const DailyArticlesResult({
    required this.articles,
    required this.fetchFailed,
    this.cacheHit = false,
    this.sourceType = 'none',
    this.lang = 'en',
    this.queriesTried = const <String>[],
  });
}

class CountryArticleResult {
  final NewsArticle? article;
  final bool cacheHit;
  final String sourceType;
  final String lang;
  final String? queryUsed;
  final List<String> queriesTried;
  final int bestScore;

  const CountryArticleResult({
    required this.article,
    this.cacheHit = false,
    this.sourceType = 'none',
    this.lang = 'en',
    this.queryUsed,
    this.queriesTried = const <String>[],
    this.bestScore = 0,
  });
}

class _MemoryEntry<T> {
  final T value;
  final DateTime storedAt;

  const _MemoryEntry(this.value, this.storedAt);
}

class DailyNewsGameRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _gdelt = GdeltNewsService();

  static const Duration dailyCacheTtl = Duration(hours: 6);
  static const Duration countryCacheTtl = Duration(hours: 12);

  static const int _maxMemoryEntries = 20;

  final LinkedHashMap<String, _MemoryEntry<DailyArticlesResult>> _dailyMemory =
      LinkedHashMap<String, _MemoryEntry<DailyArticlesResult>>();
  final LinkedHashMap<String, _MemoryEntry<CountryArticleResult>>
  _countryMemory = LinkedHashMap<String, _MemoryEntry<CountryArticleResult>>();

  final Map<String, Future<DailyArticlesResult>> _dailyInFlight = {};
  final Map<String, Future<CountryArticleResult>> _countryInFlight = {};

  String get _uid => _auth.currentUser!.uid;

  String _dayKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  String _dailyCacheId() => 'daily_${_dayKey()}';

  String _countryCacheId(String iso2) =>
      'country_${_dayKey()}_${iso2.trim().toUpperCase()}';

  DocumentReference<Map<String, dynamic>> _newsCacheRef(String cacheId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('newsCache')
        .doc(cacheId);
  }

  DocumentReference<Map<String, dynamic>> _dailyBenefitRef(String benefitId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('dailyBenefits')
        .doc(benefitId);
  }

  DocumentReference<Map<String, dynamic>> sessionRef({
    required DailyNewsGameMode mode,
    required String sessionId,
  }) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection(mode.sessionCollection)
        .doc(sessionId);
  }

  Future<SessionStartResult> startPaidSession(DailyNewsGameMode mode) async {
    final userRef = _db.collection('users').doc(_uid);
    final sessionsRef = userRef.collection(mode.sessionCollection).doc();
    final txRef = userRef.collection('economyTransactions').doc();
    final benefitRef = _dailyBenefitRef('news_${_dayKey()}');

    final result = await _db.runTransaction<SessionStartResult>((tx) async {
      final userSnap = await tx.get(userRef);
      final benefitSnap = await tx.get(benefitRef);
      final currentGems = (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
      final cost = mode.costGems;
      final modeFlag =
          mode == DailyNewsGameMode.actus
              ? 'free_actus_used'
              : 'free_monde_used';
      final freeEntryAlreadyUsed =
          (benefitSnap.data()?[modeFlag] as bool?) ?? false;
      final chargedGems = freeEntryAlreadyUsed ? cost : 0;

      if (currentGems < chargedGems) {
        return SessionStartResult.insufficient(
          currentGems: currentGems,
          requiredGems: cost,
          usedFreeEntry: !freeEntryAlreadyUsed,
        );
      }

      final remaining = currentGems - chargedGems;
      tx.set(userRef, {'gems': remaining}, SetOptions(merge: true));
      tx.set(benefitRef, {
        'dateKey': _dayKey(),
        modeFlag: true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(sessionsRef, {
        'mode': mode.modeKey,
        'createdAt': FieldValue.serverTimestamp(),
        'articles': <Map<String, dynamic>>[],
        'quiz': <Map<String, dynamic>>[],
        'answers': <Map<String, dynamic>>[],
        'score': null,
        'completedAt': null,
        'costGems': chargedGems,
        'usedFreeEntry': !freeEntryAlreadyUsed,
      });

      tx.set(txRef, {
        'type': 'daily_news_game',
        'mode': mode.modeKey,
        'costGems': chargedGems,
        'usedFreeEntry': !freeEntryAlreadyUsed,
        'sessionId': sessionsRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return SessionStartResult.success(
        sessionId: sessionsRef.id,
        currentGems: remaining,
        requiredGems: cost,
        chargedGems: chargedGems,
        usedFreeEntry: !freeEntryAlreadyUsed,
      );
    });

    if (result.success) {
      unawaited(
        ActivityTrackingService.trackForUser(
          uid: _uid,
          type: 'daily_news_session_started',
          label: mode.modeKey,
          points: result.usedFreeEntry ? 18 : 24,
          counters: <String, int>{
            'daily_news_sessions': 1,
            if (mode == DailyNewsGameMode.actus) 'daily_news_actus_sessions': 1,
            if (mode == DailyNewsGameMode.monde) 'daily_news_monde_sessions': 1,
          },
        ),
      );
      debugPrint(
        '[DailyNewsGameRepo] Session créée: mode=${mode.modeKey}, sessionId=${result.sessionId}, coût=${result.chargedGems} gemmes, gratuite=${result.usedFreeEntry}',
      );
    } else {
      debugPrint(
        '[DailyNewsGameRepo] Solde insuffisant: mode=${mode.modeKey}, gems=${result.currentGems}, requis=${result.requiredGems}',
      );
    }

    return result;
  }

  Future<void> prefetchDailyArticles() async {
    try {
      await fetchDailyArticles();
    } catch (_) {
      // no-op prefetch
    }
  }

  Future<void> prefetchCountryArticle({
    required String countryIso2,
    required String countryNameEn,
  }) async {
    try {
      await fetchCountryArticle(
        countryIso2: countryIso2,
        countryNameEn: countryNameEn,
      );
    } catch (_) {
      // no-op prefetch
    }
  }

  Future<DailyArticlesResult> fetchDailyArticles() async {
    final sw = Stopwatch()..start();
    final cacheId = _dailyCacheId();

    final mem = _takeFreshMemory(
      map: _dailyMemory,
      key: cacheId,
      ttl: dailyCacheTtl,
    );
    if (mem != null) {
      sw.stop();
      debugPrint(
        '[NewsPerf][Actus][EN] cacheHit=memory totalMs=${sw.elapsedMilliseconds} source=${mem.sourceType}',
      );
      return mem;
    }

    final inFlight = _dailyInFlight[cacheId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchDailyArticlesImpl(cacheId);
    _dailyInFlight[cacheId] = future;

    try {
      final result = await future;
      _putMemory(_dailyMemory, cacheId, _MemoryEntry(result, DateTime.now()));
      return result;
    } finally {
      _dailyInFlight.remove(cacheId);
    }
  }

  Future<CountryArticleResult> fetchCountryArticle({
    required String countryIso2,
    required String countryNameEn,
  }) async {
    final iso = countryIso2.trim().toUpperCase();
    final cacheId = _countryCacheId(iso);

    final mem = _takeFreshMemory(
      map: _countryMemory,
      key: cacheId,
      ttl: countryCacheTtl,
    );
    if (mem != null) {
      return mem;
    }

    final inFlight = _countryInFlight[cacheId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchCountryArticleImpl(
      cacheId: cacheId,
      countryIso2: iso,
      countryNameEn: countryNameEn,
    );
    _countryInFlight[cacheId] = future;

    try {
      final result = await future;
      _putMemory(_countryMemory, cacheId, _MemoryEntry(result, DateTime.now()));
      return result;
    } finally {
      _countryInFlight.remove(cacheId);
    }
  }

  Future<DailyArticlesResult> _fetchDailyArticlesImpl(String cacheId) async {
    final sw = Stopwatch()..start();

    final cached = await _readDailyCache(cacheId);
    if (cached != null) {
      sw.stop();
      debugPrint(
        '[NewsPerf][Actus][EN] cacheHit=firestore totalMs=${sw.elapsedMilliseconds} source=${cached.sourceType}',
      );
      return cached;
    }

    final fetched = await _gdelt.fetchRecentArticlesFast(limit: 3);

    if (fetched.articles.isNotEmpty && fetched.bestScore >= 45) {
      await _writeDailyCache(cacheId, fetched);
    }

    sw.stop();
    debugPrint(
      '[NewsPerf][Actus][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=${fetched.sourceType}',
    );

    return DailyArticlesResult(
      articles: fetched.articles,
      fetchFailed: fetched.articles.isEmpty,
      cacheHit: false,
      sourceType: fetched.sourceType,
      lang: fetched.lang,
      queriesTried: fetched.queriesTried,
    );
  }

  Future<CountryArticleResult> _fetchCountryArticleImpl({
    required String cacheId,
    required String countryIso2,
    required String countryNameEn,
  }) async {
    final sw = Stopwatch()..start();

    final cached = await _readCountryCache(cacheId);
    if (cached != null) {
      sw.stop();
      debugPrint(
        '[NewsPerf][Monde][$countryIso2][${cached.lang.toUpperCase()}] cacheHit=firestore totalMs=${sw.elapsedMilliseconds} source=${cached.sourceType}',
      );
      return cached;
    }

    final fetched = await _gdelt.fetchCountryArticleFast(
      countryIso2: countryIso2,
      countryNameEn: countryNameEn,
    );

    if (fetched.article != null && fetched.bestScore >= 55) {
      await _writeCountryCache(
        cacheId: cacheId,
        countryIso2: countryIso2,
        countryNameEn: countryNameEn,
        fetched: fetched,
      );
    }

    sw.stop();
    debugPrint(
      '[NewsPerf][Monde][$countryIso2][${fetched.lang.toUpperCase()}] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=${fetched.sourceType}',
    );

    return CountryArticleResult(
      article: fetched.article,
      cacheHit: false,
      sourceType: fetched.sourceType,
      lang: fetched.lang,
      queryUsed: fetched.queryUsed,
      queriesTried: fetched.queriesTried,
      bestScore: fetched.bestScore,
    );
  }

  Future<DailyArticlesResult?> _readDailyCache(String cacheId) async {
    final snap = await _newsCacheRef(cacheId).get();
    final data = snap.data();
    if (data == null) return null;

    final ts = data['fetchedAt'];
    if (!_isFresh(ts, dailyCacheTtl)) return null;

    final rawArticles =
        (data['articles'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(NewsArticle.fromFirestore)
            .toList();

    if (rawArticles.isEmpty) return null;

    return DailyArticlesResult(
      articles: rawArticles,
      fetchFailed: false,
      cacheHit: true,
      sourceType: (data['sourceType'] as String?) ?? 'cache',
      lang: (data['lang'] as String?) ?? 'en',
      queriesTried:
          (data['queriesTried'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
    );
  }

  Future<CountryArticleResult?> _readCountryCache(String cacheId) async {
    final snap = await _newsCacheRef(cacheId).get();
    final data = snap.data();
    if (data == null) return null;

    final ts = data['fetchedAt'];
    if (!_isFresh(ts, countryCacheTtl)) return null;

    final raw = data['article'];
    if (raw is! Map<String, dynamic>) return null;

    final article = NewsArticle.fromFirestore(raw);

    return CountryArticleResult(
      article: article,
      cacheHit: true,
      sourceType: (data['sourceType'] as String?) ?? 'cache',
      lang: (data['lang'] as String?) ?? 'en',
      queryUsed: data['queryUsed'] as String?,
      queriesTried:
          (data['queriesTried'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
      bestScore: (data['bestScore'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _writeDailyCache(
    String cacheId,
    DailyNewsFetchResult fetched,
  ) async {
    final data = <String, dynamic>{
      'articles': fetched.articles.map((a) => a.toFirestore()).toList(),
      'sourceType': fetched.sourceType,
      'fetchedAt': FieldValue.serverTimestamp(),
      'queriesTried': fetched.queriesTried,
      'lang': fetched.lang,
      'hash': _hashArticles(fetched.articles),
      'bestScore': fetched.bestScore,
    };

    await _newsCacheRef(cacheId).set(data, SetOptions(merge: true));
  }

  Future<void> _writeCountryCache({
    required String cacheId,
    required String countryIso2,
    required String countryNameEn,
    required CountryNewsFetchResult fetched,
  }) async {
    if (fetched.article == null) return;

    final data = <String, dynamic>{
      'article': fetched.article!.toFirestore(),
      'countryIso2': countryIso2,
      'countryNameEn': countryNameEn,
      'sourceType': fetched.sourceType,
      'fetchedAt': FieldValue.serverTimestamp(),
      'queryUsed': fetched.queryUsed,
      'queriesTried': fetched.queriesTried,
      'lang': fetched.lang,
      'hash': _hashArticles([fetched.article!]),
      'bestScore': fetched.bestScore,
    };

    await _newsCacheRef(cacheId).set(data, SetOptions(merge: true));
  }

  bool _isFresh(dynamic tsValue, Duration ttl) {
    DateTime? fetchedAt;

    if (tsValue is Timestamp) {
      fetchedAt = tsValue.toDate();
    } else if (tsValue is DateTime) {
      fetchedAt = tsValue;
    } else if (tsValue is String) {
      fetchedAt = DateTime.tryParse(tsValue);
    }

    if (fetchedAt == null) return false;

    return DateTime.now().difference(fetchedAt) <= ttl;
  }

  T? _takeFreshMemory<T>({
    required LinkedHashMap<String, _MemoryEntry<T>> map,
    required String key,
    required Duration ttl,
  }) {
    final entry = map.remove(key);
    if (entry == null) return null;

    final isFresh = DateTime.now().difference(entry.storedAt) <= ttl;
    if (!isFresh) return null;

    map[key] = entry;
    return entry.value;
  }

  void _putMemory<T>(
    LinkedHashMap<String, _MemoryEntry<T>> map,
    String key,
    _MemoryEntry<T> entry,
  ) {
    map.remove(key);
    map[key] = entry;

    while (map.length > _maxMemoryEntries) {
      map.remove(map.keys.first);
    }
  }

  String _hashArticles(List<NewsArticle> articles) {
    final raw = articles.map((a) => '${a.url}|${a.title}').join('||');
    int hash = 5381;
    for (final code in raw.codeUnits) {
      hash = ((hash << 5) + hash + code) & 0xFFFFFFFF;
    }
    return hash.toUnsigned(32).toRadixString(16);
  }

  Future<void> saveSessionArticles({
    required DailyNewsGameMode mode,
    required String sessionId,
    required List<NewsArticle> articles,
    String? countryIso2,
    String? countryNameFr,
  }) async {
    final payload = <String, dynamic>{
      'articles': articles.map((a) => a.toFirestore()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (countryIso2 != null) 'countryIso2': countryIso2.toUpperCase(),
      if (countryNameFr != null) 'countryNameFr': countryNameFr,
    };

    await sessionRef(
      mode: mode,
      sessionId: sessionId,
    ).set(payload, SetOptions(merge: true));

    debugPrint(
      '[DailyNewsGameRepo] Articles session enregistrés: mode=${mode.modeKey}, sessionId=$sessionId, nb=${articles.length}',
    );
  }
}
