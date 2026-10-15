import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sa7bi_ai/services/sa7bi_network_client.dart';

void main() {
  group('Sa7biNetworkClient lifecycle', () {
    late HttpServer server;
    late Uri baseUri;
    late StreamSubscription<HttpRequest> serverSubscription;

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

      serverSubscription = server.listen((request) async {
        requestPaths.add(request.uri.path);

        if (request.uri.path == '/health-fail') {
          request.response
            ..statusCode = HttpStatus.serviceUnavailable
            ..write('health check failed');
        } else if (request.uri.path == '/slow') {
          await Future<void>.delayed(
            const Duration(milliseconds: 300),
          );

          request.response
            ..statusCode = HttpStatus.ok
            ..write('slow response');
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('ok');
        }

        try {
          await request.response.close();
        } on HttpException {
          // The test server may already have been closed.
        } on SocketException {
          // The client or server may have disconnected.
        }
      });
    });

    tearDown(() async {
      Sa7biNetworkClient.close();
      await serverSubscription.cancel();
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

    test(
      'a timed-out request does not stop the next request',
      () async {
        final client = Sa7biNetworkClient.client;

        await expectLater(
          client
              .get(baseUri.resolve('/slow'))
              .timeout(const Duration(milliseconds: 50)),
          throwsA(isA<TimeoutException>()),
        );

        final next = await client
            .get(baseUri.resolve('/after-timeout'))
            .timeout(const Duration(seconds: 5));

        expect(next.statusCode, HttpStatus.ok);
        expect(next.body, 'ok');
        expect(requestPaths, contains('/slow'));
        expect(requestPaths, contains('/after-timeout'));
      },
    );
  });
}
