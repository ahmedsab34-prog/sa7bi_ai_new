import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config/app_config.dart';
import 'services/ai_request_service.dart';

/// الواجهة الموحدة لخدمات صاحبي AI.
///
/// كل خدمات الذكاء الاصطناعي تمر من خلال Cloudflare Worker.
/// لا توجد أي API Keys داخل التطبيق.
class AiService {
  AiService._();

  static const String base = AppConfig.backendBaseUrl;

  static const String chatEndpoint = AppConfig.aiChatEndpoint;
  static const String imageEndpoint =
      AppConfig.imageGenerationEndpoint;
  static const String newsEndpoint = AppConfig.newsEndpoint;
  static const String audioSearchEndpoint =
      AppConfig.audioSearchEndpoint;
  static const String quranEndpoint = AppConfig.quranEndpoint;
  static const String radioCountriesEndpoint =
      AppConfig.radioCountriesEndpoint;
  static const String radioStationsEndpoint =
      AppConfig.radioStationsEndpoint;
  static const String shortsEndpoint = AppConfig.shortsEndpoint;

  static const String hadithEndpoint =
      '$base/v1/hadith';

  static const String hadithBooksEndpoint =
      '$base/v1/hadith/books';

  static const String tafsirEndpoint =
      '$base/v1/tafsir';

  static const String tafsirBooksEndpoint =
      '$base/v1/tafsir/books';

  static const String tafsirAudioEndpoint =
      '$base/v1/tafsir/audio';

  static const String religiousEndpoint =
      '$base/v1/religious';

  static const String podcastsSearchEndpoint =
      '$base/v1/podcasts/search';

  static const String podcastsLookupEndpoint =
      '$base/v1/podcasts/lookup';

  static const String podcastsEpisodesEndpoint =
      '$base/v1/podcasts/episodes';

  static const int maxHistory =
      AppConfig.maximumContextMessages;

