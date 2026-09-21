import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiService {
  static const String base =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String chatEndpoint =
      '$base/v1/chat';

  static const String imageEndpoint =
      '$base/v1/image';

  static const String newsEndpoint =
      '$base/v1/news';

  static const String audioSearchEndpoint =
      '$base/v1/audio/search-v4';

  static const String quranEndpoint =
      '$base/v1/audio/quran';

  static const String radioCountriesEndpoint =
      '$base/v1/radio/countries';

  static const String radioStationsEndpoint =
      '$base/v1/radio/stations';

  static const String shortsEndpoint =
      '$base/v1/shorts';

  static const int maxHistory = 8;

  // ------------------------------------------------------------
  // CONNECTION
  // ------------------------------------------------------------

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse(base),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return false;
      }

      return data['ok'] == true &&
          data['status'] == 'online' &&
          data['ai_configured'] == true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // CHAT
  // ------------------------------------------------------------

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history =
        const [],
  }) async {
    final text = prompt.trim();

    if (text.isEmpty) {
      return 'قول لي يا صاحبي 😊';
    }

    try {
      final validHistory = history
          .where(
            (item) =>
                (item['role'] == 'user' ||
                    item['role'] == 'assistant') &&
                (item['content'] ?? '')
                    .trim()
                    .isNotEmpty,
          )
          .toList();

      final start =
          validHistory.length > maxHistory
              ? validHistory.length - maxHistory
              : 0;

      final messages =
          <Map<String, String>>[];

      for (final item
          in validHistory.sublist(start)) {
        messages.add({
          'role': item['role']!,
          'content': item['content']!.trim(),
        });
      }

      String current = text;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        current =
            'سياق الخدمة:\n'
            '${serviceContext.trim()}\n\n'
            'رسالة المستخدم:\n'
            '$text';
      }

      messages.add({
        'role': 'user',
        'content': current,
      });

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
              'Cache-Control':
                  'no-cache',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = _decodeMap(response.body);

      if (data != null &&
          data['ok'] == true &&
          data['reply'] is String &&
          data['reply']
              .toString()
              .trim()
              .isNotEmpty) {
        return data['reply']
            .toString()
            .trim();
      }

      return data?['error']?.toString() ??
          'صاحبي مش قادر يرد دلوقتي. جرّب تاني.';
    } catch (_) {
      return 'حصل تأخير في الاتصال بصاحبي. جرّب تاني.';
    }
  }

  // ------------------------------------------------------------
  // IMAGE ANALYSIS
  // ------------------------------------------------------------

  static Future<String> analyzeImage(
    XFile file, {
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، واذكر الأشياء المهمة الظاهرة فيها.',
    String? serviceContext,
  }) async {
    try {
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return 'الصورة لم يتم قراءتها.';
      }

      if (bytes.length > 5 * 1024 * 1024) {
        return 'الصورة كبيرة جدًا. ابعت صورة أصغر من 5 ميجابايت.';
      }

      String finalPrompt = prompt.trim();

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        finalPrompt =
            'سياق الخدمة:\n'
            '${serviceContext.trim()}\n\n'
            'طلب المستخدم:\n'
            '$finalPrompt';
      }

      final mime = _mime(file.name);

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'messages': [
                {
                  'role': 'user',
                  'content': finalPrompt,
                },
              ],
              'image':
                  'data:$mime;base64,${base64Encode(bytes)}',
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = _decodeMap(response.body);

      if (data != null &&
          data['ok'] == true &&
          data['reply'] is String &&
          data['reply']
              .toString()
              .trim()
              .isNotEmpty) {
        return data['reply']
            .toString()
            .trim();
      }

      return data?['error']?.toString() ??
          'الصورة وصلت، لكن التحليل لم يكتمل.';
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة. جرّب مرة تانية.';
    }
  }

  // ------------------------------------------------------------
  // IMAGE GENERATION
  // ------------------------------------------------------------

  static Future<ImageGenerationResult>
      generateImage(
    String prompt,
  ) async {
    final cleanPrompt = prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ImageGenerationResult.failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    if (cleanPrompt.length > 8000) {
      return const ImageGenerationResult.failure(
        'وصف الصورة طويل جدًا.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(imageEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
              'Cache-Control':
                  'no-cache',
            },
            body: jsonEncode({
              'prompt': cleanPrompt,
            }),
          )
          .timeout(
            const Duration(seconds: 180),
          );

      if (response.statusCode != 200) {
        return ImageGenerationResult.failure(
          _serverError(response),
        );
      }

      final data = _decodeMap(response.body);

      if (data == null) {
        return const ImageGenerationResult.failure(
          'رد خدمة الصور غير مفهوم.',
        );
      }

      if (data['ok'] != true) {
        return ImageGenerationResult.failure(
          data['error']?.toString() ??
              'خدمة الصور لم تعمل.',
        );
      }

      String? base64Image;

      final direct =
          data['image_base64'];

      if (direct is String &&
          direct.trim().isNotEmpty) {
        base64Image = direct.trim();
      }

      if (base64Image == null) {
        final nested = data['data'];

        if (nested is List &&
            nested.isNotEmpty &&
            nested.first is Map) {
          final value =
              nested.first['b64_json'];

          if (value is String &&
              value.trim().isNotEmpty) {
            base64Image = value.trim();
          }
        }
      }

      if (base64Image == null ||
          base64Image.isEmpty) {
        return const ImageGenerationResult.failure(
          'خدمة الصور لم ترجع صورة.',
        );
      }

      try {
        String cleanBase64 =
            base64Image;

        if (cleanBase64.startsWith(
          'data:image/',
        )) {
          final comma =
              cleanBase64.indexOf(',');

          if (comma != -1) {
            cleanBase64 =
                cleanBase64.substring(
              comma + 1,
            );
          }
        }

        final bytes =
            base64Decode(cleanBase64);

        if (bytes.isEmpty) {
          return const ImageGenerationResult.failure(
            'خدمة الصور رجعت بيانات فارغة.',
          );
        }

        return ImageGenerationResult.success(
          bytes,
        );
      } catch (_) {
        return const ImageGenerationResult.failure(
          'تعذر قراءة الصورة التي رجعتها الخدمة.',
        );
      }
    } catch (_) {
      return const ImageGenerationResult.failure(
        'الاتصال بخدمة الصور انتهى قبل وصول النتيجة.',
      );
    }
  }

  // ------------------------------------------------------------
  // NEWS
  // ------------------------------------------------------------

  static Future<List<NewsItem>> getNews() async {
    try {
      final uri =
          Uri.parse(newsEndpoint).replace(
        queryParameters: {
          'refresh': DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data = _decodeMap(response.body);

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      return (data['items'] as List)
          .whereType<Map>()
          .map(
            (item) => NewsItem(
              title:
                  item['title']?.toString() ?? '',
              source:
                  item['source']?.toString() ??
                      'الأخبار',
              link:
                  item['link']?.toString() ?? '',
              imageUrl:
                  item['imageUrl']?.toString() ??
                      '',
            ),
          )
          .where(
            (item) =>
                item.title.isNotEmpty &&
                item.link.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // GENERIC AUDIO SEARCH
  // ------------------------------------------------------------

  static Future<List<AudioSearchItem>>
      searchAudio(
    String query, {
    String type = 'quran',
  }) async {
    final clean = query.trim();

    if (clean.isEmpty) {
      return [];
    }

    try {
      final uri =
          Uri.parse(audioSearchEndpoint)
              .replace(
        queryParameters: {
          'q': clean,
          'type': type,
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data = _decodeMap(response.body);

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      return (data['items'] as List)
          .whereType<Map>()
          .map(
            (item) => AudioSearchItem(
              title:
                  item['title']?.toString() ??
                      '',
              artist:
                  item['artist']?.toString(),
              url:
                  item['url']?.toString() ??
                      '',
              type:
                  item['type']?.toString() ??
                      type,
              artwork:
                  item['artwork']?.toString() ??
                      '',
              storeUrl:
                  item['storeUrl']?.toString() ??
                      '',
              text:
                  item['text']?.toString() ??
                      '',
            ),
          )
          .where(
            (item) =>
                item.title.isNotEmpty &&
                item.url.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // QURAN CATALOG
  // ------------------------------------------------------------

  static Future<QuranCatalog?>
      getQuranCatalog() async {
    try {
      final response = await http
          .get(
            Uri.parse(quranEndpoint),
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final data = _decodeMap(response.body);

      if (data == null ||
          data['ok'] != true) {
        return null;
      }

      final reciterList =
          data['reciters'];

      final suraList =
          data['suwar'];

      final reciters =
          <QuranReciter>[];

      if (reciterList is List) {
        for (final item
            in reciterList) {
          if (item is! Map) continue;

          final moshafRaw =
              item['moshaf'];

          final moshafList =
              <QuranMoshaf>[];

          if (moshafRaw is List) {
            for (final m
                in moshafRaw) {
              if (m is! Map) continue;

              moshafList.add(
                QuranMoshaf(
                  id:
                      m['id']?.toString() ??
                          '',
                  name:
                      m['name']?.toString() ??
                          '',
                  server:
                      m['server']?.toString() ??
                          '',
                  surahTotal:
                      int.tryParse(
                            m['surahTotal']
                                    ?.toString() ??
                                '',
                          ) ??
                          0,
                  surahList:
                      m['surahList']
                              ?.toString() ??
                          '',
                ),
              );
            }
          }

          reciters.add(
            QuranReciter(
              id:
                  item['id']?.toString() ??
                      '',
              name:
                  item['name']?.toString() ??
                      'قارئ',
              moshaf:
                  moshafList,
            ),
          );
        }
      }

      final suwar =
          <QuranSura>[];

      if (suraList is List) {
        for (final item
            in suraList) {
          if (item is! Map) continue;

          final id =
              int.tryParse(
                item['id']?.toString() ??
                    '',
              );

          if (id == null ||
              id < 1 ||
              id > 114) {
            continue;
          }

          suwar.add(
            QuranSura(
              id: id,
              name:
                  item['name']?.toString() ??
                      'سورة',
            ),
          );
        }
      }

      return QuranCatalog(
        reciters: reciters,
        suwar: suwar,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // RADIO COUNTRIES
  // ------------------------------------------------------------

  static Future<List<RadioCountry>>
      getRadioCountries() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              radioCountriesEndpoint,
            ),
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data =
          _decodeMap(response.body);

      if (data == null ||
          data['countries'] is! List) {
        return [];
      }

      return (data['countries'] as List)
          .whereType<Map>()
          .map(
            (item) => RadioCountry(
              name:
                  item['name']?.toString() ??
                      '',
              code:
                  item['code']?.toString() ??
                      '',
              stationCount:
                  int.tryParse(
                        item['stationCount']
                                ?.toString() ??
                            '',
                      ) ??
                      0,
            ),
          )
          .where(
            (item) =>
                item.name.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // RADIO STATIONS
  // ------------------------------------------------------------

  static Future<List<RadioStation>>
      getRadioStations(
    String country,
  ) async {
    final clean = country.trim();

    if (clean.isEmpty) {
      return [];
    }

    try {
      final uri =
          Uri.parse(
            radioStationsEndpoint,
          ).replace(
        queryParameters: {
          'country': clean,
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data =
          _decodeMap(response.body);

      if (data == null ||
          data['stations'] is! List) {
        return [];
      }

      return (data['stations'] as List)
          .whereType<Map>()
          .map(
            (item) => RadioStation(
              name:
                  item['name']?.toString() ??
                      'محطة',
              url:
                  item['url']?.toString() ??
                      '',
              homepage:
                  item['homepage']?.toString() ??
                      '',
              favicon:
                  item['favicon']?.toString() ??
                      '',
              tags:
                  item['tags']?.toString() ??
                      '',
              codec:
                  item['codec']?.toString() ??
                      '',
              bitrate:
                  int.tryParse(
                        item['bitrate']
                                ?.toString() ??
                            '',
                      ) ??
                      0,
            ),
          )
          .where(
            (item) =>
                item.name.isNotEmpty &&
                item.url.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // SHORTS
  // ------------------------------------------------------------

  static Future<List<ShortVideoItem>>
      getShorts() async {
    try {
      final response = await http
          .get(
            Uri.parse(shortsEndpoint),
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data =
          _decodeMap(response.body);

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      return (data['items'] as List)
          .whereType<Map>()
          .map(
            (item) => ShortVideoItem(
              title:
                  item['title']?.toString() ??
                      '',
              creator:
                  item['creator']?.toString() ??
                      '',
              videoUrl:
                  item['videoUrl']?.toString() ??
                      '',
              thumbnail:
                  item['thumbnail']?.toString() ??
                      '',
            ),
          )
          .where(
            (item) =>
                item.videoUrl.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  static Map<String, dynamic>?
      _decodeMap(String body) {
    try {
      final decoded =
          jsonDecode(body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _mime(String name) {
    final value =
        name.toLowerCase();

    if (value.endsWith('.png')) {
      return 'image/png';
    }

    if (value.endsWith('.webp')) {
      return 'image/webp';
    }

    if (value.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }

  static String _serverError(
    http.Response response,
  ) {
    try {
      final data =
          _decodeMap(response.body);

      if (data != null) {
        final error =
            data['error'];

        if (error != null &&
            error
                .toString()
                .trim()
                .isNotEmpty) {
          return error.toString();
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'الطلب غير صحيح.';

      case 401:
      case 403:
        return 'خدمة الذكاء الاصطناعي تحتاج إعداد صلاحية صحيح.';

      case 429:
        return 'الخدمة مشغولة حاليًا. جرّب بعد لحظات.';

      case 500:
      case 502:
      case 503:
        return 'الخادم مشغول أو الخدمة غير متاحة حاليًا.';

      default:
        return 'حصل خطأ في الاتصال بالخادم.';
    }
  }
}

// ============================================================
// NEWS
// ============================================================

class NewsItem {
  final String title;
  final String source;
  final String link;
  final String imageUrl;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    this.imageUrl = '',
  });
}

// ============================================================
// AUDIO
// ============================================================

class AudioSearchItem {
  final String title;
  final String? artist;
  final String url;
  final String type;
  final String artwork;
  final String storeUrl;
  final String text;

  const AudioSearchItem({
    required this.title,
    required this.url,
    this.artist,
    required this.type,
    this.artwork = '',
    this.storeUrl = '',
    this.text = '',
  });
}

// ============================================================
// IMAGE
// ============================================================

class ImageGenerationResult {
  final Uint8List? bytes;
  final String? error;

  const ImageGenerationResult._({
    this.bytes,
    this.error,
  });

  const ImageGenerationResult.success(
    Uint8List bytes,
  ) : this._(
          bytes: bytes,
        );

  const ImageGenerationResult.failure(
    String error,
  ) : this._(
          error: error,
        );

  bool get isSuccess =>
      bytes != null &&
      bytes!.isNotEmpty;
}

// ============================================================
// QURAN
// ============================================================

class QuranCatalog {
  final List<QuranReciter> reciters;
  final List<QuranSura> suwar;

  const QuranCatalog({
    required this.reciters,
    required this.suwar,
  });
}

class QuranReciter {
  final String id;
  final String name;
  final List<QuranMoshaf> moshaf;

  const QuranReciter({
    required this.id,
    required this.name,
    required this.moshaf,
  });
}

class QuranMoshaf {
  final String id;
  final String name;
  final String server;
  final int surahTotal;
  final String surahList;

  const QuranMoshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
    required this.surahList,
  });
}

class QuranSura {
  final int id;
  final String name;

  const QuranSura({
    required this.id,
    required this.name,
  });
}

// ============================================================
// RADIO
// ============================================================

class RadioCountry {
  final String name;
  final String code;
  final int stationCount;

  const RadioCountry({
    required this.name,
    required this.code,
    required this.stationCount,
  });
}

class RadioStation {
  final String name;
  final String url;
  final String homepage;
  final String favicon;
  final String tags;
  final String codec;
  final int bitrate;

  const RadioStation({
    required this.name,
    required this.url,
    required this.homepage,
    required this.favicon,
    required this.tags,
    required this.codec,
    required this.bitrate,
  });
}

// ============================================================
// SHORT VIDEOS
// ============================================================

class ShortVideoItem {
  final String title;
  final String creator;
  final String videoUrl;
  final String thumbnail;

  const ShortVideoItem({
    required this.title,
    required this.creator,
    required this.videoUrl,
    required this.thumbnail,
  });
}
