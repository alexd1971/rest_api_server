import 'package:shelf/shelf.dart' as shelf;

/// Middleware interface
///
/// Custom middleware must implement this interface
abstract class Middleware {
  shelf.Handler call(shelf.Handler innerHandler);
}
