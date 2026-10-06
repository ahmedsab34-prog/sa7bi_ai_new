import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiagnosticResult {
final String name;
final String category;
final bool success;
final String status;
final String details;
final int? httpStatus;
final int durationMs;

const DiagnosticResult({
required this.name,
required this.category,
required this.success,
required this.status,
required this.details,
required this.durationMs,
this.httpStatus,
});

Map<String, dynamic> toJson() {
return {
'name': name,
'category': category,
'success': success,
'status': status,
'details': details,
'httpStatus': httpStatus,
'durationMs': durationMs,
};
}
}

class AppDiagnosticsReport {
final DateTime startedAt;
final DateTime finishedAt;
final List<DiagnosticResult> results;

const AppDiagnosticsReport({
required this.startedAt,
required this.finishedAt,
required this.results,
});

int get passed => results.where((e) => e.success).length;

int get failed => results.where((e) => !e.success).length;

Map<String, dynamic> toJson() {
return {
'startedAt': startedAt.toIso8601String(),
'finishedAt': finishedAt.toIso8601String(),
'passed': passed,
'failed': failed,
'total': results.length,
'results': results.map((e) => e.toJson()).toList(),
};
}

String toPrettyJson() {
return const JsonEncoder.withIndent('  ').convert(toJson());
}
}

