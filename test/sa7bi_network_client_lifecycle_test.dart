
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sa7bi_ai/services/sa7bi_network_client.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
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
    'consecutive requests work with the same Zone client',
    () async {
      await http.runWithClient(
        () async {
          final first = await http.get(baseUri.resolve('/first'));
          final second = await http.get(baseUri.resolve('/second'));

          expect(first.statusCode, HttpStatus.ok);
          expect(second.statusCode, HttpStatus.ok);
          expect(first.body, 'ok');
          expect(second.body, 'ok');
        },
        Sa7biNetworkClient.factory,
      );
    },
  );

  test(
    'Zone client does not close the persistent client',
    () async {
      final persistentClient = Sa7biNetworkClient.client;

      await http.runWithClient(
        () async {
          final response = await http.get(baseUri.resolve('/zone'));
          expect(response.statusCode, HttpStatus.ok);
        },
        Sa7biNetworkClient.factory,
      );

      final response = await persistentClient.get(
        baseUri.resolve('/persistent'),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'ok');
    },
  );

  test(
    'failed health response does not prevent the next request',
    () async {
      final client = Sa7biNetworkClient.client;

      final healthResponse = await client.get(
        baseUri.resolve('/health-fail'),
      );

      expect(
        healthResponse.statusCode,
        HttpStatus.serviceUnavailable,
      );

      final nextResponse = await client.get(
        baseUri.resolve('/next'),
      );

      expect(nextResponse.statusCode, HttpStatus.ok);
      expect(nextResponse.body, 'ok');
    },
  );

  test(
    'persistent client can be recreated after close',
    () async {
      final oldClient = Sa7biNetworkClient.client;

      final firstResponse = await oldClient.get(
        baseUri.resolve('/before-close'),
      );

      expect(firstResponse.statusCode, HttpStatus.ok);

      Sa7biNetworkClient.close();

      final newClient = Sa7biNetworkClient.client;

      expect(identical(oldClient, newClient), isFalse);

      final secondResponse = await newClient.get(
        baseUri.resolve('/after-close'),
      );

      expect(secondResponse.statusCode, HttpStatus.ok);
      expect(secondResponse.body, 'ok');
    },
  );
}
