import 'dart:math';

import 'package:jaguar_jwt/jaguar_jwt.dart';

export 'package:jaguar_jwt/jaguar_jwt.dart' show JwtException, JwtClaim;

/// JWT manager
///
/// The manager is responsible for:
///
/// * issue jwt
/// * verify jwt
/// * decode jwt
class Jwt {
  String _key;
  final String _issuer;
  final String _audience;
  final DateTime _expiry;
  final Duration _maxAge;

  /// Creates JWT-manager
  ///
  /// [securityKey] secret key
  ///
  /// [issuer] issuer of JWT
  ///
  /// [audience] audience of JWT
  ///
  /// [expiry] expiry date/time JWT
  ///
  /// [maxAge] max age of JWT token
  ///
  /// Parameters [expiry] and [maxAge] exclude each other
  Jwt(
      {String securityKey,
      String issuer,
      String audience,
      DateTime expiry,
      Duration maxAge})
      : _issuer = issuer,
        _audience = audience,
        _expiry = expiry,
        _maxAge = maxAge {
    if (securityKey == null) {
      _key = (DateTime.now().millisecondsSinceEpoch +
              Random.secure().nextInt(4294967296))
          .toRadixString(36);
    } else {
      _key = securityKey;
    }
  }

  /// Issues new JWT
  ///
  /// [subject] subject (usually user identifier)
  ///
  /// [payload] additional data
  String issue(String subject, {Map<String, dynamic> payload}) {
    final jwtClaimSet = JwtClaim(
        subject: subject,
        issuer: _issuer,
        issuedAt: DateTime.now(),
        expiry: _expiry,
        maxAge: _maxAge,
        audience: <String>[_audience],
        payload: payload);
    return issueJwtHS256(jwtClaimSet, _key);
  }

  /// Decodes and verifies jwt
  ///
  /// If jwt is invalid throws an exception
  JwtClaim decode(String jwt) {
    final jwtClaim = verifyJwtHS256Signature(jwt, _key);
    jwtClaim.validate(issuer: _issuer, audience: _audience);
    return jwtClaim;
  }
}
