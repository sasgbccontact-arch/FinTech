import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/countries_fr.dart';
import '../models/news_article.dart';
import '../models/quiz_question.dart';

enum QuizContext { actus, monde }

// ─── Public async entry point (runs in isolate) ────────────────────────────

Future<List<QuizQuestion>> generateQuizAsync({
  required List<NewsArticle> articles,
  required int seed,
  QuizContext context = QuizContext.actus,
  String? selectedCountryIso2,
  String? selectedCountryNameFr,
}) {
  return compute(
    _generateIsolated,
    _GenParams(
      articles: articles,
      seed: seed,
      context: context,
      selectedCountryIso2: selectedCountryIso2,
      selectedCountryNameFr: selectedCountryNameFr,
    ),
  );
}

List<QuizQuestion> _generateIsolated(_GenParams p) {
  return QuizGenerator().generateQuizForArticles(
    p.articles,
    seed: p.seed,
    context: p.context,
    selectedCountryIso2: p.selectedCountryIso2,
    selectedCountryNameFr: p.selectedCountryNameFr,
  );
}

class _GenParams {
  final List<NewsArticle> articles;
  final int seed;
  final QuizContext context;
  final String? selectedCountryIso2;
  final String? selectedCountryNameFr;

  const _GenParams({
    required this.articles,
    required this.seed,
    required this.context,
    this.selectedCountryIso2,
    this.selectedCountryNameFr,
  });
}

// ─── Generator ─────────────────────────────────────────────────────────────

class QuizGenerator {
  List<QuizQuestion> generateQuizForArticles(
    List<NewsArticle> articles, {
    required int seed,
    QuizContext context = QuizContext.actus,
    String? selectedCountryIso2,
    String? selectedCountryNameFr,
  }) {
    if (articles.isEmpty) return const [];

    final rng = _SeededRandom(seed);

    final content = <QuizQuestion>[];
    final fallback = <QuizQuestion>[];

    for (int i = 0; i < articles.length; i++) {
      final article = articles[i];
      final others = articles.where((a) => a.url != article.url).toList();

      // Content-based questions (ordered by quality)
      _tryAdd(content, _buildTrueSentenceQuestion(article, others, rng, i));
      _tryAdd(content, _buildClozeQuestion(article, others, rng, i));
      _tryAdd(content, _buildNumberQuestion(article, others, rng, i));
      _tryAdd(content, _buildEntityQuestion(article, others, rng, i));
      _tryAdd(content, _buildKeywordQuestion(article, others, rng, i));

      // Fallback metadata
      fallback.add(_buildSourceQuestion(article, others, rng, i));
    }

    // Association: only when ≥2 articles with snippets
    if (articles.length >= 2) {
      _tryAdd(content, _buildAssociationQuestion(articles, rng));
    }

    // Monde country question (added to fallback)
    if (context == QuizContext.monde &&
        selectedCountryIso2 != null &&
        selectedCountryNameFr != null) {
      fallback.add(
        _buildCountryQuestion(
          articles.first,
          selectedCountryIso2,
          selectedCountryNameFr,
          rng,
          0,
        ),
      );
    }

    rng.shuffle(content);
    rng.shuffle(fallback);

    // Deduplicate by id
    final seen = <String>{};
    final dedup = <QuizQuestion>[];
    for (final q in [...content, ...fallback]) {
      if (seen.add(q.id)) dedup.add(q);
    }

    // Pick 4 questions, max 1 fallback metadata
    final result = <QuizQuestion>[];
    int fallbackUsed = 0;
    for (final q in dedup) {
      if (result.length >= 4) break;
      final isMeta = q.type == QuizQuestionType.source ||
          q.type == QuizQuestionType.date ||
          q.type == QuizQuestionType.country;
      if (isMeta) {
        if (fallbackUsed < 1) {
          result.add(q);
          fallbackUsed++;
        }
      } else {
        result.add(q);
      }
    }
    // Fill remainder with any remaining question
    for (final q in dedup) {
      if (result.length >= 4) break;
      if (!result.contains(q)) result.add(q);
    }

    debugPrint(
      '[QuizGenerator] ${result.length} questions '
      '(${content.length} content, ${fallback.length} fallback)',
    );
    return result;
  }

  void _tryAdd(List<QuizQuestion> list, QuizQuestion? q) {
    if (q != null) list.add(q);
  }

  // ─── TRUE SENTENCE ────────────────────────────────────────────────────────
  // Pick a factual sentence from the snippet, generate 3 subtle wrong variants.

  QuizQuestion? _buildTrueSentenceQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final snippet = _sanitize(article.snippet ?? '');
    if (snippet.trim().length < 50) return null;

