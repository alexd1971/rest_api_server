import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;

import 'middleware.dart';

/// CorsHeadersMiddleware
///
/// Adds CORS-headers to the response
///
/// Example:
///     CorsHeadersMiddleware({
///       'Access-Control-Allow-Origin': '*',
///       'Access-Control-Expose-Headers': 'Authorization, Content-Type',
///       'Access-Control-Allow-Headers':
///         'Authorization, Origin, X-Requested-With, Content-Type, Accept, Content-Disposition',
///       'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE'
///     });
class CorsHeadersMiddleware implements Middleware {
  ///  CORS-headers
  final Map<String, String> corsHeaders;

  CorsHeadersMiddleware(this.corsHeaders) {
    if (corsHeaders == null) throw (ArgumentError.notNull('corsHeaders'));
  }

  shelf.Handler call(shelf.Handler innerHandler) => (shelf.Request request) {
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok(null, headers: corsHeaders);
        }
        return Future.sync(() => innerHandler(request)).then((response) {
          return response.change(
              headers: {}..addAll(corsHeaders)..addAll(response.headers));
        });
      };
}
