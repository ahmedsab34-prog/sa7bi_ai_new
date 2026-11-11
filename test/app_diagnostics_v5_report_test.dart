
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/app_diagnostics_service.dart';
import 'package:sa7bi_ai/services/app_diagnostics_v5_service.dart';

DiagnosticResult _result({
  required String name,
  required String category,
  required String severity,
  required String status,
  required String details,
  int durationMs = 0,
  bool blocked = false,
}) {
  return DiagnosticResult(
    name: name,
    category: category,
    success: severity == 'PASS',
    severity: severity,
    status: status,
    details: details,
    durationMs: durationMs,
    blocked: blocked,
  );
}

AppDiagnosticsV5Report _report(
  List<DiagnosticResult> results,
) {
  final startedAt = DateTime.utc(2026, 11, 11, 10);

  return AppDiagnosticsV5Report(
    startedAt: startedAt,
    finishedAt: startedAt.add(
      const Duration(seconds: 4),
    ),
    results: results,
  );
}

void main() {
  group('AppDiagnosticsV5Report summary', () {
    test('counts passed, warnings, failures and blocked tests', () {
      final report = _report([
        _result(
          name: 'Worker health',
          category: 'WORKER',
          severity: 'PASS',
          status: 'HTTP_200_OK',
          details: 'Worker responded.',
          durationMs: 120,
        ),
        _result(
          name: 'Quran catalog',
          category: 'QURAN',
          severity: 'PASS',
          status: 'PAYLOAD_VALID',
          details: 'Reciters and suras are available.',
          durationMs: 240,
        ),
        _result(
          name: 'Camera permission',
          category: 'DEVICE',
          severity: 'WARN',
          status: 'NOT_GRANTED',
          details: 'Camera permission is not granted.',
          blocked: true,
        ),
        _result(
          name: 'Real AI conversation',
          category: 'AI',
          severity: 'WARN',
          status: 'NOT_TESTED_SAFETY',
          details: 'A paid inference request was not sent.',
          blocked: true,
        ),
        _result(
          name: 'Radio stream bytes',
          category: 'RADIO',
          severity: 'FAIL',
          status: 'STREAM_EMPTY',
          details: 'No media bytes were received.',
          durationMs: 900,
        ),
      ]);

      expect(report.passed, 2);
      expect(report.warnings, 2);
      expect(report.failed, 1);
      expect(report.blocked, 2);
      expect(report.notTested, 2);
      expect(report.total, 5);
      expect(report.duration, const Duration(seconds: 4));
    });

    test('does not report a root failure when checks only warn', () {
      final report = _report([
        _result(
          name: 'TTS engine',
          category: 'DEVICE',
          severity: 'WARN',
          status: 'TTS_ENGINE_NOT_FOUND',
          details: 'No engine was detected.',
          blocked: true,
        ),
        _result(
          name: 'Ad inventory',
          category: 'MONETIZATION',
          severity: 'WARN',
          status: 'NOT_TESTED_SAFETY',
          details: 'No ad was loaded.',
          blocked: true,
        ),
      ]);

      expect(report.rootCauseCode, 'NO_CONFIRMED_FAILURE');
      expect(
        report.primaryProblem,
        contains('لم يظهر فشل قاطع'),
      );
    });

    test('build identity failure has the highest root cause priority', () {
      final report = _report([
        _result(
          name: 'Worker HTTPS health',
          category: 'NETWORK',
          severity: 'FAIL',
          status: 'TIMEOUT',
          details: 'Worker timed out.',
        ),
        _result(
          name: 'Build/source identity',
          category: 'BUILD',
          severity: 'FAIL',
          status: 'WORKER_SOURCE_MISMATCH',
          details: 'APK and Worker commits differ.',
        ),
      ]);

      expect(report.rootCauseCode, 'BUILD_IDENTITY');
      expect(
        report.primaryProblem,
        contains('Worker timed out'),
      );
    });

    test('network failure is identified before feature failures', () {
      final report = _report([
        _result(
          name: 'Radio stream',
          category: 'RADIO',
          severity: 'FAIL',
          status: 'STREAM_EMPTY',
          details: 'No stream bytes.',
        ),
        _result(
          name: 'Worker HTTPS health',
          category: 'NETWORK',
          severity: 'FAIL',
          status: 'TLS_ERROR',
          details: 'TLS handshake failed.',
        ),
      ]);

      expect(report.rootCauseCode, 'NETWORK_FAILURE');
    });

    test('feature failure identifies its category', () {
      final report = _report([
        _result(
          name: 'Radio stream bytes',
          category: 'RADIO',
          severity: 'FAIL',
          status: 'STREAM_HTTP_404',
          details: 'Station stream not found.',
        ),
      ]);

      expect(report.rootCauseCode, 'FEATURE_RADIO_FAILURE');
      expect(
        report.primaryProblem,
        contains('Station stream not found'),
      );
    });
  });

  group('AppDiagnosticsV5Report serialization', () {
    test('exports summary, coverage and result details as JSON', () {
      final report = _report([
        _result(
          name: 'Hadith content sample',
          category: 'HADITH',
          severity: 'PASS',
          status: 'PAYLOAD_VALID',
          details: 'Three valid hadith items were returned.',
          durationMs: 320,
        ),
        _result(
          name: 'Social posts',
          category: 'SOCIAL',
          severity: 'WARN',
          status: 'NOT_TESTED_SAFETY',
          details: 'No post was created.',
          blocked: true,
        ),
      ]);

      final json = report.toJson();
      final summary = json['summary'] as Map<String, dynamic>;
      final coverage = json['coverage'] as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>;

      expect(json['reportVersion'], '5.0.0');
      expect(summary['passed'], 1);
      expect(summary['warnings'], 1);
      expect(summary['failed'], 0);
      expect(summary['blocked'], 1);
      expect(summary['notTested'], 1);
      expect(summary['total'], 2);

      expect(
        coverage['paidAiInference'],
        'not_executed',
      );
      expect(
        coverage['speakerPlayback'],
        'not_executed',
      );
      expect(
        coverage['servicePayloads'],
        'validated',
      );

      expect(results, hasLength(2));
      expect(
        (results.first as Map<String, dynamic>)['name'],
        'Hadith content sample',
      );

      expect(
        report.toPrettyJson(),
        contains('"reportVersion": "5.0.0"'),
      );
    });

    test('text report lists tested and untested results', () {
      final report = _report([
        _result(
          name: 'Quran audio stream bytes',
          category: 'QURAN',
          severity: 'PASS',
          status: 'STREAM_BYTES_RECEIVED',
          details: 'Media bytes received.',
        ),
        _result(
          name: 'Real speaker playback',
          category: 'AUDIO',
          severity: 'WARN',
          status: 'NOT_TESTED_SAFETY',
          details: 'Speaker playback was not started.',
          blocked: true,
        ),
      ]);

      final text = report.toTextReport();

      expect(text, contains('SA7BI AI DIAGNOSTIC REPORT'));
      expect(text, contains('Report version: 5.0.0'));
      expect(text, contains('Quran audio stream bytes'));
      expect(text, contains('Real speaker playback'));
      expect(text, contains('Not tested: 1'));
      expect(
        text,
        contains('نجاح HTTP لا يعني نجاح تشغيل كل ميزة'),
      );
    });

    test('slowest results are sorted by duration descending', () {
      final results = List<DiagnosticResult>.generate(
        10,
        (index) => _result(
          name: 'Test $index',
          category: 'TEST',
          severity: 'PASS',
          status: 'OK',
          details: 'Test result $index.',
          durationMs: index * 100,
        ),
      );

      final report = _report(results);

      expect(report.slowestResults, hasLength(7));
      expect(report.slowestResults.first.name, 'Test 9');
      expect(report.slowestResults.first.durationMs, 900);
      expect(report.slowestResults.last.name, 'Test 3');
      expect(report.slowestResults.last.durationMs, 300);
    });
  });
}
