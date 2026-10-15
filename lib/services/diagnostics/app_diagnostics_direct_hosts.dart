part of '../app_diagnostics_service.dart';

/// Independent HTTPS probes for the primary and fallback Workers.
///
/// These probes use a fresh dart:io HttpClient directly.
/// They do not use Sa7biNetworkClient and do not send AI requests.
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

    late final Uri uri;

    try {
      uri = Uri.parse(baseUrl).replace(
        path: '/health',
        query: null,
        fragment: null,
      );

      if (uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException(
          'Worker URL must use HTTPS and include a host.',
        );
      }
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

    final directClient = HttpClient()
      ..connectionTimeout = _directConnectTimeout
      ..userAgent = Sa7biNetworkClient.userAgent;

    try {
      final request = await directClient
          .getUrl(uri)
          .timeout(_directProbeTimeout);

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      request.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache',
      );

      final response = await request
          .close()
          .timeout(_directProbeTimeout);

      final responseBody = await response
          .transform(
            const Utf8Decoder(allowMalformed: true),
          )
          .join()
          .timeout(_directProbeTimeout);

      stopwatch.stop();

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
      directClient.close(force: true);
    }
  }
}
