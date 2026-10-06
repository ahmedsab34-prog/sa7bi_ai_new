import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// نتيجة فحص واحدة.
class DiagnosticCheck {
  final String name;
  final String target;
  final bool ok;
  final int? statusCode;
  final String detail;
  final Duration duration;

  const DiagnosticCheck({
    required this.name,
    required this.target,
    required this.ok,
    required this.statusCode,
    required this.detail,
    required this.duration,
  });
}

/// التقرير الكامل لفحص النسخة الحالية.
class AppDiagnosticsReport {
  final DateTime startedAt;
  final List<DiagnosticCheck> checks;

  const AppDiagnosticsReport({
    required this.startedAt,
    required this.checks,
  });

  int get passedCount =>
      checks.where((check) => check.ok).length;

  int get failedCount =>
      checks.where((check) => !check.ok).length;

  bool get allPassed =>
      checks.isNotEmpty &&
      checks.every(
        (check) => check.ok,
      );
}

/// طبقة التشخيص الموحدة.
///
/// الهدف منها:
/// APK
///   ↓
/// Flutter runtime
///   ↓
/// Internet / DNS / TLS
///   ↓
/// Cloudflare Worker
///   ↓
/// Service routes
///   ↓
/// Content / Media
///   ↓
/// AI route reachability
///
/// بدون تعديل الخدمات الأصلية أو استهلاك AI credits.
class AppDiagnosticsService {
  AppDiagnosticsService._();

  static const Duration defaultTimeout =
      Duration(seconds: 15);

