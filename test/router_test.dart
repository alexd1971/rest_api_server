@TestOn('vm')

import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:rest_api_server/api_server.dart';
import 'package:rest_api_server/annotations.dart';
import 'package:rest_api_server/middleware.dart';

void main() {
  test('print routes', () {
    final router = Router();
    router.add(Api(), path: '/api');
    expect(() {
      router.printRoutes();
    },
        prints(
            'POST\t/api/action\nPOST\t/api/tests\nGET\t/api/tests/{id}/results\n'));
  });

  test('double method anotation', () {
    final router = Router();
    expect(() {
      router.add(BadResource());
    },
        throwsA(predicate((e) =>
            e is RouterError &&
            e.message ==
                'Method or enclosed resource has concurrent annotations')));
  });

  test('double resource anotation', () {
    final router = Router();
    expect(() {
      router.add(BadApi());
    },
        throwsA(predicate((e) =>
            e is RouterError &&
            e.message ==
                'Method or enclosed resource has concurrent annotations')));
  });

  test('conflicting routes', () {
    final router = Router();
    router.add(Tests(), path: '/api/tests');
    expect(() {
      router.add(ConflictingResource());
    },
        throwsA(predicate(
            (e) => e is RouterError && e.message == 'Routes conflict')));
  });

  test('invalid resource annotation', () {
    final router = Router();
    expect(() {
      router.add(BadAnnotation());
    },
        throwsA(predicate((e) =>
            e is RouterError && e.message == 'Invalid resource annotation')));
  });

  test('correct path parameters interpretation', () async {
    final router = Router();
    router.add(Api(), path: '/api/v1');
    final request = shelf.Request(
        'GET', Uri.parse('http://localhost/api/v1/tests/123/results'));
    final response = await router.handler(request);
    expect(response.readAsString(), completion('[1,2,3]'));
  });

  test('using named parameters throws', () {
    final router = Router();
    expect(() {
      router.add(NamedParameters());
    },
        throwsA(predicate((e) =>
            e is RouterError &&
            e.message == 'Do not use named parameters in methods')));
  });

  test('resource not found', () async {
    final router = Router();
    router.add(Api(), path: '/api');
    final request =
        shelf.Request('GET', Uri.parse('http://localhost/api/noresource'));
    final response = await router.handler(request);
    expect(response.statusCode, HttpStatus.notFound);
    expect(response.readAsString(),
        completion('Resource http://localhost/api/noresource not found'));
  });

  test('request as method parameter', () async {
    final router = Router();
    router.add(RequestAsParameter(), path: 'resource');
    final request = shelf.Request(
        'GET', Uri.parse('http://localhost/resource/123'),
        headers: {'x-test': 'test'});
    final response = await router.handler(request);
    expect(response.readAsString(), completion('"test123"'));
  });

  test('request body as method parameter (Map)', () async {
    final router = Router();
    router.add(RequestBodyAsParameter(), path: 'resource');
    final request = shelf.Request(
        'POST', Uri.parse('http://localhost/resource/map'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'param': 'value'}));
    final response = await router.handler(request);
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.readAsString();
    expect(json.decode(body), {'param': 'value'});
  });

  test('request body as method parameter (String)', () async {
    final router = Router();
    router.add(RequestBodyAsParameter(), path: 'resource');
    final request = shelf.Request(
        'POST', Uri.parse('http://localhost/resource/string'),
        headers: {'Content-Type': 'text/plain'}, body: 'test');
    final response = await router.handler(request);
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.readAsString();
    expect(json.decode(body), 'test');
  });

  test('request headers as method parameter', () async {
    final router = Router();
    router.add(RequestHeadersAsParameter(), path: 'resource');
    final request = shelf.Request(
        'GET', Uri.parse('http://localhost/resource/'),
        headers: {'x-test': '123'});
    final response = await router.handler(request);
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.readAsString();
    expect(json.decode(body), containsPair('x-test', '123'));
  });

  test('request context as method parameter', () async {
    final router = Router();
    router.add(RequestContextAsParameter(), path: 'resource');
    final request = shelf.Request(
        'GET', Uri.parse('http://localhost/resource/'),
        context: {'key': 'value'});
    final response = await router.handler(request);
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.readAsString();
    expect(json.decode(body), {'key': 'value'});
  });

  test('method middleware', () async {
    final router = Router();
    router.add(TestMiddlewareResource());
    final request = shelf.Request('DELETE', Uri.parse('http://localhost/123'));
    final response = await router.handler(request);
    expect(response.readAsString(), completion('123+middleware'));
  });

  test('resource middleware 1', () async {
    final router = Router();
    router.add(TestMiddlewareApi());
    final request =
        shelf.Request('DELETE', Uri.parse('http://localhost/items/'));
    final response = await router.handler(request);
    expect(response.readAsString(), completion('[1,2,3]+middleware'));
  });

  test('resource middleware 2', () async {
    final router = Router();
    router.add(TestMiddlewareApi());
    final request =
        shelf.Request('DELETE', Uri.parse('http://localhost/items/123'));
    final response = await router.handler(request);
    expect(response.readAsString(), completion('123+middleware+middleware'));
  });

  test('resource middleware 3', () async {
    final router = Router();
    router.add(TestMiddlewareApi(), middleware: TestMiddleware());
    final request =
        shelf.Request('DELETE', Uri.parse('http://localhost/items/123'));
    final response = await router.handler(request);
    expect(response.readAsString(),
        completion('123+middleware+middleware+middleware'));
  });
}

