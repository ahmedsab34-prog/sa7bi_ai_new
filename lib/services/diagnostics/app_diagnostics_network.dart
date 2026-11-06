part of '../app_diagnostics_service.dart';

extension AppDiagnosticsNetworkChecks on AppDiagnosticsService {
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

  // ============================================================
  // APK / WORKER SOURCE IDENTITY
  //
  // يقارن Commit الموجود داخل APK مع Commit المنشور فعليًا
  // في Worker /health.
  //
  // فشل الشبكة هنا يظهر WARN فقط؛ لأن اختبارات الشبكة
  // المستقلة مسؤولة عن تحديد فشل الاتصال.
  // اختلاف Commit أو غياب هوية Worker بعد استجابته
  // الصحيحة يظهر FAIL.
  // ============================================================

  Future<DiagnosticResult> _checkBuildSourceIdentity() async {
    final stopwatch = Stopwatch()..start();

    final buildInjected =
        AppDiagnosticsService.buildId != 'NOT_INJECTED';

    final sourceInjected =
        AppDiagnosticsService.sourceId != 'NOT_INJECTED';

    final commitInjected =
        AppDiagnosticsService.commitSha != 'NOT_INJECTED';

    final allInjected =
        buildInjected &&
        sourceInjected &&
        commitInjected;

    if (!allInjected) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: false,
        severity: 'WARN',
        status: 'NOT_INJECTED',
        details:
            'buildId=${AppDiagnosticsService.buildId}; '
            'sourceId=${AppDiagnosticsService.sourceId}; '
            'appVersion=${AppDiagnosticsService.appVersion}; '
            'buildNumber=${AppDiagnosticsService.buildNumber}; '
            'commitSha=${AppDiagnosticsService.commitSha}. '
            'لا يمكن إثبات هوية المصدر لأن بعض قيم البناء '
            'لم يتم حقنها داخل APK.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    try {
      final uri = _buildUri('/health');

      final response =
          await Sa7biNetworkClient.client
              .get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      final appCommit =
          AppDiagnosticsService.commitSha.trim();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return DiagnosticResult(
          name: 'Build/source identity',
          category: 'BUILD',
          success: false,
          severity: 'WARN',
          status:
              'WORKER_IDENTITY_HTTP_${response.statusCode}',
          httpStatus: response.statusCode,
          details:
              'APK commit=$appCommit; '
              'Worker source identity could not be checked '
              'because /health returned HTTP '
              '${response.statusCode}. '
              'The independent Worker network tests '
              'will determine connectivity.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      String workerCommit = '';

      try {
        final decoded = jsonDecode(body);

        if (decoded is Map) {
          workerCommit =
              (decoded['sourceCommit'] ?? '')
                  .toString()
                  .trim();
        }
      } catch (_) {
        workerCommit = '';
      }

      if (workerCommit.isEmpty ||
          workerCommit.toLowerCase() == 'unknown') {
        return DiagnosticResult(
          name: 'Build/source identity',
          category: 'BUILD',
          success: false,
          severity: 'FAIL',
          status: 'WORKER_SOURCE_COMMIT_MISSING',
          httpStatus: response.statusCode,
          details:
              'APK commit=$appCommit; '
              'Worker /health responded successfully, '
              'but it did not expose sourceCommit. '
              'The Worker must be deployed with '
              'SA7BI_SOURCE_COMMIT set to the same commit '
              'used to build this APK.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final matches =
          workerCommit.toLowerCase() ==
          appCommit.toLowerCase();

      return DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: matches,
        severity: matches ? 'PASS' : 'FAIL',
        status: matches
            ? 'APP_AND_WORKER_COMMIT_MATCH'
            : 'WORKER_SOURCE_MISMATCH',
        httpStatus: response.statusCode,
        details:
            'APK commit=$appCommit; '
            'Worker sourceCommit=$workerCommit; '
            'exactMatch=$matches; '
            'workerHost=${uri.host}. '
            '${matches ? 'الـAPK والـWorker من نفس Commit.' : 'لا تثبّت هذه النسخة باعتبارها نسخة متطابقة؛ يجب نشر Worker من Commit الـAPK نفسه.'}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Build/source identity',
        category: 'BUILD',
        success: false,
        severity: 'WARN',
        status: 'WORKER_IDENTITY_UNVERIFIED',
        details:
            'APK commit=${AppDiagnosticsService.commitSha}; '
            'تعذر التحقق من Commit الـWorker بسبب مشكلة اتصال: '
            '${_safeError(error)}. '
            'سيتم فحص اتصال Worker في الاختبارات المستقلة.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

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

  Future<DiagnosticResult> _checkInternetHttps() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response =
          await Sa7biNetworkClient.client
              .get(
        Uri.parse('https://example.com'),
        headers: const {
          'Accept': 'text/html',
          'Cache-Control': 'no-cache',
        },
      ).timeout(AppDiagnosticsService.defaultTimeout);

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

  Future<DiagnosticResult> _checkDns() async {
    final stopwatch = Stopwatch()..start();

    try {
      final host = Uri.parse(workerBaseUrl).host;
      final addresses = await InternetAddress.lookup(host);

      stopwatch.stop();

      final values =
          addresses.map((item) => item.address).toList();

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

  Future<DiagnosticResult> _checkWorkerHttpsHealth() async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri('/health');

      final response =
          await Sa7biNetworkClient.client
              .get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300;

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
        status:
            interfaces.isNotEmpty ? 'AVAILABLE' : 'NONE',
        details:
            interfaces.map((item) => item.name).join(', '),
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

  Future<DiagnosticResult> _checkErrorClassification() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response =
          await Sa7biNetworkClient.client
              .get(
        _buildUri('/__sa7bi_diagnostic_missing_endpoint__'),
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

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
          'deepTimeout='
          '${AppDiagnosticsService.deepTimeout.inSeconds}s.',
      durationMs: 0,
    );
  }
}
