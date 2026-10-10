
part of '../app_diagnostics_service.dart';

extension AppDiagnosticsContentChecks
    on AppDiagnosticsService {
  // ============================================================
  // HTTP GET
  // ============================================================

  Future<DiagnosticResult> _httpGet({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri(path);

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

      final status = response.statusCode;
      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // لا نعتبر 404 أو أخطاء الخادم نجاحًا.
      // بعض المسارات قد تحتاج بيانات أو صلاحيات؛ نسجلها كتحذير
      // بدل اعتبارها اختبارًا وظيفيًا ناجحًا.
      final success = status >= 200 && status < 300;
      final validationResponse =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405;

      final severity = success
          ? 'PASS'
          : validationResponse
              ? 'WARN'
              : 'FAIL';

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        severity: severity,
        status: _statusForHttpCode(status),
        httpStatus: status,
        details:
            'method=GET; path=${uri.path}; '
            'HTTP=$status; '
            'functionalSuccess=$success; '
            '${_summarizeBody(body)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: !success &&
            (category == 'WORKER' || category == 'AI'),
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details:
            'GET $path failed: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: category == 'WORKER' || category == 'AI',
      );
    }
  }

  // ============================================================
  // ROUTE PROBE
  // ============================================================

  Future<DiagnosticResult> _probeRoute({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri(path);

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

      final status = response.statusCode;
      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // هذا اختبار وصول فقط، وليس تنفيذًا لطلب AI مدفوع.
      // استجابة 404 أو 5xx لا تعني أن المسار يعمل.
      final success = status >= 200 && status < 300;
      final validationResponse =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405;

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        severity: success
            ? 'PASS'
            : validationResponse
                ? 'WARN'
                : 'FAIL',
        status: success
            ? 'ROUTE_HTTP_OK'
            : validationResponse
                ? 'ROUTE_REQUIRES_VALID_REQUEST_OR_AUTH'
                : _statusForHttpCode(status),
        httpStatus: status,
        details:
            'path=${uri.path}; HTTP=$status; '
            'routeProbeOnly=true; '
            'paidGenerationExecuted=false; '
            '${_summarizeBody(body)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: !success,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details:
            'Route probe failed for $path: '
            '${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  // ============================================================
  // MEDIA URL HANDLING
  // ============================================================

  Future<DiagnosticResult> _checkMediaUrlHandling() async {
    final stopwatch = Stopwatch()..start();

    try {
      final radio = _buildUri(
        '/v1/radio/stations?country=EG',
      );

      final audio = _buildUri(
        '/v1/audio/search-v4?q=diagnostic',
      );

      final podcast = _buildUri(
        '/v1/podcasts/search?q=diagnostic',
      );

      final valid =
          radio.queryParameters['country'] == 'EG' &&
          audio.queryParameters['q'] == 'diagnostic' &&
          podcast.queryParameters['q'] == 'diagnostic';

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: valid,
        severity: valid ? 'PASS' : 'FAIL',
        status: valid ? 'URL_PARAMETERS_OK' : 'URL_PARAMETERS_INVALID',
        details:
            'radioCountry=${radio.queryParameters['country']}; '
            'audioQ=${audio.queryParameters['q']}; '
            'podcastQ=${podcast.queryParameters['q']}; '
            'networkRequestExecuted=false.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        severity: 'FAIL',
        status: 'URL_PARAMETERS_INVALID',
        details: _safeError(error),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // MONETIZATION
  // ============================================================

  Future<DiagnosticResult> _checkMonetization() async {
    final credits = await _httpGet(
      name: 'Credits endpoint',
      category: 'MONETIZATION',
      path: '/v1/credits',
    );

    return DiagnosticResult(
      name: 'Monetization endpoints',
      category: 'MONETIZATION',
      success: credits.success,
      severity: credits.success ? 'PASS' : 'WARN',
      status: credits.success
          ? 'CREDITS_HTTP_OK'
          : 'CREDITS_NOT_CONFIRMED',
      httpStatus: credits.httpStatus,
      details:
          '/v1/credits=${credits.status}; '
          'AdMob itself is not tested through Worker.',
      durationMs: credits.durationMs,
      repairable: !credits.success,
      blocked: credits.blocked,
    );
  }
}
