@TestOn('vm')

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'package:rest_api_server/api_server.dart';
import 'package:rest_api_server/http_exception_middleware.dart';
import 'package:rest_api_server/http_exception.dart';

void main() {
  ApiServer server;
  final address = InternetAddress.loopbackIPv4;
  final port = 3000 + Random().nextInt(1000);

  setUpAll(() async {
    server = ApiServer(
        address: address,
        port: port,
        handler: shelf.Pipeline()
            .addMiddleware(HttpExceptionMiddleware())
            .addHandler((shelf.Request request) {
          switch (request.requestedUri.path) {
            case '/unauthorized':
              throw (UnauthorizedException({}, 'login failed'));
              break;
            case '/format_exception':
              throw (FormatException('wrong format'));
              break;
            default:
              return shelf.Response.ok('Ok');
          }
        }));
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  test('http exception thrown by handler', () async {
    final request = await HttpClient()
        .get(server.address.host, server.port, '/unauthorized');
    final response = await request.close();
    expect(response.transform(utf8.decoder).transform(json.decoder).join(),
        completion('login failed'));
    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('internal server error', () async {
    final request = await HttpClient()
        .get(server.address.host, server.port, '/format_exception');
    final response = await request.close();
    expect(response.transform(utf8.decoder).transform(json.decoder).join(),
        completion(startsWith('FormatException: wrong format')));
    expect(response.statusCode, HttpStatus.internalServerError);
  });
}
