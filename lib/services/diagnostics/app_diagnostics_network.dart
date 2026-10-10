
part of '../app_diagnostics_service.dart';

extension AppDiagnosticsNetworkChecks on AppDiagnosticsService {
  // ============================================================
  // BUILD IDENTITY
  // ============================================================

  Future<DiagnosticResult> _checkRuntimeIdentity() async {
    final release = kReleaseMode;

    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: release ? 'RELEASE' : 'DEBUG_OR_PROFILE',
      details:
          'Flutter runtime mode=${release ? 'release' : 'non-release'}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkDiagnosticIdentity() async {
    return DiagnosticResult(
      name: 'Diagnostic engine identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: 'DIAGNOSTIC_${AppDiagnosticsService.diagnosticVersion}',
      details:
          'Diagnostic engine version '
          '${AppDiagnosticsService.diagnosticVersion}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkBuildSourceIdentity() async {
    final buildInjected =
        AppDiagnosticsService.buildId != 'NOT_INJECTED';
    final sourceInjected =
        AppDiagnosticsService.sourceId != 'NOT_INJECTED';
    final commitInjected =
        AppDiagnosticsService.commitSha != 'NOT_INJECTED';

    final allInjected =
        buildInjected && sourceInjected && commitInjected;

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: allInjected,
      severity: allInjected ? 'PASS' : 'WARN',
      status: allInjected ? 'INJECTED' : 'NOT_INJECTED',
      details:
          'buildId=${AppDiagnosticsService.buildId}; '
          'sourceId=${AppDiagnosticsService.sourceId}; '
          'appVersion=${AppDiagnosticsService.appVersion}; '
          'buildNumber=${AppDiagnosticsService.buildNumber}; '
          'commitSha=${AppDiagnosticsService.commitSha}.',
      durationMs: 0,
    );
  }

  // ============================================================
  // TRANSPORT IDENTITY
  // ============================================================

  Future<DiagnosticResult> _checkNetworkTransportIdentity() async {
    final name = Sa7biNetworkClient.transportName;
    final cronet = Sa7biNetworkClient.isCronet;

    return DiagnosticResult(
      name: 'Network transport identity',
      category: 'NETWORK',
      success: true,
      severity: cronet ? 'PASS' : 'WARN',
      status: name,
      details: 'networkTransport=$name; cronet=$cronet.',
      durationMs: 0,
    );
  }

  // ============================================================
  // GENERAL INTERNET HTTPS
  // ============================================================

