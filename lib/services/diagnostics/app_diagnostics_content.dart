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
// SAFE POST ROUTE PROBE
// ============================================================

Future<DiagnosticResult> _probeRoute({
required String name,
required String category,
required String path,
}) async {
final stopwatch = Stopwatch()..start();

try {
  final uri = _buildUri(path);

  // طلب فارغ آمن لا ينفذ توليدًا مدفوعًا.
  final Map<String, dynamic> probeBody =
      path == '/v1/image'
          ? <String, dynamic>{'prompt': ''}
          : <String, dynamic>{'messages': <dynamic>[]};

  final response = await Sa7biNetworkClient.client
      .post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
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
      status == 400 &&
      (lowerBody.contains('empty_message') ||
          lowerBody.contains('empty_prompt'));

  final ordinarySuccess = status >= 200 && status < 300;
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
      ? 'ROUTE_HTTP_OK'
      : expectedValidation
          ? 'ROUTE_EXISTS_VALIDATION_REACHED'
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
    details:
        'path=${uri.path}; HTTP=$status; '
        'probeMethod=POST; '
        'routeResponded=$routeResponded; '
        'expectedEmptyPayload=true; '
        'paidGenerationExecuted=false; '
        '${_summarizeBody(body)}',
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
        'POST route probe failed for $path: '
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
final stopwatch = Stopwatch()..start();

try {
  // لا نرسل طلب رصيد بدون معرّف الجهاز المحفوظ.
  // المفتاح هو نفسه المستخدم في AiRequestService.
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
          'لم يتم إرسال طلب الرصيد، لتجنب استدعاء '
          'يرجع DEVICE_ID_REQUIRED. '
          'افتح خدمة الرصيد من التطبيق ثم أعد التشخيص. '
          'AdMob نفسه لا يتم اختباره من خلال Worker.',
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
          'Cache-Control': 'no-cache',
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
    details:
        'method=GET; path=${uri.path}; '
        'deviceIdHeaderSent=true; '
        'HTTP=$status; '
        '${_summarizeBody(body)}; '
        'AdMob itself is not tested through Worker.',
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
    details:
        'تعذر فحص الرصيد بأمان: ${_safeError(error)}',
    durationMs: stopwatch.elapsedMilliseconds,
    repairable: false,
  );
}

}
}
