
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../audio_player_service.dart';
import 'ads_service.dart';
import 'app_diagnostics_service.dart';
import 'sa7bi_network_client.dart';

typedef _PayloadValidator = String? Function(
  Map<String, dynamic> body,
);

class AppDiagnosticsV5Service {
  AppDiagnosticsV5Service({
    this.workerBaseUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  }) : _legacy = AppDiagnosticsService(
          workerBaseUrl: workerBaseUrl,
        );

  final String workerBaseUrl;
  final AppDiagnosticsService _legacy;

  static const String version = '5.0.0';
  static const Duration checkTimeout = Duration(seconds: 12);

  String? _quranStreamUrl;
  String? _hadithBookId;
  String? _tafsirBookId;
  List<String> _radioStreamUrls = const [];

  Future<AppDiagnosticsV5Report> runFullDiagnostics({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    final startedAt = DateTime.now();

    // Keep existing network/build/Worker checks.
    // The old URL-construction-only result is hidden because v5
    // replaces it with real media-stream byte checks.
    final legacyReport = await _legacy.runFullDiagnostics(
      onResult: (result) {
        if (result.name != 'Media URL handling') {
          onResult?.call(result);
        }
      },
    );

    final results = legacyReport.results
        .where((result) => result.name != 'Media URL handling')
        .toList();

    // Validate actual service data, not just HTTP status.
    await _append(results, onResult, _checkQuranCatalog);
    await _append(results, onResult, _checkQuranStream);

    await _append(results, onResult, _checkHadithBooks);
    await _append(results, onResult, _checkHadithSample);

    await _append(results, onResult, _checkTafsirBooks);
    await _append(results, onResult, _checkTafsirSample);

    await _append(results, onResult, _checkRadioStations);
    await _append(results, onResult, _checkRadioStream);

    await _append(results, onResult, _checkNewsPayload);
    await _append(results, onResult, _checkMusicPayload);
    await _append(results, onResult, _checkPodcastPayload);
    await _append(results, onResult, _checkShortsPayload);

    // Read-only checks against real Android plugin state.
    await _append(results, onResult, _checkAudioHandler);
    await _append(results, onResult, _checkTtsEngine);
    await _append(
      results,
      onResult,
      () => _checkPermission(
        name: 'Microphone permission',
        permission: Permission.microphone,
      ),
    );
    await _append(
      results,
      onResult,
      () => _checkPermission(
        name: 'Camera permission',
        permission: Permission.camera,
      ),
    );
    await _append(
      results,
      onResult,
      () => _checkPermission(
        name: 'Notification permission',
        permission: Permission.notification,
      ),
    );
    await _append(results, onResult, _checkAdMobInitialization);
    await _append(results, onResult, _checkAppForeground);

    // These require a user action, a paid request, or a data write.
    // We deliberately do not fake a PASS for them.
    _appendNotTested(
      results,
      onResult,
      name: 'Real AI conversation',
      category: 'AI',
      details:
          'لم يتم إرسال سؤال حقيقي إلى AI؛ قد يستهلك ذلك رصيدًا. '
          'اختبار مسار HTTP الفارغ لا يثبت نجاح الاستدلال الفعلي.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Image upload and AI image processing',
      category: 'IMAGE',
      details:
          'لم يتم فتح المعرض أو رفع صورة أو طلب توليد/تعديل؛ '
          'هذا يحتاج صورة فعلية وقد يستهلك رصيدًا.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Real speaker playback',
      category: 'AUDIO',
      details:
          'تم فحص تهيئة مشغل الصوت وبايتات بعض المصادر فقط. '
          'لم يتم تشغيل صوت مسموع أثناء التشخيص.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Social posts, stories and messages',
      category: 'SOCIAL',
      details:
          'لم يتم نشر Reel أو Story أو إرسال رسالة؛ '
          'هذه عمليات كتابة تخص بيانات المستخدم.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Online game creation and matchmaking',
      category: 'GAMES',
      details:
          'لم يتم إنشاء غرفة أو دعوة لاعب أو بدء مباراة؛ '
          'هذه عمليات تغيّر بيانات الحساب والخادم.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Ad inventory and impression',
      category: 'MONETIZATION',
      details:
          'تم فحص حالة تهيئة SDK فقط. لم يتم تحميل إعلان '
          'أو عرضه، ولذلك لا يمكن إثبات وجود مخزون إعلاني.',
    );
    _appendNotTested(
      results,
      onResult,
      name: 'Every inner-screen UI interaction',
      category: 'UI',
      details:
          'التشخيص داخل التطبيق لا يضغط كل الأزرار نيابة عن المستخدم. '
          'يوجد اختبار منفصل على Android Emulator للتنقل بين الصفحات '
          'الرئيسية والشات والألعاب والحساب والتشخيص.',
    );

    return AppDiagnosticsV5Report(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      results: results,
    );
  }

  Future<void> _append(
    List<DiagnosticResult> results,
    void Function(DiagnosticResult result)? onResult,
    Future<DiagnosticResult> Function() check,
  ) async {
    final stopwatch = Stopwatch()..start();
    DiagnosticResult result;

    try {
      result = await check().timeout(
        checkTimeout,
        onTimeout: () => DiagnosticResult(
          name: 'Diagnostic check',
          category: 'DIAGNOSTICS',
          success: false,
          severity: 'FAIL',
          status: 'TIMEOUT',
          details:
              'الاختبار تجاوز ${checkTimeout.inSeconds} ثانية.',
          durationMs: checkTimeout.inMilliseconds,
        ),
      );
    } catch (error) {
      result = DiagnosticResult(
        name: 'Diagnostic check',
        category: 'DIAGNOSTICS',
        success: false,
        severity: 'FAIL',
        status: 'CHECK_ERROR',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    stopwatch.stop();

    if (result.durationMs <= 0 &&
        stopwatch.elapsedMilliseconds > 0) {
      result = _copyWithDuration(
        result,
        stopwatch.elapsedMilliseconds,
      );
    }

    results.add(result);
    onResult?.call(result);
  }

  DiagnosticResult _copyWithDuration(
    DiagnosticResult result,
    int durationMs,
  ) {
    return DiagnosticResult(
      name: result.name,
      category: result.category,
      success: result.success,
      severity: result.severity,
      status: result.status,
      details: result.details,
      httpStatus: result.httpStatus,
      durationMs: durationMs,
      repairable: result.repairable,
      blocked: result.blocked,
    );
  }

  void _appendNotTested(
    List<DiagnosticResult> results,
    void Function(DiagnosticResult result)? onResult, {
    required String name,
    required String category,
    required String details,
  }) {
    final result = DiagnosticResult(
      name: name,
      category: category,
      success: false,
      severity: 'WARN',
      status: 'NOT_TESTED_SAFETY',
      details: details,
      durationMs: 0,
      blocked: true,
      repairable: false,
    );

    results.add(result);
    onResult?.call(result);
  }

  Uri _buildUri(String rawPath) {
    final base = Uri.parse(workerBaseUrl);
    final parsed = Uri.parse(
      rawPath.startsWith('/') ? rawPath : '/$rawPath',
    );

    return base.replace(
      path: parsed.path,
      queryParameters: parsed.queryParameters.isEmpty
          ? null
          : parsed.queryParameters,
      fragment: null,
    );
  }

  List<dynamic> _asList(Object? value) {
    return value is List ? value : const <dynamic>[];
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String _string(Object? value) =>
      value?.toString().trim() ?? '';

  bool _isHttpsUrl(Object? value) {
    final raw = _string(value);
    if (raw.isEmpty) return false;

    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty;
  }

  bool _isWebUrl(Object? value) {
    final raw = _string(value);
    if (raw.isEmpty) return false;

    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<DiagnosticResult> _jsonCheck({
    required String name,
    required String category,
    required String path,
    required _PayloadValidator validate,
    required String Function(Map<String, dynamic>) passedDetails,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri(path);
      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(checkTimeout);

      final status = response.statusCode;
      final raw = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      if (status < 200 || status >= 300) {
        stopwatch.stop();

        final isClientValidation =
            status == 400 ||
            status == 401 ||
            status == 403 ||
            status == 404 ||
            status == 429;

        return DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: isClientValidation ? 'WARN' : 'FAIL',
          status: 'HTTP_$status',
          httpStatus: status,
          details:
              'GET ${uri.path}; HTTP=$status; ${_short(raw)}',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final decoded = jsonDecode(raw);
      final body = _asMap(decoded);

      if (body == null) {
        stopwatch.stop();

        return DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: 'INVALID_JSON_OBJECT',
          httpStatus: status,
          details:
              'الخدمة أعادت HTTP 2xx لكن جسم الرد ليس JSON object صالحًا.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final workerRejected = body['ok'] == false;
      final validationProblem = workerRejected
          ? 'Worker returned ok=false: '
              '${_string(body['error']).isEmpty ? _string(body['message']) : _string(body['error'])}'
          : validate(body);

      stopwatch.stop();

      final success = validationProblem == null;

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success
            ? 'PAYLOAD_VALID'
            : 'PAYLOAD_INVALID',
        httpStatus: status,
        details: success
            ? passedDetails(body)
            : validationProblem!,
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: false,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: 'DATA_CHECK_ERROR',
        details: 'تعذر فحص بيانات $path: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkQuranCatalog() {
    return _jsonCheck(
      name: 'Quran reciters and suras data',
      category: 'QURAN',
      path: '/v1/audio/quran',
      validate: (body) {
        final reciters = _asList(body['reciters']);
        final suras = _asList(body['suras']);

        if (reciters.isEmpty) {
          return 'قائمة القراء فارغة أو غير موجودة.';
        }
        if (suras.isEmpty) {
          return 'قائمة السور فارغة أو غير موجودة.';
        }

        String? selectedServer;

        for (final rawReciter in reciters) {
          final reciter = _asMap(rawReciter);
          if (reciter == null) continue;

          for (final rawMoshaf in _asList(reciter['moshaf'])) {
            final moshaf = _asMap(rawMoshaf);
            if (moshaf == null) continue;

            final server = _string(moshaf['server']);
            if (_isHttpsUrl(server)) {
              selectedServer = server;
              break;
            }
          }

          if (selectedServer != null) break;
        }

        if (selectedServer == null) {
          return 'لم يتم العثور على رابط HTTPS صالح لأي مصحف.';
        }

        final firstSura = _asMap(suras.first);
        final suraId = int.tryParse(
              _string(firstSura?['id']),
            ) ??
            1;

        final cleanServer =
            selectedServer.replaceAll(RegExp(r'/+$'), '');

        _quranStreamUrl =
            '$cleanServer/${suraId.toString().padLeft(3, '0')}.mp3';

        return null;
      },
      passedDetails: (body) =>
          'reciters=${_asList(body['reciters']).length}; '
          'suras=${_asList(body['suras']).length}; '
          'HTTPS sample URL available=${_quranStreamUrl != null}.',
    );
  }

  Future<DiagnosticResult> _checkQuranStream() async {
    final url = _quranStreamUrl;

    if (url == null) {
      return _notTestedDependency(
        name: 'Quran audio stream bytes',
        category: 'QURAN',
        details:
            'لم يتم العثور على رابط مصحف صالح؛ لذلك لم يتم طلب بث صوتي.',
      );
    }

    return _probeStreamUrl(
      name: 'Quran audio stream bytes',
      category: 'QURAN',
      url: url,
    );
  }

  Future<DiagnosticResult> _checkHadithBooks() {
    return _jsonCheck(
      name: 'Hadith books data',
      category: 'HADITH',
      path: '/v1/hadith/books',
      validate: (body) {
        final books = _asList(body['items']);
        final validBooks = books
            .map(_asMap)
            .whereType<Map<String, dynamic>>()
            .where((book) =>
                _string(book['id']).isNotEmpty &&
                _string(book['name']).isNotEmpty)
            .toList();

        if (validBooks.isEmpty) {
          return 'لم يتم استلام كتب حديث صالحة تحتوي على id وname.';
        }

        _hadithBookId = _string(validBooks.first['id']);
        return null;
      },
      passedDetails: (body) =>
          'validBooks=${_asList(body['items']).length}; '
          'sampleBook=$_hadithBookId.',
    );
  }

  Future<DiagnosticResult> _checkHadithSample() async {
    final bookId = _hadithBookId;

    if (bookId == null || bookId.isEmpty) {
      return _notTestedDependency(
        name: 'Hadith content sample',
        category: 'HADITH',
        details: 'لم تنجح قراءة قائمة الكتب؛ لم يتم طلب حديث تجريبي.',
      );
    }

    return _jsonCheck(
      name: 'Hadith content sample',
      category: 'HADITH',
      path: Uri(
        path: '/v1/hadith',
        queryParameters: {
          'book': bookId,
          'limit': '3',
        },
      ).toString(),
      validate: (body) {
        final items = _asList(body['items']);
        final hasText = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              _string(item['text']).isNotEmpty;
        });

        if (!hasText) {
          return 'الخدمة استجابت لكن لم تُرجع حديثًا يحتوي على نص.';
        }
        return null;
      },
      passedDetails: (body) =>
          'book=${body['book']}; '
          'items=${_asList(body['items']).length}; '
          'firstHadithTextPresent=true.',
    );
  }

  Future<DiagnosticResult> _checkTafsirBooks() {
    return _jsonCheck(
      name: 'Tafsir books data',
      category: 'TAFSIR',
      path: '/v1/tafsir/books',
      validate: (body) {
        final books = _asList(body['items']);
        final validBooks = books
            .map(_asMap)
            .whereType<Map<String, dynamic>>()
            .where((book) =>
                _string(book['id']).isNotEmpty &&
                _string(book['name']).isNotEmpty)
            .toList();

        if (validBooks.isEmpty) {
          return 'قائمة كتب التفسير فارغة أو لا تحتوي على id وname.';
        }

        _tafsirBookId = _string(validBooks.first['id']);
        return null;
      },
      passedDetails: (body) =>
          'books=${_asList(body['items']).length}; '
          'selectedTafsir=$_tafsirBookId.',
    );
  }

  Future<DiagnosticResult> _checkTafsirSample() async {
    final tafsirId = _tafsirBookId;

    if (tafsirId == null || tafsirId.isEmpty) {
      return _notTestedDependency(
        name: 'Tafsir content sample',
        category: 'TAFSIR',
        details:
            'لم تنجح قراءة قائمة كتب التفسير؛ لم يتم طلب تفسير تجريبي.',
      );
    }

    final path = Uri(
      path: '/v1/tafsir',
      queryParameters: {
        'tafsir': tafsirId,
        'sura': '114',
      },
    ).toString();

    return _jsonCheck(
      name: 'Tafsir content with book and sura',
      category: 'TAFSIR',
      path: path,
      validate: (body) {
        final items = _asList(body['items']);
        if (items.isEmpty) {
          return 'الرد لا يحتوي على عناصر تفسير للسورة 114.';
        }

        final hasValidItem = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              (
                _string(item['sura']).isNotEmpty ||
                _string(item['suraName']).isNotEmpty ||
                _string(item['audioUrl']).isNotEmpty
              );
        });

        if (!hasValidItem) {
          return 'عناصر التفسير لا تحتوي على بيانات سورة قابلة للاستخدام.';
        }

        return null;
      },
      passedDetails: (body) =>
          'tafsir=$tafsirId; sura=114; '
          'items=${_asList(body['items']).length}.',
    );
  }

  Future<DiagnosticResult> _checkRadioStations() {
    return _jsonCheck(
      name: 'Egypt radio station data',
      category: 'RADIO',
      path: '/v1/radio/stations?country=EG&limit=5',
      validate: (body) {
        final rawStations = _asList(body['items']).isNotEmpty
            ? _asList(body['items'])
            : _asList(body['stations']);

        final validUrls = <String>[];

        for (final raw in rawStations) {
          final station = _asMap(raw);
          if (station == null) continue;

          final streamUrl = _string(station['streamUrl']);
          if (_isHttpsUrl(streamUrl)) {
            validUrls.add(streamUrl);
          }

          if (validUrls.length >= 3) break;
        }

        _radioStreamUrls = validUrls;

        if (validUrls.isEmpty) {
          return 'لم يتم استلام أي محطة برابط بث HTTPS صالح.';
        }

        return null;
      },
      passedDetails: (body) =>
          'stationCount=${_asList(body['items']).length}; '
          'HTTPS stream candidates=${_radioStreamUrls.length}.',
    );
  }

  Future<DiagnosticResult> _checkRadioStream() async {
    if (_radioStreamUrls.isEmpty) {
      return _notTestedDependency(
        name: 'Radio stream bytes',
        category: 'RADIO',
        details:
            'لم تصل روابط محطات HTTPS صالحة؛ لم يتم اختبار بث.',
      );
    }

    DiagnosticResult? lastFailure;

    for (var index = 0; index < _radioStreamUrls.length; index++) {
      final result = await _probeStreamUrl(
        name: 'Radio stream bytes',
        category: 'RADIO',
        url: _radioStreamUrls[index],
      );

      if (result.success) {
        return DiagnosticResult(
          name: 'Radio stream bytes',
          category: 'RADIO',
          success: true,
          severity: 'PASS',
          status: 'STREAM_BYTES_RECEIVED',
          httpStatus: result.httpStatus,
          details:
              'نجح اختبار البث من المحطة المرشحة رقم ${index + 1}. '
              '${result.details}',
          durationMs: result.durationMs,
        );
      }

      lastFailure = result;
    }

    return DiagnosticResult(
      name: 'Radio stream bytes',
      category: 'RADIO',
      success: false,
      severity: 'FAIL',
      status: 'RADIO_STREAM_CANDIDATES_FAILED',
      details:
          'فشل اختبار ${_radioStreamUrls.length} روابط بث متتالية. '
          'آخر نتيجة: ${lastFailure?.details ?? 'لا توجد تفاصيل'}.',
      httpStatus: lastFailure?.httpStatus,
      durationMs: lastFailure?.durationMs ?? 0,
    );
  }

  Future<DiagnosticResult> _probeStreamUrl({
    required String name,
    required String category,
    required String url,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = Uri.tryParse(url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: 'INVALID_HTTPS_STREAM_URL',
        details: 'رابط البث ليس HTTPS صالحًا.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    try {
      final request = http.Request('GET', uri)
        ..headers['Range'] = 'bytes=0-1023'
        ..headers['Accept'] = '*/*';

      final response = await Sa7biNetworkClient.client
          .send(request)
          .timeout(const Duration(seconds: 7));

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();

      final httpSuccess =
          response.statusCode >= 200 &&
          response.statusCode < 300;

      final obviousHtml =
          contentType.contains('text/html') ||
          contentType.contains('application/json');

      if (!httpSuccess || obviousHtml) {
        final subscription = response.stream.listen((_) {});
        await subscription.cancel();

        stopwatch.stop();

        return DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: obviousHtml
              ? 'STREAM_RETURNED_NON_MEDIA_CONTENT'
              : 'STREAM_HTTP_${response.statusCode}',
          httpStatus: response.statusCode,
          details:
              'host=${uri.host}; HTTP=${response.statusCode}; '
              'contentType=$contentType; mediaBytesRead=false.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Read only the first received chunk.
      // Stream.first cancels its subscription after that chunk.
      final firstChunk = await response.stream
          .first
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();

      final bytesReceived = firstChunk.isNotEmpty;

      return DiagnosticResult(
        name: name,
        category: category,
        success: bytesReceived,
        severity: bytesReceived ? 'PASS' : 'FAIL',
        status: bytesReceived
            ? 'STREAM_BYTES_RECEIVED'
            : 'STREAM_EMPTY',
        httpStatus: response.statusCode,
        details:
            'host=${uri.host}; HTTP=${response.statusCode}; '
            'contentType=$contentType; '
            'firstChunkBytes=${firstChunk.length}; '
            'audioPlaybackStarted=false.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: 'STREAM_PROBE_ERROR',
        details:
            'host=${uri.host}; ${_safeError(error)}; '
            'audioPlaybackStarted=false.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkNewsPayload() {
    return _jsonCheck(
      name: 'News items data',
      category: 'NEWS',
      path: '/v1/news',
      validate: (body) {
        final items = _asList(body['items']);
        final validItems = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              _string(item['title']).isNotEmpty &&
              _isWebUrl(item['link']);
        });

        if (!validItems) {
          return 'لم يتم استلام خبر واحد على الأقل بعنوان ورابط صالحين.';
        }
        return null;
      },
      passedDetails: (body) =>
          'items=${_asList(body['items']).length}; '
          'validTitleAndLink=true.',
    );
  }

  Future<DiagnosticResult> _checkMusicPayload() {
    final path = Uri(
      path: '/v1/audio/search-v4',
      queryParameters: {
        'type': 'music',
        'q': 'عمرو دياب',
        'limit': '5',
      },
    ).toString();

    return _jsonCheck(
      name: 'Music search data',
      category: 'AUDIO',
      path: path,
      validate: (body) {
        final items = _asList(body['items']);
        final validItems = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              _string(item['title']).isNotEmpty &&
              (
                _isWebUrl(item['previewUrl']) ||
                _isWebUrl(item['storeUrl'])
              );
        });

        if (!validItems) {
          return 'لم يتم استلام نتيجة موسيقى بعنوان ورابط صالحين. '
              'قد يكون مصدر Apple أو Deezer غير متاح مؤقتًا.';
        }
        return null;
      },
      passedDetails: (body) =>
          'provider=${body['provider'] ?? 'unknown'}; '
          'items=${_asList(body['items']).length}.',
    );
  }

  Future<DiagnosticResult> _checkPodcastPayload() {
    final path = Uri(
      path: '/v1/podcasts/search',
      queryParameters: {
        'q': 'فنجان',
        'limit': '3',
      },
    ).toString();

    return _jsonCheck(
      name: 'Podcast search data',
      category: 'PODCAST',
      path: path,
      validate: (body) {
        final items = _asList(body['results']).isNotEmpty
            ? _asList(body['results'])
            : _asList(body['items']);

        final validItems = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              _string(item['title']).isNotEmpty &&
              (
                _isWebUrl(item['feedUrl']) ||
                _isWebUrl(item['storeUrl'])
              );
        });

        if (!validItems) {
          return 'لم يتم استلام بودكاست بعنوان ورابط Feed أو Store صالح.';
        }
        return null;
      },
      passedDetails: (body) {
        final items = _asList(body['results']).isNotEmpty
            ? _asList(body['results'])
            : _asList(body['items']);

        return 'podcasts=${items.length}; '
            'fallback=${body['fallback'] ?? false}.';
      },
    );
  }

  Future<DiagnosticResult> _checkShortsPayload() {
    return _jsonCheck(
      name: 'Shorts video data',
      category: 'SHORTS',
      path: '/v1/shorts',
      validate: (body) {
        final items = _asList(body['items']);
        final validItems = items.any((raw) {
          final item = _asMap(raw);
          return item != null &&
              _string(item['title']).isNotEmpty &&
              _isHttpsUrl(item['videoUrl']);
        });

        if (!validItems) {
          return 'لم يتم استلام فيديو قصير بعنوان ورابط HTTPS صالحين.';
        }
        return null;
      },
      passedDetails: (body) =>
          'shorts=${_asList(body['items']).length}; '
          'validVideoUrl=true.',
    );
  }

  Future<DiagnosticResult> _checkAudioHandler() async {
    final stopwatch = Stopwatch()..start();

    try {
      await AudioController.initialize().timeout(
        const Duration(seconds: 8),
      );

      final handler = AudioController.handler;
      stopwatch.stop();

      final success = handler != null;

      return DiagnosticResult(
        name: 'Android audio service initialization',
        category: 'DEVICE',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success
            ? 'AUDIO_HANDLER_READY'
            : 'AUDIO_HANDLER_MISSING',
        details: success
            ? 'AudioController handler is initialized. '
                'No track was played and no sound was emitted.'
            : 'AudioController.handler is null after initialization.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Android audio service initialization',
        category: 'DEVICE',
        success: false,
        severity: 'FAIL',
        status: 'AUDIO_INITIALIZATION_ERROR',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkTtsEngine() async {
    final stopwatch = Stopwatch()..start();

    try {
      final rawEngines = await FlutterTts()
          .getEngines()
          .timeout(const Duration(seconds: 6));

      final engines = rawEngines is List
          ? rawEngines
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[];

      stopwatch.stop();

      final success = engines.isNotEmpty;

      return DiagnosticResult(
        name: 'Android text-to-speech engine',
        category: 'DEVICE',
        success: success,
        severity: success ? 'PASS' : 'WARN',
        status: success
            ? 'TTS_ENGINE_AVAILABLE'
            : 'TTS_ENGINE_NOT_FOUND',
        details: success
            ? 'Detected engines: ${engines.join(', ')}. '
                'No speech was played.'
            : 'لم يتم العثور على محرك TTS متاح. '
                'لم يتم تشغيل صوت أثناء الفحص.',
        durationMs: stopwatch.elapsedMilliseconds,
        blocked: !success,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Android text-to-speech engine',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'TTS_PLUGIN_UNAVAILABLE',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
        blocked: true,
      );
    }
  }

  Future<DiagnosticResult> _checkPermission({
    required String name,
    required Permission permission,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Read status only. Do not display a permission prompt.
      final status = await permission.status.timeout(
        const Duration(seconds: 5),
      );

      stopwatch.stop();

      final granted = status.isGranted || status.isLimited;

      return DiagnosticResult(
        name: name,
        category: 'DEVICE',
        success: granted,
        severity: granted ? 'PASS' : 'WARN',
        status: granted ? 'GRANTED' : 'NOT_GRANTED',
        details:
            'permissionStatus=${status.name}; '
            'permissionPromptShown=false; '
            '${granted ? 'الإذن متاح.' : 'الميزة المرتبطة بهذا الإذن قد لا تعمل حتى تمنحه من إعدادات الهاتف.'}',
        durationMs: stopwatch.elapsedMilliseconds,
        blocked: !granted,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'PERMISSION_STATUS_UNAVAILABLE',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
        blocked: true,
      );
    }
  }

  Future<DiagnosticResult> _checkAdMobInitialization() async {
    final initialized = AdsService.instance.isAdMobInitialized;

    return DiagnosticResult(
      name: 'AdMob SDK initialization',
      category: 'MONETIZATION',
      success: initialized,
      severity: initialized ? 'PASS' : 'WARN',
      status: initialized
          ? 'ADMOB_SDK_INITIALIZED'
          : 'ADMOB_SDK_NOT_INITIALIZED',
      details: initialized
          ? 'AdMob SDK initialized. This does not prove that an ad is available.'
          : 'AdMob SDK is not initialized. No ad was loaded or shown by this test.',
      durationMs: 0,
      blocked: !initialized,
    );
  }

  Future<DiagnosticResult> _checkAppForeground() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final resumed = lifecycle == AppLifecycleState.resumed;

    return DiagnosticResult(
      name: 'App foreground lifecycle',
      category: 'DEVICE',
      success: resumed,
      severity: resumed ? 'PASS' : 'WARN',
      status: resumed ? 'APP_RESUMED' : 'APP_NOT_RESUMED',
      details:
          'lifecycleState=${lifecycle?.name ?? 'unknown'}.',
      durationMs: 0,
      blocked: !resumed,
    );
  }

  DiagnosticResult _notTestedDependency({
    required String name,
    required String category,
    required String details,
  }) {
    return DiagnosticResult(
      name: name,
      category: category,
      success: false,
      severity: 'WARN',
      status: 'NOT_TESTED_DEPENDENCY_FAILED',
      details: details,
      durationMs: 0,
      blocked: true,
    );
  }

  String _short(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 500) return clean;
    return '${clean.substring(0, 500)}…';
  }

  String _safeError(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class AppDiagnosticsV5Report {
  const AppDiagnosticsV5Report({
    required this.startedAt,
    required this.finishedAt,
    required this.results,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final List<DiagnosticResult> results;

  Duration get duration => finishedAt.difference(startedAt);

  int get passed =>
      results.where((item) => item.severity == 'PASS').length;

  int get warnings =>
      results.where((item) => item.severity == 'WARN').length;

  int get failed =>
      results.where((item) => item.severity == 'FAIL').length;

  int get blocked =>
      results.where((item) => item.blocked).length;

  int get notTested => results
      .where((item) =>
          item.blocked ||
          item.status.startsWith('NOT_TESTED'))
      .length;

  int get total => results.length;

  DiagnosticResult? _firstFailure() {
    for (final item in results) {
      if (item.severity == 'FAIL' && !item.blocked) {
        return item;
      }
    }
    return null;
  }

  String get rootCauseCode {
    final build = results.where(
      (item) =>
          item.name == 'Build/source identity' &&
          item.severity == 'FAIL',
    );

    if (build.isNotEmpty) return 'BUILD_IDENTITY';

    final network = results.where(
      (item) =>
          item.category == 'NETWORK' &&
          item.severity == 'FAIL' &&
          !item.blocked,
    );

    if (network.isNotEmpty) return 'NETWORK_FAILURE';

    final worker = results.where(
      (item) =>
          item.category == 'WORKER' &&
          item.severity == 'FAIL' &&
          !item.blocked,
    );

    if (worker.isNotEmpty) return 'BACKEND_WORKER_FAILURE';

    final failure = _firstFailure();
    if (failure != null) {
      return 'FEATURE_${failure.category}_FAILURE';
    }

    return 'NO_CONFIRMED_FAILURE';
  }

  String get primaryProblem {
    final failure = _firstFailure();

    if (failure != null) {
      return '${failure.category} — ${failure.name}: '
          '${failure.details}';
    }

    if (warnings > 0) {
      return 'لم يظهر فشل قاطع في الاختبارات المنفذة. '
          'توجد $warnings تحذيرات، منها اختبارات لم تُنفذ '
          'لأنها قد تخصم رصيدًا أو تغيّر بيانات المستخدم.';
    }

    return 'كل الاختبارات المنفذة اجتازت الفحص.';
  }

  List<DiagnosticResult> get slowestResults {
    final copy = List<DiagnosticResult>.from(results)
      ..sort((a, b) => b.durationMs.compareTo(a.durationMs));

    return copy.take(7).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'reportVersion': AppDiagnosticsV5Service.version,
      'startedAt': startedAt.toLocal().toIso8601String(),
      'finishedAt': finishedAt.toLocal().toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'summary': {
        'passed': passed,
        'warnings': warnings,
        'failed': failed,
        'blocked': blocked,
        'notTested': notTested,
        'total': total,
      },
      'rootCauseCode': rootCauseCode,
      'primaryProblem': primaryProblem,
      'coverage': {
        'networkAndWorker': 'tested',
        'servicePayloads': 'validated',
        'quranAndRadioStreamBytes': 'tested_without_playback',
        'audioAndTtsPlugins': 'checked_without_playback',
        'permissions': 'read_only_status_check',
        'adMob': 'sdk_initialization_only',
        'uiNavigation': 'separate_android_emulator_workflow',
        'paidAiInference': 'not_executed',
        'imageUploadOrGeneration': 'not_executed',
        'socialAndGameWrites': 'not_executed',
        'adImpressions': 'not_executed',
        'speakerPlayback': 'not_executed',
      },
      'buildIdentity': {
        'appBuildId': AppDiagnosticsService.buildId,
        'sourceId': AppDiagnosticsService.sourceId,
        'appVersion': AppDiagnosticsService.appVersion,
        'buildNumber': AppDiagnosticsService.buildNumber,
        'commitSha': AppDiagnosticsService.commitSha,
      },
      'networkTransport': Sa7biNetworkClient.transportName,
      'results': results.map((item) => item.toJson()).toList(),
      'slowestTests': slowestResults
          .map((item) => {
                'name': item.name,
                'durationMs': item.durationMs,
                'status': item.status,
              })
          .toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  String toTextReport() {
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('SA7BI AI DIAGNOSTIC REPORT');
    buffer.writeln('========================================');
    buffer.writeln('Report version: ${AppDiagnosticsV5Service.version}');
    buffer.writeln('Started: ${startedAt.toLocal().toIso8601String()}');
    buffer.writeln('Finished: ${finishedAt.toLocal().toIso8601String()}');
    buffer.writeln('Duration: ${duration.inMilliseconds} ms');
    buffer.writeln();

    buffer.writeln('SUMMARY');
    buffer.writeln('Passed: $passed');
    buffer.writeln('Warnings: $warnings');
    buffer.writeln('Failed: $failed');
    buffer.writeln('Blocked: $blocked');
    buffer.writeln('Not tested: $notTested');
    buffer.writeln('Total: $total');
    buffer.writeln();

    buffer.writeln('ROOT CAUSE');
    buffer.writeln(rootCauseCode);
    buffer.writeln(primaryProblem);
    buffer.writeln();

    buffer.writeln('BUILD IDENTITY');
    buffer.writeln('APP_BUILD_ID: ${AppDiagnosticsService.buildId}');
    buffer.writeln('APP_SOURCE_ID: ${AppDiagnosticsService.sourceId}');
    buffer.writeln('SA7BI_APP_VERSION: ${AppDiagnosticsService.appVersion}');
    buffer.writeln('SA7BI_BUILD_NUMBER: ${AppDiagnosticsService.buildNumber}');
    buffer.writeln('SA7BI_COMMIT_SHA: ${AppDiagnosticsService.commitSha}');
    buffer.writeln();

    buffer.writeln('NETWORK TRANSPORT');
    buffer.writeln(Sa7biNetworkClient.transportName);
    buffer.writeln();

    buffer.writeln('RESULTS');
    buffer.writeln('----------------------------------------');

    for (final item in results) {
      buffer.writeln(
        '[${item.severity}] ${item.category} | ${item.name}',
      );
      buffer.writeln('Status: ${item.status}');
      buffer.writeln('HTTP: ${item.httpStatus ?? '-'}');
      buffer.writeln('Duration: ${item.durationMs} ms');
      buffer.writeln('Blocked / not tested: ${item.blocked}');
      buffer.writeln('Details: ${item.details}');
      buffer.writeln();
    }

    buffer.writeln('SLOWEST TESTS');
    buffer.writeln('----------------------------------------');

    for (final item in slowestResults) {
      buffer.writeln(
        '${item.durationMs} ms | ${item.status} | ${item.name}',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'ملاحظة: نجاح HTTP لا يعني نجاح تشغيل كل ميزة بصوت أو تفاعل حقيقي.',
    );
    buffer.writeln('========================================');
    buffer.writeln('END OF REPORT');
    buffer.writeln('========================================');

    return buffer.toString();
  }
}
