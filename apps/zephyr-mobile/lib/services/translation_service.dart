import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight translation service using Google Translate (free tier).
/// Caches translations to avoid repeated network calls.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  final Map<String, String> _cache = {};

  /// Translate [text] to [targetLang] (e.g. 'en', 'fr', 'zh').
  /// Returns translated text, or null on failure / no change.
  Future<String?> translate(String text, {String targetLang = 'en'}) async {
    if (text.trim().isEmpty) return null;

    final String cacheKey = '${targetLang}_$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final Uri uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single',
      ).replace(queryParameters: {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': 't',
        'q': text,
      });

      final http.Response response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body) as List<dynamic>;
        final StringBuffer translated = StringBuffer();
        for (final segment in decoded[0] as List<dynamic>) {
          translated.write(segment[0] as String);
        }
        final String result = translated.toString();
        if (result.toLowerCase().trim() == text.toLowerCase().trim()) {
          return null;
        }
        _cache[cacheKey] = result;
        return result;
      }
    } catch (_) {}

    return null;
  }
}
