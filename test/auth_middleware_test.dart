@TestOn('vm')

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'package:rest_api_server/api_server.dart';
import 'package:rest_api_server/auth_middleware.dart';

void main() {
  ApiServer server;
  final address = InternetAddress.loopbackIPv4;
  final port = 3000 + Random().nextInt(1000);
  final jwt = Jwt(
      securityKey: 'qwerty',
      issuer: 'Roga & Kopyta',
      maxAge: Duration(seconds: 1));

  setUpAll(() async {
    server = ApiServer(
        address: address,
        port: port,
        handler: shelf.Pipeline()
            .addMiddleware(AuthMiddleware(
                loginPath: '/login',
                exclude: const {
                  'GET': ['/anonimous'],
                  'POST': ['/login']
                },
                jwt: jwt))
            .addHandler((shelf.Request request) {
          switch (request.requestedUri.path) {
            case '/login':
              return shelf.Response.ok('Ok', context: {
                'subject': 'user',
                'payload': {'id': 'user', 'role': 'admin'}
              });
              break;
            case '/anonimous':
              return shelf.Response.ok('Ok');
            default:
              final String user = request.context['subject'] ?? '';
              if (user.isEmpty || user != 'user') {
                return shelf.Response(HttpStatus.unauthorized);
              }
              return shelf.Response.ok('Ok');
          }
        }));
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  test('anonimous allowed access', () async {
    HttpClientRequest request =
        await HttpClient().get(server.address.host, server.port, '/anonimous');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
  });

  test('anonimous access to restricted resource', () async {
    HttpClientRequest request =
        await HttpClient().get(server.address.host, server.port, '/restricted');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.unauthorized);
    String message = await response.transform(utf8.decoder).transform(json.decoder).join();
    expect(message, 'Unauthorized: Authorization header is not provided');
  });

  test('access to anonimous resource with not allowed method', () async {
    HttpClientRequest request =
        await HttpClient().post(server.address.host, server.port, '/anonimous');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.unauthorized);
    String message = await response.transform(utf8.decoder).transform(json.decoder).join();
    expect(message, 'Unauthorized: Authorization header is not provided');
  });

  test('login', () async {
    HttpClientRequest request =
        await HttpClient().post(server.address.host, server.port, '/login');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final token = response.headers.value(HttpHeaders.authorizationHeader);
    expect(token, isNotNull);
    final jwtPayload =
        json.decode(String.fromCharCodes(base64.decode(token.split('.')[1])));
    expect(jwtPayload['sub'], 'user');
    expect(jwtPayload['pld'], {'id': 'user', 'role': 'admin'});
  });

  test('authenticated access', () async {
    HttpClientRequest request =
        await HttpClient().post(server.address.host, server.port, '/login');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final token = response.headers.value(HttpHeaders.authorizationHeader);
    request =
        await HttpClient().get(server.address.host, server.port, '/restricted');
    request.headers.add(HttpHeaders.authorizationHeader, token);
    response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
  });

  test('session timeout', () async {
    HttpClientRequest request =
        await HttpClient().post(server.address.host, server.port, '/login');
    HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final token = response.headers.value(HttpHeaders.authorizationHeader);
    await Future.delayed(Duration(milliseconds: 1000));
    request =
        await HttpClient().get(server.address.host, server.port, '/restricted');
    request.headers.add(HttpHeaders.authorizationHeader, token);
    response = await request.close();
    expect(response.statusCode, HttpStatus.unauthorized);
    String message = await response.transform(utf8.decoder).transform(json.decoder).join();
    expect(message, 'JWT token expired!');
  });
}