  // ============================================================
  // CONNECTION
  // ============================================================

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              AppConfig.backendHealthEndpoint,
            ),
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

      return data != null &&
          data['ok'] == true &&
          (
            data['status'] == 'healthy' ||
            data['status'] == 'online'
          );
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // TEXT AI
  // ============================================================

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history = const [],
  }) async {
    final cleanPrompt = prompt.trim();

    if (cleanPrompt.isEmpty) {
      return 'اكتب رسالتك الأول.';
    }

    try {
      return await AiRequestService.getResponse(
        prompt: cleanPrompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
        history: _limitHistory(history),
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
        'حلل الصورة المرسلة بدقة وباختصار، '
        'واذكر الأشياء المهمة الظاهرة فيها.',
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
  // VIDEO
  // ============================================================

  static Future<String> analyzeVideoFrames(
    List<Uint8List> frames, {
    String prompt =
        'هذه لقطات مستخرجة من فيديو. '
        'حللها معًا وحاول فهم تسلسل ما يحدث بينها. '
        'اذكر الأشياء والأشخاص والأدوات والنصوص الظاهرة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (frames.isEmpty) {
      return 'لم يتم العثور على لقطات لتحليل الفيديو.';
    }

    try {
      return await AiRequestService.analyzeVideoFrames(
        frames,
        prompt: prompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
      );
    } on AiRequestException catch (error) {
      return error.message;
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الفيديو. جرّب مرة تانية.';
    }
  }

  // ============================================================
  // IMAGE GENERATION / EDITING
  // ============================================================

  static Future<ImageGenerationResult> generateImage(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Uint8List> images = const [],
    String aspectRatio = '1:1',
    String imageSize = '1K',
  }) async {
    final cleanPrompt = prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ImageGenerationResult.failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    if (cleanPrompt.length >
        AppConfig.maximumMessageCharacters) {
      return const ImageGenerationResult.failure(
        'وصف الصورة طويل جدًا.',
      );
    }

    try {
      final result = await AiRequestService.generateImage(
        prompt: cleanPrompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
        images: images,
        aspectRatio: aspectRatio,
        imageSize: imageSize,
      );

      final cleanResult = result.trim();

      if (cleanResult.isEmpty) {
        return const ImageGenerationResult.failure(
          'خدمة الصور لم ترجع صورة.',
        );
      }

      if (_isDataImageUrl(cleanResult)) {
        try {
          final bytes = _decodeImageData(cleanResult);

          if (bytes.isEmpty) {
            return const ImageGenerationResult.failure(
              'خدمة الصور رجعت بيانات فارغة.',
            );
          }

          return ImageGenerationResult.success(bytes);
        } catch (_) {
          return const ImageGenerationResult.failure(
            'تعذر قراءة الصورة التي رجعتها الخدمة.',
          );
        }
      }

      if (_isHttpUrl(cleanResult)) {
        return ImageGenerationResult.successUrl(
          cleanResult,
        );
      }

      return const ImageGenerationResult.failure(
        'خدمة الصور لم ترجع صورة مفهومة.',
      );
    } on AiRequestException catch (error) {
      return ImageGenerationResult.failure(
        error.message,
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
      final uri = Uri.parse(newsEndpoint).replace(
        queryParameters: {
          'refresh':
              DateTime.now()
                  .millisecondsSinceEpoch
                  .toString(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache, no-store',
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

      final data = _decodeMap(response.body);

      if (data == null || data['items'] is! List) {
        return [];
      }

      final result = <NewsItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item = NewsItem(
          title: raw['title']?.toString() ?? '',
          source: raw['source']?.toString() ?? 'الأخبار',
          link: raw['link']?.toString() ?? '',
          imageUrl: (
            raw['imageUrl'] ??
            raw['image'] ??
            raw['thumbnail'] ??
            ''
          ).toString(),
          description:
              raw['description']?.toString() ?? '',
          pubDate: (
            raw['pubDate'] ??
            raw['publishedAt'] ??
            ''
          ).toString(),
        );

        if (item.title.trim().isEmpty ||
            item.link.trim().isEmpty) {
          continue;
        }

        result.add(item);

        if (result.length >=
            AppConfig.maximumNewsItems) {
          break;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // GENERAL AUDIO
  // ============================================================

  static Future<List<AudioSearchItem>> searchAudio(
    String query, {
    String type = 'quran',
  }) async {
    final clean = query.trim();

    if (clean.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse(audioSearchEndpoint).replace(
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

      final data = _decodeMap(response.body);

      if (data == null || data['items'] is! List) {
        return [];
      }

      final result = <AudioSearchItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item = AudioSearchItem(
          id: raw['id']?.toString() ?? '',
          title: raw['title']?.toString() ?? '',
          artist: raw['artist']?.toString(),
          url: (
            raw['url'] ??
            raw['previewUrl'] ??
            raw['streamUrl'] ??
            ''
          ).toString(),
          type: raw['type']?.toString() ?? type,
          artwork: (
            raw['artwork'] ??
            raw['artworkUrl'] ??
            raw['image'] ??
            ''
          ).toString(),
          storeUrl:
              raw['storeUrl']?.toString() ?? '',
          text: raw['text']?.toString() ?? '',
          repeat: raw['repeat']?.toString() ?? '',
          collection:
              raw['collection']?.toString() ?? '',
          feedUrl:
              raw['feedUrl']?.toString() ?? '',
        );

        if (item.title.trim().isEmpty) {
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
  // HADITH
  // ============================================================

  static Future<List<HadithBook>> getHadithBooks() async {
    final data = await _getMap(
      hadithBooksEndpoint,
    );

    if (data == null ||
        data['items'] is! List) {
      return [];
    }

    final result = <HadithBook>[];

    for (final raw in data['items'] as List) {
      if (raw is! Map) {
        continue;
      }

      final id =
          raw['id']?.toString().trim() ?? '';

      final name =
          raw['name']?.toString().trim() ?? '';

      if (id.isEmpty || name.isEmpty) {
        continue;
      }

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
    try {
      final parameters = <String, String>{
        'limit': limit.clamp(1, 50).toString(),
      };

      if (query.trim().isNotEmpty) {
        parameters['q'] = query.trim();
      }

      if (book != null &&
          book.trim().isNotEmpty) {
        parameters['book'] = book.trim();
      }

      final uri = Uri.parse(
        hadithEndpoint,
      ).replace(
        queryParameters: parameters,
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data =
          _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <HadithItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final text =
            raw['text']?.toString().trim() ?? '';

        if (text.isEmpty) {
          continue;
        }

        result.add(
          HadithItem(
            id: raw['id']?.toString() ?? '',
            number: raw['number']?.toString() ?? '',
            book: raw['book']?.toString() ?? '',
            bookName:
                raw['bookName']?.toString() ?? '',
            text: text,
            source:
                raw['source']?.toString() ??
                    'Hadith API',
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // TAFSIR
  // ============================================================

  static Future<List<TafsirBook>>
      getTafsirBooks() async {
    final data = await _getMap(
      tafsirBooksEndpoint,
    );

    if (data == null ||
        data['items'] is! List) {
      return [];
    }

    final result = <TafsirBook>[];

    for (final raw in data['items'] as List) {
      if (raw is! Map) {
        continue;
      }

      final id = int.tryParse(
            raw['id']?.toString() ?? '',
          ) ??
          0;

      final name =
          raw['name']?.toString().trim() ?? '';

      if (id <= 0 || name.isEmpty) {
        continue;
      }

      result.add(
        TafsirBook(
          id: id,
          name: name,
        ),
      );
    }

    return result;
  }

  static Future<List<TafsirItem>>
      searchTafsir({
    required int tafsirId,
    String? query,
    int? sura,
  }) async {
    if (tafsirId <= 0) {
      return [];
    }

    try {
      final parameters = <String, String>{
        'tafsir': tafsirId.toString(),
      };

      if (query != null &&
          query.trim().isNotEmpty) {
        parameters['q'] = query.trim();
      }

      if (sura != null &&
          sura >= 1 &&
          sura <= 114) {
        parameters['sura'] = sura.toString();
      }

      final uri = Uri.parse(
        tafsirEndpoint,
      ).replace(
        queryParameters: parameters,
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data =
          _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <TafsirItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final suraNumber =
            int.tryParse(
                  raw['sura']?.toString() ?? '',
                ) ??
                0;

        if (suraNumber < 1 ||
            suraNumber > 114) {
          continue;
        }

        result.add(
          TafsirItem(
            id:
                raw['id']?.toString() ?? '',
            tafsirId:
                int.tryParse(
                      raw['tafsirId']?.toString() ??
                          '',
                    ) ??
                    tafsirId,
            tafsirName:
                raw['tafsirName']?.toString() ??
                    '',
            sura: suraNumber,
            suraName:
                raw['suraName']?.toString() ??
                    'سورة $suraNumber',
            audioUrl:
                raw['audioUrl']?.toString() ??
                    '',
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<TafsirAudioResult?>
      getTafsirAudio({
    required int tafsirId,
    required int sura,
  }) async {
    if (tafsirId <= 0 ||
        sura < 1 ||
        sura > 114) {
      return null;
    }

    try {
      final uri = Uri.parse(
        tafsirAudioEndpoint,
      ).replace(
        queryParameters: {
          'tafsir': tafsirId.toString(),
          'sura': sura.toString(),
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 25),
          );

      final data =
          _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return null;
      }

      return TafsirAudioResult(
        available:
            data['available'] == true,
        audioUrl:
            data['audioUrl']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // UNIFIED RELIGIOUS SEARCH
  // ============================================================

  static Future<List<dynamic>>
      searchReligiousContent({
    required String type,
    String query = '',
  }) async {
    final cleanType = type.trim();

    if (cleanType.isEmpty) {
      return [];
    }

    try {
      final parameters = <String, String>{
        'type': cleanType,
      };

      if (query.trim().isNotEmpty) {
        parameters['q'] = query.trim();
      }

      final uri = Uri.parse(
        religiousEndpoint,
      ).replace(
        queryParameters: parameters,
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data =
          _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      return List<dynamic>.from(
        data['items'] as List,
      );
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // PODCASTS
  // ============================================================

  static Future<List<PodcastItem>> searchPodcasts({
    String query = '',
    int limit = 20,
  }) async {
    final clean = query.trim();

    try {
      final uri = Uri.parse(
        podcastsSearchEndpoint,
      ).replace(
        queryParameters: {
          'q': clean.isEmpty
              ? 'Arabic podcast'
              : clean,
          'limit': limit.clamp(1, 50).toString(),
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <PodcastItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final id = (
          raw['id'] ??
          raw['collectionId'] ??
          ''
        ).toString().trim();

        final title = (
          raw['title'] ??
          raw['collectionName'] ??
          raw['name'] ??
          ''
        ).toString().trim();

        if (title.isEmpty) {
          continue;
        }

        result.add(
          PodcastItem(
            id: id,
            title: title,
            artist: (
              raw['artist'] ??
              raw['artistName'] ??
              raw['author'] ??
              ''
            ).toString(),
            author: (
              raw['author'] ??
              raw['artist'] ??
              raw['artistName'] ??
              ''
            ).toString(),
            artwork: (
              raw['artwork'] ??
              raw['artworkUrl'] ??
              raw['artworkUrl600'] ??
              raw['image'] ??
              ''
            ).toString(),
            feedUrl: (
              raw['feedUrl'] ??
              raw['feed_url'] ??
              ''
            ).toString(),
            storeUrl: (
              raw['storeUrl'] ??
              raw['collectionViewUrl'] ??
              raw['trackViewUrl'] ??
              ''
            ).toString(),
            genre:
                raw['genre']?.toString() ?? '',
            country:
                raw['country']?.toString() ?? '',
            releaseDate:
                raw['releaseDate']?.toString() ?? '',
            episodeCount:
                int.tryParse(
                      (
                        raw['episodeCount'] ??
                        raw['trackCount'] ??
                        raw['collectionCount'] ??
                        0
                      ).toString(),
                    ) ??
                    0,
            description:
                raw['description']?.toString() ?? '',
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<PodcastItem?> getPodcast(
    String id,
  ) async {
    final clean = id.trim();

    if (clean.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        podcastsLookupEndpoint,
      ).replace(
        queryParameters: {
          'id': clean,
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return null;
      }

      final raw =
          data['podcast'] ??
          data['item'];

      if (raw is! Map) {
        return null;
      }

      final title = (
        raw['title'] ??
        raw['collectionName'] ??
        raw['name'] ??
        ''
      ).toString().trim();

      if (title.isEmpty) {
        return null;
      }

      return PodcastItem(
        id: (
          raw['id'] ??
          raw['collectionId'] ??
          clean
        ).toString(),
        title: title,
        artist: (
          raw['artist'] ??
          raw['artistName'] ??
          raw['author'] ??
          ''
        ).toString(),
        author: (
          raw['author'] ??
          raw['artist'] ??
          raw['artistName'] ??
          ''
        ).toString(),
        artwork: (
          raw['artwork'] ??
          raw['artworkUrl'] ??
          raw['artworkUrl600'] ??
          raw['image'] ??
          ''
        ).toString(),
        feedUrl: (
          raw['feedUrl'] ??
          raw['feed_url'] ??
          ''
        ).toString(),
        storeUrl: (
          raw['storeUrl'] ??
          raw['collectionViewUrl'] ??
          raw['trackViewUrl'] ??
          ''
        ).toString(),
        genre:
            raw['genre']?.toString() ?? '',
        country:
            raw['country']?.toString() ?? '',
        releaseDate:
            raw['releaseDate']?.toString() ?? '',
        episodeCount:
            int.tryParse(
                  (
                    raw['episodeCount'] ??
                    raw['trackCount'] ??
                    raw['collectionCount'] ??
                    0
                  ).toString(),
                ) ??
                0,
        description:
            raw['description']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<PodcastEpisode>>
      getPodcastEpisodes({
    required String feedUrl,
    int limit = 100,
  }) async {
    final clean = feedUrl.trim();

    if (clean.isEmpty ||
        !_isHttpUrl(clean)) {
      return [];
    }

    try {
      final uri = Uri.parse(
        podcastsEpisodesEndpoint,
      ).replace(
        queryParameters: {
          'feedUrl': clean,
          'limit': limit.clamp(1, 100).toString(),
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <PodcastEpisode>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final title = (
          raw['title'] ??
          raw['name'] ??
          ''
        ).toString().trim();

        final audioUrl = (
          raw['audioUrl'] ??
          raw['audio_url'] ??
          raw['url'] ??
          ''
        ).toString().trim();

        if (title.isEmpty ||
            audioUrl.isEmpty ||
            !_isHttpUrl(audioUrl)) {
          continue;
        }

        result.add(
          PodcastEpisode(
            id: (
              raw['id'] ??
              raw['guid'] ??
              ''
            ).toString(),
            title: title,
            description:
                raw['description']?.toString() ?? '',
            audioUrl: audioUrl,
            image: (
              raw['image'] ??
              raw['artwork'] ??
              raw['artworkUrl'] ??
              ''
            ).toString(),
            publishedAt: (
              raw['publishedAt'] ??
              raw['pubDate'] ??
              ''
            ).toString(),
            duration:
                raw['duration']?.toString() ?? '',
            episode:
                int.tryParse(
                      raw['episode']?.toString() ?? '',
                    ) ??
                    0,
            season:
                int.tryParse(
                      raw['season']?.toString() ?? '',
                    ) ??
                    0,
            explicit:
                raw['explicit'] == true,
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // QURAN
  // ============================================================

  static Future<QuranCatalog?> getQuranCatalog() async {
    try {
      final response = await http
          .get(Uri.parse(quranEndpoint))
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final data = _decodeMap(response.body);

      if (data == null ||
          data['ok'] != true) {
        return null;
      }

      final reciters =
          <QuranReciter>[];

      final rawReciters =
          data['reciters'];

      if (rawReciters is List) {
        for (final raw in rawReciters) {
          if (raw is! Map) {
            continue;
          }

          final moshaf =
              <QuranMoshaf>[];

          final rawMoshaf =
              raw['moshaf'];

          if (rawMoshaf is List) {
            for (final value
                in rawMoshaf) {
              if (value is! Map) {
                continue;
              }

              final server =
                  (
                    value['server'] ??
                    value['url'] ??
                    ''
                  ).toString().trim();

              final name =
                  (
                    value['name'] ??
                    value['title'] ??
                    ''
                  ).toString().trim();

              if (server.isEmpty &&
                  name.isEmpty) {
                continue;
              }

              moshaf.add(
                QuranMoshaf(
                  id:
                      value['id']?.toString() ??
                          '',
                  name: name,
                  server: server,
                  surahTotal:
                      int.tryParse(
                            (
                              value['surahTotal'] ??
                              value['surah_total'] ??
                              0
                            ).toString(),
                          ) ??
                          0,
                  surahList:
                      (
                        value['suras'] ??
                        value['surahList'] ??
                        ''
                      ).toString(),
                ),
              );
            }
          }

          final name =
              (
                raw['name'] ??
                raw['title'] ??
                'قارئ'
              ).toString().trim();

          reciters.add(
            QuranReciter(
              id:
                  raw['id']?.toString() ??
                      '',
              name:
                  name.isEmpty
                      ? 'قارئ'
                      : name,
              moshaf: moshaf,
            ),
          );
        }
      }

      final suwar =
          <QuranSura>[];

      final rawSuras =
          data['suras'] ??
          data['suwar'];

      if (rawSuras is List) {
        for (final raw in rawSuras) {
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

          final name =
              (
                raw['name'] ??
                raw['sura_name'] ??
                raw['title'] ??
                'سورة $id'
              ).toString().trim();

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
        (a, b) => a.id.compareTo(b.id),
      );

      return QuranCatalog(
        reciters: reciters,
        suwar: suwar,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // RADIO
  // ============================================================

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

      final result =
          <RadioCountry>[];

      for (final raw
          in data['countries']
              as List) {
        if (raw is! Map) {
          continue;
        }

        final country =
            RadioCountry(
          name:
              raw['name']?.toString() ??
                  '',
          code:
              (
                raw['iso'] ??
                raw['code'] ??
                ''
              ).toString(),
          stationCount:
              int.tryParse(
                    (
                      raw['stationCount'] ??
                      raw['station_count'] ??
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
            b.stationCount.compareTo(
          a.stationCount,
        ),
      );

      return result;
    } catch (_) {
      return [];
    }
  }

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
          .get(uri)
          .timeout(
            const Duration(seconds: 25),
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
          in data['stations']
              as List) {
        if (raw is! Map) {
          continue;
        }

        final url =
            (
              raw['streamUrl'] ??
              raw['url'] ??
              ''
            ).toString().trim();

        final name =
            (
              raw['name'] ??
              raw['title'] ??
              'محطة'
            ).toString().trim();

        if (name.isEmpty ||
            !_isPlayableHttpUrl(
              url,
            )) {
          continue;
        }

        result.add(
          RadioStation(
            id:
                raw['id']?.toString() ??
                    '',
            name: name,
            url: url,
            homepage:
                raw['homepage']?.toString() ??
                    '',
            favicon:
                (
                  raw['favicon'] ??
                  raw['logo'] ??
                  ''
                ).toString(),
            tags:
                raw['tags']?.toString() ??
                    '',
            codec:
                raw['codec']?.toString() ??
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
      final response = await http
          .get(Uri.parse(shortsEndpoint))
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

      final result =
          <ShortVideoItem>[];

      for (final raw
          in data['items']
              as List) {
        if (raw is! Map) {
          continue;
        }

        final item =
            ShortVideoItem(
          id:
              raw['id']?.toString() ??
                  '',
          title:
              raw['title']?.toString() ??
                  '',
          creator:
              (
                raw['creator'] ??
                raw['source'] ??
                ''
              ).toString(),
          videoUrl:
              (
                raw['videoUrl'] ??
                raw['url'] ??
                ''
              ).toString(),
          thumbnail:
              (
                raw['thumbnail'] ??
                raw['image'] ??
                raw['cover'] ??
                ''
              ).toString(),
          description:
              raw['description']?.toString() ??
                  '',
        );

        if (item.videoUrl.trim().isEmpty &&
            item.thumbnail.trim().isEmpty) {
          continue;
        }

        result.add(item);

        if (result.length >=
            AppConfig.maximumShortsItems) {
          break;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // HTTP HELPERS
  // ============================================================

  static Future<Map<String, dynamic>?>
      _getMap(
    String endpoint,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      return _decodeMap(response.body);
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, String>>
      _limitHistory(
    List<Map<String, String>>
        history,
  ) {
    final cleaned =
        history
            .where(
              (item) {
                final role =
                    item['role']
                            ?.trim() ??
                        '';
                final content =
                    item['content']
                            ?.trim() ??
                        '';

                return (
                  role == 'user' ||
                  role == 'assistant'
                ) &&
                    content.isNotEmpty;
              },
            )
            .map(
              (item) =>
                  <String, String>{
                'role':
                    item['role']!.trim(),
                'content':
                    item['content']!.trim(),
              },
            )
            .toList();

    if (cleaned.length <= maxHistory) {
      return cleaned;
    }

    return cleaned.sublist(
      cleaned.length - maxHistory,
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

  static Uint8List _decodeImageData(
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

    final header =
        clean.substring(
      0,
      comma,
    );

    if (!header
        .toLowerCase()
        .contains(';base64')) {
      throw const FormatException(
        'Image data is not Base64.',
      );
    }

    final encoded =
        clean
            .substring(
              comma + 1,
            )
            .trim();

    if (encoded.isEmpty) {
      throw const FormatException(
        'Empty image data.',
      );
    }

    return Uint8List.fromList(
      base64Decode(
        base64.normalize(
          encoded,
        ),
      ),
    );
  }

  static bool _isHttpUrl(
    String value,
  ) {
    final uri =
        Uri.tryParse(
      value.trim(),
    );

    return uri != null &&
        (
          uri.scheme == 'http' ||
          uri.scheme == 'https'
        );
  }

  static bool _isPlayableHttpUrl(
    String value,
  ) {
    final uri =
        Uri.tryParse(
      value.trim(),
    );

    return uri != null &&
        (
          uri.scheme == 'http' ||
          uri.scheme == 'https'
        );
  }

  static Map<String, dynamic>?
      _decodeMap(
    String body,
  ) {
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
}

// ============================================================
// MODELS
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

class PodcastItem {
  final String id;
  final String title;
  final String artist;
  final String author;
  final String artwork;
  final String feedUrl;
  final String storeUrl;
  final String genre;
  final String country;
  final String releaseDate;
  final int episodeCount;
  final String description;

  const PodcastItem({
    this.id = '',
    required this.title,
    this.artist = '',
    this.author = '',
    this.artwork = '',
    this.feedUrl = '',
    this.storeUrl = '',
    this.genre = '',
    this.country = '',
    this.releaseDate = '',
    this.episodeCount = 0,
    this.description = '',
  });
}

class PodcastEpisode {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final String image;
  final String publishedAt;
  final String duration;
  final int episode;
  final int season;
  final bool explicit;

  const PodcastEpisode({
    this.id = '',
    required this.title,
    required this.audioUrl,
    this.description = '',
    this.image = '',
    this.publishedAt = '',
    this.duration = '',
    this.episode = 0,
    this.season = 0,
    this.explicit = false,
  });
}

class HadithBook {
  final String id;
  final String name;

  const HadithBook({
    required this.id,
    required this.name,
  });
}

class HadithItem {
  final String id;
  final String number;
  final String book;
  final String bookName;
  final String text;
  final String source;

  const HadithItem({
    this.id = '',
    this.number = '',
    this.book = '',
    this.bookName = '',
    required this.text,
    this.source = '',
  });
}

class TafsirBook {
  final int id;
  final String name;

  const TafsirBook({
    required this.id,
    required this.name,
  });
}

class TafsirItem {
  final String id;
  final int tafsirId;
  final String tafsirName;
  final int sura;
  final String suraName;
  final String audioUrl;

  const TafsirItem({
    this.id = '',
    required this.tafsirId,
    required this.tafsirName,
    required this.sura,
    required this.suraName,
    this.audioUrl = '',
  });
}

class TafsirAudioResult {
  final bool available;
  final String audioUrl;

  const TafsirAudioResult({
    required this.available,
    required this.audioUrl,
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
