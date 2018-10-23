@TestOn('vm')

import 'dart:async';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:rest_api_server/auth_middleware.dart';

void main() {
  test('jwt issue with expiry date', () {
    final issuedAt = DateTime.now();
    final expiry = issuedAt.add(Duration(hours: 1));
    final jwt = Jwt(
        securityKey: 'secret key',
        issuer: 'Roga & Kopyta',
        audience: 'example.com',
        expiry: expiry);

    final token = jwt.issue('user');
    List<String> parts = token.split('.');
    expect(parts.length, 3);

    String jwtHeader = parts[0];
    final expectedHeader = <String, String>{'alg': 'HS256', 'typ': 'JWT'};
    expect(json.decode(String.fromCharCodes(base64.decode(jwtHeader))),
        expectedHeader);

    String jwtPayload = parts[1];
    final expectedPayload = <String, dynamic>{
      'aud': ['example.com'],
      'exp': (expiry.millisecondsSinceEpoch / 1000).floor(),
      'iat': (issuedAt.millisecondsSinceEpoch / 1000).floor(),
      'iss': 'Roga & Kopyta',
      'sub': 'user'
    };
    expect(json.decode(String.fromCharCodes(base64.decode(jwtPayload))),
        expectedPayload);
  });

  test('jwt issue with maxAge', () {
    final issuedAt = DateTime.now();
    final maxAge = Duration(days: 1);

    final jwt = Jwt(
        securityKey: 'secret key',
        issuer: 'Roga & Kopyta',
        audience: 'example.com',
        maxAge: maxAge);

    final token = jwt.issue('user');
    List<String> parts = token.split('.');
    expect(parts.length, 3);

    String jwtHeader = parts[0];
    final expectedHeader = <String, String>{'alg': 'HS256', 'typ': 'JWT'};
    expect(json.decode(String.fromCharCodes(base64.decode(jwtHeader))),
        expectedHeader);

    String jwtPayload = parts[1];
    final expectedPayload = <String, dynamic>{
      'aud': ['example.com'],
      'exp': (issuedAt.add(maxAge).millisecondsSinceEpoch / 1000).floor(),
      'iat': (issuedAt.millisecondsSinceEpoch / 1000).floor(),
      'iss': 'Roga & Kopyta',
      'sub': 'user'
    };
    expect(json.decode(String.fromCharCodes(base64.decode(jwtPayload))),
        expectedPayload);
  });

  test('decode correct jwt', () {
    final jwt = Jwt(
      securityKey: 'secret key',
      issuer: 'Roga & Kopyta',
      audience: 'example.com',
      maxAge: Duration(days: 1),
    );
    final token = jwt.issue('user', payload: {'param': 'value'});
    expect(() {
      jwt.decode(token);
    }, isNot(throwsException));
  });

  test('decode incorrect jwt', () {
    final jwt = Jwt(
        securityKey: 'secret key',
        issuer: 'Roga & Kopyta',
        audience: 'example.com',
        maxAge: Duration(days: 1));
    final token = jwt.issue('user');
    final parts = token.split('.');
    final Map<String, dynamic> payload =
        json.decode(String.fromCharCodes(base64.decode(parts[1])));
    payload['sub'] = 'other';
    parts[1] = base64.encode(json.encode(payload).codeUnits);
    String incorrectToken = parts.join('.');
    expect(() {
      jwt.decode(incorrectToken);
    },
        throwsA(predicate(
            (e) => e is JwtException && e.message == 'JWT hash mismatch!')));
  });

  test('expired jwt', () async {
    final jwt = Jwt(
        securityKey: 'secret key',
        issuer: 'Roga & Kopyta',
        audience: 'example.com',
        maxAge: Duration(milliseconds: 100));
    final token = jwt.issue('user');
    await Future.delayed(Duration(milliseconds: 101));
    expect(() {
      jwt.decode(token);
    },
        throwsA(predicate(
            (e) => e is JwtException && e.message == 'JWT token expired!')));
  });
}