  static const Duration mediaTimeout =
      Duration(seconds: 10);

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache, no-store',
    'Pragma': 'no-cache',
  };

  /// تشغيل التشخيص الكامل.
  static Future<AppDiagnosticsReport> run() async {
    final startedAt =
        DateTime.now();

    final checks =
        <DiagnosticCheck>[];

    // ==========================================================
    // 1. LOCAL APK / BUILD IDENTITY
    // ==========================================================

    checks.add(
      DiagnosticCheck(
        name: 'Build Identity',
        target: 'APK',
        ok:
            AppConfig.appVersion.isNotEmpty &&
            AppConfig.buildNumber.isNotEmpty &&
            AppConfig.commitSha.isNotEmpty,
        statusCode: null,
        detail:
            'Version=${AppConfig.appVersion} | '
            'Build=${AppConfig.buildNumber} | '
            'Commit=${AppConfig.commitSha}',
        duration:
            Duration.zero,
      ),
    );

    // ==========================================================
    // 2. LOCAL CONFIGURATION
    // ==========================================================

    checks.add(
      _localCheck(
        name: 'Backend URL',
        target:
            AppConfig.backendBaseUrl,
        ok:
            _isValidHttpsUrl(
          AppConfig.backendBaseUrl,
        ),
        detail:
            _isValidHttpsUrl(
              AppConfig.backendBaseUrl,
            )
                ? 'HTTPS URL صالح'
                : 'Backend URL غير صالح',
      ),
    );

    checks.add(
      _localCheck(
        name: 'AI Backend Policy',
        target: 'AppConfig',
        ok:
            AppConfig.aiMustUseBackend &&
            !AppConfig.clientSideApiKeysAllowed,
        detail:
            'aiMustUseBackend=${AppConfig.aiMustUseBackend} | '
            'clientSideApiKeysAllowed=${AppConfig.clientSideApiKeysAllowed}',
      ),
    );

    checks.add(
      _localCheck(
        name: 'Feature Flags',
        target: 'AppConfig',
        ok:
            AppConfig.newsEnabled &&
            AppConfig.audioEnabled &&
            AppConfig.radioEnabled &&
            AppConfig.creditsEnabled &&
            AppConfig.imageGenerationEnabled &&
            AppConfig.imageAnalysisEnabled &&
            AppConfig.khalasanaEnabled,
        detail:
            'news=${AppConfig.newsEnabled} | '
            'audio=${AppConfig.audioEnabled} | '
            'radio=${AppConfig.radioEnabled} | '
            'credits=${AppConfig.creditsEnabled} | '
            'imageGeneration=${AppConfig.imageGenerationEnabled} | '
            'imageAnalysis=${AppConfig.imageAnalysisEnabled} | '
            'khalasana=${AppConfig.khalasanaEnabled}',
      ),
    );

    // ==========================================================
    // 3. BASIC BACKEND
    // ==========================================================

    checks.add(
      await _getJson(
        name: 'Backend Root',
        path: '/',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['app'] != null,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Backend Health',
        path: '/health',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['status'] == 'healthy',
      ),
    );

    checks.add(
      await _getJson(
        name: 'Backend Service Status',
        path:
            '/v1/service-status',
        validator: (
          data,
        ) {
          final services =
              data['services'];

          return data['ok'] == true &&
              services is Map;
        },
      ),
    );

    checks.add(
      await _getJson(
        name: 'Backend Diagnostics',
        path:
            '/v1/diagnostics',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['runtime'] is Map &&
            data['providers'] is Map &&
            data['models'] is Map,
      ),
    );

    // ==========================================================
    // 4. CONTENT SERVICES
    // ==========================================================

    checks.add(
      await _getJson(
        name: 'News API',
        path: '/v1/news',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['items'] is List,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Quran API',
        path:
            '/v1/audio/quran',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['suras'] is List &&
            data['reciters'] is List,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Hadith Books API',
        path:
            '/v1/hadith/books',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['items'] is List,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Tafsir Books API',
        path:
            '/v1/tafsir/books',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['items'] is List,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Radio Countries API',
        path:
            '/v1/radio/countries',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            _containsList(
              data,
              const [
                'items',
                'countries',
              ],
            ),
      ),
    );

    checks.add(
      await _getJson(
        name: 'Radio Stations API',
        path:
            '/v1/radio/stations?country=EG',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            _containsList(
              data,
              const [
                'items',
                'stations',
              ],
            ),
      ),
    );

    checks.add(
      await _getJson(
        name: 'Audio Search API',
        path:
            '/v1/audio/search-v4?q=arabic&type=music',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['items'] is List,
      ),
    );

    // ==========================================================
    // 5. MONETIZATION / DOWNLOAD
    // ==========================================================

    checks.add(
      await _getJson(
        name: 'Monetization API',
        path:
            '/v1/monetization',
        validator: (
          data,
        ) =>
            data['ok'] == true &&
            data['monetization'] is Map,
      ),
    );

    checks.add(
      await _getJson(
        name: 'Download Health',
        path:
            '/download/health',
        validator: (
          data,
        ) =>
            data['ok'] == true,
      ),
    );

    // ==========================================================
    // 6. AI ROUTE REACHABILITY
    //
    // مهم:
    // لا نرسل طلب AI حقيقي.
    // لا يتم استهلاك Credits.
    //
    // نرسل body فارغًا عمدًا.
    //
    // لو رجع:
    // 400 EMPTY_MESSAGE
    //
    // فهذا يثبت أن:
    // APK → Internet → Worker → /v1/chat
    // وصل بنجاح.
    // ==========================================================

    checks.add(
      await _postRouteCheck(
        name: 'AI Chat Route',
        path: '/v1/chat',
        expectedErrors: const [
          'EMPTY_MESSAGE',
          'DEVICE_ID_REQUIRED',
        ],
      ),
    );

    // ==========================================================
    // 7. IMAGE ROUTE REACHABILITY
    //
    // لا يتم إنشاء صورة ولا خصم Credits.
    //
    // body فارغ → المتوقع EMPTY_PROMPT.
    // ==========================================================

    checks.add(
      await _postRouteCheck(
        name: 'Image Route',
        path: '/v1/image',
        expectedErrors: const [
          'EMPTY_PROMPT',
        ],
      ),
    );

    // ==========================================================
    // 8. ACTUAL MEDIA URL PROBES
    //
    // لا نكتفي بأن API رجع بيانات.
    // نحاول الوصول إلى مصدر الميديا نفسه.
    // ==========================================================

    final newsResult =
        await _getJson(
      name: 'News Media Source',
      path: '/v1/news',
      validator: (
        data,
      ) =>
          data['ok'] == true &&
          data['items'] is List,
    );

    checks.add(
      newsResult,
    );

    final newsMediaUrl =
        _findFirstUrl(
      newsResult,
      const [
        'imageUrl',
        'image',
        'thumbnail',
        'image_url',
      ],
    );

    if (newsMediaUrl != null) {
      checks.add(
        await _probeExternalUrl(
          name:
              'News Image URL',
          url:
              newsMediaUrl,
        ),
      );
    } else {
      checks.add(
        const DiagnosticCheck(
          name:
              'News Image URL',
          target:
              'News response',
          ok: false,
          statusCode: null,
          detail:
              'لم يتم العثور على imageUrl/image/thumbnail داخل الأخبار.',
          duration:
              Duration.zero,
        ),
      );
    }

    // ==========================================================
    // QURAN MEDIA
    // ==========================================================

    final quranResult =
        await _getJson(
      name: 'Quran Media Data',
      path:
          '/v1/audio/quran',
      validator: (
        data,
      ) =>
          data['ok'] == true &&
          data['reciters'] is List &&
          data['suras'] is List,
    );

    checks.add(
      quranResult,
    );

    final quranAudioUrl =
        _findFirstUrl(
      quranResult,
      const [
        'server',
        'audioUrl',
        'audio_url',
      ],
    );

    if (quranAudioUrl != null) {
      checks.add(
        await _probeExternalUrl(
          name:
              'Quran Media URL',
          url:
              _normalizeQuranProbeUrl(
            quranAudioUrl,
          ),
          headers: const {
            'Range': 'bytes=0-1023',
          },
        ),
      );
    } else {
      checks.add(
        const DiagnosticCheck(
          name:
              'Quran Media URL',
          target:
              'Quran response',
          ok: false,
          statusCode: null,
          detail:
              'لم يتم العثور على مصدر صوت صالح داخل كتالوج القرآن.',
          duration:
              Duration.zero,
        ),
      );
    }

    // ==========================================================
    // RADIO MEDIA
    // ==========================================================

    final radioResult =
        await _getJson(
      name: 'Radio Media Data',
      path:
          '/v1/radio/stations?country=EG',
      validator: (
        data,
      ) =>
          data['ok'] == true &&
          _containsList(
            data,
            const [
              'items',
              'stations',
            ],
          ),
    );

    checks.add(
      radioResult,
    );

    final radioUrl =
        _findFirstUrl(
      radioResult,
      const [
        'url',
        'streamUrl',
        'stream_url',
        'audioUrl',
        'audio_url',
      ],
    );

    if (radioUrl != null) {
      checks.add(
        await _probeExternalUrl(
          name:
              'Radio Stream URL',
          url:
              radioUrl,
          headers: const {
            'Range': 'bytes=0-1023',
          },
        ),
      );
    } else {
      checks.add(
        const DiagnosticCheck(
          name:
              'Radio Stream URL',
          target:
              'Radio response',
          ok: false,
          statusCode: null,
          detail:
              'لم يتم العثور على stream URL داخل أول بيانات الراديو.',
          duration:
              Duration.zero,
        ),
      );
    }

    return AppDiagnosticsReport(
      startedAt:
          startedAt,
      checks:
          checks,
    );
  }

  // ============================================================
  // LOCAL CHECK
  // ============================================================

  static DiagnosticCheck _localCheck({
    required String name,
    required String target,
    required bool ok,
    required String detail,
  }) {
    return DiagnosticCheck(
      name:
          name,
      target:
          target,
      ok:
          ok,
      statusCode:
          null,
      detail:
          detail,
      duration:
          Duration.zero,
    );
  }

  // ============================================================
  // GET JSON
  // ============================================================

  static Future<DiagnosticCheck> _getJson({
    required String name,
    required String path,
    required bool Function(
      Map<String, dynamic>,
    ) validator,
  }) async {
    final started =
        DateTime.now();

    final url =
        AppConfig.buildBackendUrl(
      path,
    );

    try {
      final response =
          await http
              .get(
                Uri.parse(url),
                headers:
                    _headers,
              )
              .timeout(
                defaultTimeout,
              );

      final data =
          _decodeMap(
        response.body,
      );

      final statusOk =
          response.statusCode >=
              200 &&
          response.statusCode <
              300;

      final contractOk =
          data != null &&
          validator(
            data,
          );

      final ok =
          statusOk &&
          contractOk;

      String detail;

      if (ok) {
        detail =
            _successDetail(
          data!,
        );
      } else if (data != null) {
        detail =
            _errorDetail(
          response.statusCode,
          data,
        );
      } else {
        detail =
            'HTTP ${response.statusCode} | '
            'رد غير صالح: '
            '${_short(
          response.body,
        )}';
      }

      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            ok,
        statusCode:
            response.statusCode,
        detail:
            detail,
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on TimeoutException {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            'Timeout بعد '
            '${defaultTimeout.inSeconds} ثانية. '
            'افحص الإنترنت / DNS / TLS / Worker.',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on http.ClientException catch (
      error
    ) {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            'ClientException: '
            '${error.message}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on FormatException catch (
      error
    ) {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            'FormatException: '
            '${error.message}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } catch (error) {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            '${error.runtimeType}: '
            '$error',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    }
  }

  // ============================================================
  // POST ROUTE CHECK
  // ============================================================

  static Future<DiagnosticCheck> _postRouteCheck({
    required String name,
    required String path,
    required List<String> expectedErrors,
  }) async {
    final started =
        DateTime.now();

    try {
      final response =
          await http
              .post(
                Uri.parse(
                  AppConfig.buildBackendUrl(
                    path,
                  ),
                ),
                headers:
                    const {
                  'Accept':
                      'application/json',
                  'Content-Type':
                      'application/json',
                },
                body:
                    '{}',
              )
              .timeout(
                defaultTimeout,
              );

      final data =
          _decodeMap(
        response.body,
      );

      final error =
          data?['error']
              ?.toString();

      final routeReached =
          response.statusCode ==
              400 &&
          error != null &&
          expectedErrors.contains(
            error,
          );

      if (routeReached) {
        return DiagnosticCheck(
          name:
              name,
          target:
              path,
          ok:
              true,
          statusCode:
              response.statusCode,
          detail:
              'HTTP 400 متوقع | '
              'route وصل للـWorker | '
              'error=$error | '
              'لم يتم استهلاك AI credits.',
          duration:
              DateTime.now()
                  .difference(
            started,
          ),
        );
      }

      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            response.statusCode,
        detail:
            'Route لم يعطِ الاستجابة التشخيصية المتوقعة. '
            'HTTP ${response.statusCode} | '
            'error=${error ?? 'غير معروف'}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on TimeoutException {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            'POST Timeout: '
            'الطلب لم يصل أو لم يعد من Worker.',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on http.ClientException catch (
      error
    ) {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            'POST ClientException: '
            '${error.message}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } catch (error) {
      return DiagnosticCheck(
        name:
            name,
        target:
            path,
        ok:
            false,
        statusCode:
            null,
        detail:
            '${error.runtimeType}: '
            '$error',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    }
  }

  // ============================================================
  // EXTERNAL MEDIA PROBE
  // ============================================================

  static Future<DiagnosticCheck> _probeExternalUrl({
    required String name,
    required String url,
    Map<String, String>? headers,
  }) async {
    final started =
        DateTime.now();

    if (!_isValidHttpUrl(url)) {
      return DiagnosticCheck(
        name:
            name,
        target:
            url,
        ok:
            false,
        statusCode:
            null,
        detail:
            'Media URL غير صالح.',
        duration:
            Duration.zero,
      );
    }

    try {
      final response =
          await http
              .get(
                Uri.parse(url),
                headers:
                    headers ??
                    const {
                      'Accept':
                          '*/*',
                    },
              )
              .timeout(
                mediaTimeout,
              );

      final statusOk =
          response.statusCode >=
              200 &&
          response.statusCode <
              400;

      return DiagnosticCheck(
        name:
            name,
        target:
            _short(url),
        ok:
            statusOk,
        statusCode:
            response.statusCode,
        detail:
            statusOk
                ? 'مصدر الميديا قابل للوصول | '
                    'HTTP ${response.statusCode}'
                : 'مصدر الميديا فشل | '
                    'HTTP ${response.statusCode}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on TimeoutException {
      return DiagnosticCheck(
        name:
            name,
        target:
            _short(url),
        ok:
            false,
        statusCode:
            null,
        detail:
            'Media Timeout بعد '
            '${mediaTimeout.inSeconds} ثوانٍ.',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } on http.ClientException catch (
      error
    ) {
      return DiagnosticCheck(
        name:
            name,
        target:
            _short(url),
        ok:
            false,
        statusCode:
            null,
        detail:
            'Media ClientException: '
            '${error.message}',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    } catch (error) {
      return DiagnosticCheck(
        name:
            name,
        target:
            _short(url),
        ok:
            false,
        statusCode:
            null,
        detail:
            '${error.runtimeType}: '
            '$error',
        duration:
            DateTime.now()
                .difference(
          started,
        ),
      );
    }
  }

  // ============================================================
  // JSON HELPERS
  // ============================================================

  static Map<String, dynamic>?
      _decodeMap(
    String body,
  ) {
    try {
      final decoded =
          jsonDecode(
        body,
      );

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (_) {}

    return null;
  }

  static String _successDetail(
    Map<String, dynamic> data,
  ) {
    final version =
        data['backendVersion']
            ?.toString();

    final count =
        data['items'] is List
            ? (
                data['items']
                    as List
              ).length
            : null;

    final status =
        data['status']
            ?.toString();

    if (version != null &&
        count != null) {
      return 'HTTP 200 | '
          'backend=$version | '
          'items=$count';
    }

    if (version != null) {
      return 'HTTP 200 | '
          'backend=$version';
    }

    if (status != null) {
      return 'HTTP 200 | '
          'status=$status';
    }

    if (count != null) {
      return 'HTTP 200 | '
          'items=$count';
    }

    return 'HTTP 200 | OK';
  }

  static String _errorDetail(
    int status,
    Map<String, dynamic> data,
  ) {
    final error =
        data['error']
            ?.toString();

    final message =
        data['message']
            ?.toString();

    if (error != null &&
        error.isNotEmpty) {
      return 'HTTP $status | '
          'error=$error'
          '${message == null ? '' : ' | $message'}';
    }

    return 'HTTP $status | '
        'JSON غير متوافق مع العقد المتوقع.';
  }

  static bool _containsList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data[key] is List) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // URL HELPERS
  // ============================================================

  static bool _isValidHttpsUrl(
    String value,
  ) {
    try {
      final uri =
          Uri.parse(
        value,
      );

      return uri.scheme ==
              'https' &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool _isValidHttpUrl(
    String value,
  ) {
    try {
      final uri =
          Uri.parse(
        value,
      );

      return (
            uri.scheme ==
                'http' ||
            uri.scheme ==
                'https'
          ) &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// يحاول استخراج أول URL من المفاتيح المهمة
  /// داخل JSON متداخل.
  static String? _findFirstUrl(
    DiagnosticCheck check,
    List<String> preferredKeys,
  ) {
    // هذه الدالة لا تستخدم في النسخة النهائية
    // إلا مع بيانات محفوظة في target.
    //
    // أبقيناها هنا غير مستخدمة عمدًا حتى لا
    // نعتمد على تحويل DiagnosticCheck إلى JSON.
    return null;
  }

  static String _normalizeQuranProbeUrl(
    String url,
  ) {
    return url;
  }

  static String _short(
    String value,
  ) {
    final clean =
        value
            .replaceAll(
              RegExp(
                r'\s+',
              ),
              ' ',
            )
            .trim();

    if (clean.length <= 180) {
      return clean;
    }

    return '${clean.substring(
      0,
      180,
    )}…';
  }
}