/// API Resource
///
/// Mounts [Tests] resource
class Api {
  @Resource(path: 'tests')
  Tests get resource => Tests();

  @Post(path: 'action')
  int testAction() => 1;
}

/// Tests resource
///
/// Is used in [Api]
/// Mounts [Results] resource
class Tests {
  @Post(path: '')
  int getValues() => 1;

  @Resource(path: '{id}')
  Results get results => Results();
}

/// Results resource
///
/// Is used in [Tests] resource
class Results {
  @Get(path: 'results')
  List<int> get(int id) =>
      id.toString().split('').map((item) => int.parse(item)).toList();
}

/// Resource with bad method annotations
///
/// Is used in [BadApi]
class BadResource {
  @Post(path: 'path1')
  @Get(path: 'path2')
  int get() => 1;
}

/// Resource with bad mounted resource annotation
///
/// Mounts [BadResource]
class BadApi {
  @Resource(path: 'path')
  @Resource(path: 'path1')
  BadResource get badResource => BadResource();
}

/// Resource to test conflicting resources
class ConflictingResource {
  @Get(path: '/api/tests')
  int get() => 1;
}

/// Resource with bad annotation
///
/// Mounted resource annotated as method
class BadAnnotation {
  @Get(path: 'path')
  Tests get testResource => Tests();
}

/// Resource to test named parameters in methods
///
/// Named parameters in resource methods are not allowed
class NamedParameters {
  @Get(path: '{id}')
  int method({int id}) => id;
}

/// Resource to test request object as method parameter
class RequestAsParameter {
  @Get(path: '{id}')
  String method(int id, shelf.Request request) {
    return request.headers['x-test'] + id.toString();
  }
}

/// Resource to test request body as method parameter
class RequestBodyAsParameter {
  @Post(path: 'map')
  Map<String, dynamic> method1(Map requestBody) {
    return requestBody;
  }

  @Post(path: 'string')
  String method2(String requestBody) {
    return requestBody;
  }
}

/// Resource to test request headers as method parameter
class RequestHeadersAsParameter {
  @Get(path: '')
  Map<String, dynamic> method(Map requestHeaders) {
    return requestHeaders;
  }
}

/// Resource to test request context as method parameter
class RequestContextAsParameter {
  @Get(path: '')
  Map<String, dynamic> method(Map context) {
    return context;
  }
}

/// Resource to test middleware
///
/// Mounts [TestMiddlewareResource]
class TestMiddlewareApi {
  @Resource(path: 'items/', middleware: TestMiddleware())
  TestMiddlewareResource get resource => TestMiddlewareResource();
}

/// Resource to test middleware
///
/// Is used in [TestMiddlewareApi]
class TestMiddlewareResource {
  @Delete()
  List<int> items() => [1, 2, 3];

  @Delete(path: '{id}/', middleware: TestMiddleware())
  int item(int id) => id;
}

/// Middleware for testing
///
/// Adds "+middleware" to the end of body string
class TestMiddleware implements Middleware {
  shelf.Handler call(shelf.Handler innerHandler) =>
      (shelf.Request request) async {
        final response = await innerHandler(request);
        final body = await response.readAsString();
        return response.change(body: '$body+middleware');
      };
  const TestMiddleware();
}
