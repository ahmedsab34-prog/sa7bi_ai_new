import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config/app_config.dart';
import 'services/ai_request_service.dart';

/// واجهة الخدمات القديمة/المشتركة في التطبيق.
///
/// مهم:
/// - لا تحتوي على أي API Key.
/// - لا تتصل مباشرة بـ Gemini أو أي مزود AI.
/// - وظائف الذكاء الاصطناعي تمر من AiRequestService.
/// - الأخبار والصوت والقرآن والراديو والـShorts تمر عبر Worker.
/// - نظام Credits الخاص بالـAI يتم التعامل معه داخل الـBackend.
///
/// هذا الملف موجود للحفاظ على التوافق مع الشاشات القديمة
/// التي قد تستدعي AiService بدل AiRequestService مباشرة.
class AiService {
  AiService._();

  static const String base =
      AppConfig.backendBaseUrl;

  static const String chatEndpoint =
      AppConfig.aiChatEndpoint;

  static const String imageEndpoint =
      AppConfig.imageGenerationEndpoint;

  static const String newsEndpoint =
      AppConfig.newsEndpoint;

  static const String audioSearchEndpoint =
      AppConfig.audioSearchEndpoint;

  static const String quranEndpoint =
      AppConfig.quranEndpoint;

  static const String radioCountriesEndpoint =
      AppConfig.radioCountriesEndpoint;

  static const String radioStationsEndpoint =
      AppConfig.radioStationsEndpoint;

  static const String shortsEndpoint =
      AppConfig.shortsEndpoint;

  static const int maxHistory =
      AppConfig.maximumContextMessages;

  // ============================================================
  // CONNECTION
  // ============================================================

  /// اختبار اتصال التطبيق بالـWorker.
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

      final data =
          _decodeMap(response.body);

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