class AppDiagnosticsService {
AppDiagnosticsService({
this.workerBaseUrl =
'https://sa7bi-ai-new.ahmedsab34.workers.dev',
});

final String workerBaseUrl;

static const Duration defaultTimeout = Duration(seconds: 12);

/// Diagnostic version.
///
/// Changed whenever the diagnostic engine itself changes.
/// This allows the report to prove which diagnostic engine
/// is actually running inside the APK.
static const String diagnosticVersion = '2.1.0';

/// Optional build identity supplied by Flutter/Dart defines.
///
/// If the GitHub Actions workflow does not supply APP_BUILD_ID,
/// the report explicitly says that no build ID was injected.
static const String buildId = String.fromEnvironment(
'APP_BUILD_ID',
defaultValue: 'NOT_INJECTED',
);

/// Optional source/commit identity supplied by Flutter/Dart defines.
///
/// If the workflow does not supply APP_SOURCE_ID, the report
/// explicitly exposes that fact instead of pretending we know
/// the source commit.
static const String sourceId = String.fromEnvironment(
'APP_SOURCE_ID',
defaultValue: 'NOT_INJECTED',
);

Future<AppDiagnosticsReport> runFullDiagnostics({
void Function(DiagnosticResult result)? onResult,
}) async {
final started = DateTime.now();
final results = <DiagnosticResult>[];

Future<void> run(
  String category,
  String name,
  Future<DiagnosticResult> Function() test,
) async {
  DiagnosticResult result;

  try {
    result = await test().timeout(
      defaultTimeout,
      onTimeout: () {
        return DiagnosticResult(
          name: name,
          category: category,
          success: false,
          status: 'TIMEOUT',
          details:
              'The diagnostic test exceeded '
              '${defaultTimeout.inSeconds} seconds.',
          durationMs: defaultTimeout.inMilliseconds,
        );
      },
    );
  } catch (e) {
    result = DiagnosticResult(
      name: name,
      category: category,
      success: false,
      status: 'EXCEPTION',
      details: _safeError(e),
      durationMs: 0,
    );
  }

  results.add(result);
  onResult?.call(result);
}

// ============================================================
// BUILD / APP IDENTITY
// ============================================================

await run(
  'BUILD',
  'Runtime identity',
  _checkRuntimeIdentity,
);

await run(
  'BUILD',
  'Diagnostic engine identity',
  _checkDiagnosticIdentity,
);

await run(
  'BUILD',
  'Build/source identity',
  _checkBuildSourceIdentity,
);

// ============================================================
// NETWORK — BASIC
// ============================================================

await run(
  'NETWORK',
  'Internet connectivity',
  _checkInternet,
);

await run(
  'NETWORK',
  'DNS resolution',
  _checkDns,
);

// ============================================================
// NETWORK — TRANSPORT COMPARISON
//
// These tests are intentionally separate.
//
// 1. Raw dart:io HttpClient -> Google
// 2. package:http -> Google
// 3. package:http -> Worker /health
//
// This tells us whether the problem is:
// - general Android/Dart networking,
// - specifically dart:io HttpClient,
// - specifically package:http,
// - or specifically the Worker path.
// ============================================================

await run(
  'NETWORK',
  'Raw HttpClient HTTPS → Google',
  _checkRawHttpClientGoogle,
);

await run(
  'NETWORK',
  'package:http HTTPS → Google',
  _checkPackageHttpGoogle,
);

await run(
  'NETWORK',
  'package:http HTTPS → Worker health',
  _checkPackageHttpWorkerHealth,
);

await run(
  'NETWORK',
  'TLS / HTTPS',
  _checkTls,
);

// ============================================================
// WORKER
// ============================================================

await run(
  'WORKER',
  'Worker root',
  () => _httpGet(
    name: 'Worker root',
    category: 'WORKER',
    path: '/',
  ),
);

await run(
  'WORKER',
  'Worker health',
  () => _httpGet(
    name: 'Worker health',
    category: 'WORKER',
    path: '/health',
  ),
);

// ============================================================
// AI
//
// IMPORTANT:
// We deliberately DO NOT send a real AI generation POST here.
// We only probe the route using OPTIONS/GET.
//
// This avoids consuming Gemini/OpenAI/Workers AI credits.
// ============================================================

await run(
  'AI',
  'AI chat route reachability',
  () => _probeRoute(
    name: 'AI chat route reachability',
    category: 'AI',
    path: '/v1/chat',
  ),
);

// ============================================================
// IMAGE
//
// IMPORTANT:
// We deliberately DO NOT call POST /v1/image.
// A real image request could create an image and consume
// credits/cost.
// ============================================================

await run(
  'IMAGE',
  'Image route reachability',
  () => _probeRoute(
    name: 'Image route reachability',
    category: 'IMAGE',
    path: '/v1/image',
  ),
);

// ============================================================
// NEWS
// ============================================================

await run(
  'NEWS',
  'News route',
  () => _httpGet(
    name: 'News route',
    category: 'NEWS',
    path: '/v1/news',
  ),
);

// ============================================================
// QURAN / TAFSIR / HADITH
// ============================================================

await run(
  'QURAN',
  'Quran route',
  () => _httpGet(
    name: 'Quran route',
    category: 'QURAN',
    path: '/v1/audio/quran',
  ),
);

await run(
  'TAFSIR',
  'Tafsir route',
  () => _httpGet(
    name: 'Tafsir route',
    category: 'TAFSIR',
    path: '/v1/audio/tafsir',
  ),
);

await run(
  'HADITH',
  'Hadith route',
  () => _httpGet(
    name: 'Hadith route',
    category: 'HADITH',
    path: '/v1/audio/hadith',
  ),
);

// ============================================================
// RADIO
// ============================================================

await run(
  'RADIO',
  'Radio countries',
  () => _httpGet(
    name: 'Radio countries',
    category: 'RADIO',
    path: '/v1/radio/countries',
  ),
);

await run(
  'RADIO',
  'Egypt radio stations',
  () => _httpGet(
    name: 'Egypt radio stations',
    category: 'RADIO',
    path: '/v1/radio/stations?country=EG',
  ),
);

// ============================================================
// AUDIO
// ============================================================

await run(
  'AUDIO',
  'Audio search route',
  () => _httpGet(
    name: 'Audio search route',
    category: 'AUDIO',
    path: '/v1/audio/search-v4?q=diagnostic',
  ),
);

// ============================================================
// SHORTS
// ============================================================

await run(
  'SHORTS',
  'Shorts route',
  () => _httpGet(
    name: 'Shorts route',
    category: 'SHORTS',
    path: '/v1/shorts',
  ),
);

// ============================================================
// DOWNLOAD
// ============================================================

await run(
  'DOWNLOAD',
  'Download route',
  () => _httpGet(
    name: 'Download route',
    category: 'DOWNLOAD',
    path: '/download',
  ),
);

// ============================================================
// MEDIA URL
// ============================================================

await run(
  'MEDIA',
  'Media URL handling',
  _checkMediaUrlHandling,
);

// ============================================================
// MONETIZATION
// ============================================================

await run(
  'MONETIZATION',
  'Monetization endpoint',
  _checkMonetization,
);

// ============================================================
// HTTP ERROR CLASSIFICATION
// ============================================================

await run(
  'ERRORS',
  'HTTP error classification',
  _checkErrorClassification,
);

// ============================================================
// TIMEOUT
// ============================================================

await run(
  'TIMEOUT',
  'Timeout handling',
  _checkTimeoutConfiguration,
);

final finished = DateTime.now();

return AppDiagnosticsReport(
  startedAt: started,
  finishedAt: finished,
  results: results,
);

}

// ==============================================================
// BUILD IDENTITY
// ==============================================================

Future<DiagnosticResult> _checkRuntimeIdentity() async {
final stopwatch = Stopwatch()..start();

final info = <String, dynamic>{
  'platform': Platform.operatingSystem,
  'version': Platform.operatingSystemVersion,
  'dart': Platform.version,
  'debugMode': kDebugMode,
  'profileMode': kProfileMode,
  'releaseMode': kReleaseMode,
  'worker': workerBaseUrl,
};

stopwatch.stop();

return DiagnosticResult(
  name: 'Runtime identity',
  category: 'BUILD',
  success: true,
  status: 'OK',
  details: jsonEncode(info),
  durationMs: stopwatch.elapsedMilliseconds,
);

}

Future<DiagnosticResult> _checkDiagnosticIdentity() async {
final stopwatch = Stopwatch()..start();

stopwatch.stop();

return DiagnosticResult(
  name: 'Diagnostic engine identity',
  category: 'BUILD',
  success: true,
  status: 'OK',
  details: 'diagnosticVersion=$diagnosticVersion',
  durationMs: stopwatch.elapsedMilliseconds,
);

}

Future<DiagnosticResult> _checkBuildSourceIdentity() async {
final stopwatch = Stopwatch()..start();

final buildKnown = buildId != 'NOT_INJECTED';
final sourceKnown = sourceId != 'NOT_INJECTED';

final success = buildKnown || sourceKnown;

final details = <String, dynamic>{
  'buildId': buildId,
  'sourceId': sourceId,
  'buildIdentityInjected': buildKnown,
  'sourceIdentityInjected': sourceKnown,
  'diagnosticVersion': diagnosticVersion,
};

stopwatch.stop();

return DiagnosticResult(
  name: 'Build/source identity',
  category: 'BUILD',
  success: success,
  status: success ? 'IDENTIFIED' : 'NOT_INJECTED',
  details: jsonEncode(details),
  durationMs: stopwatch.elapsedMilliseconds,
);

}

// ==============================================================
// NETWORK — BASIC
// ==============================================================

Future<DiagnosticResult> _checkInternet() async {
final stopwatch = Stopwatch()..start();

try {
  final addresses = await InternetAddress.lookup(
    'example.com',
  );

  stopwatch.stop();

  if (addresses.isEmpty) {
    return DiagnosticResult(
      name: 'Internet connectivity',
      category: 'NETWORK',
      success: false,
      status: 'NO_ADDRESS',
      details: 'DNS returned no address.',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  return DiagnosticResult(
    name: 'Internet connectivity',
    category: 'NETWORK',
    success: true,
    status: 'OK',
    details: 'Internet/DNS access is available.',
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'Internet connectivity',
    category: 'NETWORK',
    success: false,
    status: 'FAILED',
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

}

Future<DiagnosticResult> _checkDns() async {
final stopwatch = Stopwatch()..start();

try {
  final uri = Uri.parse(workerBaseUrl);
  final addresses = await InternetAddress.lookup(uri.host);

  stopwatch.stop();

  return DiagnosticResult(
    name: 'DNS resolution',
    category: 'NETWORK',
    success: addresses.isNotEmpty,
    status: addresses.isNotEmpty ? 'OK' : 'NO_ADDRESS',
    details: addresses.map((e) => e.address).join(', '),
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'DNS resolution',
    category: 'NETWORK',
    success: false,
    status: 'FAILED',
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

}

// ==============================================================
// NETWORK — RAW DART:IO VS package:http
// ==============================================================

Future<DiagnosticResult> _checkRawHttpClientGoogle() async {
final stopwatch = Stopwatch()..start();

final uri = Uri.parse('https://www.google.com');

final client = HttpClient()
  ..connectionTimeout = defaultTimeout;

try {
  final request = await client.getUrl(uri);

  request.headers.set(
    HttpHeaders.userAgentHeader,
    'Sa7biAI-Diagnostics/$diagnosticVersion',
  );

  final response = await request.close();

  await response.drain();

  stopwatch.stop();

  return DiagnosticResult(
    name: 'Raw HttpClient HTTPS → Google',
    category: 'NETWORK',
    success:
        response.statusCode >= 200 &&
        response.statusCode < 500,
    status: _statusForHttpCode(response.statusCode),
    details:
        'Raw dart:io HttpClient reached '
        '${uri.host} successfully.',
    httpStatus: response.statusCode,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'Raw HttpClient HTTPS → Google',
    category: 'NETWORK',
    success: false,
    status: _classifyException(e),
    details:
        'Raw dart:io HttpClient could not reach '
        '${uri.host}. ${_safeError(e)}',
    durationMs: stopwatch.elapsedMilliseconds,
  );
} finally {
  client.close(force: true);
}

}

Future<DiagnosticResult> _checkPackageHttpGoogle() async {
final stopwatch = Stopwatch()..start();

final uri = Uri.parse('https://www.google.com');

final client = http.Client();

try {
  final response = await client
      .get(
        uri,
        headers: {
          'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
          'User-Agent':
              'Sa7biAI-Diagnostics/$diagnosticVersion',
        },
      )
      .timeout(defaultTimeout);

  stopwatch.stop();

  return DiagnosticResult(
    name: 'package:http HTTPS → Google',
    category: 'NETWORK',
    success:
        response.statusCode >= 200 &&
        response.statusCode < 500,
    status: _statusForHttpCode(response.statusCode),
    details:
        'package:http reached ${uri.host} successfully. '
        'responseBytes=${response.bodyBytes.length}.',
    httpStatus: response.statusCode,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'package:http HTTPS → Google',
    category: 'NETWORK',
    success: false,
    status: _classifyException(e),
    details:
        'package:http could not reach ${uri.host}. '
        '${_safeError(e)}',
    durationMs: stopwatch.elapsedMilliseconds,
  );
} finally {
  client.close();
}

}

Future<DiagnosticResult> _checkPackageHttpWorkerHealth() async {
final stopwatch = Stopwatch()..start();

final uri = _buildUri('/health');

final client = http.Client();

try {
  final response = await client
      .get(
        uri,
        headers: {
          'Accept': 'application/json,text/plain,*/*',
          'User-Agent':
              'Sa7biAI-Diagnostics/$diagnosticVersion',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      )
      .timeout(defaultTimeout);

  stopwatch.stop();

  final body = response.body;

  final success =
      response.statusCode >= 200 &&
      response.statusCode < 400;

  return DiagnosticResult(
    name: 'package:http HTTPS → Worker health',
    category: 'NETWORK',
    success: success,
    status: _statusForHttpCode(response.statusCode),
    details:
        'package:http reached Worker /health. '
        'body=${_summarizeBody(body)}',
    httpStatus: response.statusCode,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'package:http HTTPS → Worker health',
    category: 'NETWORK',
    success: false,
    status: _classifyException(e),
    details:
        'package:http could not reach Worker /health. '
        '${_safeError(e)}',
    durationMs: stopwatch.elapsedMilliseconds,
  );
} finally {
  client.close();
}

}

// ==============================================================
// TLS / HTTPS — RAW HttpClient
// ==============================================================

Future<DiagnosticResult> _checkTls() async {
final stopwatch = Stopwatch()..start();

try {
  final uri = Uri.parse(workerBaseUrl);

  if (uri.scheme.toLowerCase() != 'https') {
    stopwatch.stop();

    return DiagnosticResult(
      name: 'TLS / HTTPS',
      category: 'NETWORK',
      success: false,
      status: 'NOT_HTTPS',
      details: 'Worker URL is not using HTTPS.',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  final client = HttpClient()
    ..connectionTimeout = defaultTimeout;

  try {
    final request = await client.getUrl(uri);
    final response = await request.close();

    await response.drain();

    stopwatch.stop();

    return DiagnosticResult(
      name: 'TLS / HTTPS',
      category: 'NETWORK',
      success: response.statusCode > 0,
      status: 'HTTP_${response.statusCode}',
      details:
          'Raw dart:io HttpClient established HTTPS '
          'connection with ${uri.host}.',
      httpStatus: response.statusCode,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  } finally {
    client.close(force: true);
  }
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'TLS / HTTPS',
    category: 'NETWORK',
    success: false,
    status: 'TLS_FAILED',
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

}

// ==============================================================
// SAFE ROUTE PROBE
// ==============================================================

Future<DiagnosticResult> _probeRoute({
required String name,
required String category,
required String path,
}) async {
final stopwatch = Stopwatch()..start();

final uri = _buildUri(path);

// First try OPTIONS because it is non-generating and does not
// execute the actual AI/image operation.
final optionsResult = await _httpOptions(
  name: name,
  category: category,
  path: path,
);

if (_routeExistsFromStatus(optionsResult.httpStatus)) {
  stopwatch.stop();

  return DiagnosticResult(
    name: name,
    category: category,
    success: true,
    status: _routeProbeStatus(optionsResult.httpStatus),
    details:
        'Route is reachable without executing the actual '
        'operation. Method used: OPTIONS. '
        'URL: ${uri.toString()}. '
        'No AI/image generation request was executed.',
    httpStatus: optionsResult.httpStatus,
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

// Some Workers do not implement OPTIONS.
// A GET can still reveal whether the route exists.
final getResult = await _httpGet(
  name: name,
  category: category,
  path: path,
);

stopwatch.stop();

final status = getResult.httpStatus;

if (_routeExistsFromStatus(status)) {
  return DiagnosticResult(
    name: name,
    category: category,
    success: true,
    status: _routeProbeStatus(status),
    details:
        'Route is reachable without executing the actual '
        'generation operation. Method used: GET. '
        'A 405/401/403 can indicate the route exists even '
        'when GET itself is not the expected application method.',
    httpStatus: status,
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

if (status == 404) {
  return DiagnosticResult(
    name: name,
    category: category,
    success: false,
    status: 'ROUTE_NOT_FOUND',
    details:
        'The route returned HTTP 404. '
        'No real AI/image generation request was executed.',
    httpStatus: status,
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

return DiagnosticResult(
  name: name,
  category: category,
  success: false,
  status: getResult.status,
  details:
      'Safe route probe could not confirm the route. '
      'OPTIONS=${optionsResult.status}; '
      'GET=${getResult.status}. '
      'No real AI/image generation request was executed.',
  httpStatus: status ?? optionsResult.httpStatus,
  durationMs: stopwatch.elapsedMilliseconds,
);

}

// ==============================================================
// HTTP GET — RAW dart:io
// ==============================================================

Future<DiagnosticResult> _httpGet({
required String name,
required String category,
required String path,
}) async {
final stopwatch = Stopwatch()..start();

final uri = _buildUri(path);

final client = HttpClient()
  ..connectionTimeout = defaultTimeout;

try {
  final request = await client.getUrl(uri);

  request.headers.set(
    HttpHeaders.acceptHeader,
    'application/json, text/plain, */*',
  );

  request.headers.set(
    HttpHeaders.userAgentHeader,
    'Sa7biAI-Diagnostics/$diagnosticVersion',
  );

  final response = await request.close();

  final body = await response
      .transform(utf8.decoder)
      .join()
      .timeout(defaultTimeout);

  stopwatch.stop();

  final success = response.statusCode >= 200 &&
      response.statusCode < 400;

  return DiagnosticResult(
    name: name,
    category: category,
    success: success,
    status: _statusForHttpCode(response.statusCode),
    details: _summarizeBody(body),
    httpStatus: response.statusCode,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: name,
    category: category,
    success: false,
    status: _classifyException(e),
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
} finally {
  client.close(force: true);
}

}

// ==============================================================
// HTTP OPTIONS — RAW dart:io
// ==============================================================

Future<DiagnosticResult> _httpOptions({
required String name,
required String category,
required String path,
}) async {
final stopwatch = Stopwatch()..start();

final uri = _buildUri(path);

final client = HttpClient()
  ..connectionTimeout = defaultTimeout;

try {
  final request = await client.openUrl('OPTIONS', uri);

  request.headers.set(
    HttpHeaders.acceptHeader,
    'application/json, text/plain, */*',
  );

  request.headers.set(
    HttpHeaders.userAgentHeader,
    'Sa7biAI-Diagnostics/$diagnosticVersion',
  );

  final response = await request.close();

  final body = await response
      .transform(utf8.decoder)
      .join()
      .timeout(defaultTimeout);

  stopwatch.stop();

  return DiagnosticResult(
    name: name,
    category: category,
    success: _routeExistsFromStatus(response.statusCode),
    status: _statusForHttpCode(response.statusCode),
    details: _summarizeBody(body),
    httpStatus: response.statusCode,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: name,
    category: category,
    success: false,
    status: _classifyException(e),
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
} finally {
  client.close(force: true);
}

}

// ==============================================================
// MEDIA
// ==============================================================

Future<DiagnosticResult> _checkMediaUrlHandling() async {
final stopwatch = Stopwatch()..start();

try {
  final testUrls = <String>[
    workerBaseUrl,
    '$workerBaseUrl/health',
    '$workerBaseUrl/v1/radio/stations?country=EG',
    '$workerBaseUrl/v1/audio/search-v4?q=diagnostic',
  ];

  final parsed = <String>[];

  for (final value in testUrls) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        status: 'INVALID_URL',
        details: 'Invalid URL: $value',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    parsed.add(uri.toString());
  }

  // Verify the internal URL builder because query-string
  // handling was previously a source of problems.
  final radioUri = _buildUri(
    '/v1/radio/stations?country=EG',
  );

  final audioUri = _buildUri(
    '/v1/audio/search-v4?q=diagnostic',
  );

  final queryHandlingWorks =
      radioUri.queryParameters['country'] == 'EG' &&
          audioUri.queryParameters['q'] == 'diagnostic';

  stopwatch.stop();

  return DiagnosticResult(
    name: 'Media URL handling',
    category: 'MEDIA',
    success: queryHandlingWorks,
    status: queryHandlingWorks
        ? 'OK'
        : 'QUERY_BUILD_FAILED',
    details:
        'Parsed ${parsed.length} URLs. '
        'Internal query builder: '
        'country=${radioUri.queryParameters['country']}, '
        'q=${audioUri.queryParameters['q']}.',
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'Media URL handling',
    category: 'MEDIA',
    success: false,
    status: 'FAILED',
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

}

// ==============================================================
// MONETIZATION
// ==============================================================

Future<DiagnosticResult> _checkMonetization() async {
final stopwatch = Stopwatch()..start();

final candidates = <String>[
  '/v1/credits',
  '/v1/monetization',
  '/v1/rewards',
];

final statuses = <String>[];

for (final path in candidates) {
  try {
    final result = await _httpGet(
      name: 'Monetization probe',
      category: 'MONETIZATION',
      path: path,
    );

    statuses.add(
      '$path=${result.status}'
      '${result.httpStatus != null ? '(${result.httpStatus})' : ''}',
    );

    if (result.httpStatus != null &&
        result.httpStatus! >= 200 &&
        result.httpStatus! < 400) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Monetization endpoint',
        category: 'MONETIZATION',
        success: true,
        status: 'CONFIRMED',
        details: statuses.join(' | '),
        httpStatus: result.httpStatus,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    // 401/403 prove that the route exists.
    if (result.httpStatus == 401 ||
        result.httpStatus == 403) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Monetization endpoint',
        category: 'MONETIZATION',
        success: true,
        status: 'ROUTE_EXISTS_AUTH_REQUIRED',
        details:
            '$path exists but requires authentication/authorization. '
            '${statuses.join(' | ')}',
        httpStatus: result.httpStatus,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  } catch (e) {
    statuses.add('$path=${_safeError(e)}');
  }
}

stopwatch.stop();

return DiagnosticResult(
  name: 'Monetization endpoint',
  category: 'MONETIZATION',
  success: false,
  status: 'NOT_CONFIRMED',
  details:
      'No known monetization endpoint was confirmed. '
      '${statuses.join(' | ')}',
  durationMs: stopwatch.elapsedMilliseconds,
);

}

// ==============================================================
// ERROR CLASSIFICATION
// ==============================================================

Future<DiagnosticResult> _checkErrorClassification() async {
final stopwatch = Stopwatch()..start();

try {
  final result = await _httpGet(
    name: 'HTTP error classification',
    category: 'ERRORS',
    path: '/__sa7bi_diagnostic_missing_endpoint__',
  );

  stopwatch.stop();

  final validClassification =
      result.httpStatus == 404;

  return DiagnosticResult(
    name: 'HTTP error classification',
    category: 'ERRORS',
    success: validClassification,
    status: validClassification
        ? 'CONTROLLED_404'
        : result.status,
    details:
        'Diagnostic intentionally requested a known-missing '
        'endpoint. Expected HTTP 404. '
        'This verifies that the Worker/network can return '
        'a controlled HTTP error.',
    httpStatus: result.httpStatus,
    durationMs: stopwatch.elapsedMilliseconds,
  );
} catch (e) {
  stopwatch.stop();

  return DiagnosticResult(
    name: 'HTTP error classification',
    category: 'ERRORS',
    success: false,
    status: 'EXCEPTION',
    details: _safeError(e),
    durationMs: stopwatch.elapsedMilliseconds,
  );
}

}

// ==============================================================
// TIMEOUT
// ==============================================================

Future<DiagnosticResult> _checkTimeoutConfiguration() async {
final stopwatch = Stopwatch()..start();

final valid = defaultTimeout.inSeconds >= 5 &&
    defaultTimeout.inSeconds <= 60;

stopwatch.stop();

return DiagnosticResult(
  name: 'Timeout configuration',
  category: 'TIMEOUT',
  success: valid,
  status: valid ? 'OK' : 'INVALID',
  details:
      'Diagnostic network timeout = '
      '${defaultTimeout.inSeconds} seconds.',
  durationMs: stopwatch.elapsedMilliseconds,
);

}

// ==============================================================
// URL BUILDER
// ==============================================================

Uri _buildUri(String rawPath) {
final raw = rawPath.trim();

if (raw.startsWith('http://') ||
    raw.startsWith('https://')) {
  return Uri.parse(raw);
}

final base = Uri.parse(workerBaseUrl);

final normalized =
    raw.startsWith('/') ? raw : '/$raw';

final parsed = Uri.parse(normalized);

return base.replace(
  path: parsed.path,
  queryParameters: parsed.queryParameters.isEmpty
      ? null
      : parsed.queryParameters,
);

}

// ==============================================================
// HELPERS
// ==============================================================

bool _routeExistsFromStatus(int? status) {
if (status == null) {
return false;
}

// 2xx = route reachable.
if (status >= 200 && status < 300) {
  return true;
}

// 3xx = route reachable and redirecting.
if (status >= 300 && status < 400) {
  return true;
}

// 401/403 = route exists but protected.
if (status == 401 || status == 403) {
  return true;
}

// 405 = route exists but the diagnostic HTTP method
// is not the method expected by the endpoint.
if (status == 405) {
  return true;
}

return false;

}

String _routeProbeStatus(int? status) {
if (status == null) {
return 'UNKNOWN';
}

if (status >= 200 && status < 300) {
  return 'ROUTE_REACHABLE';
}

if (status >= 300 && status < 400) {
  return 'ROUTE_REDIRECT';
}

if (status == 401) {
  return 'ROUTE_EXISTS_AUTH_REQUIRED';
}

if (status == 403) {
  return 'ROUTE_EXISTS_FORBIDDEN';
}

if (status == 405) {
  return 'ROUTE_EXISTS_METHOD_REQUIRED';
}

if (status == 404) {
  return 'ROUTE_NOT_FOUND';
}

if (status >= 500) {
  return 'SERVER_ERROR';
}

return 'HTTP_$status';

}

String _statusForHttpCode(int statusCode) {
if (statusCode == 401) {
return 'HTTP_401_AUTH_REQUIRED';
}

if (statusCode == 403) {
  return 'HTTP_403_FORBIDDEN';
}

if (statusCode == 404) {
  return 'HTTP_404_NOT_FOUND';
}

if (statusCode == 405) {
  return 'HTTP_405_METHOD_NOT_ALLOWED';
}

if (statusCode >= 500) {
  return 'HTTP_${statusCode}_SERVER_ERROR';
}

if (statusCode >= 400) {
  return 'HTTP_${statusCode}_CLIENT_ERROR';
}

if (statusCode >= 300) {
  return 'HTTP_${statusCode}_REDIRECT';
}

if (statusCode >= 200) {
  return 'HTTP_${statusCode}_OK';
}

return 'HTTP_$statusCode';

}

String _summarizeBody(String body) {
if (body.isEmpty) {
return 'Empty response body.';
}

final cleaned =
    body.replaceAll(RegExp(r'\s+'), ' ').trim();

if (cleaned.length <= 800) {
  return cleaned;
}

return '${cleaned.substring(0, 800)}…';

}

String _classifyException(Object error) {
final value = error.toString().toLowerCase();

if (value.contains('timeout')) {
  return 'TIMEOUT';
}

if (value.contains('socket')) {
  return 'SOCKET_ERROR';
}

if (value.contains('certificate') ||
    value.contains('tls') ||
    value.contains('ssl')) {
  return 'TLS_ERROR';
}

if (value.contains('failed host lookup') ||
    value.contains('dns')) {
  return 'DNS_ERROR';
}

if (value.contains('network is unreachable')) {
  return 'NETWORK_UNREACHABLE';
}

if (value.contains('connection refused')) {
  return 'CONNECTION_REFUSED';
}

return 'NETWORK_ERROR';

}

String _safeError(Object error) {
return error
.toString()
.replaceAll(RegExp(r'\s+'), ' ')
.trim();
}
}
