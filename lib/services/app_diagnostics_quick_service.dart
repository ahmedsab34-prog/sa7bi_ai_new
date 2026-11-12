import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_diagnostics_service.dart';
import 'app_performance_diagnostics_service.dart';
import 'sa7bi_network_client.dart';

class AppDiagnosticsQuickService {
  AppDiagnosticsQuickService({
    http.Client? client,
    String? buildId,
    String? sourceId,
    String? commitSha,
    String? appVersion,
    String? buildNumber,
    this.primaryWorkerUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
    this.fallbackWorkerUrl =
        'https://sa7bi-ai-new-fallback.ahmedsab34.workers.dev',
  })  : _clientOverride = client,
        _buildId = buildId ?? AppDiagnosticsService.buildId,
        _sourceId = sourceId ?? AppDiagnosticsService.sourceId,
        _commitSha = commitSha ?? AppDiagnosticsService.commitSha,
        _appVersion = appVersion ?? AppDiagnosticsService.appVersion,
        _buildNumber =
            buildNumber ?? AppDiagnosticsService.buildNumber;

  static const Duration checkTimeout = Duration(seconds: 8);

  final http.Client? _clientOverride;

  final String _buildId;
  final String _sourceId;
  final String _commitSha;
  final String _appVersion;
  final String _buildNumber;

  final String primaryWorkerUrl;
  final String fallbackWorkerUrl;

