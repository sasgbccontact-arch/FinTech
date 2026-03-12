import 'dart:math' as math;

import '../services/yahoo_finance_service.dart';

enum SearchInstrumentPriority { all, equities, etfs, funds }

String normalizeSearchText(String input) {
  const mappings = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ä': 'A',
    'Ã': 'A',
    'Å': 'A',
    'æ': 'ae',
    'Æ': 'AE',
    'œ': 'oe',
    'Œ': 'OE',
    'ç': 'c',
    'Ç': 'C',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'ñ': 'n',
    'Ñ': 'N',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Ö': 'O',
    'Õ': 'O',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'ý': 'y',
    'ÿ': 'y',
    'Ý': 'Y',
  };

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(mappings[char] ?? char);
  }

  final normalized =
      buffer
          .toString()
          .replaceAll(RegExp(r'[\-‐‑–—−/]'), ' ')
          .replaceAll(RegExp(r'[^\w.\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
  return normalized;
}

List<TickerSearchResult> rankSearchSuggestions({
  required List<TickerSearchResult> candidates,
  required String query,
  SearchInstrumentPriority priority = SearchInstrumentPriority.all,
  int limit = 15,
}) {
  final ranked =
      candidates.asMap().entries.map((entry) {
        final score = computeSearchSuggestionScore(
          result: entry.value,
          query: query,
          priority: priority,
        );
        return _RankedSuggestion(
          result: entry.value,
          score: score,
          index: entry.key,
        );
      }).toList();

  ranked.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;

    final yahooCompare = (b.result.yahooScore ?? 0).compareTo(
      a.result.yahooScore ?? 0,
    );
    if (yahooCompare != 0) return yahooCompare;

    final exchangeCompare = (b.result.isSupportedExchange ? 1 : 0).compareTo(
      a.result.isSupportedExchange ? 1 : 0,
    );
    if (exchangeCompare != 0) return exchangeCompare;

    final symbolCompare = a.result.symbol.compareTo(b.result.symbol);
    if (symbolCompare != 0) return symbolCompare;

    return a.index.compareTo(b.index);
  });

  return ranked.take(limit).map((entry) => entry.result).toList();
}

int computeSearchSuggestionScore({
  required TickerSearchResult result,
  required String query,
  SearchInstrumentPriority priority = SearchInstrumentPriority.all,
}) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return 0;

  final rawUpperQuery = trimmedQuery.toUpperCase();
  final normalizedQuery = normalizeSearchText(trimmedQuery);
  if (normalizedQuery.isEmpty) return 0;

  final queryTokens = _tokenize(normalizedQuery);
  final symbolUpper = result.symbol.toUpperCase();
  final symbolNormalized = normalizeSearchText(result.symbol);
  final nameNormalized = normalizeSearchText(result.displayName);
  final nameTokens = _tokenize(nameNormalized);

  var score = 0;

  if (symbolUpper == rawUpperQuery) {
    score += 2400;
  } else if (symbolUpper.startsWith(rawUpperQuery)) {
    score += 1900;
  } else if (symbolNormalized == normalizedQuery) {
    score += 1700;
  } else if (symbolUpper.contains(rawUpperQuery) ||
      symbolNormalized.contains(normalizedQuery)) {
    score += 1150;
  }

  if (nameNormalized == normalizedQuery) {
    score += 1800;
  } else if (nameNormalized.startsWith(normalizedQuery)) {
    score += 1500;
  } else if (_matchesAllTokenPrefixes(queryTokens, nameTokens)) {
    score += 1250;
  } else if (_matchesAllTokensContained(queryTokens, nameNormalized)) {
    score += 980;
  } else if (nameNormalized.contains(normalizedQuery)) {
    score += 820;
  }

  if (_matchesAnyTokenPrefix(queryTokens, nameTokens)) {
    score += 160;
  }
  if (_matchesAnyToken(queryTokens, nameTokens)) {
    score += 90;
  }

  score += _priorityBonus(result, priority);
  score += _instrumentBonus(result);
  if (result.isSupportedExchange) {
    score += 110;
  }
  final yahooScore = result.yahooScore;
  if (yahooScore != null && yahooScore.isFinite && yahooScore > 0) {
    score += math.min(yahooScore.round(), 80);
  }

  return score;
}

bool hasStrongSearchMatch(
  List<TickerSearchResult> candidates,
  String query, {
  SearchInstrumentPriority priority = SearchInstrumentPriority.all,
}) {
  if (candidates.isEmpty) return false;
  final topScore = computeSearchSuggestionScore(
    result: candidates.first,
    query: query,
    priority: priority,
  );
  return topScore >= 1200;
}

int _priorityBonus(
  TickerSearchResult result,
  SearchInstrumentPriority priority,
) {
  switch (priority) {
    case SearchInstrumentPriority.all:
      if (result.isFrenchListed && result.isEquity) return 260;
      if (result.isEquity) return 140;
      if (result.isEtf) return 70;
      if (result.isMutualFund) return 35;
      if (result.isIndex) return 20;
      return 0;
    case SearchInstrumentPriority.equities:
      if (result.isFrenchListed && result.isEquity) return 360;
      if (result.isEquity) return 240;
      if (result.isEtf) return 90;
      if (result.isMutualFund) return 30;
      if (result.isIndex) return 20;
      return 0;
    case SearchInstrumentPriority.etfs:
      if (result.isEtf) return 240;
      if (result.isFrenchListed && result.isEquity) return 150;
      if (result.isEquity) return 120;
      if (result.isMutualFund) return 80;
      if (result.isIndex) return 30;
      return 0;
    case SearchInstrumentPriority.funds:
      if (result.isMutualFund) return 240;
      if (result.isEtf) return 120;
      if (result.isFrenchListed && result.isEquity) return 120;
      if (result.isEquity) return 90;
      if (result.isIndex) return 30;
      return 0;
  }
}

int _instrumentBonus(TickerSearchResult result) {
  if (result.isFrenchListed && result.isEquity) return 190;
  if (result.isEquity) return 150;
  if (result.isEtf) return 145;
  if (result.isMutualFund) return 80;
  if (result.isIndex) return 45;
  return 0;
}

List<String> _tokenize(String value) {
  return value.split(' ').where((token) => token.isNotEmpty).toList();
}

bool _matchesAllTokenPrefixes(
  List<String> queryTokens,
  List<String> nameTokens,
) {
  if (queryTokens.isEmpty || nameTokens.isEmpty) return false;
  return queryTokens.every(
    (queryToken) =>
        nameTokens.any((nameToken) => nameToken.startsWith(queryToken)),
  );
}

bool _matchesAllTokensContained(List<String> queryTokens, String text) {
  if (queryTokens.isEmpty || text.isEmpty) return false;
  return queryTokens.every(text.contains);
}

bool _matchesAnyTokenPrefix(List<String> queryTokens, List<String> nameTokens) {
  if (queryTokens.isEmpty || nameTokens.isEmpty) return false;
  return queryTokens.any(
    (queryToken) =>
        nameTokens.any((nameToken) => nameToken.startsWith(queryToken)),
  );
}

bool _matchesAnyToken(List<String> queryTokens, List<String> nameTokens) {
  if (queryTokens.isEmpty || nameTokens.isEmpty) return false;
  return queryTokens.any(
    (queryToken) =>
        nameTokens.any((nameToken) => nameToken.contains(queryToken)),
  );
}

class _RankedSuggestion {
  const _RankedSuggestion({
    required this.result,
    required this.score,
    required this.index,
  });

  final TickerSearchResult result;
  final int score;
  final int index;
}
