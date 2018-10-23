import 'middleware.dart';

/// Abstract annotation Routable
///
/// Base class for [Resource] annotation and methods annotations:
/// 
/// * [Get],
/// * [Post],
/// * [Put],
/// * [Patch]
/// * [Delete]
abstract class Routable {

  /// Relative path to resource
  final String path;

  /// Middleware for the routable resource
  /// 
  /// For a base resource class the middleware is applied to each resource method.
  /// For a method the middleware is applied to the method
  final Middleware middleware;

  const Routable(this.path, this.middleware);
}

/// Resource
///
/// The annotation for resource getters
///
/// Example:
///     class Api {
///       @Resource(path: 'users')
///       Users get users => Users()
///     }
class Resource extends Routable {

  /// Creates resource annotation
  const Resource({String path = '', Middleware middleware}): super(path, middleware);
}

/// Get
///
/// The annotation of resource method to indicate the method shuold be applied to the resource
/// with `path` while requested with HTTP-method GET
class Get extends Routable {

  /// Creates Get annotation
  const Get({String path = '', Middleware middleware}): super(path, middleware);
}

/// Post
///
/// The annotation of resource method to indicate the method shuold be applied to the resource
/// with `path` while requested with HTTP-method POST
class Post extends Routable {

  /// Create Post annotation
  const Post({String path = '', Middleware middleware}): super(path, middleware);
}

/// Put
///
/// The annotation of resource method to indicate the method shuold be applied to the resource
/// with `path` while requested with HTTP-method PUT
class Put extends Routable {

  /// Create Put annotation
  const Put({String path = '', Middleware middleware}): super(path, middleware);
}

/// Patch
///
/// The annotation of resource method to indicate the method shuold be applied to the resource
/// with `path` while requested with HTTP-method PATCH
class Patch extends Routable {

  /// Create Patch annotation
  const Patch({String path = '', Middleware middleware}): super(path, middleware);
}

/// Delete
///
/// The annotation of resource method to indicate the method shuold be applied to the resource
/// with `path` while requested with HTTP-method DELETE
class Delete extends Routable {

  /// Creates Delete annotation
  const Delete({String path = '', Middleware middleware}): super(path, middleware);
}
