@TestOn('vm')

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'package:rest_api_server/api_server.dart';

void main() {
  ApiServer server;
  final address = InternetAddress.loopbackIPv4;
  final pingHandler = shelf.Pipeline().addHandler((request) async {
    final body = await request.readAsString();
    if (body == 'ping') {
      return shelf.Response.ok('pong');
    } else {
      return shelf.Response(HttpStatus.badRequest);
    }
  });

  setUpAll(() async {
    server = ApiServer(
        address: address,
        port: 3000 + Random().nextInt(1000),
        handler: pingHandler);
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  test('start api server', () async {
    final request =
        await HttpClient().post(server.address.host, server.port, '');
    request.write('ping');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    expect(response.statusCode, HttpStatus.ok);
    expect(body, 'pong');
  });

  test('bad request', () async {
    final request =
        await HttpClient().post(server.address.host, server.port, '');
    request.write('bad request');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.badRequest);
  });
}
