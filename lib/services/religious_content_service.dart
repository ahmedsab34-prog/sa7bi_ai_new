import 'dart:async';
import 'dart:convert';

import '../ai_service.dart';
import '../config/app_config.dart';
import 'sa7bi_network_client.dart';

/// خدمات المحتوى الديني التي تحتاج إلى إظهار أخطاء المصدر
/// بدل إرجاع قائمة فارغة توحي بأن البحث لم يجد نتائج.
class ReligiousContentService {
  ReligiousContentService._();

  static const Duration _timeout = Duration(seconds: 25);

  static String get _base => AppConfig.backendBaseUrl;

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> _get(
    String endpoint, {
    Map<String, String> query = const {},
  }) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: query.isEmpty ? null : query,
    );

    try {
      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_timeout);

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final providerError =
            data?['providerError']?.toString().trim() ??
            data?['error']?.toString().trim() ??
            '';

        throw ReligiousContentException(
          _httpMessage(response.statusCode, providerError),
          statusCode: response.statusCode,
          providerCode: providerError,
        );
      }

      if (data == null) {
        throw const ReligiousContentException(
          'رد المصدر غير مفهوم. حاول التحديث.',
        );
      }

      if (data['ok'] == false) {
        final code = data['error']?.toString() ?? '';
        final message = data['message']?.toString().trim();

        throw ReligiousContentException(
          message != null && message.isNotEmpty
              ? message
              : _providerMessage(code),
          providerCode: code,
        );
      }

      return data;
    } on TimeoutException {
      throw const ReligiousContentException(
        'الاتصال بمصدر المحتوى استغرق وقتًا أطول من اللازم. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } on ReligiousContentException {
      rethrow;
    } catch (error) {
      throw ReligiousContentException(
        'تعذر الاتصال بمصدر المحتوى: ${_safeError(error)}',
      );
    }
  }

  static String _httpMessage(int status, String providerCode) {
    if (status == 429) {
      return 'المصدر يستقبل طلبات كثيرة حاليًا. حاول بعد قليل.';
    }
    if (status >= 500) {
      return 'مصدر المحتوى غير متاح مؤقتًا. حاول مرة أخرى لاحقًا.';
    }
    if (providerCode.isNotEmpty) {
      return _providerMessage(providerCode);
    }
    return 'تعذر تحميل المحتوى (HTTP $status).';
  }

  static String _providerMessage(String code) {
    switch (code) {
      case 'TAFSIR_TEXT_BOOKS_UNAVAILABLE':
      case 'TAFSIR_TEXT_UNAVAILABLE':
      case 'QURANENC_TIMEOUT':
      case 'QURANENC_UNAVAILABLE':
        return 'مصدر التفسير النصي غير متاح مؤقتًا.';
      case 'UNSUPPORTED_TAFSIR_KEY':
        return 'كتاب التفسير المختار غير متاح.';
      case 'TAFSIR_TEXT_QUERY_REQUIRED':
        return 'اكتب كلمة للبحث في التفسير.';
      default:
        return code.isEmpty
            ? 'تعذر تحميل المحتوى من المصدر.'
            : 'تعذر تحميل المحتوى: $code';
    }
  }

  static String _safeError(Object error) {
    final value = error.toString();
    if (value.length > 180) {
      return value.substring(0, 180);
    }
    return value;
  }

  // ------------------------------------------------------------
  // HADITH
  // ------------------------------------------------------------

  static Future<List<HadithBook>> getHadithBooks() async {
    final data = await _get('$_base/v1/hadith/books');
    final rawItems = data['items'];

    if (rawItems is! List) {
      throw const ReligiousContentException(
        'رد قائمة كتب الحديث غير مكتمل.',
      );
    }

    final result = <HadithBook>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;

      final id = raw['id']?.toString().trim() ?? '';
      final name = raw['name']?.toString().trim() ?? '';

      if (id.isEmpty || name.isEmpty) continue;

      result.add(
        HadithBook(
          id: id,
          name: name,
        ),
      );
    }

    return result;
  }

  static Future<List<HadithItem>> searchHadith({
    String query = '',
    String? book,
    int limit = 20,
  }) async {
    final parameters = <String, String>{
      'limit': limit.clamp(1, 50).toString(),
    };

    if (query.trim().isNotEmpty) {
      parameters['q'] = query.trim();
    }
    if (book != null && book.trim().isNotEmpty) {
      parameters['book'] = book.trim();
    }

    final data = await _get(
      '$_base/v1/hadith',
      query: parameters,
    );

    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const ReligiousContentException(
        'رد البحث عن الحديث غير مكتمل.',
      );
    }

    final result = <HadithItem>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;

      final text = raw['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;

      result.add(
        HadithItem(
          id: raw['id']?.toString() ?? '',
          number: raw['number']?.toString() ?? '',
          book: raw['book']?.toString() ?? '',
          bookName: raw['bookName']?.toString() ?? '',
          text: text,
          source: raw['source']?.toString() ?? 'Hadith API',
        ),
      );
    }

    return result;
  }

  // ------------------------------------------------------------
  // QURANENC ARABIC TAFSIR TEXT
  // ------------------------------------------------------------

  static Future<List<TafsirTextBook>> getTafsirTextBooks() async {
    final data = await _get(
      '$_base/v1/tafsir-text/books',
    );

    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const ReligiousContentException(
        'رد قائمة كتب التفسير النصي غير مكتمل.',
      );
    }

    final result = <TafsirTextBook>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;

      final key = raw['key']?.toString().trim() ?? '';
      final name = raw['name']?.toString().trim() ?? '';

      if (key.isEmpty || name.isEmpty) continue;

      result.add(
        TafsirTextBook(
          key: key,
          name: name,
          description: raw['description']?.toString() ?? '',
          version: raw['version']?.toString() ?? '',
        ),
      );
    }

    return result;
  }

  static Future<List<TafsirTextItem>> searchTafsirText({
    required String key,
    required String query,
  }) async {
    final cleanKey = key.trim();
    final cleanQuery = query.trim();

    if (cleanKey.isEmpty) {
      throw const ReligiousContentException(
        'اختر كتاب التفسير النصي أولًا.',
      );
    }

    if (cleanQuery.isEmpty) {
      return const <TafsirTextItem>[];
    }

    final data = await _get(
      '$_base/v1/tafsir-text',
      query: {
        'key': cleanKey,
        'q': cleanQuery,
      },
    );

    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const ReligiousContentException(
        'رد البحث في التفسير غير مكتمل.',
      );
    }

    final result = <TafsirTextItem>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;

      final text = raw['text']?.toString().trim() ?? '';
      final sura = int.tryParse(raw['sura']?.toString() ?? '') ?? 0;
      final fromAya =
          int.tryParse(raw['fromAya']?.toString() ?? '') ?? 0;
      final toAya =
          int.tryParse(raw['toAya']?.toString() ?? '') ?? fromAya;

      if (text.isEmpty ||
          sura < 1 ||
          sura > 114 ||
          fromAya < 1) {
        continue;
      }

      result.add(
        TafsirTextItem(
          id: raw['id']?.toString() ?? '$sura-$fromAya',
          sura: sura,
          fromAya: fromAya,
          toAya: toAya >= fromAya ? toAya : fromAya,
          type: raw['type']?.toString() ?? 'tafsir',
          text: text,
          source: raw['source']?.toString() ?? 'QuranEnc',
        ),
      );
    }

    return result;
  }
}

class ReligiousContentException implements Exception {
  final String message;
  final int? statusCode;
  final String? providerCode;

  const ReligiousContentException(
    this.message, {
    this.statusCode,
    this.providerCode,
  });

  @override
  String toString() => message;
}

class TafsirTextBook {
  final String key;
  final String name;
  final String description;
  final String version;

  const TafsirTextBook({
    required this.key,
    required this.name,
    this.description = '',
    this.version = '',
  });

  @override
  bool operator ==(Object other) =>
      other is TafsirTextBook && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class TafsirTextItem {
  final String id;
  final int sura;
  final int fromAya;
  final int toAya;
  final String type;
  final String text;
  final String source;

  const TafsirTextItem({
    required this.id,
    required this.sura,
    required this.fromAya,
    required this.toAya,
    required this.type,
    required this.text,
    required this.source,
  });
}
