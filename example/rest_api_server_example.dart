import 'dart:io';
import 'dart:async';

import 'package:nanoid/nanoid.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:data_model/data_model.dart';

import 'package:rest_api_server/api_server.dart';
import 'package:rest_api_server/annotations.dart';
import 'package:rest_api_server/http_exception_middleware.dart';
import 'package:rest_api_server/auth_middleware.dart';
import 'package:rest_api_server/cors_headers_middleware.dart';
import 'package:rest_api_server/mongo_collection.dart';

main() async {
  final address = InternetAddress.anyIPv4;
  final port = 7777;
  final jwt = Jwt(
      securityKey: nanoid(),
      issuer: 'Some organization',
      maxAge: Duration(days: 1));
  final router = Router();

  final mongoDb = mongo.Db('mongodb://localhost/testdb');
  await mongoDb.open();

  router.add(
      Api(
          usersResource:
              UsersResource(UsersCollection(mongoDb.collection('users')))),
      path: '/v1');

  ApiServer apiServer = ApiServer(
      address: address,
      port: port,
      handler: shelf.Pipeline()
          .addMiddleware(HttpExceptionMiddleware())
          .addMiddleware(CorsHeadersMiddleware({
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Expose-Headers': 'Authorization, Content-Type',
            'Access-Control-Allow-Headers':
                'Authorization, Origin, X-Requested-With, Content-Type, Accept, Content-Disposition',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE'
          }))
          .addMiddleware(AuthMiddleware(
              loginPath: '/v1/login',
              exclude: const {
                'POST': ['/v1/login', '/v1/users'],
              },
              jwt: jwt))
          .addHandler(router.handler));
  await apiServer.start();

  router.printRoutes();
}

class Api {
  UsersResource usersResource;
  Api({this.usersResource});

  @Post(path: 'login')
  shelf.Response login() {
    return shelf.Response.ok('Ok', context: {
      'subject': 'any',
      'payload': {'role': 'any'}
    });
  }

  @Resource(path: 'users')
  UsersResource get users => usersResource;
}

class UsersResource {
  final UsersCollection usersCollection;

  UsersResource(this.usersCollection);

  @Post(path: '')
  Future<User> create(Map requestBody) =>
      usersCollection.insert(User.fromJson(requestBody));

  @Get(path: '{userId}')
  Future<User> getUser(String userId) =>
      usersCollection.findOne(UserId(userId));
}

class UserId extends ObjectId {
  UserId._(id) : super(id);
  factory UserId(id) {
    if (id == null) return null;
    return UserId._(id);
  }
}

class User extends Model<UserId> {
  UserId id;
  String name;
  String occupation;

  User({this.id, this.name, this.occupation});

  factory User.fromJson(Map<String, dynamic> json) {
    if (json == null) return null;
    return User(
        id: UserId(json['id']),
        name: json['name'],
        occupation: json['occupation']);
  }

  @override
  Map<String, dynamic> get json => {
    'id': id?.json, 'name': name, 'occupation': occupation
    }..removeWhere((key, value) => value == null);
}

class UsersCollection extends MongoCollection<User, UserId> {
  UsersCollection(mongo.DbCollection collection) : super(collection);

  @override
  User createModel(Map<String, dynamic> data) => User.fromJson(data);
}