    final sentences = _extractSentences(snippet)
        .where((s) => s.trim().length >= 35 && s.trim().length <= 220)
        .toList();
    if (sentences.isEmpty) return null;

    rng.shuffle(sentences);
    final original = sentences.first.trim();
    final wrongs = <String>{};

    final entities = _extractNamedEntities(original);
    final nums = _extractNumbersWithUnits(original);

    // Variant A: replace a named entity with one from static bank or other articles
    if (entities.isNotEmpty) {
      final entity = entities[rng.nextInt(entities.length)];
      final domain = _detectDomain(article);
      final replacements = _buildEntityPool(domain, others)
          .where((e) => e != entity && !original.toLowerCase().contains(e.toLowerCase()))
          .toList();
      rng.shuffle(replacements);
      if (replacements.isNotEmpty) {
        wrongs.add(original.replaceFirst(entity, replacements.first));
      }
    }

    // Variant B: replace a number with a plausible alternative
    if (nums.isNotEmpty) {
      final nm = nums[rng.nextInt(nums.length)];
      final alts = _numericDistractors(nm.value, nm.rawNumber)
          .where((d) => d != nm.rawNumber)
          .toList();
      rng.shuffle(alts);
      if (alts.isNotEmpty) {
        wrongs.add(original.replaceFirst(nm.rawNumber, alts.first));
      }
    }

    // Variant C: semantic inversion (up/down, approved/rejected…)
    final inverted = _semanticInversion(original);
    if (inverted != null && inverted != original) wrongs.add(inverted);

    // Variant D: swap two entities within the sentence
    if (entities.length >= 2) {
      rng.shuffle(entities);
      wrongs.add(original.replaceFirst(entities[0], entities[1]));
    }

    // Variant E: swap entity with one from another article (cross-contamination)
    if (wrongs.length < 2 && entities.isNotEmpty && others.isNotEmpty) {
      final otherEntities = others
          .expand((a) => _extractNamedEntities('${a.title} ${a.snippet ?? ''}'))
          .where((e) => !original.toLowerCase().contains(e.toLowerCase()))
          .toList();
      rng.shuffle(otherEntities);
      if (otherEntities.isNotEmpty) {
        wrongs.add(original.replaceFirst(entities.first, otherEntities.first));
      }
    }

    final wrongList =
        wrongs.where((w) => w != original && w.trim().length >= 10).toList();
    if (wrongList.length < 2) return null;

