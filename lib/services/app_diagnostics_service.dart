import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

part 'diagnostics/app_diagnostics_models.dart';
part 'diagnostics/app_diagnostics_network.dart';
part 'diagnostics/app_diagnostics_content.dart';

class AppDiagnosticsService {
  AppDiagnosticsService({
    this.workerBaseUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  });

  final String workerBaseUrl;

  static const Duration defaultTimeout =
      Duration(seconds: 12);

  static const Duration deepTimeout =
      Duration(seconds: 5);

  static const String diagnosticVersion =
      '4.1.0';

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
      DiagnosticResult result;

      final stopwatch = Stopwatch()..start();

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
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      stopwatch.stop();

      if (result.durationMs == 0) {
        result = DiagnosticResult(
          name: result.name,
          category: result.category,
          success: result.success,
          status: result.status,
          details: result.details,
          httpStatus: result.httpStatus,
          durationMs: stopwatch.elapsedMilliseconds,
          severity: result.severity,
          repairable: result.repairable,
        );
      }

      results.add(result);
      onResult?.call(result);
    }

    // ============================================================
    // BUILD
    // ============================================================

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

    // ============================================================
    // DEVICE
    // ============================================================

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

    // ============================================================
    // NETWORK
    // ============================================================

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
      'Worker IPv4 DNS',
      _checkDnsV4,
    );

    await run(
      'NETWORK',
      'Worker IPv6 DNS',
      _checkDnsV6,
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
      'HTTP proxy configuration',
      _checkProxyConfiguration,
    );

    await run(
      'NETWORK',
      'Worker IPv4 socket reachability',
      _checkWorkerIpv4Socket,
    );

    await run(
      'NETWORK',
      'Worker IPv6 socket reachability',
      _checkWorkerIpv6Socket,
    );

    await run(
      'NETWORK',
      'Worker HTTPS via resolved IPv4',
      _checkWorkerHttpsViaIp4,
    );

    await run(
      'NETWORK',
      'Worker HTTPS via resolved IPv6',
      _checkWorkerHttpsViaIp6,
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

    // ============================================================
    // WORKER
    // ============================================================

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

    // ============================================================
    // AI
    // ============================================================

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

    // ============================================================
    // CONTENT
    // ============================================================

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

    // ============================================================
    // MEDIA / MONETIZATION / ERRORS
    // ============================================================

    await run(
      'MEDIA',
      'Media URL handling',
      _checkMediaUrlHandling,
    );

    await run(
      'MONETIZATION',
      'Monetization endpoints',
      _checkMonetization,
    );

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

    return AppDiagnosticsReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      results: results,
    );
  }

  Future<DiagnosticRepairResult> repairSafeIssues(
    AppDiagnosticsReport report, {
    bool clearTemporaryFiles = false,
  }) async {
    final actions = <String>[];
    var changed = false;

    // متعمدين عدم حذف Directory.systemTemp بالكامل.
    // ده كان إصلاحًا خطرًا لأنه ممكن يمس ملفات تخص مكتبات
    // أو عمليات أخرى داخل النظام.
    if (clearTemporaryFiles) {
      actions.add(
        'تم تجاهل تنظيف systemTemp بالكامل '
        'لأسباب تتعلق بسلامة التطبيق.',
      );
    }

    final networkFailure = report.results.any(
      (item) =>
          item.category == 'NETWORK' &&
          !item.success &&
          (
            item.status == 'TIMEOUT' ||
            item.status == 'SOCKET_ERROR' ||
            item.status == 'NETWORK_ERROR' ||
            item.status == 'DNS_ERROR' ||
            item.status == 'NETWORK_UNREACHABLE'
          ),
    );

    if (networkFailure) {
      try {
        await InternetAddress.lookup(
          Uri.parse(workerBaseUrl).host,
        );

        actions.add(
          'تمت إعادة حل DNS للـWorker بنجاح.',
        );

        actions.add(
          'VPN وISP وFirewall وCloudflare '
          'لا يمكن إصلاحها من داخل APK.',
        );

        changed = true;
      } catch (error) {
        actions.add(
          'إعادة حل DNS فشلت: ${_safeError(error)}',
        );
      }
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
      changed: changed,
      title: changed
          ? 'تم تنفيذ الإصلاح الآمن'
          : 'تم تنفيذ التشخيص الآمن',
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

  String _classifyException(Object error) {
    final value = error.toString().toLowerCase();

    if (value.contains('timeout')) {
      return 'TIMEOUT';
    }

    if (value.contains('network is unreachable')) {
      return 'NETWORK_UNREACHABLE';
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

    if (value.contains('socket')) {
      return 'SOCKET_ERROR';
    }

    return 'NETWORK_ERROR';
  }

  String _safeError(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _summarizeBody(String body) {
    final cleaned = body
        .replaceAll(RegExp(r'\s+'), ' ')
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
