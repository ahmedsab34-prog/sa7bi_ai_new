import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiagnosticResult {
  final String name;
  final String category;
  final bool success;
  final String status;
  final String details;
  final int? httpStatus;
  final int durationMs;
  final String severity;

  const DiagnosticResult({
    required this.name,
    required this.category,
    required this.success,
    required this.status,
    required this.details,
    required this.durationMs,
    this.httpStatus,
    this.severity = 'PASS',
  });

  bool get isWarning => severity == 'WARN';

  bool get isFailure => severity == 'FAIL';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'success': success,
      'severity': severity,
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

  int get passed =>
      results.where((e) => e.severity == 'PASS').length;

  int get warnings =>
      results.where((e) => e.severity == 'WARN').length;

  int get failed =>
      results.where((e) => e.severity == 'FAIL').length;

  int get total => results.length;

  Duration get duration => finishedAt.difference(startedAt);

  String get primaryProblem {
    final failures = results
        .where((e) => e.severity == 'FAIL')
        .toList();

    if (failures.isEmpty) {
      final warnings = results
          .where((e) => e.severity == 'WARN')
          .toList();

      if (warnings.isEmpty) {
        return 'لم يتم اكتشاف مشكلة في الاختبارات الحالية.';
      }

      return warnings.first.details;
    }

    final networkTimeouts = failures
        .where((e) =>
            e.status == 'TIMEOUT' ||
            e.status == 'SOCKET_ERROR' ||
            e.status == 'NETWORK_ERROR')
        .toList();

    if (networkTimeouts.isNotEmpty) {
      return networkTimeouts.first.details;
    }

    return failures.first.details;
  }

  List<DiagnosticResult> get slowestResults {
    final copy = List<DiagnosticResult>.from(results);
    copy.sort(
      (a, b) => b.durationMs.compareTo(a.durationMs),
    );
    return copy.take(5).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'reportVersion': '3.0.0',
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'passed': passed,
      'warnings': warnings,
      'failed': failed,
      'total': total,
      'primaryProblem': primaryProblem,
      'results': results.map((e) => e.toJson()).toList(),
      'slowestTests': slowestResults
          .map((e) => {
                'name': e.name,
                'durationMs': e.durationMs,
                'status': e.status,
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
    buffer.writeln('Report version: 3.0.0');
    buffer.writeln(
      'Started: ${startedAt.toLocal().toIso8601String()}',
    );
    buffer.writeln(
      'Finished: ${finishedAt.toLocal().toIso8601String()}',
    );
    buffer.writeln(
      'Duration: ${duration.inMilliseconds} ms',
    );
    buffer.writeln();

    buffer.writeln('SUMMARY');
    buffer.writeln('Passed: $passed');
    buffer.writeln('Warnings: $warnings');
    buffer.writeln('Failed: $failed');
    buffer.writeln('Total: $total');
    buffer.writeln();

    buffer.writeln('PRIMARY PROBLEM');
    buffer.writeln(primaryProblem);
    buffer.writeln();

    buffer.writeln('RESULTS');
    buffer.writeln('----------------------------------------');

    for (final result in results) {
      buffer.writeln(
        '[${result.severity}] '
        '${result.category} | '
        '${result.name}',
      );
      buffer.writeln('Status: ${result.status}');
      buffer.writeln(
        'HTTP: ${result.httpStatus ?? '-'}',
      );
      buffer.writeln(
        'Duration: ${result.durationMs} ms',
      );
      buffer.writeln('Details: ${result.details}');
      buffer.writeln();
    }

    buffer.writeln('SLOWEST TESTS');
    buffer.writeln('----------------------------------------');

    for (final result in slowestResults) {
      buffer.writeln(
        '${result.durationMs} ms | '
        '${result.status} | '
        '${result.name}',
      );
    }

    buffer.writeln();
    buffer.writeln('========================================');
    buffer.writeln('END OF REPORT');
    buffer.writeln('========================================');

    return buffer.toString();
  }
}

class AppDiagnosticsService {
  AppDiagnosticsService({
    this.workerBaseUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  });

  final String workerBaseUrl;

  static const Duration defaultTimeout =
      Duration(seconds: 12);

  static const String diagnosticVersion = '3.0.0';

  static const String buildId = String.fromEnvironment(
    'APP_BUILD_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String sourceId = String.fromEnvironment(
    'APP_SOURCE_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String appVersion = String.fromEnvironment(
    'SA7BI_APP_VERSION',
    defaultValue: 'NOT_INJECTED',
  );

  static const String buildNumber = String.fromEnvironment(
    'SA7BI_BUILD_NUMBER',
    defaultValue: 'NOT_INJECTED',
  );

  static const String commitSha = String.fromEnvironment(
    'SA7BI_COMMIT_SHA',
    defaultValue: 'NOT_INJECTED',
  );

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
              severity: 'FAIL',
              status: 'TIMEOUT',
              details:
                  'الاختبار تجاوز مهلة '
                  '${defaultTimeout.inSeconds} ثانية.',
              durationMs:
                  defaultTimeout.inMilliseconds,
            );
          },
        );
      } catch (e) {
        result = DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: 'EXCEPTION',
          details: _safeError(e),
          durationMs: 0,
        );
      }

      results.add(result);
      onResult?.call(result);
    }

    // BUILD
    await run(
      'BUILD',
      'Runtime identity',
      _checkRuntimeIdentity,
    );

    await run(
      'BUILD',
      'Diagnostic engine identity',
      _checkDiagnosticIdentity,
    );

    await run(
      'BUILD',
      'Build/source identity',
      _checkBuildSourceIdentity,
    );

    // DEVICE / PERFORMANCE
    await run(
      'DEVICE',
      'Runtime memory',
      _checkRuntimeMemory,
    );

    await run(
      'DEVICE',
      'Temporary storage',
      _checkTemporaryStorage,
    );

    // NETWORK
    await run(
      'NETWORK',
      'Internet connectivity',
      _checkInternet,
    );

    await run(
      'NETWORK',
      'Worker DNS resolution',
      _checkDns,
    );

    await run(
      'NETWORK',
      'Raw HttpClient HTTPS → Google',
      _checkRawHttpClientGoogle,
    );

    await run(
      'NETWORK',
      'package:http HTTPS → Google',
      _checkPackageHttpGoogle,
    );

    await run(
      'NETWORK',
      'Cloudflare HTTPS',
      _checkCloudflare,
    );

    await run(
      'NETWORK',
      'package:http HTTPS → Worker health',
      _checkPackageHttpWorkerHealth,
    );

    await run(
      'NETWORK',
      'Raw TLS / HTTPS → Worker',
      _checkTls,
    );

    // WORKER
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
      'WORKER',
      'Worker service status',
      () => _httpGet(
        name: 'Worker service status',
        category: 'WORKER',
        path: '/v1/service-status',
      ),
    );

    // AI
    await run(
      'AI',
      'AI chat route',
      () => _probeRoute(
        name: 'AI chat route',
        category: 'AI',
        path: '/v1/chat',
      ),
    );

    await run(
      'AI',
      'AI credits route',
      () => _httpGet(
        name: 'AI credits route',
        category: 'AI',
        path: '/v1/credits',
      ),
    );

    // IMAGE
    await run(
      'IMAGE',
      'Image route',
      () => _probeRoute(
        name: 'Image route',
        category: 'IMAGE',
        path: '/v1/image',
      ),
    );

    // CONTENT
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
        path: '/v1/tafsir',
      ),
    );

    await run(
      'TAFSIR',
      'Tafsir books',
      () => _httpGet(
        name: 'Tafsir books',
        category: 'TAFSIR',
        path: '/v1/tafsir/books',
      ),
    );

    await run(
      'HADITH',
      'Hadith route',
      () => _httpGet(
        name: 'Hadith route',
        category: 'HADITH',
        path: '/v1/hadith',
      ),
    );

    await run(
      'HADITH',
      'Hadith books',
      () => _httpGet(
        name: 'Hadith books',
        category: 'HADITH',
        path: '/v1/hadith/books',
      ),
    );

    await run(
      'RADIO',
      'Radio health',
      () => _httpGet(
        name: 'Radio health',
        category: 'RADIO',
        path: '/v1/radio/health',
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
      'PODCAST',
      'Podcast search route',
      () => _httpGet(
        name: 'Podcast search route',
        category: 'PODCAST',
        path: '/v1/podcasts/search?q=diagnostic',
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

    // MEDIA / DOWNLOAD
    await run(
      'MEDIA',
      'Media URL handling',
      _checkMediaUrlHandling,
    );

    await run(
      'DOWNLOAD',
      'Download health',
      () => _httpGet(
        name: 'Download health',
        category: 'DOWNLOAD',
        path: '/download/health',
      ),
    );

    // MONETIZATION
    await run(
      'MONETIZATION',
      'Monetization endpoint',
      _checkMonetization,
    );

    // ERROR HANDLING
    await run(
      'ERRORS',
      'HTTP error classification',
      _checkErrorClassification,
    );

    await run(
      'TIMEOUT',
      'Timeout configuration',
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
      'osVersion': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'debugMode': kDebugMode,
      'profileMode': kProfileMode,
      'releaseMode': kReleaseMode,
      'worker': workerBaseUrl,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'commitSha': commitSha,
    };

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: 'OK',
      details: jsonEncode(info),
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkDiagnosticIdentity() async {
    final stopwatch = Stopwatch()..start();

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Diagnostic engine identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: 'OK',
      details:
          'diagnosticVersion=$diagnosticVersion',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkBuildSourceIdentity() async {
    final stopwatch = Stopwatch()..start();

    final injected = <String, String>{
      'APP_BUILD_ID': buildId,
      'APP_SOURCE_ID': sourceId,
      'SA7BI_APP_VERSION': appVersion,
      'SA7BI_BUILD_NUMBER': buildNumber,
      'SA7BI_COMMIT_SHA': commitSha,
    };

    final known = injected.values.any(
      (value) => value != 'NOT_INJECTED',
    );

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: known,
      severity: known ? 'PASS' : 'WARN',
      status: known ? 'IDENTIFIED' : 'NOT_INJECTED',
      details: jsonEncode(injected),
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkRuntimeMemory() async {
    final stopwatch = Stopwatch()..start();

    try {
      final rss = ProcessInfo.currentRss;

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Runtime memory',
        category: 'DEVICE',
        success: rss > 0,
        severity: rss > 0 ? 'PASS' : 'WARN',
        status: rss > 0 ? 'OK' : 'UNAVAILABLE',
        details:
            'Current Dart VM RSS: '
            '${_formatBytes(rss)}.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Runtime memory',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkTemporaryStorage() async {
    final stopwatch = Stopwatch()..start();

    try {
      final directory = Directory.systemTemp;

      if (!await directory.exists()) {
        stopwatch.stop();

        return DiagnosticResult(
          name: 'Temporary storage',
          category: 'DEVICE',
          success: false,
          severity: 'WARN',
          status: 'UNAVAILABLE',
          details: 'System temporary directory is unavailable.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      var totalBytes = 0;
      var fileCount = 0;

      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (fileCount >= 2000) {
          break;
        }

        if (entity is File) {
          try {
            totalBytes += await entity.length();
            fileCount++;
          } catch (_) {
            // Ignore inaccessible temporary files.
          }
        }
      }

      stopwatch.stop();

      final limited = fileCount >= 2000;

      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: true,
        severity: limited ? 'WARN' : 'PASS',
        status: limited ? 'SCAN_LIMIT_REACHED' : 'OK',
        details:
            'Accessible temporary files: $fileCount. '
            'Approximate size: ${_formatBytes(totalBytes)}.'
            '${limited ? ' Scan capped at 2000 files.' : ''}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkInternet() async {
    final stopwatch = Stopwatch()..start();

    try {
      final addresses =
          await InternetAddress.lookup('example.com');

      stopwatch.stop();

      final ok = addresses.isNotEmpty;

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: ok ? 'OK' : 'NO_ADDRESS',
        details: ok
            ? 'Internet/DNS access is available.'
            : 'DNS returned no address.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
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
      final addresses =
          await InternetAddress.lookup(uri.host);

      stopwatch.stop();

      final ok = addresses.isNotEmpty;

      return DiagnosticResult(
        name: 'Worker DNS resolution',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: ok ? 'OK' : 'NO_ADDRESS',
        details: addresses
            .map((e) => e.address)
            .join(', '),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Worker DNS resolution',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: 'DNS_ERROR',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkRawHttpClientGoogle() async {
    final stopwatch = Stopwatch()..start();

    final uri = Uri.parse('https://www.google.com');

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout;

    try {
      final request = await client.getUrl(uri);

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sa7biAI-Diagnostics/$diagnosticVersion',
      );

      final response = await request.close();

      await response.drain();

      stopwatch.stop();

      final ok = response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name: 'Raw HttpClient HTTPS → Google',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: _statusForHttpCode(response.statusCode),
        details:
            'Raw dart:io HttpClient reached '
            '${uri.host}.',
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Raw HttpClient HTTPS → Google',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult> _checkPackageHttpGoogle() async {
    final stopwatch = Stopwatch()..start();

    final uri = Uri.parse('https://www.google.com');
    final client = http.Client();

    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept':
                  'text/html,application/xhtml+xml,*/*;q=0.8',
              'User-Agent':
                  'Sa7biAI-Diagnostics/$diagnosticVersion',
            },
          )
          .timeout(defaultTimeout);

      stopwatch.stop();

      final ok = response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name: 'package:http HTTPS → Google',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: _statusForHttpCode(response.statusCode),
        details:
            'package:http reached ${uri.host}. '
            'responseBytes=${response.bodyBytes.length}.',
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'package:http HTTPS → Google',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close();
    }
  }

  Future<DiagnosticResult> _checkCloudflare() async {
    final stopwatch = Stopwatch()..start();

    final client = http.Client();
    final uri = Uri.parse('https://www.cloudflare.com');

    try {
      final response = await client
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Sa7biAI-Diagnostics/$diagnosticVersion',
            },
          )
          .timeout(defaultTimeout);

      stopwatch.stop();

      final ok = response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name: 'Cloudflare HTTPS',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: _statusForHttpCode(response.statusCode),
        details:
            'Cloudflare HTTPS response received.',
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Cloudflare HTTPS',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close();
    }
  }

  Future<DiagnosticResult> _checkPackageHttpWorkerHealth() async {
    final stopwatch = Stopwatch()..start();

    final uri = _buildUri('/health');
    final client = http.Client();

    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept':
                  'application/json,text/plain,*/*',
              'User-Agent':
                  'Sa7biAI-Diagnostics/$diagnosticVersion',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(defaultTimeout);

      stopwatch.stop();

      final ok = response.statusCode >= 200 &&
          response.statusCode < 400;

      return DiagnosticResult(
        name: 'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: _statusForHttpCode(response.statusCode),
        details:
            'Worker /health body: '
            '${_summarizeBody(response.body)}',
        httpStatus: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details:
            'package:http could not reach Worker /health. '
            '${_safeError(e)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close();
    }
  }

  Future<DiagnosticResult> _checkTls() async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(workerBaseUrl);

      if (uri.scheme.toLowerCase() != 'https') {
        stopwatch.stop();

        return DiagnosticResult(
          name: 'Raw TLS / HTTPS → Worker',
          category: 'NETWORK',
          success: false,
          severity: 'FAIL',
          status: 'NOT_HTTPS',
          details: 'Worker URL is not HTTPS.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final client = HttpClient()
        ..connectionTimeout = defaultTimeout;

      try {
        final request = await client.getUrl(uri);

        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Sa7biAI-Diagnostics/$diagnosticVersion',
        );

        final response = await request.close();

        await response.drain();

        stopwatch.stop();

        return DiagnosticResult(
          name: 'Raw TLS / HTTPS → Worker',
          category: 'NETWORK',
          success: true,
          severity: 'PASS',
          status: 'HTTP_${response.statusCode}',
          details:
              'HTTPS connection established with '
              '${uri.host}.',
          httpStatus: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Raw TLS / HTTPS → Worker',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: 'TLS_FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _probeRoute({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    final options = await _httpOptions(
      name: name,
      category: category,
      path: path,
    );

    if (_routeExistsFromStatus(options.httpStatus)) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: true,
        severity: 'PASS',
        status: _routeProbeStatus(options.httpStatus),
        details:
            'Route reachable using OPTIONS. '
            'No real AI/image generation executed.',
        httpStatus: options.httpStatus,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final getResult = await _httpGet(
      name: name,
      category: category,
      path: path,
    );

    stopwatch.stop();

    if (_routeExistsFromStatus(getResult.httpStatus)) {
      return DiagnosticResult(
        name: name,
        category: category,
        success: true,
        severity: 'PASS',
        status: _routeProbeStatus(
          getResult.httpStatus,
        ),
        details:
            'Route reachable without executing '
            'generation.',
        httpStatus: getResult.httpStatus,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (getResult.httpStatus == 404) {
      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: 'ROUTE_NOT_FOUND',
        details:
            'Route returned HTTP 404. '
            'No generation executed.',
        httpStatus: 404,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    return DiagnosticResult(
      name: name,
      category: category,
      success: false,
      severity: 'FAIL',
      status: getResult.status,
      details:
          'OPTIONS=${options.status}; '
          'GET=${getResult.status}. '
          'No generation executed.',
      httpStatus:
          getResult.httpStatus ?? options.httpStatus,
      durationMs: stopwatch.elapsedMilliseconds,
    );
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
        'Sa7biAI-Diagnostics/$diagnosticVersion',
      );

      request.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache',
      );

      final response = await request.close();

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(defaultTimeout);

      stopwatch.stop();

      final ok = response.statusCode >= 200 &&
          response.statusCode < 400;

      final authRoute = response.statusCode == 401 ||
          response.statusCode == 403;

      return DiagnosticResult(
        name: name,
        category: category,
        success: ok || authRoute,
        severity:
            ok || authRoute ? 'PASS' : 'FAIL',
        status: _statusForHttpCode(response.statusCode),
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
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult> _httpOptions({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    final uri = _buildUri(path);

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout;

    try {
      final request = await client.openUrl(
        'OPTIONS',
        uri,
      );

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sa7biAI-Diagnostics/$diagnosticVersion',
      );

      final response = await request.close();

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(defaultTimeout);

      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success:
            _routeExistsFromStatus(response.statusCode),
        severity:
            _routeExistsFromStatus(response.statusCode)
                ? 'PASS'
                : 'FAIL',
        status: _statusForHttpCode(
          response.statusCode,
        ),
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
        severity: 'FAIL',
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
      final urls = <String>[
        workerBaseUrl,
        '$workerBaseUrl/health',
        '$workerBaseUrl/v1/radio/stations?country=EG',
        '$workerBaseUrl/v1/audio/search-v4?q=diagnostic',
        '$workerBaseUrl/v1/podcasts/search?q=diagnostic',
      ];

      for (final value in urls) {
        final uri = Uri.tryParse(value);

        if (uri == null ||
            !uri.hasScheme ||
            uri.host.isEmpty) {
          stopwatch.stop();

          return DiagnosticResult(
            name: 'Media URL handling',
            category: 'MEDIA',
            success: false,
            severity: 'FAIL',
            status: 'INVALID_URL',
            details: 'Invalid URL: $value',
            durationMs:
                stopwatch.elapsedMilliseconds,
          );
        }
      }

      final radioUri = _buildUri(
        '/v1/radio/stations?country=EG',
      );

      final audioUri = _buildUri(
        '/v1/audio/search-v4?q=diagnostic',
      );

      final podcastUri = _buildUri(
        '/v1/podcasts/search?q=diagnostic',
      );

      final ok =
          radioUri.queryParameters['country'] == 'EG' &&
              audioUri.queryParameters['q'] == 'diagnostic' &&
              podcastUri.queryParameters['q'] ==
                  'diagnostic';

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: ok,
        severity: ok ? 'PASS' : 'FAIL',
        status: ok ? 'OK' : 'QUERY_BUILD_FAILED',
        details:
            'URL parsing and query handling verified. '
            'country=${radioUri.queryParameters['country']}, '
            'audioQ=${audioUri.queryParameters['q']}, '
            'podcastQ=${podcastUri.queryParameters['q']}.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        severity: 'FAIL',
        status: 'FAILED',
        details: _safeError(e),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkMonetization() async {
    final stopwatch = Stopwatch()..start();

    final candidates = <String>[
      '/v1/monetization',
      '/v1/credits',
    ];

    final statuses = <String>[];

    for (final path in candidates) {
      final result = await _httpGet(
        name: 'Monetization probe',
        category: 'MONETIZATION',
        path: path,
      );

      statuses.add(
        '$path=${result.status}'
        '${result.httpStatus != null ? '(${result.httpStatus})' : ''}',
      );

      if (result.httpStatus != null &&
          result.httpStatus! >= 200 &&
          result.httpStatus! < 400) {
        stopwatch.stop();

        return DiagnosticResult(
          name: 'Monetization endpoint',
          category: 'MONETIZATION',
          success: true,
          severity: 'PASS',
          status: 'CONFIRMED',
          details: statuses.join(' | '),
          httpStatus: result.httpStatus,
          durationMs:
              stopwatch.elapsedMilliseconds,
        );
      }

      if (result.httpStatus == 401 ||
          result.httpStatus == 403) {
        stopwatch.stop();

        return DiagnosticResult(
          name: 'Monetization endpoint',
          category: 'MONETIZATION',
          success: true,
          severity: 'WARN',
          status: 'AUTH_REQUIRED',
          details: statuses.join(' | '),
          httpStatus: result.httpStatus,
          durationMs:
              stopwatch.elapsedMilliseconds,
        );
      }
    }

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Monetization endpoint',
      category: 'MONETIZATION',
      success: false,
      severity: 'FAIL',
      status: 'NOT_CONFIRMED',
      details: statuses.join(' | '),
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkErrorClassification() async {
    final stopwatch = Stopwatch()..start();

    final result = await _httpGet(
      name: 'HTTP error classification',
      category: 'ERRORS',
      path: '/__sa7bi_diagnostic_missing_endpoint__',
    );

    stopwatch.stop();

    final ok = result.httpStatus == 404;

    return DiagnosticResult(
      name: 'HTTP error classification',
      category: 'ERRORS',
      success: ok,
      severity: ok ? 'PASS' : 'FAIL',
      status: ok ? 'CONTROLLED_404' : result.status,
      details:
          'Expected controlled HTTP 404 from an intentionally '
          'missing endpoint.',
      httpStatus: result.httpStatus,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<DiagnosticResult> _checkTimeoutConfiguration() async {
    final stopwatch = Stopwatch()..start();

    final valid =
        defaultTimeout.inSeconds >= 5 &&
        defaultTimeout.inSeconds <= 60;

    stopwatch.stop();

    return DiagnosticResult(
      name: 'Timeout configuration',
      category: 'TIMEOUT',
      success: valid,
      severity: valid ? 'PASS' : 'FAIL',
      status: valid ? 'OK' : 'INVALID',
      details:
          'Diagnostic timeout = '
          '${defaultTimeout.inSeconds} seconds.',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Uri _buildUri(String rawPath) {
    final raw = rawPath.trim();

    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      return Uri.parse(raw);
    }

    final base = Uri.parse(workerBaseUrl);

    final normalized =
        raw.startsWith('/') ? raw : '/$raw';

    final parsed = Uri.parse(normalized);

    return base.replace(
      path: parsed.path,
      queryParameters:
          parsed.queryParameters.isEmpty
              ? null
              : parsed.queryParameters,
    );
  }

  bool _routeExistsFromStatus(int? status) {
    if (status == null) {
      return false;
    }

    if (status >= 200 && status < 400) {
      return true;
    }

    if (status == 401 ||
        status == 403 ||
        status == 405) {
      return true;
    }

    return false;
  }

  String _routeProbeStatus(int? status) {
    if (status == null) {
      return 'UNKNOWN';
    }

    if (status >= 200 && status < 300) {
      return 'ROUTE_REACHABLE';
    }

    if (status >= 300 && status < 400) {
      return 'ROUTE_REDIRECT';
    }

    if (status == 401) {
      return 'ROUTE_EXISTS_AUTH_REQUIRED';
    }

    if (status == 403) {
      return 'ROUTE_EXISTS_FORBIDDEN';
    }

    if (status == 405) {
      return 'ROUTE_EXISTS_METHOD_REQUIRED';
    }

    if (status == 404) {
      return 'ROUTE_NOT_FOUND';
    }

    if (status >= 500) {
      return 'SERVER_ERROR';
    }

    return 'HTTP_$status';
  }

  String _statusForHttpCode(int statusCode) {
    if (statusCode == 401) {
      return 'HTTP_401_AUTH_REQUIRED';
    }

    if (statusCode == 403) {
      return 'HTTP_403_FORBIDDEN';
    }

    if (statusCode == 404) {
      return 'HTTP_404_NOT_FOUND';
    }

    if (statusCode == 405) {
      return 'HTTP_405_METHOD_NOT_ALLOWED';
    }

    if (statusCode >= 500) {
      return 'HTTP_${statusCode}_SERVER_ERROR';
    }

    if (statusCode >= 400) {
      return 'HTTP_${statusCode}_CLIENT_ERROR';
    }

    if (statusCode >= 300) {
      return 'HTTP_${statusCode}_REDIRECT';
    }

    if (statusCode >= 200) {
      return 'HTTP_${statusCode}_OK';
    }

    return 'HTTP_$statusCode';
  }

  String _summarizeBody(String body) {
    if (body.isEmpty) {
      return 'Empty response body.';
    }

    final cleaned =
        body.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length <= 1000) {
      return cleaned;
    }

    return '${cleaned.substring(0, 1000)}…';
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

    if (value.contains('network is unreachable')) {
      return 'NETWORK_UNREACHABLE';
    }

    if (value.contains('connection refused')) {
      return 'CONNECTION_REFUSED';
    }

    return 'NETWORK_ERROR';
  }

  String _safeError(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
