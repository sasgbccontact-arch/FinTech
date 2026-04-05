import '../utils/news_text_sanitizer.dart';

class NewsArticle {
  final String id;
  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
  final String? snippet;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.snippet,
  });

  /// Construit un NewsArticle depuis la réponse GDELT artlist.
  /// Format seendatetime : YYYYMMDDHHmmss
  factory NewsArticle.fromGdelt(Map<String, dynamic> json) {
    final raw = (json['seendatetime'] as String?) ?? '';
    DateTime date;
    try {
      date = DateTime.utc(
        int.parse(raw.substring(0, 4)),
        int.parse(raw.substring(4, 6)),
        int.parse(raw.substring(6, 8)),
        int.parse(raw.substring(8, 10)),
        int.parse(raw.substring(10, 12)),
        int.parse(raw.substring(12, 14)),
      );
    } catch (_) {
      date = DateTime.now();
    }
    final url = (json['url'] as String?) ?? '';
    return NewsArticle(
      id: url.hashCode.abs().toString(),
      title: sanitizeNewsGameText((json['title'] as String?) ?? ''),
      url: url,
      source: (json['domain'] as String?) ?? '',
      publishedAt: date,
    );
  }

  /// Construit un NewsArticle depuis un item RSS (fallback gratuit).
  factory NewsArticle.fromRss({
    required String title,
    required String url,
    required DateTime publishedAt,
    String source = 'Google News',
    String? snippet,
  }) {
    return NewsArticle(
      id: url.hashCode.abs().toString(),
      title: sanitizeNewsGameText(title),
      url: url,
      source: source,
      publishedAt: publishedAt,
      snippet: snippet == null ? null : sanitizeNewsGameText(snippet),
    );
  }

  /// Sérialisation Firestore.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'url': url,
    'source': source,
    'publishedAt': publishedAt.toIso8601String(),
    if (snippet != null) 'snippet': snippet,
  };

  factory NewsArticle.fromFirestore(Map<String, dynamic> map) => NewsArticle(
    id: (map['id'] as String?) ?? '',
    title: sanitizeNewsGameText((map['title'] as String?) ?? ''),
    url: (map['url'] as String?) ?? '',
    source: (map['source'] as String?) ?? '',
    publishedAt:
        DateTime.tryParse((map['publishedAt'] as String?) ?? '') ??
        DateTime.now(),
    snippet:
        map['snippet'] == null
            ? null
            : sanitizeNewsGameText((map['snippet'] as String?) ?? ''),
  );
}
