part of '../app_diagnostics_service.dart';

extension AppDiagnosticsContentChecks
    on AppDiagnosticsService {
  // ============================================================
  // WORKER / ROUTES
  // ============================================================

  Future<DiagnosticResult> _httpGet({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch =
        Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout =
          defaultTimeout
      ..userAgent =
          'Sa7biAI-Diagnostics/'
          '$diagnosticVersion';

    try {
      final request =
          await client.getUrl(
        _buildUri(path),
      );

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      request.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache',
      );

      final response =
          await request.close();

      final status =
          response.statusCode;

      final body =
          await response
              .take(32)
              .map(
                (chunk) =>
                    utf8.decode(
                  chunk,
                  allowMalformed: true,
                ),
              )
              .join();

      await response.drain<void>();

      stopwatch.stop();

      final reachable =
          status >= 200 &&
          status < 500;

      final expectedValidation =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405;

      return DiagnosticResult(
        name: name,
        category: category,
        success: reachable,
        severity:
            reachable
                ? (
                    expectedValidation
                        ? 'WARN'
                        : 'PASS'
                  )
                : 'FAIL',
        status:
            _statusForHttpCode(status),
        httpStatus: status,
        details:
            'HTTP $status. '
            '${_summarizeBody(body)}',
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable:
            !reachable &&
            (
              category == 'WORKER' ||
              category == 'AI'
            ),
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable:
            category == 'WORKER' ||
            category == 'AI',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult>
      _probeRoute({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final response =
          await http.get(
        _buildUri(path),
        headers: {
          'Accept':
              'application/json',
          'User-Agent':
              'Sa7biAI-Diagnostics/'
              '$diagnosticVersion',
          'Cache-Control':
              'no-cache',
        },
      ).timeout(defaultTimeout);

      stopwatch.stop();

      final reachable =
          response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name: name,
        category: category,
        success: reachable,
        severity:
            reachable ? 'PASS' : 'FAIL',
        status:
            reachable
                ? 'ROUTE_REACHABLE'
                : 'ROUTE_UNREACHABLE',
        httpStatus:
            response.statusCode,
        details:
            'HTTP ${response.statusCode}. '
            'هذا اختبار route فقط؛ '
            'لم يتم تنفيذ توليد AI.',
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: !reachable,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  // ============================================================
  // MEDIA
  // ============================================================

  Future<DiagnosticResult>
      _checkMediaUrlHandling() async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final radio =
          _buildUri(
        '/v1/radio/stations'
        '?country=EG',
      );

      final audio =
          _buildUri(
        '/v1/audio/search-v4'
        '?q=diagnostic',
      );

      final podcast =
          _buildUri(
        '/v1/podcasts/search'
        '?q=diagnostic',
      );

      final valid =
          radio.queryParameters[
                  'country'] ==
              'EG' &&
          audio.queryParameters['q'] ==
              'diagnostic' &&
          podcast.queryParameters['q'] ==
              'diagnostic';

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: valid,
        severity:
            valid ? 'PASS' : 'FAIL',
        status:
            valid ? 'OK' : 'INVALID',
        details:
            'country='
            '${radio.queryParameters['country']}; '
            'audioQ='
            '${audio.queryParameters['q']}; '
            'podcastQ='
            '${podcast.queryParameters['q']}.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        severity: 'FAIL',
        status: 'INVALID',
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // MONETIZATION
  // ============================================================

  Future<DiagnosticResult>
      _checkMonetization() async {
    final credits =
        await _httpGet(
      name: 'Credits endpoint',
      category: 'MONETIZATION',
      path: '/v1/credits',
    );

    final success =
        credits.success;

    return DiagnosticResult(
      name:
          'Monetization endpoints',
      category: 'MONETIZATION',
      success: success,
      severity:
          success ? 'PASS' : 'WARN',
      status:
          success
              ? 'CREDITS_REACHABLE'
              : 'NOT_CONFIRMED',
      httpStatus:
          credits.httpStatus,
      details:
          '/v1/credits='
          '${credits.status}. '
          'AdMob نفسه لا يتم اختباره '
          'من خلال Worker.',
      durationMs:
          credits.durationMs,
      repairable: !success,
    );
  }

  // ============================================================
  // ERROR CLASSIFICATION
  // ============================================================

  Future<DiagnosticResult>
      _checkErrorClassification() async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final response =
          await http.get(
        _buildUri(
          '/__sa7bi_diagnostic_missing_endpoint__',
        ),
      ).timeout(defaultTimeout);

      stopwatch.stop();

      final expected =
          response.statusCode == 404;

      return DiagnosticResult(
        name:
            'HTTP error classification',
        category: 'ERRORS',
        success: expected,
        severity:
            expected ? 'PASS' : 'WARN',
        status:
            expected
                ? 'HTTP_404_EXPECTED'
                : _statusForHttpCode(
                    response.statusCode,
                  ),
        httpStatus:
            response.statusCode,
        details:
            'تم إرسال طلب إلى route '
            'غير موجود عمدًا؛ المتوقع 404.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name:
            'HTTP error classification',
        category: 'ERRORS',
        success: false,
        severity: 'WARN',
        status:
            _classifyException(error),
        details:
            'تعذر تنفيذ اختبار 404 '
            'المتحكم فيه: '
            '${_safeError(error)}',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ============================================================
  // TIMEOUT
  // ============================================================

  Future<DiagnosticResult>
      _checkTimeoutConfiguration() async {
    final valid =
        defaultTimeout.inSeconds >= 5 &&
        deepTimeout.inSeconds >= 3;

    return DiagnosticResult(
      name: 'Timeout configuration',
      category: 'TIMEOUT',
      success: valid,
      severity:
          valid ? 'PASS' : 'WARN',
      status:
          valid ? 'OK' : 'INVALID',
      details:
          'defaultTimeout='
          '${defaultTimeout.inSeconds}s; '
          'deepTimeout='
          '${deepTimeout.inSeconds}s.',
      durationMs: 0,
    );
  }
}
