class FinanceNewsItem {
  FinanceNewsItem({
    required this.id,
    required this.title,
    required this.publisher,
    required this.publishedAt,
    required this.url,
    this.summary,
    this.thumbnailUrl,
    Set<String>? relatedTickers,
  }) : relatedTickers = relatedTickers == null
            ? const <String>{}
            : Set.unmodifiable(relatedTickers);

  final String id;
  final String title;
  final String publisher;
  final DateTime publishedAt;
  final String url;
  final String? summary;
  final String? thumbnailUrl;
  final Set<String> relatedTickers;

  static FinanceNewsItem? fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['uuid'] ?? json['hash'])?.toString();
    final rawTitle = (json['title'] ?? json['headline'])?.toString();
    final rawUrl = (json['url'] ?? json['link'])?.toString();
    if (rawId == null || rawId.isEmpty) return null;
    if (rawTitle == null || rawTitle.isEmpty) return null;
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final rawPublisher = (json['publisher'] ?? json['provider'] ?? '')?.toString();
    final publisher = rawPublisher == null || rawPublisher.isEmpty ? '—' : rawPublisher;

    DateTime publishedAt = DateTime.now();
    final pubDate = json['pubDate'] ?? json['publishedAt'] ?? json['publisher_timedate'];
    if (pubDate is num) {
      final millis = pubDate > 2000000000 ? pubDate.toInt() : pubDate.toInt() * 1000;
      publishedAt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } else if (pubDate is String) {
      final parsed = DateTime.tryParse(pubDate);
      if (parsed != null) {
        publishedAt = parsed.isUtc ? parsed : parsed.toUtc();
      }
    }

    String? summary;
    final content = json['summary'] ?? json['description'] ?? json['content'];
    if (content is String) {
      summary = content.trim().isEmpty ? null : content.trim();
    } else if (content is Map<String, dynamic>) {
      final body = content['summary'] ?? content['description'] ?? content['body'];
      if (body is String && body.trim().isNotEmpty) {
        summary = body.trim();
      }
    }

    String? thumbnail;
    final thumb = json['thumbnail'] ?? json['main_image'] ?? json['preview'];
    if (thumb is String) {
      thumbnail = thumb;
    } else if (thumb is Map<String, dynamic>) {
      final resolutions = thumb['resolutions'] ?? thumb['images'] ?? thumb['sizes'];
      if (resolutions is List && resolutions.isNotEmpty) {
        for (final entry in resolutions) {
          if (entry is Map<String, dynamic>) {
            final url = entry['url'] ?? entry['src'];
            if (url is String && url.isNotEmpty) {
              thumbnail = url;
              break;
            }
          }
        }
      } else {
        final url = thumb['url'] ?? thumb['src'];
        if (url is String && url.isNotEmpty) {
          thumbnail = url;
        }
      }
    }

    final tickers = <String>{};

    void absorbTickers(dynamic raw) {
      if (raw == null) return;
      if (raw is String) {
        final value = raw.trim();
        if (value.isNotEmpty) tickers.add(value.toUpperCase());
        return;
      }
      if (raw is Iterable) {
        for (final entry in raw) {
          absorbTickers(entry);
        }
        return;
      }
      if (raw is Map<String, dynamic>) {
        for (final value in raw.values) {
          absorbTickers(value);
        }
      }
    }

    absorbTickers(json['relatedTickers']);
    absorbTickers(json['relatedTickerSymbols']);
    absorbTickers(json['tickerSymbols']);
    absorbTickers(json['tickers']);
    absorbTickers(json['symbols']);
    absorbTickers(json['symbol']);
    if (json['content'] is Map<String, dynamic>) {
      absorbTickers((json['content'] as Map<String, dynamic>)['relatedTickers']);
    }

    return FinanceNewsItem(
      id: rawId,
      title: rawTitle,
      publisher: publisher,
      publishedAt: publishedAt,
      url: rawUrl,
      summary: summary,
      thumbnailUrl: thumbnail,
      relatedTickers: tickers,
    );
  }
}
