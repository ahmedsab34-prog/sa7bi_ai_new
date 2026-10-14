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

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('ok');

        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      Sa7biNetworkClient.close();
    });

    test(
      'two consecutive top-level requests use independent Zone clients',
      () async {
        final uri = Uri.parse(
          'http://127.0.0.1:${server.port}/health',
        );

        final statuses = await http.runWithClient(
          () async {
            final first = await http.get(uri).timeout(
              const Duration(seconds: 3),
            );

            final second = await http.get(uri).timeout(
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

        expect(
          identical(zoneClient, persistent),
          isFalse,
        );

        zoneClient.close();

        expect(
          identical(Sa7biNetworkClient.client, persistent),
          isTrue,
        );

        final response = await persistent
            .get(
              Uri.parse(
                'http://127.0.0.1:${server.port}/persistent',
              ),
            )
            .timeout(
              const Duration(seconds: 3),
            );

        expect(
          response.statusCode,
          HttpStatus.ok,
        );
      },
    );
  });
}
