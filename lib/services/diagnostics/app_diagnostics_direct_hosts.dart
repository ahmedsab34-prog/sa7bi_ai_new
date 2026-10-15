part of '../app_diagnostics_service.dart';

/// Independent HTTPS probes for the primary and fallback Workers.
///
/// These checks intentionally bypass Sa7biNetworkClient and its
/// automatic failover by using a fresh dart:io HttpClient.
///
/// Purpose:
/// - Determine whether the primary hostname is reachable directly.
/// - Determine whether the fallback hostname is reachable directly.
/// - Compare these results with the app's existing network diagnostics.
///
/// These checks do not send AI generation requests or spend credits.
extension AppDiagnosticsDirectHostChecks on AppDiagnosticsService {
  static const String _fallbackWorkerUrl =
      'https://sa7bi-ai-new-fallback.ahmedsab34.workers.dev';

  static const Duration _directProbeTimeout =
      Duration(seconds: 10);

  static const Duration _directConnectTimeout =
      Duration(seconds: 8);

  Future<DiagnosticResult> _checkPrimaryDirectHttps() {
    return _checkDirectWorkerHealth(
      name: 'Primary Worker direct HTTPS',
      baseUrl: workerBaseUrl,
    );
  }

  Future<DiagnosticResult> _checkFallbackDirectHttps() {
    return _checkDirectWorkerHealth(
      name: 'Fallback Worker direct HTTPS',
      baseUrl: _fallbackWorkerUrl,
    );
  }

  Future<DiagnosticResult> _checkDirectWorkerHealth({
    required String name,
    required String baseUrl,
  }) async {
    final stopwatch = Stopwatch()..start();

    final Uri uri;

    try {
      uri = Uri.parse(baseUrl).replace(
        path: '/health',
        query: null,
        fragment: null,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: 'INVALID_WORKER_URL',
        details: 'Invalid Worker URL: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final ioHttpClient = HttpClient()
      ..connectionTimeout = _directConnectTimeout
      ..userAgent = Sa7biNetworkClient.userAgent;

    final directClient = http.IOClient(ioHttpClient);

    try {
      final response = await directClient
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(_directProbeTimeout);

      stopwatch.stop();

      final responseBody = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: success,
        severity: success ? 'PASS' : 'FAIL',
        status: success
            ? 'DIRECT_HTTPS_OK'
            : _statusForHttpCode(response.statusCode),
        httpStatus: response.statusCode,
        details:
            'host=${uri.host}; '
            'path=${uri.path}; '
            'transport=DIRECT_DART_IO; '
            'HTTP=${response.statusCode}; '
            '${_summarizeBody(responseBody)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details:
            'Direct HTTPS request failed; '
            'host=${uri.host}; '
            'transport=DIRECT_DART_IO; '
            'timeout=${_directProbeTimeout.inSeconds}s; '
            'connectTimeout=${_directConnectTimeout.inSeconds}s; '
            'error=${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      directClient.close();
    }
  }
}
