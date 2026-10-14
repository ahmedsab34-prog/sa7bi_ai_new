
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sa7bi_ai/services/sa7bi_network_client.dart';

void main() {
  group('Sa7biNetworkClient lifecycle', () {
    late HttpServer server;
    late Uri baseUri;
    final requestPaths = <String>[];

    setUp(() async {
      requestPaths.clear();

      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );

      baseUri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
      );

      server.listen((request) async {
        requestPaths.add(request.uri.path);

        if (request.uri.path == '/health-fail') {
          request.response
            ..statusCode = HttpStatus.serviceUnavailable
            ..write('health check failed');
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('ok');
        }

        await request.response.close();
      });
    });

    tearDown(() async {
      Sa7biNetworkClient.close();
      await server.close(force: true);
    });

    test(
      'consecutive requests work in the same Zone',
      () async {
        await http.runWithClient(
          () async {
            final first = await http
                .get(baseUri.resolve('/first'))
                .timeout(const Duration(seconds: 5));

            final second = await http
                .get(baseUri.resolve('/second'))
                .timeout(const Duration(seconds: 5));

            expect(first.statusCode, HttpStatus.ok);
            expect(second.statusCode, HttpStatus.ok);
            expect(first.body, 'ok');
            expect(second.body, 'ok');
          },
          Sa7biNetworkClient.factory,
        );

        expect(requestPaths, contains('/first'));
        expect(requestPaths, contains('/second'));
      },
    );

    test(
      'Zone client is independent from persistent client',
      () async {
        final persistent = Sa7biNetworkClient.client;
        final zoneClient = Sa7biNetworkClient.factory();

        expect(identical(zoneClient, persistent), isFalse);

        zoneClient.close();

        final response = await persistent
            .get(baseUri.resolve('/persistent'))
            .timeout(const Duration(seconds: 5));

        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'ok');
      },
    );

    test(
      'HTTP 503 does not prevent the next request',
      () async {
        final client = Sa7biNetworkClient.client;

        final failedHealth = await client
            .get(baseUri.resolve('/health-fail'))
            .timeout(const Duration(seconds: 5));

        expect(
          failedHealth.statusCode,
          HttpStatus.serviceUnavailable,
        );

        final next = await client
            .get(baseUri.resolve('/next'))
            .timeout(const Duration(seconds: 5));

        expect(next.statusCode, HttpStatus.ok);
        expect(next.body, 'ok');
      },
    );

    test(
      'persistent client can be recreated after close',
      () async {
        final oldClient = Sa7biNetworkClient.client;

        final before = await oldClient
            .get(baseUri.resolve('/before-close'))
            .timeout(const Duration(seconds: 5));

        expect(before.statusCode, HttpStatus.ok);

        Sa7biNetworkClient.close();

        final newClient = Sa7biNetworkClient.client;

        expect(identical(oldClient, newClient), isFalse);

        final after = await newClient
            .get(baseUri.resolve('/after-close'))
            .timeout(const Duration(seconds: 5));

        expect(after.statusCode, HttpStatus.ok);
        expect(after.body, 'ok');
      },
    );
  });
}
