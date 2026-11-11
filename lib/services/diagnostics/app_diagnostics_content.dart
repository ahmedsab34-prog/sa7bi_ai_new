
part of '../app_diagnostics_service.dart';

extension AppDiagnosticsContentChecks on AppDiagnosticsService {
  Future<DiagnosticResult> _httpGet({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // /v1/tafsir requires a book ID.
      // The old diagnostic omitted it and produced a false warning.
      final effectivePath =
          name == 'Tafsir route' &&
                  Uri.parse(path).path == '/v1/tafsir'
              ? '/v1/tafsir?tafsir=1&sura=114'
              : path;

      final uri = _buildUri(effectivePath);

      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final status = response.statusCode;
      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      var success = status >= 200 && status < 300;
      var payloadFailure = '';

      // A HTTP 200 response containing {"ok": false}
      // is not a successful feature response.
      if (success && body.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(body);

          if (decoded is Map && decoded['ok'] == false) {
            success = false;
            payloadFailure =
                (decoded['error'] ??
                        decoded['message'] ??
                        'The Worker reported ok=false')
                    .toString();
          }
        } catch (_) {
          // Some Worker routes may return non-JSON content.
          // Detailed JSON validation is performed by v5 checks.
        }
      }

      final validationResponse =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405 ||
          status == 422;

      final severity = success
          ? 'PASS'
          : validationResponse
              ? 'WARN'
              : 'FAIL';

      final resultStatus = success
          ? _statusForHttpCode(status)
          : payloadFailure.isNotEmpty
              ? 'WORKER_PAYLOAD_REPORTED_FAILURE'
              : _statusForHttpCode(status);

      return DiagnosticResult(
        name: name,
        category: category,
        success: success,
        severity: severity,
        status: resultStatus,
        httpStatus: status,
        details: [
          'method=GET',
          'requestedPath=${uri.path}',
          'query=${uri.query}',
          'HTTP=$status',
          'functionalSuccess=$success',
          if (payloadFailure.isNotEmpty)
            'workerError=$payloadFailure',
          _summarizeBody(body),
        ].join('; '),
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
        details: 'GET $path failed: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: category == 'WORKER' || category == 'AI',
      );
    }
  }

  Future<DiagnosticResult> _probeRoute({
    required String name,
    required String category,
    required String path,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri(path);
      final isImageRoute = uri.path == '/v1/image';

      // Empty validation request only.
      // It must never trigger real AI generation.
      final Map<String, dynamic> probeBody = isImageRoute
          ? <String, dynamic>{'prompt': ''}
          : <String, dynamic>{'messages': <dynamic>[]};

      final response = await Sa7biNetworkClient.client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache, no-store',
            },
            body: jsonEncode(probeBody),
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final status = response.statusCode;
      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      final lowerBody = body.toLowerCase();

      final expectedValidation =
          (status == 400 || status == 422) &&
          (
            lowerBody.contains('empty_message') ||
            lowerBody.contains('empty_messages') ||
            lowerBody.contains('empty_prompt') ||
            lowerBody.contains('messages_required') ||
            lowerBody.contains('prompt_required')
          );

      final ordinarySuccess =
          status >= 200 && status < 300;

      final validationResponse =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405 ||
          status == 422;

      final routeResponded =
          ordinarySuccess || expectedValidation;

      final severity = routeResponded
          ? 'PASS'
          : validationResponse
              ? 'WARN'
              : 'FAIL';

      final routeStatus = ordinarySuccess
          ? 'ROUTE_HTTP_OK_NOT_INFERENCE'
          : expectedValidation
              ? 'ROUTE_VALIDATION_REACHED'
              : validationResponse
                  ? 'ROUTE_REQUIRES_VALID_REQUEST_OR_AUTH'
                  : _statusForHttpCode(status);

      return DiagnosticResult(
        name: name,
        category: category,
        success: routeResponded,
        severity: severity,
        status: routeStatus,
        httpStatus: status,
        details: [
          'path=${uri.path}',
          'HTTP=$status',
          'probeMethod=POST',
          'emptyValidationPayload=true',
          'paidGenerationExecuted=false',
          'realInferenceTested=false',
          _summarizeBody(body),
        ].join('; '),
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: !routeResponded && !validationResponse,
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
            'POST route probe failed for $path: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

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
        status: valid
            ? 'URL_PARAMETERS_ONLY'
            : 'URL_PARAMETERS_INVALID',
        details: [
          'radioCountry=${radio.queryParameters['country']}',
          'audioQ=${audio.queryParameters['q']}',
          'podcastQ=${podcast.queryParameters['q']}',
          'networkRequestExecuted=false',
          'streamBytesTested=false',
          'هذا اختبار لتكوين العناوين فقط؛ فحص البث الفعلي موجود في محرك v5.',
        ].join('; '),
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

  Future<DiagnosticResult> _checkMonetization() async {
    final stopwatch = Stopwatch()..start();

    try {
      const deviceIdStorageKey = 'sa7bi_ai_device_id';
      const deviceIdHeader = 'X-Sa7bi-Device-Id';

      final preferences = await SharedPreferences.getInstance();
      final deviceId =
          preferences.getString(deviceIdStorageKey)?.trim();

      if (deviceId == null || deviceId.isEmpty) {
        stopwatch.stop();

        return DiagnosticResult(
          name: 'Monetization endpoints',
          category: 'MONETIZATION',
          success: false,
          severity: 'WARN',
          status: 'DEVICE_ID_NOT_INITIALIZED',
          details:
              'لم يتم العثور على معرّف الجهاز المحفوظ. '
              'لم يتم إرسال طلب الرصيد لتجنب DEVICE_ID_REQUIRED. '
              'فحص AdMob منفصل ولا يثبت توفر إعلان.',
          durationMs: stopwatch.elapsedMilliseconds,
          repairable: false,
          blocked: true,
        );
      }

      final uri = _buildUri('/v1/credits');

      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
              deviceIdHeader: deviceId,
            },
          )
          .timeout(AppDiagnosticsService.defaultTimeout);

      stopwatch.stop();

      final status = response.statusCode;
      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      final success = status >= 200 && status < 300;

      return DiagnosticResult(
        name: 'Monetization endpoints',
        category: 'MONETIZATION',
        success: success,
        severity: success ? 'PASS' : 'WARN',
        status: success
            ? 'CREDITS_HTTP_OK'
            : status == 400 &&
                    body.toUpperCase().contains('DEVICE_ID_REQUIRED')
                ? 'DEVICE_ID_HEADER_REJECTED'
                : 'CREDITS_NOT_CONFIRMED',
        httpStatus: status,
        details: [
          'method=GET',
          'path=${uri.path}',
          'deviceIdHeaderSent=true',
          'HTTP=$status',
          _summarizeBody(body),
          'AdMob inventory and impressions are not tested here.',
        ].join('; '),
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: false,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Monetization endpoints',
        category: 'MONETIZATION',
        success: false,
        severity: 'WARN',
        status: _classifyException(error),
        details: 'تعذر فحص الرصيد بأمان: ${_safeError(error)}',
        durationMs: stopwatch.elapsedMilliseconds,
        repairable: false,
      );
    }
  }
}