  Future<AppDiagnosticsQuickReport> runQuickDiagnostics({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    final startedAt = DateTime.now();
    final results = <DiagnosticResult>[];

    // اتصال HTTP مستقل لاختبار كل Worker مباشرة.
    // لا نستخدم عميل التحويل التلقائي حتى لا يخفي فشل الأساسي.
    final client = _clientOverride ?? http.Client();

    void emit(DiagnosticResult result) {
      results.add(result);
      onResult?.call(result);
    }

    try {
      await _publish(
        results: results,
        onResult: onResult,
        name: 'Build/source metadata',
        category: 'BUILD',
        check: _checkBuildMetadata,
      );

      await _publish(
        results: results,
        onResult: onResult,
        name: 'Network transport identity',
        category: 'NETWORK',
        check: _checkNetworkTransport,
      );

      // ------------------------------------------------------
      // DEVICE AND APP PERFORMANCE
      // ------------------------------------------------------

      final performanceResults =
          await AppPerformanceDiagnosticsService()
              .runQuickChecks(
        onResult: onResult,
      );

      results.addAll(performanceResults);

      // ------------------------------------------------------
      // PRIMARY WORKER
      // ------------------------------------------------------

      final primary = await _probeWorker(
        client: client,
        name: 'Primary Worker direct HTTPS',
        baseUrl: primaryWorkerUrl,
      );

      emit(primary.result);

      await _publish(
        results: results,
        onResult: onResult,
        name: 'Build/source identity',
        category: 'BUILD',
        check: () async => _checkBuildSourceIdentity(primary),
      );

      // ------------------------------------------------------
      // FALLBACK WORKER
      // ------------------------------------------------------

      final fallback = await _probeWorker(
        client: client,
        name: 'Fallback Worker direct HTTPS',
        baseUrl: fallbackWorkerUrl,
      );

      emit(fallback.result);

      // ------------------------------------------------------
      // GENERAL HTTPS
      // ------------------------------------------------------

      await _publish(
        results: results,
        onResult: onResult,
        name: 'Internet HTTPS control',
        category: 'NETWORK',
        check: () => _checkInternetHttps(client),
      );

      return AppDiagnosticsQuickReport(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        results: results,
      );
    } finally {
      if (_clientOverride == null) {
        client.close();
      }
    }
  }

  Future<void> _publish({
    required List<DiagnosticResult> results,
    required void Function(DiagnosticResult result)? onResult,
    required String name,
    required String category,
    required Future<DiagnosticResult> Function() check,
  }) async {
    final stopwatch = Stopwatch()..start();

    DiagnosticResult result;

    try {
      result = await check().timeout(
        checkTimeout,
        onTimeout: () => DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: 'TIMEOUT',
          details:
              'الفحص السريع تجاوز مهلة '
              '${checkTimeout.inSeconds} ثوانٍ.',
          durationMs: checkTimeout.inMilliseconds,
        ),
      );
    } catch (error) {
      result = DiagnosticResult(
        name: name,
        category: category,
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

  Future<DiagnosticResult> _checkBuildMetadata() async {
    final injected = _isInjected(_buildId) &&
        _isInjected(_sourceId) &&
        _isInjected(_commitSha);

    return DiagnosticResult(
      name: 'Build/source metadata',
      category: 'BUILD',
      success: injected,
      severity: injected ? 'PASS' : 'WARN',
      status: injected
          ? 'BUILD_METADATA_INJECTED'
          : 'BUILD_METADATA_NOT_INJECTED',
      details:
          'buildId=$_buildId; '
          'sourceId=$_sourceId; '
          'appVersion=$_appVersion; '
          'buildNumber=$_buildNumber; '
          'commitSha=$_commitSha; '
          'complete=$injected.',
      durationMs: 0,
      blocked: !injected,
    );
  }

  Future<DiagnosticResult> _checkNetworkTransport() async {
    final cronet = Sa7biNetworkClient.isCronet;
    final transport = Sa7biNetworkClient.transportName;

    return DiagnosticResult(
      name: 'Network transport identity',
      category: 'NETWORK',
      success: true,
      severity: cronet ? 'PASS' : 'WARN',
      status: transport,
      details:
          'transport=$transport; '
          'cronet=$cronet; '
          'failoverEnabled=${Sa7biNetworkClient.failoverEnabled}.',
      durationMs: 0,
    );
  }

  Future<_WorkerHealthProbe> _probeWorker({
    required http.Client client,
    required String name,
    required String baseUrl,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = _healthUri(baseUrl);

    try {
      final response = await client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(checkTimeout);

      stopwatch.stop();

      final reachable =
          response.statusCode >= 200 &&
          response.statusCode < 300;

      String workerCommit = '';

      if (reachable) {
        try {
          final decoded = jsonDecode(
            utf8.decode(
              response.bodyBytes,
              allowMalformed: true,
            ),
          );

          if (decoded is Map) {
            workerCommit =
                (decoded['sourceCommit'] ?? '')
                    .toString()
                    .trim();
          }
        } catch (_) {
          workerCommit = '';
        }
      }

      return _WorkerHealthProbe(
        reachable: reachable,
        sourceCommit: workerCommit,
        result: DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: reachable,
          severity: reachable ? 'PASS' : 'FAIL',
          status: reachable
              ? 'WORKER_HEALTH_OK'
              : 'WORKER_HTTP_${response.statusCode}',
          httpStatus: response.statusCode,
          details:
              'host=${uri.host}; '
              'path=${uri.path}; '
              'HTTP=${response.statusCode}; '
              'sourceCommitPresent=${workerCommit.isNotEmpty}.',
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } catch (error) {
      stopwatch.stop();

      return _WorkerHealthProbe(
        reachable: false,
        sourceCommit: '',
        result: DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: false,
          severity: 'FAIL',
          status: 'WORKER_DIRECT_HTTPS_ERROR',
          details:
              'host=${uri.host}; '
              'error=${_safeError(error)}',
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  DiagnosticResult _checkBuildSourceIdentity(
    _WorkerHealthProbe primary,
  ) {
    if (!_isInjected(_commitSha)) {
      return const DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: false,
        severity: 'WARN',
        status: 'APP_COMMIT_NOT_INJECTED',
        details:
            'لا يمكن مقارنة APK مع Worker لأن Commit التطبيق '
            'لم يتم حقنه داخل نسخة البناء.',
        durationMs: 0,
        blocked: true,
      );
    }

    if (!primary.reachable) {
      return DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: false,
        severity: 'WARN',
        status: 'WORKER_IDENTITY_UNVERIFIED',
        details:
            'APK commit=$_commitSha; '
            'تعذر فحص sourceCommit لأن الخادم الأساسي '
            'لم يستجب لاختبار HTTPS.',
        durationMs: 0,
        blocked: true,
      );
    }

    final workerCommit = primary.sourceCommit.trim();

    if (workerCommit.isEmpty ||
        workerCommit.toLowerCase() == 'unknown') {
      return DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: false,
        severity: 'FAIL',
        status: 'WORKER_SOURCE_COMMIT_MISSING',
        details:
            'الخادم الأساسي استجاب، لكنه لم يعرض sourceCommit صالحًا. '
            'APK commit=$_commitSha; '
            'يجب أن تكون هوية Worker محددة قبل اعتماد النسخة.',
        durationMs: 0,
      );
    }

    final matches =
        workerCommit.toLowerCase() == _commitSha.toLowerCase();

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: matches,
      severity: matches ? 'PASS' : 'FAIL',
      status: matches
          ? 'APP_AND_WORKER_COMMIT_MATCH'
          : 'WORKER_SOURCE_MISMATCH',
      details:
          'APK commit=$_commitSha; '
          'Worker sourceCommit=$workerCommit; '
          'exactMatch=$matches.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkInternetHttps(
    http.Client client,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await client.get(
        Uri.parse('https://example.com/'),
        headers: const {
          'Accept': 'text/html',
          'Cache-Control': 'no-cache',
        },
      ).timeout(checkTimeout);

      stopwatch.stop();

      final success =
          response.statusCode >= 200 &&
          response.statusCode < 400;

      return DiagnosticResult(
        name: 'Internet HTTPS control',
        category: 'NETWORK',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success
            ? 'HTTPS_OK'
            : 'HTTPS_HTTP_ERROR',
        httpStatus: response.statusCode,
        details:
            'probeHost=example.com; '
            'HTTP=${response.statusCode}; '
            'durationMs=${stopwatch.elapsedMilliseconds}.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Internet HTTPS control',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: 'INTERNET_HTTPS_ERROR',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Uri _healthUri(String baseUrl) {
    final base = Uri.parse(baseUrl);

    return base.replace(
      path: '/health',
      query: null,
      fragment: null,
    );
  }

  bool _isInjected(String value) {
    final clean = value.trim();

    return clean.isNotEmpty &&
        clean.toUpperCase() != 'NOT_INJECTED' &&
        clean.toLowerCase() != 'unknown';
  }

  DiagnosticResult _copyWithDuration(
    DiagnosticResult result,
    int durationMs,
  ) {
    return DiagnosticResult(
      name: result.name,
      category: result.category,
      success: result.success,
      status: result.status,
      details: result.details,
      httpStatus: result.httpStatus,
      durationMs: durationMs,
      severity: result.severity,
      repairable: result.repairable,
      blocked: result.blocked,
    );
  }

  String _safeError(Object error) {
    final value = error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (value.length <= 400) return value;

    return '${value.substring(0, 400)}…';
  }
}

class _WorkerHealthProbe {
  const _WorkerHealthProbe({
    required this.reachable,
    required this.sourceCommit,
    required this.result,
  });

  final bool reachable;
  final String sourceCommit;
  final DiagnosticResult result;
}

class AppDiagnosticsQuickReport {
  const AppDiagnosticsQuickReport({
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

  int get failed => results
      .where(
        (item) => item.severity == 'FAIL' && !item.blocked,
      )
      .length;

  int get total => results.length;

  String get rootCauseCode {
    final identityFailure = results.any(
      (item) =>
          item.name == 'Build/source identity' &&
          item.severity == 'FAIL',
    );

    if (identityFailure) return 'BUILD_IDENTITY';

    final networkFailure = results.any(
      (item) =>
          item.category == 'NETWORK' &&
          item.severity == 'FAIL' &&
          !item.blocked,
    );

    if (networkFailure) return 'NETWORK_FAILURE';

    final performanceFailure = results.any(
      (item) =>
          item.category == 'PERFORMANCE' &&
          item.severity == 'FAIL' &&
          !item.blocked,
    );

    if (performanceFailure) return 'APP_PERFORMANCE';

    return 'NO_CONFIRMED_FAILURE';
  }
}
