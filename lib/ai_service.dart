import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'config/app_config.dart';
import 'ai/ai_service_core.dart';
import 'ai/ai_service_text_media.dart';
import 'ai/ai_service_news_audio.dart';
import 'ai/ai_service_religious.dart';
import 'ai/ai_service_podcast.dart';
import 'ai/ai_service_quran.dart';
import 'ai/ai_service_radio.dart';
import 'ai/ai_service_shorts.dart';

export 'ai/ai_service_models.dart';

/// الواجهة الموحدة لخدمات صاحبي AI.
///
/// هذا الملف هو الواجهة العامة للتطبيق.
/// الخدمات الفعلية مقسمة إلى Modules داخل lib/ai.
///
/// مهم:
/// - لا توجد API Keys هنا.
/// - ai_request_service.dart لا يتم تعديله من خلال هذا التقسيم.
/// - كل الـ APIs القديمة تظل متاحة من خلال AiService.
class AiService {
  AiService._();

  // ============================================================
  // BACKEND
  // ============================================================

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

  /// فحص اتصال التطبيق بالـ Worker.
  ///
  /// يتم الفحص من خلال:
  /// /health
  ///
  /// وليس من خلال root URL.
  static Future<bool> checkConnection() {
    return AiServiceCore.checkConnection();
  }

  // ============================================================
  // TEXT AI
  // ============================================================

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history = const [],
  }) {
    return AiServiceTextMedia.getResponse(
      prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
      history: history,
    );
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
  }) {
    return AiServiceTextMedia.analyzeImage(
      file,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
  }

  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا. '
        'اشرح ما يظهر فيها، واذكر النصوص والأشياء المهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) {
    return AiServiceTextMedia.analyzeImages(
      images,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
  }

  // ============================================================
  // VIDEO ANALYSIS
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
  }) {
    return AiServiceTextMedia.analyzeVideoFrames(
      frames,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
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
  }) {
    return AiServiceTextMedia.generateImage(
      prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
      images: images,
      aspectRatio: aspectRatio,
      imageSize: imageSize,
    );
  }

  // ============================================================
  // NEWS
  // ============================================================

  static Future<List<NewsItem>> getNews() {
    return AiServiceNewsAudio.getNews();
  }

  // ============================================================
  // GENERAL AUDIO
  // ============================================================

  static Future<List<AudioSearchItem>> searchAudio(
    String query, {
    String type = 'quran',
  }) {
    return AiServiceNewsAudio.searchAudio(
      query,
      type: type,
    );
  }

  // ============================================================
  // HADITH
  // ============================================================

  static Future<List<HadithBook>> getHadithBooks() {
    return AiServiceReligious.getHadithBooks();
  }

  static Future<List<HadithItem>> searchHadith({
    String query = '',
    String? book,
    int limit = 20,
  }) {
    return AiServiceReligious.searchHadith(
      query: query,
      book: book,
      limit: limit,
    );
  }

  // ============================================================
  // TAFSIR
  // ============================================================

  static Future<List<TafsirBook>> getTafsirBooks() {
    return AiServiceReligious.getTafsirBooks();
  }

  static Future<List<TafsirItem>> searchTafsir({
    required int tafsirId,
    String? query,
    int? sura,
  }) {
    return AiServiceReligious.searchTafsir(
      tafsirId: tafsirId,
      query: query,
      sura: sura,
    );
  }

  static Future<TafsirAudioResult?> getTafsirAudio({
    required int tafsirId,
    required int sura,
  }) {
    return AiServiceReligious.getTafsirAudio(
      tafsirId: tafsirId,
      sura: sura,
    );
  }

  // ============================================================
  // UNIFIED RELIGIOUS SEARCH
  // ============================================================

  static Future<List<dynamic>> searchReligiousContent({
    required String type,
    String query = '',
  }) {
    return AiServiceReligious.searchReligiousContent(
      type: type,
      query: query,
    );
  }

  // ============================================================
  // PODCASTS
  // ============================================================

  static Future<List<PodcastItem>> searchPodcasts({
    String query = '',
    int limit = 20,
  }) {
    return AiServicePodcast.searchPodcasts(
      query: query,
      limit: limit,
    );
  }

  static Future<PodcastItem?> getPodcast(
    String id,
  ) {
    return AiServicePodcast.getPodcast(id);
  }

  static Future<List<PodcastEpisode>> getPodcastEpisodes({
    required String feedUrl,
    int limit = 100,
  }) {
    return AiServicePodcast.getPodcastEpisodes(
      feedUrl: feedUrl,
      limit: limit,
    );
  }

  // ============================================================
  // QURAN
  // ============================================================

  static Future<QuranCatalog?> getQuranCatalog() {
    return AiServiceQuran.getQuranCatalog();
  }

  // ============================================================
  // RADIO
  // ============================================================

  static Future<List<RadioCountry>> getRadioCountries() {
    return AiServiceRadio.getRadioCountries();
  }

  static Future<List<RadioStation>> getRadioStations(
    String country,
  ) {
    return AiServiceRadio.getRadioStations(country);
  }

  // ============================================================
  // SHORTS
  // ============================================================

  static Future<List<ShortVideoItem>> getShorts() {
    return AiServiceShorts.getShorts();
  }
}
