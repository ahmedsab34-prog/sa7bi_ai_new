import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sa7bi_network_client.dart';

part 'diagnostics/app_diagnostics_models.dart';
part 'diagnostics/app_diagnostics_network.dart';
part 'diagnostics/app_diagnostics_content.dart';
part 'diagnostics/app_diagnostics_storage.dart';

class AppDiagnosticsService {
  AppDiagnosticsService({
    this.workerBaseUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  });

  final String workerBaseUrl;

  static const Duration defaultTimeout =
      Duration(seconds: 15);

  static const Duration deepTimeout =
      Duration(seconds: 8);

  static const String diagnosticVersion =
      '4.3.0';

  static const String buildId =
      String.fromEnvironment(
    'APP_BUILD_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String sourceId =
      String.fromEnvironment(
    'APP_SOURCE_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String appVersion =
      String.fromEnvironment(
    'SA7BI_APP_VERSION',
    defaultValue: 'NOT_INJECTED',
  );

  static const String buildNumber =
      String.fromEnvironment(
    'SA7BI_BUILD_NUMBER',
    defaultValue: 'NOT_INJECTED',
  );

  static const String commitSha =
      String.fromEnvironment(
    'SA7BI_COMMIT_SHA',
    defaultValue: 'NOT_INJECTED',
  );

  // ============================================================
  // FULL DIAGNOSTICS
  // ============================================================

  Future<AppDiagnosticsReport> runFullDiagnostics({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    final startedAt = DateTime.now();
    final results = <DiagnosticResult>[];

    Future<void> run(
      String category,
      String name,
      Future<DiagnosticResult> Function() test,
    ) async {
      final stopwatch = Stopwatch()..start();

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
      } catch (error) {
        result = DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: _classifyException(error),
          details: _safeError(error),
          durationMs:
              stopwatch.elapsedMilliseconds,
        );
      }

      stopwatch.stop();

      if (result.durationMs <= 0) {
        result = DiagnosticResult(
          name: result.name,
          category: result.category,
          success: result.success,
          status: result.status,
          details: result.details,
          httpStatus: result.httpStatus,
          durationMs:
              stopwatch.elapsedMilliseconds,
          severity: result.severity,
          repairable: result.repairable,
          blocked: result.blocked,
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

    // NETWORK

    await run(
      'NETWORK',
      'Network transport identity',
      _checkNetworkTransportIdentity,
    );

    await run(
      'NETWORK',
      'Internet HTTPS control',
      _checkInternetHttps,
    );

    await run(
      'NETWORK',
      'Network speed and stability',
      _checkNetworkQuality,
    );

    await run(
      'NETWORK',
      'Worker DNS resolution',
      _checkDns,
    );

    await run(
      'NETWORK',
      'Worker HTTPS health',
      _checkWorkerHttpsHealth,
    );

    await run(
      'NETWORK',
      'HTTP error classification',
      _checkErrorClassification,
    );

    await run(
      'NETWORK',
      'Network timeout configuration',
      _checkTimeoutConfiguration,
    );

    // LOCAL STORAGE / OFFLINE FOUNDATION

    await run(
      'OFFLINE',
      'Local storage write/read/delete',
      _checkLocalStorageRoundTrip,
    );

    // DEVICE

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

    await run(
      'DEVICE',
      'Network interfaces',
      _checkNetworkInterfaces,
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

    // AI: route reachability only; no paid generation.

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

    // MEDIA

    await run(
      'MEDIA',
      'Media URL handling',
      _checkMediaUrlHandling,
    );

    // MONETIZATION

    await run(
      'MONETIZATION',
      'Monetization endpoints',
      _checkMonetization,
    );

    return AppDiagnosticsReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      results: results,
    );
  }

  // ============================================================
  // NETWORK QUALITY
  // ============================================================

  Future<DiagnosticResult> _checkNetworkQuality() async {
    const probeUrl =
        'https://www.cloudflare.com/cdn-cgi/trace';
    const sampleCount = 3;
    const perSampleTimeout =
        Duration(seconds: 4);

    final latencies = <int>[];
    final httpStatuses = <int>[];
    final errors = <String>[];
    final overall = Stopwatch()..start();

    for (var i = 0; i < sampleCount; i++) {
      final sample = Stopwatch()..start();

      try {
        final response =
            await Sa7biNetworkClient.client
                .get(
          Uri.parse(probeUrl),
          headers: const {
            'Accept': 'text/plain',
            'Cache-Control': 'no-cache',
          },
        ).timeout(perSampleTimeout);

        sample.stop();
        latencies.add(
          sample.elapsedMilliseconds,
        );
        httpStatuses.add(response.statusCode);
      } catch (error) {
        sample.stop();
        errors.add(_classifyException(error));
      }
    }

    overall.stop();

    final successCount = latencies.length;
    final failureCount = errors.length;

    final averageMs = successCount == 0
        ? null
        : (latencies.reduce((a, b) => a + b) /
                successCount)
            .round();

    final minMs = successCount == 0
        ? null
        : latencies.reduce(
            (a, b) => a < b ? a : b,
          );

    final maxMs = successCount == 0
        ? null
        : latencies.reduce(
            (a, b) => a > b ? a : b,
          );

    final spreadMs =
        minMs == null || maxMs == null
            ? null
            : maxMs - minMs;

    final serverErrorCount =
        httpStatuses.where(
      (status) => status >= 500,
    ).length;

    final isUnreliable = successCount < 2;
    final isSlow =
        averageMs != null && averageMs >= 2000;
    final isUnstable =
        spreadMs != null && spreadMs >= 1500;
    final hasServerErrors = serverErrorCount > 0;

    final success = !isUnreliable &&
        averageMs != null &&
        averageMs < 3500 &&
        !hasServerErrors;

    final severity = isUnreliable
        ? 'FAIL'
        : (
            isSlow ||
                    isUnstable ||
                    failureCount > 0 ||
                    hasServerErrors
                ? 'WARN'
                : 'PASS'
          );

    final status = isUnreliable
        ? 'NETWORK_UNRELIABLE'
        : (
            isSlow
                ? 'NETWORK_SLOW'
                : (
                    isUnstable || failureCount > 0
                        ? 'NETWORK_UNSTABLE'
                        : (
                            hasServerErrors
                                ? 'CONTROL_SERVER_ERROR'
                                : 'NETWORK_OK'
                          )
                  )
          );

    final advice = isUnreliable
        ? 'نجح أقل من اختبارين. جرّب تبديل الواي فاي '
            'وبيانات الهاتف، ثم أعد الفحص.'
        : (
            isSlow
                ? 'الاستجابة بطيئة. أوقف تنزيلات الخلفية، '
                    'وقرّب الجهاز من الراوتر أو جرّب بيانات الهاتف.'
                : (
                    isUnstable || failureCount > 0
                        ? 'الاتصال متذبذب. أعد الاختبار على الشبكة '
                            'نفسها ثم قارن بالشبكة الأخرى.'
                        : (
                            hasServerErrors
                                ? 'تم الوصول إلى خادم الاختبار لكنه '
                                    'أعاد خطأ خادم؛ أعد المحاولة لاحقًا.'
                                : 'زمن الاستجابة وثبات الاختبارات '
                                    'ضمن الحدود المقبولة.'
                          )
                  )
          );

    final details = <String>[
      'Probe=Cloudflare HTTPS control',
      'samples=$sampleCount',
      'responses=$successCount',
      'transportFailures=$failureCount',
      'latencyMs=${latencies.isEmpty ? 'none' : latencies.join(',')}',
      'averageMs=${averageMs ?? 'none'}',
      'spreadMs=${spreadMs ?? 'none'}',
      'httpStatuses=${httpStatuses.isEmpty ? 'none' : httpStatuses.join(',')}',
      if (errors.isNotEmpty)
        'errors=${errors.join(',')}',
      advice,
    ].join('; ');

    return DiagnosticResult(
      name: 'Network speed and stability',
      category: 'NETWORK',
      success: success,
      severity: severity,
      status: status,
      httpStatus:
          httpStatuses.isEmpty ? null : httpStatuses.last,
      details: details,
      durationMs: overall.elapsedMilliseconds,
      repairable: false,
    );
  }

  // ============================================================
  // SAFE REPAIR
  // ============================================================

  Future<DiagnosticRepairResult> repairSafeIssues(
    AppDiagnosticsReport report, {
    bool clearTemporaryFiles = false,
  }) async {
    final actions = <String>[];

    if (clearTemporaryFiles) {
      actions.add(
        'تم تجاهل تنظيف الملفات المؤقتة '
        'حتى لا يتم حذف بيانات التطبيق.',
      );
    }

    final networkFailure =
        report.results.any(
      (item) =>
          item.category == 'NETWORK' &&
          !item.success &&
          !item.blocked,
    );

    if (networkFailure) {
      actions.add(
        'تم تسجيل مشكلة في طبقة الشبكة.',
      );

      actions.add(
        'لا يتم تغيير DNS أو IP أو Proxy '
        'أو إعدادات Cloudflare تلقائيًا.',
      );

      actions.add(
        'يجب إصلاح السبب من طبقة النقل '
        'أو الشبكة الخارجية.',
      );
    }

    if (actions.isEmpty) {
      return const DiagnosticRepairResult(
        success: true,
        changed: false,
        title: 'لا يوجد إصلاح محلي مؤكد',
        details:
            'لم يتم تنفيذ أي تغيير محلي.',
      );
    }

    return DiagnosticRepairResult(
      success: true,
      changed: false,
      title: 'تم تنفيذ التشخيص الآمن',
      details: actions.join('\n'),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Uri _buildUri(String rawPath) {
    final raw = rawPath.trim();

    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      return Uri.parse(raw);
    }

    final base = Uri.parse(workerBaseUrl);

    final parsed = Uri.parse(
      raw.startsWith('/') ? raw : '/$raw',
    );

    return base.replace(
      path: parsed.path,
      queryParameters:
          parsed.queryParameters.isEmpty
              ? null
              : parsed.queryParameters,
    );
  }

  String _statusForHttpCode(
    int statusCode,
  ) {
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

  String _classifyException(
    Object error,
  ) {
    final value =
        error.toString().toLowerCase();

    if (value.contains('timeout')) {
      return 'TIMEOUT';
    }

    if (value.contains('failed host lookup') ||
        value.contains('no address associated')) {
      return 'DNS_ERROR';
    }

    if (value.contains('certificate') ||
        value.contains('tls') ||
        value.contains('ssl')) {
      return 'TLS_ERROR';
    }

    if (value.contains('connection refused')) {
      return 'CONNECTION_REFUSED';
    }

    if (value.contains('network is unreachable')) {
      return 'NETWORK_UNREACHABLE';
    }

    if (value.contains('socket')) {
      return 'SOCKET_ERROR';
    }

    if (error is http.ClientException) {
      return 'HTTP_CLIENT_ERROR';
    }

    return 'NETWORK_ERROR';
  }

  String _safeError(Object error) {
    return error
        .toString()
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  String _summarizeBody(
    String body,
  ) {
    final cleaned = body
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    if (cleaned.isEmpty) {
      return 'Empty response body.';
    }

    if (cleaned.length <= 1000) {
      return cleaned;
    }

    return '${cleaned.substring(0, 1000)}…';
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
