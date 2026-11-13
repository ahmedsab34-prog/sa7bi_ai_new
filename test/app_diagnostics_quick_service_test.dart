import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sa7bi_ai/services/app_diagnostics_quick_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDiagnosticsQuickService', () {
    test(
      'checks both Workers, performance and matching source identity',
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

        final performanceResults =
            report.results.where(
          (result) =>
              result.category == 'PERFORMANCE',
        );

        expect(identity.success, isTrue);

        expect(
          identity.status,
          'APP_AND_WORKER_COMMIT_MATCH',
        );

        expect(identity.details, contains('primaryMatch=true'));
        expect(identity.details, contains('fallbackMatch=true'));

        expect(primary.success, isTrue);
        expect(fallback.success, isTrue);

        expect(
          performanceResults,
          hasLength(4),
        );

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

        // 6 build/network checks + 4 performance checks.
        expect(report.total, 10);

        client.close();
      },
    );

    test(
      'reports a failure when only the Primary Worker source differs from the APK',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/health') {
            final sourceCommit =
                request.url.host == 'primary.example.workers.dev'
                    ? 'different-primary'
                    : 'abc123';

            return http.Response(
              jsonEncode({
                'ok': true,
                'sourceCommit': sourceCommit,
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

        expect(identity.details, contains('primaryMatch=false'));
        expect(identity.details, contains('fallbackMatch=true'));

        client.close();
      },
    );

    test(
      'reports a failure when only the Fallback Worker source differs from the APK',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/health') {
            final sourceCommit =
                request.url.host == 'primary.example.workers.dev'
                    ? 'abc123'
                    : 'different-fallback';

            return http.Response(
              jsonEncode({
                'ok': true,
                'sourceCommit': sourceCommit,
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

        expect(identity.details, contains('primaryMatch=true'));
        expect(identity.details, contains('fallbackMatch=false'));

        client.close();
      },
    );
  });
}
