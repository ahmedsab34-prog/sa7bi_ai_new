
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:sa7bi_ai/services/sa7bi_network_client.dart';

void main() {
  group('Sa7biNetworkClient lifecycle', () {
    late HttpServer server;
    var requestCount = 0;

    setUp(() async {
      requestCount = 0;

      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );

      server.listen((request) async {
        requestCount++;

        // محاكاة فشل فحص الصحة ثم استعادة الخدمة.
        final failedHealthProbe =
            request.uri.path == '/health-fail';

        request.response
          ..statusCode = failedHealthProbe
              ? HttpStatus.serviceUnavailable
              : HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write(failedHealthProbe ? 'unavailable' : 'ok');

        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      Sa7biNetworkClient.close();
    });

    Uri localUri(String path) =>
        Uri.parse('http://127.0.0.1:${server.port}$path');

    test(
      'two consecutive top-level requests use independent Zone clients',
      () async {
        final statuses = await http.runWithClient(
          () async {
            final first = await http.get(localUri('/health')).timeout(
              const Duration(seconds: 3),
            );

            final second = await http.get(localUri('/health')).timeout(
              const Duration(seconds: 3),
            );

            return <int>[
              first.statusCode,
              second.statusCode,
            ];
          },
          Sa7biNetworkClient.factory,
        );

        expect(
          statuses,
          <int>[
            HttpStatus.ok,
            HttpStatus.ok,
          ],
        );

        expect(requestCount, 2);
      },
    );

    test(
      'closing a Zone client does not close the persistent service client',
      () async {
        final persistent = Sa7biNetworkClient.client;
        final zoneClient = Sa7biNetworkClient.factory();

        expect(identical(zoneClient, persistent), isFalse);

        zoneClient.close();

        expect(
          identical(Sa7biNetworkClient.client, persistent),
          isTrue,
        );

        final response = await persistent
            .get(localUri('/persistent'))
            .timeout(const Duration(seconds: 3));

        expect(response.statusCode, HttpStatus.ok);
      },
    );

    test(
      'failed health response does not poison the next request',
      () async {
        final persistent = Sa7biNetworkClient.client;

        final failedProbe = await persistent
            .get(localUri('/health-fail'))
            .timeout(const Duration(seconds: 3));

        expect(
          failedProbe.statusCode,
          HttpStatus.serviceUnavailable,
        );

        final nextResponse = await persistent
            .get(localUri('/health-next'))
            .timeout(const Duration(seconds: 3));

        expect(nextResponse.statusCode, HttpStatus.ok);
        expect(requestCount, 2);
      },
    );

    test(
      'a closed Zone client can be replaced by a fresh client',
      () async {
        final oldZoneClient = Sa7biNetworkClient.factory();
        oldZoneClient.close();

        final freshZoneClient = Sa7biNetworkClient.factory();

        expect(
          identical(oldZoneClient, freshZoneClient),
          isFalse,
        );

        final response = await freshZoneClient
            .get(localUri('/fresh'))
            .timeout(const Duration(seconds: 3));

        expect(response.statusCode, HttpStatus.ok);

        freshZoneClient.close();
      },
    );
  });
}
