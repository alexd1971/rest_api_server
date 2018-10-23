import 'dart:io' hide HttpException;

import 'package:shelf/shelf.dart' as shelf;

import 'http_exception.dart';
import 'middleware.dart';

/// HttpExceptionMiddleware
///
/// Transforms [HttpException] to the corresponding http-responses
class HttpExceptionMiddleware implements Middleware {
  shelf.Handler call(shelf.Handler innerHandler) =>
      (shelf.Request request) async {
        shelf.Response response;
        try {
          response = await innerHandler(request);
        } on HttpException catch (e) {
          response = shelf.Response(e.status, body: e.toString());
        } catch (e, s) {
          response = shelf.Response(HttpStatus.internalServerError,
              body: '$e\n$s'
          );
        }
        return response;
      };
}