    rng.shuffle(wrongList);
    final choices = [original, ...wrongList.take(3)];
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'q${idx}_true_${article.id}',
      prompt:
          'Laquelle de ces affirmations est correcte selon l\'article ?',
      choices: choices,
      correctIndex: choices.indexOf(original),
      type: QuizQuestionType.trueSentence,
      sourceArticleUrl: article.url,
    );
  }

  // ─── CLOZE ────────────────────────────────────────────────────────────────
  // Extract a sentence, blank a key word, generate plausible distractors.
  // Falls back to the title when no usable snippet is available.

  QuizQuestion? _buildClozeQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final rawSnippet = _sanitize(article.snippet ?? '');
    final hasSnippet = rawSnippet.trim().length >= 60;
    final title = _sanitize(article.title);
    // Use snippet when available, otherwise fall back to title (≥4 words)
    final base = hasSnippet
        ? rawSnippet
        : (title.split(RegExp(r'\s+')).length >= 4 ? title : '');
    if (base.trim().length < 20) return null;

    final sentences = _extractSentences(base);
    final candidates =
        sentences.isNotEmpty ? sentences : [base.trim()];

    // selectedSentenceBlanked already contains '___'
    String? selectedSentenceBlanked;
    String? blankWord; // clean version shown as a choice
    String? blankType; // 'entity' | 'number'

    // Prefer sentences with a named entity (more meaningful blanks)
    for (final sent in candidates) {
      if (sent.trim().length < 20 || sent.trim().length > 230) continue;
      final words = sent.trim().split(RegExp(r'\s+'));
      if (words.length < 4) continue;

      // For snippets skip position 0 (sentence-start capital is noise).
      // For titles every word is content so start at 0.
      final startIdx = hasSnippet ? 1 : 0;
      for (int wi = startIdx; wi < words.length; wi++) {
        final rawWord = words[wi];
        final clean = rawWord.replaceAll(RegExp(r'[^\w\-]'), '');
        if (clean.length < 3) continue;
        if (!RegExp(r'^[A-Z]').hasMatch(clean)) continue;
        if (RegExp(r'^[A-Z]+$').hasMatch(clean) && clean.length <= 3) continue;

        // Replace the raw word (with punctuation) so '___' is always inserted
        final candidate = sent.trim().replaceFirst(rawWord, '___');
        if (!candidate.contains('___')) continue; // silent failure guard

        blankWord = clean;
        selectedSentenceBlanked = candidate;
        blankType = 'entity';
        break;
      }
      if (blankWord != null) break;
    }

    // Fallback: sentence with a number+unit
    if (blankWord == null) {
      for (final sent in candidates) {
        final nm = _extractNumbersWithUnits(sent);
        if (nm.isNotEmpty) {
          final m = nm.first;
          final rawBlank = '${m.rawNumber}${m.unit}';
          final candidate = sent.trim().replaceFirst(rawBlank, '___');
          if (candidate.contains('___')) {
            blankWord = rawBlank;
            selectedSentenceBlanked = candidate;
            blankType = 'number';
            break;
          }
          // Try number without unit
          final candidate2 = sent.trim().replaceFirst(m.rawNumber, '___');
          if (candidate2.contains('___')) {
            blankWord = rawBlank;
            selectedSentenceBlanked = candidate2;
            blankType = 'number';
            break;
          }
        }
      }
    }

    if (selectedSentenceBlanked == null ||
        blankWord == null ||
        blankWord.length < 2) {
      return null;
    }

    final prompt =
        'Complétez la phrase extraite de l\'article :\n"${_truncate(selectedSentenceBlanked, max: 160)}"';

    final distractors = <String>{};

    if (blankType == 'number') {
      final numVal = double.tryParse(
        blankWord.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.'),
      );
      if (numVal != null) {
        distractors.addAll(_numericDistractors(numVal, blankWord));
      }
    } else {
      // Entity distractors: from other articles + static bank
      distractors.addAll(
        _buildEntityPool(_detectDomain(article), others).where(
          (e) =>
              e != blankWord &&
              !selectedSentenceBlanked!.contains(e),
        ),
      );
      for (final other in others) {
        distractors.addAll(
          _extractNamedEntities(
            _sanitize('${other.title} ${other.snippet ?? ''}'),
          ).where((e) => e != blankWord),
        );
      }
    }

    distractors.remove(blankWord);
    final distList = distractors.toList();
    rng.shuffle(distList);
    final wrongs = distList.take(3).toList();
    if (wrongs.length < 2) return null;

    final choices = [blankWord, ...wrongs];
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'q${idx}_cloze_${article.id}',
      prompt: prompt,
      choices: choices,
      correctIndex: choices.indexOf(blankWord),
      type: QuizQuestionType.cloze,
      sourceArticleUrl: article.url,
    );
  }

  // ─── NUMBER ───────────────────────────────────────────────────────────────
  // Find a number+unit in the snippet, generate mathematically plausible alternatives.

  QuizQuestion? _buildNumberQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final text = _sanitize('${article.title} ${article.snippet ?? ''}');
    final matches = _extractNumbersWithUnits(text);
    if (matches.isEmpty) return null;

    rng.shuffle(matches);
    final match = matches.first;

    final distractors = _numericDistractors(match.value, match.rawNumber)
        .where((d) => d != match.rawNumber)
        .toList();
    if (distractors.length < 2) return null;

    rng.shuffle(distractors);

    final correct = '${match.rawNumber}${match.unit}';
    final wrongs = distractors.take(3).map((d) => '$d${match.unit}').toList();
    final choices = [correct, ...wrongs];
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'q${idx}_number_${article.id}',
      prompt: match.prompt,
      choices: choices,
      correctIndex: choices.indexOf(correct),
      type: QuizQuestionType.number,
      sourceArticleUrl: article.url,
    );
  }

  // ─── ENTITY ───────────────────────────────────────────────────────────────
  // Pick a named entity from the article, distract with plausible others.

  QuizQuestion? _buildEntityQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final text = _sanitize('${article.title} ${article.snippet ?? ''}');
    // _extractNamedEntities skips position-0 words per sentence (noise filter).
    // For the title we also extract ALL positions since every word is content.
    final entities = {
      ..._extractNamedEntities(text),
      ..._extractTitleEntities(_sanitize(article.title)),
    }.toList();
    if (entities.isEmpty) return null;

    rng.shuffle(entities);
    // Prefer multi-word entities (more specific)
    final multiWord = entities.where((e) => e.contains(' ')).toList();
    final correct = multiWord.isNotEmpty ? multiWord.first : entities.first;

    final articleLower = text.toLowerCase();
    final distractorPool = <String>{};

    // From other articles
    for (final other in others) {
      distractorPool.addAll(
        _extractNamedEntities(
          _sanitize('${other.title} ${other.snippet ?? ''}'),
        ).where(
          (e) => e != correct && !articleLower.contains(e.toLowerCase()),
        ),
      );
    }

    // Static bank
    distractorPool.addAll(
      _buildEntityPool(_detectDomain(article), others)
          .where(
            (e) =>
                e != correct && !articleLower.contains(e.toLowerCase()),
          ),
    );

    final distList = distractorPool.toList();
    rng.shuffle(distList);
    final wrongs = distList.take(3).toList();
    if (wrongs.length < 2) return null;

    final choices = [correct, ...wrongs];
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'q${idx}_entity_${article.id}',
      prompt:
          'Quel acteur, organisation ou lieu est mentionné dans cet article ?',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      type: QuizQuestionType.entity,
      sourceArticleUrl: article.url,
    );
  }

  // ─── KEYWORD ──────────────────────────────────────────────────────────────
  // Find the most discriminating content keyword; distract with topically adjacent terms.

  QuizQuestion? _buildKeywordQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final text = _sanitize('${article.title} ${article.snippet ?? ''}');
    final otherTexts =
        others.map((a) => _sanitize('${a.title} ${a.snippet ?? ''}')).toList();
    final keywords = _extractKeywords(text, otherTexts);
    if (keywords.isEmpty) return null;

    rng.shuffle(keywords);
    final correct = keywords.first;
    final articleLower = text.toLowerCase();

    final distractorPool = <String>{};

    // Keywords from other articles NOT present in this article
    for (final other in others) {
      final otherKws = _extractKeywords(
        '${other.title} ${other.snippet ?? ''}',
        [text],
      );
      distractorPool.addAll(
        otherKws.where(
          (k) =>
              !articleLower.contains(k.toLowerCase()) &&
              k != correct,
        ),
      );
    }

    // Static keyword bank (domain-appropriate, not in article)
    final domain = _detectDomain(article);
    distractorPool.addAll(
      _staticKeywordBank(domain).where(
        (k) =>
            !articleLower.contains(k.toLowerCase()) &&
            k != correct,
      ),
    );

    final distList = distractorPool.toList();
    rng.shuffle(distList);
    final wrongs = distList.take(3).toList();
    if (wrongs.length < 2) return null;

    // Capitalize for display (keywords are extracted in lowercase)
    String cap(String w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

    final choices = [correct, ...wrongs].map(cap).toList();
    final correctDisplay = cap(correct);
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'q${idx}_keyword_${article.id}',
      prompt: 'Lequel de ces termes est un mot-clé central de cet article ?',
      choices: choices,
      correctIndex: choices.indexOf(correctDisplay),
      type: QuizQuestionType.keyword,
      sourceArticleUrl: article.url,
    );
  }

  // ─── ASSOCIATION ──────────────────────────────────────────────────────────
  // Show an anonymized snippet fragment; ask which article it belongs to.

  QuizQuestion? _buildAssociationQuestion(
    List<NewsArticle> articles,
    _SeededRandom rng,
  ) {
    final withSnippets = articles
        .where((a) => _sanitize(a.snippet ?? '').trim().length >= 50)
        .toList();
    if (withSnippets.length < 2) return null;

    rng.shuffle(withSnippets);
    final target = withSnippets.first;
    final sentences = _extractSentences(_sanitize(target.snippet!))
        .where((s) => s.trim().length >= 35 && s.trim().length <= 160)
        .toList();
    if (sentences.isEmpty) return null;

    rng.shuffle(sentences);
    String fragment = sentences.first.trim();

    // Anonymize: remove source domain hints
    final sourceParts = target.source.split('.');
    for (final part in sourceParts) {
      if (part.length >= 3) {
        fragment = fragment.replaceAll(
          RegExp(r'\b' + RegExp.escape(part) + r'\b', caseSensitive: false),
          '…',
        );
      }
    }

    final correct = _truncate(target.title, max: 90);
    final wrongPool = articles
        .where((a) => a.url != target.url)
        .map((a) => _truncate(a.title, max: 90))
        .where((t) => t != correct)
        .toList();

    if (wrongPool.isEmpty) return null;
    rng.shuffle(wrongPool);
    final wrongs = wrongPool.take(3).toList();

    final choices = [correct, ...wrongs];
    rng.shuffle(choices);

    return QuizQuestion(
      id: 'assoc_${target.id}',
      prompt:
          'Ce passage provient de quel article ?\n"${_truncate(fragment, max: 160)}"',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      type: QuizQuestionType.association,
      sourceArticleUrl: target.url,
    );
  }

  // ─── FALLBACK: SOURCE ─────────────────────────────────────────────────────

  QuizQuestion _buildSourceQuestion(
    NewsArticle article,
    List<NewsArticle> others,
    _SeededRandom rng,
    int idx,
  ) {
    final correct =
        article.source.isNotEmpty ? article.source : 'Source inconnue';
    final wrongPool = <String>{
      ...others
          .where((a) => a.source.isNotEmpty)
          .map((a) => a.source),
      'Reuters',
      'AFP',
      'Bloomberg',
      'BBC News',
      'Le Monde',
      'Financial Times',
      'The Guardian',
      'CNBC',
      'The Economist',
      'Wall Street Journal',
    }.where((s) => s != correct).toList();
    rng.shuffle(wrongPool);
    final choices = [correct, ...wrongPool.take(3)];
    rng.shuffle(choices);
    return QuizQuestion(
      id: 'q${idx}_source_${article.id}',
      prompt: 'Quel média a publié cet article ?',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      type: QuizQuestionType.source,
      sourceArticleUrl: article.url,
    );
  }

  // ─── FALLBACK: COUNTRY ────────────────────────────────────────────────────

  QuizQuestion _buildCountryQuestion(
    NewsArticle article,
    String iso2,
    String countryNameFr,
    _SeededRandom rng,
    int idx,
  ) {
    final correct = countryNameFr;
    final wrongPool = kAllCountries
        .where((c) => c.iso2.toUpperCase() != iso2.toUpperCase())
        .map((c) => c.nameFr)
        .toList();
    rng.shuffle(wrongPool);
    final choices = [correct, ...wrongPool.take(3)];
    rng.shuffle(choices);
    return QuizQuestion(
      id: 'q${idx}_country_${article.id}',
      prompt: 'À quel pays cet article est-il principalement lié ?',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      type: QuizQuestionType.country,
      sourceArticleUrl: article.url,
    );
  }

  // ─── TEXT UTILITIES ───────────────────────────────────────────────────────

  /// Supprime toutes les URLs (http/https/ftp) d'un texte brut.
  /// Évite que des liens GDELT se retrouvent dans les questions.
  String _sanitize(String text) {
    return text
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'ftp://\S+'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  List<String> _extractSentences(String text) {
    return _sanitize(text)
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        // Rejette tout fragment qui contient encore un schéma URL ou ressemble
        // à un nom de domaine seul (ex: "reuters.com")
        .where(
          (s) =>
              s.length >= 10 &&
              !RegExp(r'https?://', caseSensitive: false).hasMatch(s) &&
              !RegExp(r'^\s*\w+\.\w{2,4}\s*$').hasMatch(s),
        )
        .toList();
  }

  /// Extracts ALL capitalized-word sequences from a title (no position skip).
  /// Used for titles where every word is content (unlike sentence-first words).
  List<String> _extractTitleEntities(String title) {
    final words = title.split(RegExp(r'\s+'));
    final entities = <String>[];
    StringBuffer? current;
    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^\w\-]'), '');
      if (clean.isEmpty) continue;
      final isCapitalized =
          RegExp(r'^[A-Z]').hasMatch(clean) &&
          clean.length >= 2 &&
          !(clean.length <= 3 && RegExp(r'^[A-Z]+$').hasMatch(clean));
      if (isCapitalized) {
        current ??= StringBuffer();
        if (current.isNotEmpty) current.write(' ');
        current.write(clean);
      } else {
        if (current != null) {
          entities.add(current.toString().trim());
          current = null;
        }
      }
    }
    if (current != null) entities.add(current.toString().trim());
    return entities.where((e) => e.isNotEmpty).toSet().toList();
  }

  /// Extracts capitalized-word sequences that are NOT at the start of a sentence.
  List<String> _extractNamedEntities(String text) {
    final entities = <String>[];
    for (final sentence in _extractSentences(text)) {
      final words = sentence.split(RegExp(r'\s+'));
      StringBuffer? current;
      for (int wi = 1; wi < words.length; wi++) {
        final clean = words[wi].replaceAll(RegExp(r'[^\w\-]'), '');
        if (clean.isEmpty) continue;
        final isCapitalized =
            clean.isNotEmpty &&
            RegExp(r'^[A-Z]').hasMatch(clean) &&
            // Exclude ALL-CAPS abbreviations < 4 letters (can be noise)
            !(clean.length <= 3 && RegExp(r'^[A-Z]+$').hasMatch(clean));
        if (isCapitalized && clean.length >= 2) {
          current ??= StringBuffer();
          if (current.isNotEmpty) current.write(' ');
          current.write(clean);
        } else {
          if (current != null) {
            final e = current.toString().trim();
            if (e.isNotEmpty) entities.add(e);
            current = null;
          }
        }
      }
      if (current != null) {
        final e = current.toString().trim();
        if (e.isNotEmpty) entities.add(e);
      }
    }
    return entities.toSet().toList();
  }

  List<_NumberMatch> _extractNumbersWithUnits(String text) {
    final results = <_NumberMatch>[];
    // Matches: 3.5%, $1.2B, 45 billion, 12,000 bps, etc.
    final pattern = RegExp(
      r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)'
      r'\s*(%|bn|B|M|billion|million|milliard|trillion|€|\$|USD|EUR|bps|pb|pts?)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(text)) {
      final raw = match.group(1)!;
      final unit = match.group(2)!;
      final numStr = raw
          .replaceAll(RegExp(r'\.(?=\d{3})'), '')
          .replaceAll(',', '.');
      final value = double.tryParse(numStr);
      if (value == null) continue;

      // Build contextual prompt
      final start = math.max(0, match.start - 50);
      final end = math.min(text.length, match.end + 50);
      final ctx = text.substring(start, end).trim();

      results.add(
        _NumberMatch(
          rawNumber: raw,
          unit: unit,
          value: value,
          prompt:
              'Quelle valeur chiffrée apparaît dans ce contexte ?\n"${_truncate(ctx, max: 110)}"',
        ),
      );
    }
    return results;
  }

  List<String> _numericDistractors(double value, String rawNumber) {
    final results = <String>{};
    if (value < 100) {
      // Percentage / small value: nearby steps
      for (final delta in [-5.0, -2.0, -1.0, -0.5, 0.5, 1.0, 2.0, 5.0, 10.0]) {
        final alt = value + delta;
        if (alt > 0 && alt != value) results.add(_formatLike(alt, rawNumber));
      }
      for (final factor in [0.5, 0.75, 1.25, 1.5, 2.0, 3.0]) {
        final alt = value * factor;
        if (alt != value) results.add(_formatLike(alt, rawNumber));
      }
    } else {
      // Large values: factor variants
      for (final factor in [0.25, 0.5, 0.75, 1.5, 2.0, 3.0, 5.0, 10.0]) {
        results.add(_formatLike(value * factor, rawNumber));
      }
      // Also ±round numbers
      for (final delta in [-100.0, -50.0, 50.0, 100.0, 500.0]) {
        final alt = value + delta;
        if (alt > 0) results.add(_formatLike(alt, rawNumber));
      }
    }
    return results.where((r) => r != rawNumber).toList();
  }

  String _formatLike(double value, String original) {
    final hasFraction =
        original.contains('.') || (original.contains(',') && !original.contains('.'));
    if (hasFraction) {
      final decimals = original.split(RegExp(r'[.,]')).last.length;
      return value.toStringAsFixed(decimals);
    }
    return value.round().toString();
  }

  /// TF-based keyword extraction, penalized for occurrence in other texts.
  List<String> _extractKeywords(String text, List<String> otherTexts) {
    final tokens = text
        .toLowerCase()
        .split(RegExp('[\\s\\-,;:.!?()\\[\\]{}\'"]+'))
        .where((t) => t.length >= 4 && !_stopWords.contains(t))
        .toList();

    final freq = <String, int>{};
    for (final t in tokens) {
      freq[t] = (freq[t] ?? 0) + 1;
    }

    final otherCombined = otherTexts.join(' ').toLowerCase();
    final scored = freq.entries.map((e) {
      final inOthers = otherCombined.contains(e.key) ? 1 : 0;
      return MapEntry(e.key, e.value.toDouble() * (inOthers == 0 ? 2.0 : 1.0));
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.take(10).map((e) => e.key).toList();
  }

  String? _semanticInversion(String sentence) {
    const replacements = <String, String>{
      ' increased': ' decreased',
      ' rose': ' fell',
      ' fell': ' rose',
      ' gained': ' lost',
      ' lost': ' gained',
      ' declined': ' surged',
      ' surged': ' declined',
      ' up ': ' down ',
      ' down ': ' up ',
      ' approved': ' rejected',
      ' rejected': ' approved',
      ' signed': ' blocked',
      ' launched': ' cancelled',
      ' expanded': ' contracted',
      ' cut': ' raised',
      ' raised': ' cut',
      ' a augmenté': ' a diminué',
      ' a diminué': ' a augmenté',
      ' en hausse': ' en baisse',
      ' en baisse': ' en hausse',
      ' hausse': ' baisse',
      ' baisse': ' hausse',
      ' adopté': ' rejeté',
      ' rejeté': ' adopté',
    };
    for (final entry in replacements.entries) {
      if (sentence.contains(entry.key)) {
        return sentence.replaceFirst(entry.key, entry.value);
      }
    }
    return null;
  }

  String _detectDomain(NewsArticle article) {
    final t = '${article.title} ${article.snippet ?? ''}'.toLowerCase();
    if (t.contains('bank') || t.contains('stock') || t.contains('market') ||
        t.contains('fund') || t.contains('invest') || t.contains('finance')) {
      return 'finance';
    }
    if (t.contains('war') || t.contains('guerre') || t.contains('nato') ||
        t.contains('military') || t.contains('sanction') || t.contains('missile')) {
      return 'geo';
    }
    if (t.contains('tech') || t.contains(' ai ') || t.contains('software') ||
        t.contains('startup') || t.contains('digital')) {
      return 'tech';
    }
    if (t.contains('oil') || t.contains('energy') || t.contains('opec') ||
        t.contains('gas') || t.contains('climate')) {
      return 'energy';
    }
    if (t.contains('election') || t.contains('government') ||
        t.contains('president') || t.contains('parlement')) {
      return 'politics';
    }
    return 'general';
  }

  /// Combines static entity bank with entities extracted from other articles.
  List<String> _buildEntityPool(String domain, List<NewsArticle> others) {
    final pool = <String>[..._staticEntityBank(domain)];
    for (final other in others) {
      pool.addAll(
        _extractNamedEntities(
          _sanitize('${other.title} ${other.snippet ?? ''}'),
        ),
      );
    }
    return pool.toSet().toList();
  }

  List<String> _staticEntityBank(String domain) {
    const banks = <String, List<String>>{
      'finance': [
        'Goldman Sachs', 'JPMorgan Chase', 'BlackRock', 'Morgan Stanley',
        'Vanguard Group', 'Berkshire Hathaway', 'Warren Buffett', 'Jerome Powell',
        'Christine Lagarde', 'Larry Fink', 'Ray Dalio', 'Citadel',
        'Deutsche Bank', 'UBS', 'Citigroup', 'Bank of America', 'HSBC',
        'Barclays', 'Credit Suisse', 'Wells Fargo', 'Société Générale',
        'BNP Paribas', 'Moody\'s', 'S&P Global', 'Fitch Ratings',
      ],
      'geo': [
        'Vladimir Poutine', 'Xi Jinping', 'Joe Biden', 'Emmanuel Macron',
        'Volodymyr Zelensky', 'Benjamin Netanyahu', 'Olaf Scholz',
        'Ursula von der Leyen', 'António Guterres', 'Mark Rutte',
        'Jens Stoltenberg', 'Boris Johnson', 'Rishi Sunak', 'Recep Erdoğan',
        'UN Security Council', 'European Commission', 'International Court of Justice',
      ],
      'tech': [
        'Google DeepMind', 'Apple Inc', 'Microsoft', 'Meta Platforms',
        'Amazon Web Services', 'Nvidia Corporation', 'OpenAI', 'Anthropic',
        'Sam Altman', 'Elon Musk', 'Sundar Pichai', 'Satya Nadella',
        'Tim Cook', 'Mark Zuckerberg', 'Jensen Huang', 'Mistral AI',
        'Hugging Face', 'Tesla', 'SpaceX', 'ByteDance',
      ],
      'energy': [
        'OPEC Plus', 'Saudi Aramco', 'BP', 'Shell', 'ExxonMobil',
        'TotalEnergies', 'Chevron', 'Gazprom', 'IEA', 'Prince Abdulaziz',
        'Fatih Birol', 'ConocoPhillips', 'Hess Corporation',
        'International Energy Agency', 'Climate Change Committee',
      ],
      'politics': [
        'United States Congress', 'Senate', 'Supreme Court', 'White House',
        'Kremlin', 'Élysée Palace', 'Bundestag', 'European Commission',
        'World Bank', 'International Monetary Fund', 'Mario Draghi',
        'Pedro Sánchez', 'Giorgia Meloni', 'Narendra Modi', 'Keir Starmer',
      ],
      'general': [
        'World Trade Organization', 'International Monetary Fund',
        'United Nations', 'NATO', 'European Central Bank', 'Federal Reserve',
        'World Economic Forum', 'OECD', 'G20 Summit', 'G7',
        'Washington DC', 'Brussels', 'Beijing', 'Tokyo', 'Berlin',
        'Davos', 'World Bank Group',
      ],
    };
    return [
      ...(banks[domain] ?? []),
      ...(banks['general'] ?? []),
    ];
  }

  List<String> _staticKeywordBank(String domain) {
    const banks = <String, List<String>>{
      'finance': [
        'rendement', 'liquidité', 'volatilité', 'capitalisation',
        'dividende', 'obligation', 'dérivés', 'spread', 'levier',
        'rachat', 'acquisition', 'bénéfice', 'dette', 'couverture',
        'émission', 'titrisation', 'covenant', 'collatéral',
      ],
      'geo': [
        'cessez-le-feu', 'souveraineté', 'sanctions', 'négociations',
        'diplomatie', 'escalade', 'armistice', 'déploiement',
        'offensive', 'territoire', 'accord', 'ultimatum', 'représailles',
      ],
      'tech': [
        'algorithme', 'infrastructure', 'déploiement', 'modèle',
        'paramètres', 'cryptographie', 'surveillance', 'régulation',
        'brevet', 'interopérabilité', 'latence', 'scalabilité',
      ],
      'energy': [
        'capacité', 'raffinage', 'pipeline', 'approvisionnement',
        'transition', 'émissions', 'carbone', 'quota', 'barils',
        'mégawatts', 'stockage', 'réseau', 'interconnexion',
      ],
      'general': [
        'accord', 'annonce', 'rapport', 'stratégie', 'croissance',
        'secteur', 'réforme', 'programme', 'initiative', 'mesure',
        'résolution', 'directive', 'protocole', 'mécanisme',
      ],
    };
    return [
      ...(banks[domain] ?? []),
      ...(banks['general'] ?? []),
    ];
  }

  String _truncate(String text, {int max = 90}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

class _NumberMatch {
  final String rawNumber;
  final String unit;
  final double value;
  final String prompt;

  const _NumberMatch({
    required this.rawNumber,
    required this.unit,
    required this.value,
    required this.prompt,
  });
}

// ─── Seed ──────────────────────────────────────────────────────────────────

int computeQuizSeed({
  required String uid,
  required String sessionId,
  required List<NewsArticle> articles,
}) {
  final input = '$uid|$sessionId|${articles.map((a) => a.url).join('|')}';
  int hash = 5381;
  for (final cu in input.codeUnits) {
    hash = ((hash << 5) + hash + cu) & 0xFFFFFFFF;
  }
  debugPrint('[QuizGenerator] seed(session=$sessionId) -> $hash');
  return hash;
}

// ─── Seeded RNG ────────────────────────────────────────────────────────────

class _SeededRandom {
  int _state;

  _SeededRandom(int seed) : _state = seed == 0 ? 1 : seed.abs();

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state % max;
  }

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}

// ─── Stop words (FR + EN) ──────────────────────────────────────────────────

const _stopWords = <String>{
  // French
  'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'en', 'au', 'aux',
  'ce', 'qui', 'que', 'se', 'sa', 'son', 'ses', 'sur', 'par', 'pour', 'dans',
  'avec', 'est', 'sont', 'ont', 'être', 'avoir', 'mais', 'donc', 'ni',
  'car', 'plus', 'tout', 'tous', 'très', 'aussi', 'bien', 'comme', 'si', 'alors',
  'lors', 'leur', 'leurs', 'cette', 'ces', 'même', 'ainsi', 'entre', 'vers',
  'sous', 'contre', 'depuis', 'avant', 'après', 'selon', 'afin', 'dont',
  'autre', 'autres', 'nous', 'vous', 'ils', 'elles', 'lui',
  'eux', 'était', 'sera', 'serait', 'peut', 'doit', 'fait', 'dit',
  'peu', 'tant', 'quel', 'quelle', 'quels', 'quelles', 'quand', 'comment',
  'chez', 'sans', 'pendant', 'jusque', 'chaque', 'ceux', 'or',
  // English
  'the', 'a', 'an', 'of', 'in', 'to', 'for', 'and', 'is', 'are',
  'was', 'were', 'has', 'have', 'had', 'be', 'been', 'by', 'at', 'on',
  'with', 'as', 'from', 'that', 'this', 'it', 'its', 'said', 'will',
  'would', 'could', 'may', 'after', 'into', 'about', 'over', 'also',
  'their', 'which', 'when', 'up', 'not', 'but', 'if', 'more', 'than',
  'he', 'she', 'they', 'we', 'you', 'his', 'her', 'our', 'your', 'new',
  'what', 'who', 'how', 'all', 'can', 'do', 'did', 'now', 'just',
  'them', 'out', 'so', 'no', 'some', 'other', 'then', 'time',
  'two', 'first', 'last', 'long', 'great', 'little', 'own', 'right',
  'old', 'big', 'high', 'such', 'even', 'back', 'any', 'good', 'same',
  'while', 'where', 'should', 'each', 'between', 'need', 'large', 'often',
};