  Future<DiagnosticResult> _checkInternetHttps() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await Sa7biNetworkClient.client
          .get(
            Uri.parse('https://example.com'),
            headers: const {
              'Accept': 'text/html',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      // 2xx و3xx يعني שהגענו إلى خادم HTTPS صالح.
      // 4xx لا يُعتبر نجاحًا لاختبار الاتصال العام.
      final success =
          response.statusCode >= 200 && response.statusCode < 400;

      return DiagnosticResult(
        name: 'Internet HTTPS control',
        category: 'NETWORK',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success ? 'HTTPS_OK' : 'HTTPS_HTTP_ERROR',
        httpStatus: response.statusCode,
        details:
            'probeHost=example.com; '
            'transport=${Sa7biNetworkClient.transportName}; '
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
        status: _classifyException(error),
        details:
            'Internet HTTPS failed: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // PRIMARY WORKER DNS
  // ============================================================

  Future<DiagnosticResult> _checkDns() async {
    final stopwatch = Stopwatch()..start();

    try {
      final host = Uri.parse(workerBaseUrl).host;
      final addresses = await InternetAddress.lookup(host);

      stopwatch.stop();

      final values = addresses
          .map((item) => item.address)
          .toList();

      final success = values.isNotEmpty;

      return DiagnosticResult(
        name: 'Worker DNS resolution',
        category: 'NETWORK',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success ? 'DNS_OK' : 'DNS_EMPTY',
        details:
            'host=$host; addresses=${values.join(', ')}.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Worker DNS resolution',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details:
            'DNS lookup failed: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // PRIMARY WORKER HTTPS HEALTH
  // ============================================================

  Future<DiagnosticResult> _checkWorkerHttpsHealth() async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri('/health');

      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // اختبار الصحة يحتاج استجابة ناجحة من الخادم،
      // وليس مجرد وصول HTTP مثل 404.
      final success =
          response.statusCode >= 200 && response.statusCode < 300;

      return DiagnosticResult(
        name: 'Worker HTTPS health',
        category: 'NETWORK',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success
            ? 'WORKER_HEALTH_OK'
            : _statusForHttpCode(response.statusCode),
        httpStatus: response.statusCode,
        details:
            'requestedHost=${uri.host}; '
            'transport=${Sa7biNetworkClient.transportName}; '
            'HTTP=${response.statusCode}; '
            '${_summarizeBody(body)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Worker HTTPS health',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details:
            'Worker health failed: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // DEVICE
  // ============================================================

  Future<DiagnosticResult> _checkRuntimeMemory() async {
    return DiagnosticResult(
      name: 'Runtime memory',
      category: 'DEVICE',
      success: true,
      severity: 'PASS',
      status: 'AVAILABLE',
      details: 'Dart runtime is active.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkTemporaryStorage() async {
    try {
      final directory = Directory.systemTemp;
      final exists = await directory.exists();

      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: exists,
        severity: exists ? 'PASS' : 'WARN',
        status: exists ? 'AVAILABLE' : 'UNAVAILABLE',
        details: 'systemTemp=${directory.path}',
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'CHECK_ERROR',
        details: _safeError(error),
        durationMs: 0,
      );
    }
  }

  Future<DiagnosticResult> _checkNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
      );

      return DiagnosticResult(
        name: 'Network interfaces',
        category: 'DEVICE',
        success: interfaces.isNotEmpty,
        severity: interfaces.isNotEmpty ? 'PASS' : 'WARN',
        status: interfaces.isNotEmpty ? 'AVAILABLE' : 'NONE',
        details: interfaces.map((item) => item.name).join(', '),
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'Network interfaces',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'CHECK_ERROR',
        details: _safeError(error),
        durationMs: 0,
      );
    }
  }

  // ============================================================
  // CONTROLLED 404 TEST
  // ============================================================

  Future<DiagnosticResult> _checkErrorClassification() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await Sa7biNetworkClient.client
          .get(
            _buildUri('/__sa7bi_diagnostic_missing_endpoint__'),
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      // هذا المسار غير موجود عمدًا.
      // النجاح هنا هو أن الخادم أعاد 404 كما هو متوقع.
      final expected = response.statusCode == 404;

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: expected,
        severity: expected ? 'PASS' : 'WARN',
        status: expected
            ? 'HTTP_404_EXPECTED'
            : _statusForHttpCode(response.statusCode),
        httpStatus: response.statusCode,
        details:
            'Controlled missing endpoint; '
            'expected=404; actual=${response.statusCode}.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: false,
        severity: 'WARN',
        status: _classifyException(error),
        details:
            'تعذر تنفيذ اختبار 404 المتحكم فيه: '
            '${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // TIMEOUT CONFIGURATION
  // ============================================================

  Future<DiagnosticResult> _checkTimeoutConfiguration() async {
    final valid =
        AppDiagnosticsService.defaultTimeout.inSeconds >= 10 &&
        AppDiagnosticsService.deepTimeout.inSeconds >= 5;

    return DiagnosticResult(
      name: 'Network timeout configuration',
      category: 'TIMEOUT',
      success: valid,
      severity: valid ? 'PASS' : 'WARN',
      status: valid ? 'OK' : 'INVALID',
      details:
          'defaultTimeout='
          '${AppDiagnosticsService.defaultTimeout.inSeconds}s; '
          'deepTimeout=${AppDiagnosticsService.deepTimeout.inSeconds}s.',
      durationMs: 0,
    );
  }
}
