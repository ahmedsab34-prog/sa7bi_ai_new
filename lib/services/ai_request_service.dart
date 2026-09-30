import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String backendBaseUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String backendHealthEndpoint =
      '$backendBaseUrl/health';

  static const String aiChatEndpoint =
      '$backendBaseUrl/v1/chat';

  static const String imageGenerationEndpoint =
      '$backendBaseUrl/v1/image';

  static const String newsEndpoint =
      '$backendBaseUrl/v1/news';

  static const String audioSearchEndpoint =
      '$backendBaseUrl/v1/audio/search-v4';

  static const String quranEndpoint =
      '$backendBaseUrl/v1/audio/quran';

  static const String radioCountriesEndpoint =
      '$backendBaseUrl/v1/radio/countries';

  static const String radioStationsEndpoint =
      '$backendBaseUrl/v1/radio/stations';

  static const String shortsEndpoint =
      '$backendBaseUrl/v1/shorts';

  // ============================================================
  // AI / REQUEST LIMITS
  // ============================================================

  static const int maximumContextMessages = 20;

  static const int maximumMessageCharacters = 12000;

  static const int maximumImageSizeMb = 5;

  static const int maximumVideoFrames = 8;

  // ============================================================
  // TIMEOUTS
  // ============================================================

  static const int networkTimeoutSeconds = 15;

  static const int chatTimeoutSeconds = 60;

  static const int imageTimeoutSeconds = 120;

  // ============================================================
  // CONTENT LIMITS
  // ============================================================

  static const int maximumNewsItems = 30;

  static const int maximumShortsItems = 20;

  // ============================================================
  // LEGACY / GENERAL REQUEST TIMEOUT
  // ============================================================

  static const Duration requestTimeout =
      Duration(seconds: 30);

  // ============================================================
  // DEBUG
  // ============================================================

  static bool get isDebug =>
      kDebugMode;
}
