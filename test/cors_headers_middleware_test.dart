@TestOn('vm')

import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'package:rest_api_server/api_server.dart';
import 'package:rest_api_server/cors_headers_middleware.dart';

void main() {
  ApiServer server;
  final address = InternetAddress.loopbackIPv4;
  final port = 3000 + Random().nextInt(1000);

  setUpAll(() async {
    server = ApiServer(
        address: address,
        port: port,
        handler: shelf.Pipeline()
            .addMiddleware(
                CorsHeadersMiddleware({'Access-Control-Allow-Origin': '*'}))
            .addHandler((shelf.Request request) => shelf.Response.ok('Ok',
                headers: {'Access-Control-Allow-Origin': 'domain.com'})));
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  test('request method OPTIONS', () async {
    final request = await HttpClient()
        .open('OPTIONS', server.address.host, server.port, '');
    final response = await request.close();
    expect(response.headers.value('Access-Control-Allow-Origin'), '*');
  });

  test('rewrite default CORS headers', () async {
    final request =
        await HttpClient().post(server.address.host, server.port, '');
    final response = await request.close();
    expect(response.headers.value('Access-Control-Allow-Origin'), 'domain.com');
  });
}
