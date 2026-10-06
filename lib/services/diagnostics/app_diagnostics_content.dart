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
    final stopwatch =
        Stopwatch()..start();

    try {
      final uri =
          _buildUri(path);

      final response =
          await Sa7biNetworkClient.client
              .get(
        uri,
        headers: const {
          'Accept':
              'application/json',
          'Cache-Control':
              'no-cache',
        },
      )
              .timeout(
        AppDiagnosticsService
            .defaultTimeout,
      );

      stopwatch.stop();

      final status =
          response.statusCode;

      final body =
          utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

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
    }
  }

  // ============================================================
  // ROUTE PROBE
  // ============================================================

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
          await Sa7biNetworkClient.client
              .get(
        _buildUri(path),
        headers: const {
          'Accept':
              'application/json',
          'Cache-Control':
              'no-cache',
        },
      )
              .timeout(
        AppDiagnosticsService
            .defaultTimeout,
      );

      stopwatch.stop();

      final reachable =
          response.statusCode >= 200 &&
          response.statusCode < 500;

      final body =
          utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

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
            'Route reachability only; '
            'no paid AI generation executed. '
            '${_summarizeBody(body)}',
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
  // MEDIA URL HANDLING
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
        name:
            'Media URL handling',
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
        name:
            'Media URL handling',
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
          'AdMob itself is not tested '
          'through Worker.',
      durationMs:
          credits.durationMs,
      repairable: !success,
      blocked:
          credits.blocked,
    );
  }
}
