import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpException;

import 'package:path/path.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'middleware.dart';
import 'jwt.dart';

export 'jwt.dart' show Jwt;

/// AuthMiddleware
///
/// The middleware is responsible for user authentication
///
/// [loginPath] should contain path to login api-method.
///
/// If login successful login api-method should return shelf [Response] object with `status`
/// 200-Ok and `context` containing following [Map]:
///
///     {
///       subject: <userId>,
///       payload: {
///         // any additional information
///       }
///     }
///
/// If authentication was successful ([Response] `status` 200-Ok), then response `Authorization` header
/// will contain jwt which must be sent from cleint along with each subsequent requests
///
/// Jwt has expiry period after that jwt is not valid. If request has valid jwt then
/// response will contain new jwt with new expiry date and time.
///
/// If jwt is not valid request will not proceed to the handler
class AuthMiddleware implements Middleware {
  final String _loginPath;
  final Map<String, List<String>> _exclude;
  final Jwt _jwt;

  /// Creates AuthMiddleware
  ///
  /// [loginPath] path to the login api-method.
  ///
  /// Example:
  ///
  ///     loginPath: '/api/login'
  ///
  /// [exclude] - [Map] object describing api-paths which does not require authentication.
  ///
  /// Example:
  ///     {
  ///       'GET': [
  ///         '/path/to/resource1',
  ///         '/path/to/resource2',
  ///         ...
  ///       ],
  ///       'POST': [
  ///         '/api/login',
  ///         ...
  ///       ],
  ///       ...
  ///     }
  /// Names of http-methods must be in upper case
  ///
  /// [jwt] JWT-manager
  AuthMiddleware(
      {String loginPath, Map<String, List<String>> exclude = const {}, Jwt jwt})
      : _loginPath = normalize(loginPath),
        _exclude = Map.unmodifiable(exclude.map((method, paths) =>
            MapEntry(method, paths.map((path) => normalize(path)).toList()))),
        _jwt = jwt;

  shelf.Handler call(shelf.Handler innerHandler) => (shelf.Request request) {
        return Future.sync(() {
          final method = request.method;
          final anonimous = _exclude[method] ?? [];
          String jwt = request.headers[HttpHeaders.authorizationHeader];
          if (anonimous.contains(normalize(request.requestedUri.path))) {
            if (jwt != null) {
              try {
                request = _addJwtPayloadToRequestContext(request, jwt);
              } on JwtException {}
            }
          } else {
            if (jwt == null) {
              throw (JwtException('Authorization header is not provided'));
            }
            request = _addJwtPayloadToRequestContext(request, jwt);
          }
          return request;
        }).then((request) {
          return Future<shelf.Response>.sync(() => innerHandler(request))
              .then((response) {
            if (url.normalize(request.requestedUri.path) == _loginPath &&
                response.statusCode == HttpStatus.ok) {
              if (!response.context.containsKey('subject') ||
                  response.context['subject'] == null) {
                return shelf.Response(HttpStatus.unauthorized,
                    body: json.encode('User not found'));
              }
              String token = _jwt.issue(response.context['subject'],
                  payload: response.context['payload']);
              response = _addJwtToResponse(token, response);
            } else if (request.context.containsKey('subject')) {
              String token = _jwt.issue(request.context['subject'],
                  payload: request.context['payload']);
              response = _addJwtToResponse(token, response);
            }
            return response;
          });
        }).catchError((e) {
          if (e is JwtException) {
            return shelf.Response(HttpStatus.unauthorized,
                body: json.encode(e.toString()));
          } else {
            throw (e);
          }
        });
      };

  shelf.Request _addJwtPayloadToRequestContext(
      shelf.Request request, String jwt) {
    JwtClaim jwtClaim = _jwt.decode(jwt);
    return request.change(
        context: {'subject': jwtClaim.subject, 'payload': jwtClaim.payload});
  }

  shelf.Response _addJwtToResponse(String jwt, shelf.Response response) =>
      response.change(
          headers: <String, String>{}
            ..addAll(response.headers)
            ..addAll({HttpHeaders.authorizationHeader: jwt}));
}
