String sanitizeNewsGameText(String raw) {
  if (raw.trim().isEmpty) return '';

  var cleaned = raw;

  const entityMap = <String, String>{
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&#34;': '"',
    '&#39;': '\'',
    '&apos;': '\'',
    '&#x27;': '\'',
    '&nbsp;': ' ',
  };

  String decodePercentFragments(String value) {
    var output = value;
    for (var i = 0; i < 2; i += 1) {
      try {
        final decoded = Uri.decodeFull(output);
        if (decoded == output) break;
        output = decoded;
      } catch (_) {
        break;
      }
    }
    return output;
  }

  entityMap.forEach((key, value) {
    cleaned = cleaned.replaceAll(key, value);
  });

  cleaned = decodePercentFragments(cleaned);

  entityMap.forEach((key, value) {
    cleaned = cleaned.replaceAll(key, value);
  });

  final patterns = <RegExp>[
    RegExp(r'%3C[^%]*%3E', caseSensitive: false),
    RegExp(r'<[^>]*>', caseSensitive: false),
    RegExp(
      r'''(?<!\w)(?:href|src|target|rel|class|id|style|color|face|size|width|height|title|alt|media|lang|charset|font|blank|data-[a-z0-9_-]+)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>"']*)''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?<!\w)(?:h|hr|hre|href|s|sr|src|t|ta|tar|targ|target|r|re|rel|c|cl|cla|class|st|sty|style|co|col|color|f|fo|fon|font|fa|fac|face|si|siz|size|i|id)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>"']*)''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?:(?<=\s)|^|[?&])(?:utm_[a-z0-9_]+|fbclid|gclid|hl|h|src|ref|output|format|lang|target|class|style|color|size)\s*=\s*[^&\s]+''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?<!\w)(?:/?(?:a|font|span|div|p|strong|em|b|i|u)|href|src|target|rel|class|id|style|color|font|face|size|blank)(?!\w)''',
      caseSensitive: false,
    ),
    RegExp(r'''(?<!\w)_?blank["']?(?!\w)''', caseSensitive: false),
    RegExp(r'https?%3A%2F%2F\S+', caseSensitive: false),
    RegExp(r'https?://\S+', caseSensitive: false),
    RegExp(r'ftp://\S+', caseSensitive: false),
    RegExp(r'www\.\S+', caseSensitive: false),
    RegExp(r'\b[a-z0-9.-]+\.(com|net|org|io|co|fr|uk)\b', caseSensitive: false),
    RegExp(r'\[[^\]]*\]'),
    RegExp(r'\{[^\}]*\}'),
    RegExp(
      r'\([^)]*(?:href|target|blank|style|color|class)[^)]*\)',
      caseSensitive: false,
    ),
    RegExp(r'&[#a-z0-9]+;', caseSensitive: false),
    RegExp(r'%(?:[0-9a-f]{2})', caseSensitive: false),
    RegExp(r'[_|]+'),
    RegExp(
      r'''(?:(?<=\s)|^)[a-z]{1,3}\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>"']*)''',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    cleaned = cleaned.replaceAll(pattern, ' ');
  }

  cleaned =
      cleaned
          .replaceAll(RegExp(r'[<>]'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

  return cleaned;
}