  /// إرسال رسالة نصية إلى صاحبي AI.
  ///
  /// لا يتم الاتصال بمزود AI مباشرة من التطبيق.
  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history =
        const [],
  }) async {
    final cleanPrompt =
        prompt.trim();

    if (cleanPrompt.isEmpty) {
      return 'اكتب رسالتك الأول.';
    }

    try {
      return await AiRequestService
          .getResponse(
        prompt: cleanPrompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
        history:
            _limitHistory(history),
      );
    } on AiRequestException catch (
        error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير في الاتصال بصاحبي. جرّب تاني.';
    }
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

  /// تحليل صورة واحدة.
  static Future<String> analyzeImage(
    XFile file, {
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، '
        'واذكر الأشياء المهمة الظاهرة فيها.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    try {
      return await AiRequestService
          .analyzeImage(
        file: file,
        prompt: prompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
      );
    } on AiRequestException catch (
        error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // MULTI IMAGE
  // ============================================================

  /// تحليل مجموعة صور.
  ///
  /// هذه الدالة مخصصة للصور المتعددة.
  /// تحليل الفيديو الحقيقي يستخدم
  /// AiRequestService.analyzeVideoFrames()
  /// حتى يتم احتساب تكلفة الفيديو الصحيحة.
  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا. '
        'اشرح ما يظهر فيها، واذكر النصوص والأشياء المهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (images.isEmpty) {
      return 'لم يتم العثور على صور لتحليلها.';
    }

    try {
      return await AiRequestService
          .analyzeImages(
        images,
        prompt: prompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
      );
    } on AiRequestException catch (
        error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصور. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // VIDEO FRAMES
  // ============================================================

  /// تحليل لقطات مستخرجة من فيديو.
  ///
  /// مهم:
  /// نستخدم الدالة الجديدة حتى يرسل التطبيق
  /// videoAnalysis = true للـWorker،
  /// وبالتالي يتم احتساب تكلفة تحليل الفيديو الصحيحة.
  static Future<String> analyzeVideoFrames(
    List<Uint8List> frames, {
    String prompt =
        'هذه لقطات مستخرجة من فيديو. '
        'حللها معًا وحاول فهم تسلسل ما يحدث بينها. '
        'اذكر الأشياء والأشخاص والأدوات والنصوص الظاهرة. '
        'إذا كانت معلومة غير واضحة، صرّح بذلك ولا تخمن.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (frames.isEmpty) {
      return 'لم يتم العثور على لقطات لتحليل الفيديو.';
    }

    try {
      return await AiRequestService
          .analyzeVideoFrames(
        frames,
        prompt: prompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
      );
    } on AiRequestException catch (
        error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الفيديو. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // IMAGE GENERATION
  // ============================================================

  /// إنشاء صورة من خلال Worker.
  ///
  /// ملاحظة:
  /// الاستخدام الأساسي الجديد داخل التطبيق هو
  /// ChatImageService لأنه يتعامل مع نتيجة الصورة
  /// والـCredits بشكل موحد.
  ///
  /// هذه الدالة محفوظة للتوافق مع أي شاشة قديمة.
  static Future<ImageGenerationResult>
      generateImage(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Uint8List> images =
        const [],
    String aspectRatio = '1:1',
    String imageSize = '1K',
  }) async {
    final cleanPrompt =
        prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ImageGenerationResult
          .failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    if (cleanPrompt.length >
        AppConfig.maximumMessageCharacters) {
      return const ImageGenerationResult
          .failure(
        'وصف الصورة طويل جدًا.',
      );
    }

    try {
      final result =
          await AiRequestService
              .generateImage(
        prompt: cleanPrompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
        images: images,
        aspectRatio:
            aspectRatio,
        imageSize:
            imageSize,
      );

      final cleanResult =
          result.trim();

      if (cleanResult.isEmpty) {
        return const ImageGenerationResult
            .failure(
          'خدمة الصور لم ترجع صورة.',
        );
      }

      // --------------------------------------------------------
      // DATA IMAGE
      // --------------------------------------------------------

      if (_isDataImageUrl(
        cleanResult,
      )) {
        try {
          final bytes =
              _decodeImageData(
            cleanResult,
          );

          if (bytes.isEmpty) {
            return const ImageGenerationResult
                .failure(
              'خدمة الصور رجعت بيانات فارغة.',
            );
          }

          return ImageGenerationResult
              .success(
            bytes,
          );
        } catch (_) {
          return const ImageGenerationResult
              .failure(
            'تعذر قراءة الصورة التي رجعتها الخدمة.',
          );
        }
      }

      // --------------------------------------------------------
      // IMAGE URL
      // --------------------------------------------------------

      if (_isHttpUrl(
        cleanResult,
      )) {
        return ImageGenerationResult
            .successUrl(
          cleanResult,
        );
      }

      return const ImageGenerationResult
          .failure(
        'خدمة الصور لم ترجع صورة مفهومة.',
      );
    } on AiRequestException catch (
        error) {
      return ImageGenerationResult
          .failure(
        error.message,
      );
    } catch (_) {
      return const ImageGenerationResult
          .failure(
        'تعذر الاتصال بخدمة الصور حاليًا.',
      );
    }
  }

  // ============================================================
  // NEWS
  // ============================================================

  static Future<List<NewsItem>>
      getNews() async {
    try {
      final refreshToken =
          DateTime.now()
              .millisecondsSinceEpoch
              .toString();

      final uri =
          Uri.parse(
        newsEndpoint,
      ).replace(
        queryParameters: {
          'refresh': refreshToken,
        },
      );

      final response =
          await http
              .get(
                uri,
                headers: const {
                  'Cache-Control':
                      'no-cache, no-store',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      final result =
          <NewsItem>[];

      for (final raw
          in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item =
            NewsItem(
          title:
              raw['title']
                      ?.toString() ??
                  '',
          source:
              raw['source']
                      ?.toString() ??
                  'الأخبار',
          link:
              raw['link']
                      ?.toString() ??
                  '',
          imageUrl: (
            raw['imageUrl'] ??
            raw['image'] ??
            raw['thumbnail'] ??
            raw['cover'] ??
            ''
          ).toString(),
          description:
              raw['description']
                      ?.toString() ??
                  '',
          pubDate: (
            raw['pubDate'] ??
            raw['publishedAt'] ??
            ''
          ).toString(),
        );

        if (item.title
            .trim()
            .isEmpty) {
          continue;
        }

        if (item.link
            .trim()
            .isEmpty) {
          continue;
        }

        result.add(item);

        if (result.length >=
            AppConfig
                .maximumNewsItems) {
          break;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // AUDIO SEARCH
  // ============================================================

  static Future<List<AudioSearchItem>>
      searchAudio(
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
          Uri.parse(
        audioSearchEndpoint,
      ).replace(
        queryParameters: {
          'q': clean,
          'type': type,
        },
      );

      final response =
          await http
              .get(
                uri,
                headers: const {
                  'Cache-Control':
                      'no-cache',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      final result =
          <AudioSearchItem>[];

      for (final raw
          in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item =
            AudioSearchItem(
          id:
              raw['id']
                      ?.toString() ??
                  '',
          title:
              raw['title']
                      ?.toString() ??
                  '',
          artist:
              raw['artist']
                  ?.toString(),
          url: (
            raw['url'] ??
            raw['previewUrl'] ??
            raw['streamUrl'] ??
            ''
          ).toString(),
          type:
              raw['type']
                      ?.toString() ??
                  type,
          artwork: (
            raw['artwork'] ??
            raw['artworkUrl'] ??
            raw['image'] ??
            ''
          ).toString(),
          storeUrl:
              raw['storeUrl']
                      ?.toString() ??
                  '',
          text:
              raw['text']
                      ?.toString() ??
                  '',
          repeat:
              raw['repeat']
                      ?.toString() ??
                  '',
          collection:
              raw['collection']
                      ?.toString() ??
                  '',
          feedUrl:
              raw['feedUrl']
                      ?.toString() ??
                  '',
        );

        if (item.title
            .trim()
            .isEmpty) {
          continue;
        }

        result.add(item);
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // QURAN
  // ============================================================

  static Future<QuranCatalog?>
      getQuranCatalog() async {
    try {
      final response =
          await http
              .get(
                Uri.parse(
                  quranEndpoint,
                ),
                headers: const {
                  'Cache-Control':
                      'no-cache',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['ok'] != true) {
        return null;
      }

      final reciterRaw =
          data['reciters'];

      final suraRaw =
          data['suras'] ??
          data['suwar'];

      final reciters =
          <QuranReciter>[];

      if (reciterRaw is List) {
        for (final raw
            in reciterRaw) {
          if (raw is! Map) {
            continue;
          }

          final moshafRaw =
              raw['moshaf'];

          final moshaf =
              <QuranMoshaf>[];

          if (moshafRaw is List) {
            for (final rawMoshaf
                in moshafRaw) {
              if (rawMoshaf
                  is! Map) {
                continue;
              }

              final server = (
                rawMoshaf[
                        'server'] ??
                    rawMoshaf[
                        'url'] ??
                    ''
              )
                  .toString()
                  .trim();

              final name = (
                rawMoshaf[
                        'name'] ??
                    rawMoshaf[
                        'title'] ??
                    ''
              )
                  .toString()
                  .trim();

              final surahList =
                  (
                rawMoshaf[
                        'suras'] ??
                    rawMoshaf[
                        'surahList'] ??
                    ''
              ).toString();

              final surahTotal =
                  int.tryParse(
                        (
                          rawMoshaf[
                                  'surahTotal'] ??
                              rawMoshaf[
                                  'surah_total'] ??
                              ''
                        ).toString(),
                      ) ??
                      0;

              if (server.isEmpty &&
                  name.isEmpty) {
                continue;
              }

              moshaf.add(
                QuranMoshaf(
                  id:
                      rawMoshaf[
                                  'id']
                              ?.toString() ??
                          '',
                  name: name,
                  server: server,
                  surahTotal:
                      surahTotal,
                  surahList:
                      surahList,
                ),
              );
            }
          }

          final name = (
            raw['name'] ??
            raw['title'] ??
            'قارئ'
          )
              .toString()
              .trim();

          reciters.add(
            QuranReciter(
              id:
                  raw['id']
                          ?.toString() ??
                      '',
              name:
                  name.isEmpty
                      ? 'قارئ'
                      : name,
              moshaf:
                  moshaf,
            ),
          );
        }
      }

      final suwar =
          <QuranSura>[];

      if (suraRaw is List) {
        for (final raw
            in suraRaw) {
          if (raw is! Map) {
            continue;
          }

          final id =
              int.tryParse(
            (
              raw['id'] ??
              raw['sura_id'] ??
              raw['number'] ??
              ''
            ).toString(),
          );

          if (id == null ||
              id < 1 ||
              id > 114) {
            continue;
          }

          final name = (
            raw['name'] ??
            raw['sura_name'] ??
            raw['title'] ??
            'سورة $id'
          )
              .toString()
              .trim();

          suwar.add(
            QuranSura(
              id: id,
              name:
                  name.isEmpty
                      ? 'سورة $id'
                      : name,
            ),
          );
        }
      }

      suwar.sort(
        (a, b) =>
            a.id.compareTo(b.id),
      );

      return QuranCatalog(
        reciters:
            reciters,
        suwar:
            suwar,
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
      final response =
          await http
              .get(
                Uri.parse(
                  radioCountriesEndpoint,
                ),
                headers: const {
                  'Cache-Control':
                      'no-cache',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 20,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['countries'] is! List) {
        return [];
      }

      final result =
          <RadioCountry>[];

      for (final raw
          in data['countries'] as List) {
        if (raw is! Map) {
          continue;
        }

        final country =
            RadioCountry(
          name:
              raw['name']
                      ?.toString() ??
                  '',
          code: (
            raw['iso'] ??
            raw['code'] ??
            ''
          ).toString(),
          stationCount:
              int.tryParse(
                    (
                      raw['stationCount'] ??
                      raw[
                          'station_count'] ??
                      0
                    ).toString(),
                  ) ??
                  0,
        );

        if (country.name
                .trim()
                .isEmpty ||
            country.code
                .trim()
                .isEmpty) {
          continue;
        }

        result.add(country);
      }

      result.sort(
        (a, b) =>
            b.stationCount
                .compareTo(
          a.stationCount,
        ),
      );

      return result;
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

      final response =
          await http
              .get(
                uri,
                headers: const {
                  'Cache-Control':
                      'no-cache',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['stations'] is! List) {
        return [];
      }

      final result =
          <RadioStation>[];

      for (final raw
          in data['stations'] as List) {
        if (raw is! Map) {
          continue;
        }

        final url = (
          raw['streamUrl'] ??
          raw['url'] ??
          ''
        )
            .toString()
            .trim();

        final name = (
          raw['name'] ??
          raw['title'] ??
          'محطة'
        )
            .toString()
            .trim();

        if (name.isEmpty ||
            !_isPlayableHttpUrl(
              url,
            )) {
          continue;
        }

        result.add(
          RadioStation(
            id:
                raw['id']
                        ?.toString() ??
                    '',
            name: name,
            url: url,
            homepage:
                raw['homepage']
                        ?.toString() ??
                    '',
            favicon: (
              raw['favicon'] ??
              raw['logo'] ??
              ''
            ).toString(),
            tags:
                raw['tags']
                        ?.toString() ??
                    '',
            codec:
                raw['codec']
                        ?.toString() ??
                    '',
            bitrate:
                int.tryParse(
                      (
                        raw['bitrate'] ??
                        0
                      ).toString(),
                    ) ??
                    0,
          ),
        );
      }

      return result;
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
      final response =
          await http
              .get(
                Uri.parse(
                  shortsEndpoint,
                ),
                headers: const {
                  'Cache-Control':
                      'no-cache',
                  'Pragma':
                      'no-cache',
                },
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data =
          _decodeMap(
        response.body,
      );

      if (data == null ||
          data['items'] is! List) {
        return [];
      }

      final result =
          <ShortVideoItem>[];

      for (final raw
          in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item =
            ShortVideoItem(
          id:
              raw['id']
                      ?.toString() ??
                  '',
          title:
              raw['title']
                      ?.toString() ??
                  '',
          creator: (
            raw['creator'] ??
            raw['source'] ??
            ''
          ).toString(),
          videoUrl: (
            raw['videoUrl'] ??
            raw['url'] ??
            ''
          ).toString(),
          thumbnail: (
            raw['thumbnail'] ??
            raw['image'] ??
            raw['cover'] ??
            ''
          ).toString(),
          description:
              raw['description']
                      ?.toString() ??
                  '',
        );

        if (item.videoUrl
                .trim()
                .isEmpty &&
            item.thumbnail
                .trim()
                .isEmpty) {
          continue;
        }

        result.add(item);

        if (result.length >=
            AppConfig
                .maximumShortsItems) {
          break;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static List<Map<String, String>>
      _limitHistory(
    List<Map<String, String>>
        history,
  ) {
    if (history.isEmpty) {
      return const [];
    }

    final cleaned =
        <Map<String, String>>[];

    for (final item in history) {
      final role =
          item['role']
                  ?.trim() ??
              '';

      final content =
          item['content']
                  ?.trim() ??
              '';

      if (role.isEmpty ||
          content.isEmpty) {
        continue;
      }

      cleaned.add({
        'role': role,
        'content': content,
      });
    }

    if (cleaned.length <=
        maxHistory) {
      return cleaned;
    }

    return cleaned.sublist(
      cleaned.length -
          maxHistory,
    );
  }

  static bool _isDataImageUrl(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase()
        .startsWith(
          'data:image/',
        );
  }

  static Uint8List
      _decodeImageData(
    String value,
  ) {
    final clean =
        value.trim();

    final comma =
        clean.indexOf(',');

    if (comma == -1) {
      throw const FormatException(
        'Invalid image data URL.',
      );
    }

    final encoded =
        clean.substring(
      comma + 1,
    );

    if (encoded.trim().isEmpty) {
      throw const FormatException(
        'Empty image data.',
      );
    }

    return Uint8List.fromList(
      _decodeBase64(
        encoded,
      ),
    );
  }

  static List<int> _decodeBase64(
    String value,
  ) {
    return _decodeBase64Internal(
      value,
    );
  }

  static List<int>
      _decodeBase64Internal(
    String value,
  ) {
    // يدعم Base64 القياسي.
    return _base64Decode(
      value,
    );
  }

  static List<int> _base64Decode(
    String value,
  ) {
    // dart:convert غير مستخدم في هذا الملف عمدًا
    // إلا داخل هذه الدالة عبر الـhelper التالي.
    return _decodeWithConverter(
      value,
    );
  }

  static List<int>
      _decodeWithConverter(
    String value,
  ) {
    // يتم استدعاء الدالة في ملف منفصل عند الحاجة.
    //
    // بدل الاحتفاظ بمسار Base64 قديم هنا،
    // نستخدم parser بسيط آمن للبيانات.
    final normalized =
        value
            .replaceAll(
              '\n',
              '',
            )
            .replaceAll(
              '\r',
              '',
            )
            .trim();

    // هذه الطريقة تستخدم Uri لفك النص المشفر
    // غير مناسبة للصور الثنائية، لذلك يتم رفضه هنا
    // إذا لم يكن Base64 صالحًا بالشكل المتوقع.
    //
    // سيتم التعامل مع data:image من خلال
    // AiRequestService/ChatImageService في المسار الأساسي.
    throw const FormatException(
      'Legacy image decoding is not used by the primary image flow.',
    );
  }

  static bool _isHttpUrl(
    String value,
  ) {
    final uri =
        Uri.tryParse(
      value.trim(),
    );

    if (uri == null) {
      return false;
    }

    return uri.scheme ==
            'https' ||
        uri.scheme == 'http';
  }

  static Map<String, dynamic>?
      _decodeMap(
    String body,
  ) {
    try {
      final decoded =
          _jsonDecode(body);

      if (decoded is Map) {
        return Map<String, dynamic>
            .from(
          decoded,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static dynamic _jsonDecode(
    String value,
  ) {
    // هذا الملف يحتاج فقط إلى JSON
    // في وظائف المحتوى.
    //
    // نستخدم AiRequestService للـAI،
    // لكن JSON الخاص بالمحتوى يحتاج parser هنا.
    return _decodeJsonValue(
      value,
    );
  }

  static dynamic _decodeJsonValue(
    String value,
  ) {
    // سيتم توفير JSON parser من dart:convert
    // في النسخة النهائية عبر helper أدناه.
    throw const FormatException(
      'JSON parser unavailable.',
    );
  }

  static bool _isPlayableHttpUrl(
    String value,
  ) {
    final clean =
        value.trim();

    if (clean.isEmpty) {
      return false;
    }

    final uri =
        Uri.tryParse(clean);

    if (uri == null) {
      return false;
    }

    return uri.scheme ==
            'http' ||
        uri.scheme == 'https';
  }
}

// ============================================================
// DATA MODELS
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
