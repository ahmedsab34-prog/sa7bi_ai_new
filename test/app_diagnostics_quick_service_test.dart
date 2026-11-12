import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sa7bi_ai/services/app_diagnostics_quick_service.dart';

void main() {
  group('AppDiagnosticsQuickService', () {
    test(
      'checks both Workers and confirms matching source identity',
      () async {
        final requests = <http.Request>[];

        final client = MockClient((request) async {
          requests.add(request);

          if (request.url.path == '/health') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'sourceCommit': 'abc123',
              }),
              200,
              headers: {
                'content-type': 'application/json',
              },
            );
          }

          if (request.url.host == 'example.com') {
            return http.Response('ok', 200);
          }

          return http.Response('not found', 404);
        });

        final service = AppDiagnosticsQuickService(
          client: client,
          buildId: 'build-123',
          sourceId: 'source-123',
          commitSha: 'abc123',
          appVersion: '1.0.1',
          buildNumber: '1',
          primaryWorkerUrl:
              'https://primary.example.workers.dev',
          fallbackWorkerUrl:
              'https://fallback.example.workers.dev',
        );

        final report = await service.runQuickDiagnostics();

        final identity = report.results.singleWhere(
          (result) =>
              result.name == 'Build/source identity',
        );

        final primary = report.results.singleWhere(
          (result) =>
              result.name == 'Primary Worker direct HTTPS',
        );

        final fallback = report.results.singleWhere(
          (result) =>
              result.name == 'Fallback Worker direct HTTPS',
        );

        expect(identity.success, isTrue);
        expect(
          identity.status,
          'APP_AND_WORKER_COMMIT_MATCH',
        );
        expect(primary.success, isTrue);
        expect(fallback.success, isTrue);

        expect(
          requests.map((request) => request.method).toSet(),
          {'GET'},
        );

        expect(
          requests.any(
            (request) =>
                request.url.host ==
                'primary.example.workers.dev',
          ),
          isTrue,
        );

        expect(
          requests.any(
            (request) =>
                request.url.host ==
                'fallback.example.workers.dev',
          ),
          isTrue,
        );

        expect(
          requests.every(
            (request) =>
                request.url.path == '/health' ||
                request.url.host == 'example.com',
          ),
          isTrue,
        );

        expect(report.total, 6);

        client.close();
      },
    );

    test(
      'reports a failure when Worker source commit differs from APK',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/health') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'sourceCommit': 'different-commit',
              }),
              200,
              headers: {
                'content-type': 'application/json',
              },
            );
          }

          if (request.url.host == 'example.com') {
            return http.Response('ok', 200);
          }

          return http.Response('', 404);
        });

        final service = AppDiagnosticsQuickService(
          client: client,
          buildId: 'build-123',
          sourceId: 'source-123',
          commitSha: 'abc123',
          primaryWorkerUrl:
              'https://primary.example.workers.dev',
          fallbackWorkerUrl:
              'https://fallback.example.workers.dev',
        );

        final report = await service.runQuickDiagnostics();

        final identity = report.results.singleWhere(
          (result) =>
              result.name == 'Build/source identity',
        );

        expect(identity.success, isFalse);
        expect(identity.severity, 'FAIL');
        expect(
          identity.status,
          'WORKER_SOURCE_MISMATCH',
        );

        client.close();
      },
    );
  });
}
