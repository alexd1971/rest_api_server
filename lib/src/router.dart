import 'dart:async';
import 'dart:convert';
import 'dart:mirrors';

import 'package:shelf/shelf.dart' as shelf;
import 'package:path/path.dart';
import 'package:data_model/data_model.dart';

import 'annotations.dart';
import 'middleware.dart';

/// Request router
class Router {
  final _routes = <Route>[];

  /// Adds a resource to the router
  ///
  /// [resource] usually class with annotated methods and other resources
  ///
  /// [path] resource mounting path
  ///
  /// [middleware] middleware for all resource methods
  void add(dynamic resource, {String path = '/', Middleware middleware}) {
    final resourceReflection = reflect(resource);
    final newRoutes = _getRoutes(resourceReflection, _getPathParameters(path))
        .map((route) => Route(
            method: route.method,
            path: url.normalize(url.join('/', path, route.path)),
            handler:
                middleware != null ? middleware(route.handler) : route.handler))
        .toList();
    final conflictingRoutes = _routes.where((route) =>
        newRoutes.where((newRoute) => newRoute.path == route.path).isNotEmpty);
    if (conflictingRoutes.isNotEmpty) throw (RouterError('Routes conflict'));
    _routes.addAll(newRoutes);
    _routes.sort((a, b) => a.path.compareTo(b.path));
  }

  /// Prints routes list
  void printRoutes() {
    _routes.forEach((route) {
      print('${route.method}\t${route.path}');
    });
  }

  /// Router handler
  shelf.Handler get handler {
    return (shelf.Request request) {
      final route = _routes.firstWhere(
          (route) =>
              request.method == route.method &&
              route.pathRegExp
                  .hasMatch(url.normalize(request.requestedUri.path)),
          orElse: () => null);
      if (route == null) {
        return shelf.Response.notFound(
            'Resource ${request.requestedUri} not found');
      }
      final response = route.handler(request);
      return response;
    };
  }

  /// Parses resource and extracts routes with its handlers
  List<Route> _getRoutes(
      InstanceMirror resourceReflection, List<String> pathParameters) {
    final routes = <Route>[];

    resourceReflection.type.instanceMembers.forEach((name, method) {
      final routableAnnotations = method.metadata.where(
          (annotation) => annotation.type.isSubtypeOf(reflectType(Routable)));
      if (routableAnnotations.isNotEmpty) {
        if (routableAnnotations.length > 1) {
          throw (RouterError(
              'Method or enclosed resource has concurrent annotations'));
        }

        final methodAnnotation = routableAnnotations.elementAt(0);

        final String path = methodAnnotation.getField(#path).reflectee;
        final Middleware middleware =
            methodAnnotation.getField(#middleware).reflectee;
        final newPathParameters = List<String>.from(pathParameters)
          ..addAll(_getPathParameters(path));

        if (method.isGetter) {
          if (methodAnnotation.type.reflectedType != Resource) {
            throw (RouterError('Invalid resource annotation'));
          }

          List<Route> resourceRoutes =
              _getRoutes(resourceReflection.getField(name), newPathParameters)
                  .map((route) => Route(
                      method: route.method,
                      path: url.join(path, route.path),
                      handler: middleware != null
                          ? middleware(route.handler)
                          : route.handler))
                  .toList();

          final conflictingRoutes = routes.where((route) => resourceRoutes
              .where((resourceRoute) => resourceRoute.path == route.path)
              .isNotEmpty);
          if (conflictingRoutes.isNotEmpty)
            throw (RouterError('Routes confilct'));
          routes.addAll(resourceRoutes);
        } else if (method.isRegularMethod) {
          if (method.parameters.any((parameter) => parameter.isNamed))
            throw (RouterError('Do not use named parameters in methods'));
          String httpMethod = methodAnnotation.type.reflectedType.toString();
          shelf.Handler handler = _createHandler(
              resourceReflection.getField(name), newPathParameters);
          if (middleware != null) {
            handler = middleware(handler);
          }
          routes.add(Route(method: httpMethod, path: path, handler: handler));
        }
      }
    });

    return routes;
  }

  /// Extracts parameters from path
  ///
  /// Example: if there is a path `/users/{userId}/messages`, the function returns `[userId]`
  List<String> _getPathParameters(String path) {
    if (path.isEmpty) return [];
    path = url.normalize(path);
    if (url.isAbsolute(path)) {
      path = url.relative(path, from: '/');
      if (path == '.') path = '';
    }
    final paramRegexp = RegExp(r'\{(.+)\}');
    return url
        .split(path)
        .map((segment) => paramRegexp.firstMatch(segment)?.group(1))
        .toList();
  }

  /// Creates route handler
  shelf.Handler _createHandler(
      ClosureMirror method, List<String> pathParameters) {
    shelf.Handler handler = (shelf.Request request) async {
      final reqParams = <String, String>{};
      for (int i = 0; i < pathParameters.length; i++) {
        if (pathParameters[i] != null) {
          reqParams[pathParameters[i]] = request.requestedUri.pathSegments[i];
        }
      }
      reqParams.addAll(request.requestedUri.queryParameters);
      final args = [];
      await Future.forEach(method.function.parameters, (param) async {
        final paramName = MirrorSystem.getName(param.simpleName);
        final reqValue = reqParams[paramName];
        var argValue;
        if (reqValue != null) {
          switch (param.type.reflectedType) {
            case num:
              argValue = num.parse(reqValue);
              break;
            case double:
              argValue = double.parse(reqValue);
              break;
            case int:
              argValue = int.parse(reqValue);
              break;
            default:
              argValue = reqValue;
          }
        } else if (paramName == 'requestBody') {
          switch (param.type.reflectedType) {
            case Map:
              argValue = json.decode(await request.readAsString());
              break;
            case String:
              argValue = await request.readAsString();
              break;
            default:
              throw ArgumentError(
                  'Request body type in ${method} must be Map or String');
          }
        } else if (paramName == 'requestHeaders') {
          argValue = request.headers;
        } else if (paramName == 'context') {
          argValue = request.context;
        } else {
          argValue = null;
        }
        if (param.type.reflectedType == shelf.Request) argValue = request;
        args.add(argValue);
      });
      final returnedValue = method.apply(args).reflectee;
      final result =
          returnedValue is Future ? await returnedValue : returnedValue;
      if (result is shelf.Response) return result;
      return shelf.Response.ok(json.encode(result, toEncodable: (value) {
        if (value is DateTime) return value.toUtc().toIso8601String();
        if (value is JsonEncodable) return value.json;
        return '';
      }));
    };
    return handler;
  }
}

/// Rote
class Route {
  /// Http-request method
  final String method;

  /// Request path
  final String path;

  /// Regular expression for quick path search
  final RegExp pathRegExp;

  /// route handler
  final shelf.Handler handler;

  /// Creates new routes
  Route({String method, this.path, this.handler})
      : assert(const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
            .contains(method.toUpperCase())),
        method = method.toUpperCase(),
        pathRegExp =
            RegExp('^' + path.replaceAll(RegExp(r'\{\w+\}'), '[^/]+') + r'$');
}

/// Router Error
class RouterError extends Error {
  final String message;
  RouterError(this.message);
}
