import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class DiagnosticResult {
  final String name;
  final String category;
  final bool success;
  final String status;
  final String details;
  final int? httpStatus;
  final int durationMs;

  const DiagnosticResult({
    required this.name,
    required this.category,
    required this.success,
    required this.status,
    required this.details,
    required this.durationMs,
    this.httpStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'success': success,
      'status': status,
      'details': details,
      'httpStatus': httpStatus,
      'durationMs': durationMs,
    };
  }
}

class AppDiagnosticsReport {
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<DiagnosticResult> results;

  const AppDiagnosticsReport({
    required this.startedAt,
    required this.finishedAt,
    required this.results,
  });

  int get passed => results.where((e) => e.success).length;

  int get failed => results.where((e) => !e.success).length;

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'passed': passed,
      'failed': failed,
      'total': results.length,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class AppDiagnosticsService {
  AppDiagnosticsService({
    this.workerBaseUrl = 'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  });

  final String workerBaseUrl;

  static const Duration defaultTimeout = Duration(seconds: 12);

  Future<AppDiagnosticsReport> runFullDiagnostics({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    final started = DateTime.now();
    final results = <DiagnosticResult>[];

    Future<void> run(
      String category,
      String name,
      Future<DiagnosticResult> Function() test,
    ) async {
      DiagnosticResult result;

      try {
        result = await test().timeout(
          defaultTimeout,
          onTimeout: () {
            return DiagnosticResult(
              name: name,
              category: category,
              success: false,
              status: 'TIMEOUT',
              details:
                  'The diagnostic test exceeded ${defaultTimeout.inSeconds} seconds.',
              durationMs: defaultTimeout.inMilliseconds,
            );
          },
        );
      } catch (e) {
        result = DiagnosticResult(
          name: name,
          category: category,
          success: false,
          status: 'EXCEPTION',
          details: _safeError(e),
          durationMs: 0,
        );
      }

      results.add(result);
      onResult?.call(result);
    }

    await run(
      'BUILD',
      'Runtime identity',
      _checkRuntimeIdentity,
    );

    await run(
      'NETWORK',
      'Internet connectivity',
      _checkInternet,
    );

    await run(
      'NETWORK',
      'DNS resolution',
      _checkDns,
    );

    await run(
      'NETWORK',
      'TLS / HTTPS',
      _checkTls,
    );

    await run(
      'WORKER',
      'Worker root',
      () => _httpGet(
        name: 'Worker root',
        category: 'WORKER',
        path: '/',
      ),
    );

    await run(
      'WORKER',
      'Worker health',
      () => _httpGet(
        name: 'Worker health',
        category: 'WORKER',
        path: '/health',
      ),
    );

    await run(
      'AI',
      'AI chat route',
      () => _httpPost(
        name: 'AI chat route',
        category: 'AI',
        path: '/v1/chat',
        body: {
          'message': 'diagnostic ping',
          'input': 'diagnostic ping',
          'stream': false,
        },
      ),
    );

    await run(
      'IMAGE',
      'Image route',
      () => _httpPost(
        name: 'Image route',
        category: 'IMAGE',
        path: '/v1/image',
        body: {
          'prompt': 'diagnostic test',
        },
      ),
    );

    await run(
      'NEWS',
      'News route',
      () => _httpGet(
        name: 'News route',
        category: 'NEWS',
        path: '/v1/news',
      ),
    );

    await run(
      'QURAN',
      'Quran route',
      () => _httpGet(
        name: 'Quran route',
        category: 'QURAN',
        path: '/v1/audio/quran',
      ),
    );

    await run(
      'TAFSIR',
      'Tafsir route',
      () => _httpGet(
        name: 'Tafsir route',
        category: 'TAFSIR',
        path: '/v1/audio/tafsir',
      ),
    );

    await run(
      'HADITH',
      'Hadith route',
      () => _httpGet(
        name: 'Hadith route',
        category: 'HADITH',
        path: '/v1/audio/hadith',
      ),
    );

    await run(
      'RADIO',
      'Radio countries',
      () => _httpGet(
        name: 'Radio countries',
        category: 'RADIO',
        path: '/v1/radio/countries',
      ),
    );

    await run(
      'RADIO',
      'Egypt radio stations',
      () => _httpGet(
        name: 'Egypt radio stations',
        category: 'RADIO',
        path: '/v1/radio/stations?country=EG',
      ),
    );

    await run(
      'AUDIO',
      'Audio search route',
      () => _httpGet(
        name: 'Audio search route',
        category: 'AUDIO',
        path: '/v1/audio/search-v4?q=diagnostic',
      ),
    );

    await run(
      'SHORTS',
      'Shorts route',
      () => _httpGet(
        name: 'Shorts route',
        category: 'SHORTS',
        path: '/v1/shorts',
      ),
    );

    await run(
      'DOWNLOAD',
      'Download route',
      () => _httpGet(
        name: 'Download route',
        category: 'DOWNLOAD',
        path: '/download',
      ),
    );

    await run(
      'MEDIA',
      'Media URL handling',
      _checkMediaUrlHandling,
    );

    await run(
      'MONETIZATION',
      'Monetization endpoint',
      _checkMonetization,
    );

    await run(
      'ERRORS',
      'HTTP error classification',
      _checkErrorClassification,
    );

    await run(
      'TIMEOUT',
      'Timeout handling',
      _checkTimeoutConfiguration,
    );

    final finished = DateTime.now();

    return AppDiagnosticsReport(
      startedAt: started,
      finishedAt: finished,
      results: results,
    );
  }

  Future<DiagnosticResult> _checkRuntimeIdentity() async {
    final stopwatch = Stopwatch()..start();

    final info = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'debugMode': kDebugMode,
      'profileMode': kProfileMode,
      'releaseMode': kReleaseMode,
      'worker': workerBaseUrl,
    };

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      status: 'OK',
      details: jsonEncode(info),
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkInternet() async {
    final stopwatch = Stopwatch()..start();

    try {
      final addresses = await InternetAddress.lookup(
        'example.com',
      );

      stopwatch.stop();

      if (addresses.isEmpty) {
        return DiagnosticResult(
          name: 'Internet connectivity',
          category: 'NETWORK',
          success: false,
          status: 'NO_ADDRESS',
          details: 'DNS returned no address.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: true,
        status: 'OK',
        details: 'Internet/DNS access is available.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: false,
        status: 'FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkDns() async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(workerBaseUrl);
      final addresses = await InternetAddress.lookup(uri.host);

      stopwatch.stop();

      return DiagnosticResult(
        name: 'DNS resolution',
        category: 'NETWORK',
        success: addresses.isNotEmpty,
        status: addresses.isNotEmpty ? 'OK' : 'NO_ADDRESS',
        details: addresses.map((e) => e.address).join(', '),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'DNS resolution',
        category: 'NETWORK',
        success: false,
        status: 'FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkTls() async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(workerBaseUrl);

      final client = HttpClient()
        ..connectionTimeout = defaultTimeout;

      try {
        final request = await client.getUrl(uri);
        final response = await request.close();

        stopwatch.stop();

        return DiagnosticResult(
          name: 'TLS / HTTPS',
          category: 'NETWORK',
          success: response.statusCode > 0,
          status: 'HTTP_${response.statusCode}',
          details:
              'HTTPS connection established successfully with ${uri.host}.',
          httpStatus: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'TLS / HTTPS',
        category: 'NETWORK',
        success: false,
        status: 'TLS_FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _httpGet({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    final uri = _buildUri(path);

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout;

    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain, */*',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sa7biAI-Diagnostics/1.0',
      );

      final response = await request.close();
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(defaultTimeout);

      stopwatch.stop();

      final success = response.statusCode >= 200 &&
          response.statusCode < 400;

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        status: 'HTTP_${response.statusCode}',
        details: _summarizeBody(body),
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult> _httpPost({
    required String name,
    required String category,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final stopwatch = Stopwatch()..start();

    final uri = _buildUri(path);

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout;

    try {
      final request = await client.postUrl(uri);

      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain, */*',
      );

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sa7biAI-Diagnostics/1.0',
      );

      request.write(jsonEncode(body));

      final response = await request.close();

      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(defaultTimeout);

      stopwatch.stop();

      final success = response.statusCode >= 200 &&
          response.statusCode < 400;

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        status: 'HTTP_${response.statusCode}',
        details: _summarizeBody(responseBody),
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult> _checkMediaUrlHandling() async {
    final stopwatch = Stopwatch()..start();

    try {
      final testUrls = <String>[
        workerBaseUrl,
        '$workerBaseUrl/health',
      ];

      final parsed = <String>[];

      for (final value in testUrls) {
        final uri = Uri.tryParse(value);

        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          stopwatch.stop();

          return DiagnosticResult(
            name: 'Media URL handling',
            category: 'MEDIA',
            success: false,
            status: 'INVALID_URL',
            details: 'Invalid media/base URL: $value',
            durationMs: stopwatch.elapsedMilliseconds,
          );
        }

        parsed.add(uri.toString());
      }

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: true,
        status: 'OK',
        details: 'URL parsing works for ${parsed.length} URLs.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        status: 'FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkMonetization() async {
    final stopwatch = Stopwatch()..start();

    final candidates = <String>[
      '/v1/credits',
      '/v1/monetization',
      '/v1/rewards',
    ];

    final statuses = <String>[];

    for (final path in candidates) {
      try {
        final result = await _httpGet(
          name: 'Monetization probe',
          category: 'MONETIZATION',
          path: path,
        );

        statuses.add(
          '$path=${result.status}${result.httpStatus != null ? '(${result.httpStatus})' : ''}',
        );

        if (result.httpStatus != null &&
            result.httpStatus! >= 200 &&
            result.httpStatus! < 400) {
          stopwatch.stop();

          return DiagnosticResult(
            name: 'Monetization endpoint',
            category: 'MONETIZATION',
            success: true,
            status: result.status,
            details: statuses.join(' | '),
            httpStatus: result.httpStatus,
            durationMs: stopwatch.elapsedMilliseconds,
          );
        }
      } catch (e) {
        statuses.add('$path=${_safeError(e)}');
      }
    }

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Monetization endpoint',
      category: 'MONETIZATION',
      success: false,
      status: 'NOT_CONFIRMED',
      details:
          'No known monetization endpoint was confirmed. ${statuses.join(' | ')}',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkErrorClassification() async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _httpGet(
        name: 'HTTP error classification',
        category: 'ERRORS',
        path: '/__sa7bi_diagnostic_missing_endpoint__',
      );

      stopwatch.stop();

      final validClassification =
          result.httpStatus == 404 ||
              result.status == 'HTTP_404';

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: validClassification,
        status: result.status,
        details:
            'Diagnostic intentionally requested a missing endpoint. '
            'Expected a controlled HTTP error such as 404.',
        httpStatus: result.httpStatus,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: false,
        status: 'EXCEPTION',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkTimeoutConfiguration() async {
    final stopwatch = Stopwatch()..start();

    final valid = defaultTimeout.inSeconds >= 5 &&
        defaultTimeout.inSeconds <= 60;

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Timeout configuration',
      category: 'TIMEOUT',
      success: valid,
      status: valid ? 'OK' : 'INVALID',
      details:
          'Diagnostic network timeout = ${defaultTimeout.inSeconds} seconds.',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Uri _buildUri(String path) {
    final base = Uri.parse(workerBaseUrl);

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return base.replace(
      path: normalizedPath,
      queryParameters: _extractQueryParameters(normalizedPath),
    );
  }

  Map<String, String>? _extractQueryParameters(String path) {
    final index = path.indexOf('?');

    if (index == -1) {
      return null;
    }

    final query = path.substring(index + 1);

    return Uri.splitQueryString(query);
  }

  String _summarizeBody(String body) {
    if (body.isEmpty) {
      return 'Empty response body.';
    }

    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length <= 800) {
      return cleaned;
    }

    return '${cleaned.substring(0, 800)}…';
  }

  String _classifyException(Object error) {
    final value = error.toString().toLowerCase();

    if (value.contains('timeout')) {
      return 'TIMEOUT';
    }

    if (value.contains('socket')) {
      return 'SOCKET_ERROR';
    }

    if (value.contains('certificate') ||
        value.contains('tls') ||
        value.contains('ssl')) {
      return 'TLS_ERROR';
    }

    if (value.contains('failed host lookup') ||
        value.contains('dns')) {
      return 'DNS_ERROR';
    }

    return 'NETWORK_ERROR';
  }

  String _safeError(Object error) {
    return error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
