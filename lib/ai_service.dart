import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'services/ai_request_service.dart';

class AiService {
  AiService._();

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

  // ============================================================
  // CONNECTION
  // ============================================================

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

      final data = _decodeMap(response.body);

      if (data == null) {
        return false;
      }

      return data['ok'] == true &&
          data['status'] == 'online';
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // CHAT
  // ============================================================

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      return await AiRequestService.getResponse(
        prompt: prompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
        history: history,
      );
    } on AiRequestException catch (error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير في الاتصال بصاحبي. جرّب تاني.';
    }
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

  static Future<String> analyzeImage(
    XFile file, {
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، واذكر الأشياء المهمة الظاهرة فيها.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    try {
      return await AiRequestService.analyzeImage(
        file: file,
        prompt: prompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
      );
    } on AiRequestException catch (error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // MULTI IMAGE / VIDEO FRAME ANALYSIS
  // ============================================================

  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا باعتبارها لقطات من نفس الفيديو. '
        'اشرح ما يظهر فيها، وما الذي يحدث عبر اللقطات، '
        'واذكر أي نصوص أو أدوات أو أشخاص أو أشياء مهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    try {
      return await AiRequestService.analyzeImages(
        images,
        prompt: prompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
      );
    } on AiRequestException catch (error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصور. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // IMAGE GENERATION
  // ============================================================

  static Future<ImageGenerationResult> generateImage(
    String prompt,
  ) async {
    try {
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

      final response = await http
          .post(
            Uri.parse(imageEndpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
            body: jsonEncode({
              'prompt': cleanPrompt,
            }),
          )
          .timeout(
            const Duration(seconds: 180),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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

      final direct = data['imageDataUrl'];

      if (direct is String &&
          direct.trim().isNotEmpty) {
        try {
          var cleanBase64 = direct.trim();

          if (cleanBase64.startsWith('data:image/')) {
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
      }

      final imageUrl = data['imageUrl'];

      if (imageUrl is String &&
          imageUrl.trim().isNotEmpty) {
        return ImageGenerationResult.successUrl(
          imageUrl.trim(),
        );
      }

      return const ImageGenerationResult.failure(
        'خدمة الصور لم ترجع صورة.',
      );
    } on TimeoutException {
      return const ImageGenerationResult.failure(
        'الاتصال بخدمة الصور استغرق وقتًا أطول من اللازم.',
      );
    } catch (_) {
      return const ImageGenerationResult.failure(
        'تعذر الاتصال بخدمة الصور حاليًا.',
      );
    }
  }

  // ============================================================
  // NEWS
  // ============================================================

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
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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
            (item) => NewsItem(
              title:
                  item['title']?.toString() ??
                      '',
              source:
                  item['source']?.toString() ??
                      'الأخبار',
              link:
                  item['link']?.toString() ??
                      '',
              imageUrl:
                  (
                    item['imageUrl'] ??
                    item['image'] ??
                    ''
                  ).toString(),
              description:
                  item['description']
                          ?.toString() ??
                      '',
              pubDate:
                  item['pubDate']
                          ?.toString() ??
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

  // ============================================================
  // AUDIO SEARCH
  // ============================================================

  static Future<List<AudioSearchItem>> searchAudio(
    String query, {
    String type = 'quran',
  }) async {
    final clean =
        query.trim();

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
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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
            (item) => AudioSearchItem(
              id:
                  item['id']?.toString() ??
                      '',
              title:
                  item['title']?.toString() ??
                      '',
              artist:
                  item['artist']?.toString(),
              url:
                  (
                    item['url'] ??
                    item['previewUrl'] ??
                    ''
                  ).toString(),
              type:
                  item['type']?.toString() ??
                      type,
              artwork:
                  (
                    item['artwork'] ??
                    ''
                  ).toString(),
              storeUrl:
                  (
                    item['storeUrl'] ??
                    ''
                  ).toString(),
              text:
                  (
                    item['text'] ??
                    ''
                  ).toString(),
              repeat:
                  item['repeat']?.toString() ??
                      '',
              collection:
                  item['collection']
                          ?.toString() ??
                      '',
              feedUrl:
                  item['feedUrl']?.toString() ??
                      '',
            ),
          )
          .where(
            (item) =>
                item.title.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // QURAN CATALOG
  // ============================================================

  static Future<QuranCatalog?> getQuranCatalog() async {
    try {
      final response = await http
          .get(
            Uri.parse(quranEndpoint),
            headers: const {
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final data =
          _decodeMap(response.body);

      if (data == null ||
          data['ok'] != true) {
        return null;
      }

      final reciterList =
          data['reciters'];

      final suraList =
          data['suras'] ??
              data['suwar'];

      final reciters =
          <QuranReciter>[];

      if (reciterList is List) {
        for (final item in reciterList) {
          if (item is! Map) {
            continue;
          }

          final moshafRaw =
              item['moshaf'];

          final moshafList =
              <QuranMoshaf>[];

          if (moshafRaw is List) {
            for (final m in moshafRaw) {
              if (m is! Map) {
                continue;
              }

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
                            (
                              m['surahTotal'] ??
                              m['surah_total'] ??
                              ''
                            ).toString(),
                          ) ??
                          0,
                  surahList:
                      (
                        m['suras'] ??
                        m['surahList'] ??
                        ''
                      ).toString(),
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
        for (final item in suraList) {
          if (item is! Map) {
            continue;
          }

          final id =
              int.tryParse(
            (
              item['id'] ??
              item['sura_id'] ??
              item['number'] ??
              ''
            ).toString(),
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
                  (
                    item['name'] ??
                    item['sura_name'] ??
                    'سورة'
                  ).toString(),
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

  // ============================================================
  // RADIO COUNTRIES
  // ============================================================

  static Future<List<RadioCountry>>
      getRadioCountries() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              radioCountriesEndpoint,
            ),
            headers: const {
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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
                  (
                    item['iso'] ??
                    item['code'] ??
                    ''
                  ).toString(),
              stationCount:
                  int.tryParse(
                        (
                          item['stationCount'] ??
                          0
                        ).toString(),
                      ) ??
                      0,
            ),
          )
          .where(
            (item) =>
                item.name.isNotEmpty &&
                item.code.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // RADIO STATIONS
  // ============================================================

  static Future<List<RadioStation>>
      getRadioStations(
    String country,
  ) async {
    final clean =
        country.trim();

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
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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
              id:
                  item['id']?.toString() ??
                      '',
              name:
                  item['name']?.toString() ??
                      'محطة',
              url:
                  (
                    item['streamUrl'] ??
                    item['url'] ??
                    ''
                  ).toString(),
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
                        (
                          item['bitrate'] ??
                          0
                        ).toString(),
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

  // ============================================================
  // SHORTS
  // ============================================================

  static Future<List<ShortVideoItem>>
      getShorts() async {
    try {
      final response = await http
          .get(
            Uri.parse(shortsEndpoint),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
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
              id:
                  item['id']?.toString() ??
                      '',
              title:
                  item['title']?.toString() ??
                      '',
              creator:
                  (
                    item['creator'] ??
                    item['source'] ??
                    ''
                  ).toString(),
              videoUrl:
                  (
                    item['videoUrl'] ??
                    item['url'] ??
                    ''
                  ).toString(),
              thumbnail:
                  (
                    item['thumbnail'] ??
                    item['image'] ??
                    item['cover'] ??
                    ''
                  ).toString(),
              description:
                  item['description']
                          ?.toString() ??
                      '',
            ),
          )
          .where(
            (item) =>
                item.videoUrl.isNotEmpty ||
                item.thumbnail.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

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

  static String _serverError(
    http.Response response,
  ) {
    final data =
        _decodeMap(response.body);

    final error =
        data?['error']
            ?.toString()
            .trim();

    if (error != null &&
        error.isNotEmpty) {
      return error;
    }

    switch (response.statusCode) {
      case 400:
        return 'الطلب غير صحيح.';

      case 401:
      case 403:
        return 'خدمة الذكاء الاصطناعي تحتاج إعداد صلاحية صحيح.';

      case 408:
        return 'الطلب استغرق وقتًا أطول من اللازم.';

      case 413:
        return 'البيانات المرسلة كبيرة جدًا.';

      case 429:
        return 'الخدمة مشغولة حاليًا. جرّب بعد لحظات.';

      case 500:
        return 'حصل خطأ داخل الخادم.';

      case 502:
      case 503:
      case 504:
        return 'الخدمة غير متاحة مؤقتًا.';

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
  final String description;
  final String pubDate;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    this.imageUrl = '',
    this.description = '',
    this.pubDate = '',
  });
}

// ============================================================
// AUDIO
// ============================================================

class AudioSearchItem {
  final String id;
  final String title;
  final String? artist;
  final String url;
  final String type;
  final String artwork;
  final String storeUrl;
  final String text;
  final String repeat;
  final String collection;
  final String feedUrl;

  const AudioSearchItem({
    this.id = '',
    required this.title,
    required this.url,
    this.artist,
    required this.type,
    this.artwork = '',
    this.storeUrl = '',
    this.text = '',
    this.repeat = '',
    this.collection = '',
    this.feedUrl = '',
  });
}

// ============================================================
// IMAGE
// ============================================================

class ImageGenerationResult {
  final Uint8List? bytes;
  final String? imageUrl;
  final String? error;

  const ImageGenerationResult._({
    this.bytes,
    this.imageUrl,
    this.error,
  });

  const ImageGenerationResult.success(
    Uint8List bytes,
  ) : this._(
          bytes: bytes,
        );

  const ImageGenerationResult.successUrl(
    String url,
  ) : this._(
          imageUrl: url,
        );

  const ImageGenerationResult.failure(
    String error,
  ) : this._(
          error: error,
        );

  bool get isSuccess =>
      (bytes != null &&
          bytes!.isNotEmpty) ||
      (imageUrl != null &&
          imageUrl!.isNotEmpty);
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
  final String id;
  final String name;
  final String url;
  final String homepage;
  final String favicon;
  final String tags;
  final String codec;
  final int bitrate;

  const RadioStation({
    this.id = '',
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
  final String id;
  final String title;
  final String creator;
  final String videoUrl;
  final String thumbnail;
  final String description;

  const ShortVideoItem({
    this.id = '',
    required this.title,
    required this.creator,
    required this.videoUrl,
    required this.thumbnail,
    this.description = '',
  });
}
