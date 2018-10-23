import 'package:test/test.dart';
import 'package:data_model/data_model.dart';
import 'package:rest_api_server/mongo_collection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:nanoid/nanoid.dart';

class TestModelId extends ObjectId {
  TestModelId._(id): super(id);
  factory TestModelId(id) {
    if (id == null) return null;
    return TestModelId._(id);
  }
}

class TestModel extends Model {
  int intParam;
  String stringParam;

  TestModel({ TestModelId id, this.intParam, this.stringParam}): super(id);

  factory TestModel.fromJson(Map<String, dynamic> json) {
    if (json == null) return null;
    return TestModel(
      id: TestModelId(json['id']),
      intParam: json['intParam'],
      stringParam: json['stringParam']
    );
  }

  @override
  Map<String, dynamic> get json => super.json..addAll({
    'intParam': intParam,
    'stringParam': stringParam
  }..removeWhere((key, value) => value == null));
}

class TestMongoCollection extends MongoCollection<TestModel, TestModelId> {
  TestMongoCollection(mongo.DbCollection collection): super(collection);
  @override
  TestModel createModel(Map<String, dynamic> data) => TestModel.fromJson(data);
}

main() {
  final db = mongo.Db('mongodb://127.0.0.1/testdb');

  setUpAll(() async {
    await db.open();
  });

  tearDownAll(() {
    db.drop();
    db.close();
  });

  group('insert test', () {
    mongo.DbCollection mongoCollection;

    setUpAll(() {
      mongoCollection = mongo.DbCollection(db, nanoid(10));
    });

    tearDownAll(() {
      mongoCollection.drop();
    });

    test('insert object', () async {
      final collection = TestMongoCollection(mongoCollection);
      final object = TestModel(
        intParam: 123,
        stringParam: 'some string');
      final inserted = await collection.insert(object);
      expect(inserted.id.value, TypeMatcher<String>());
      expect(inserted.id.value.length, 24);
      expect(inserted.json..remove('id'), object.json);
    });

  });

  group('find tests', () {
    mongo.DbCollection mongoCollection;

    final object1 = TestModel(
      id: TestModelId(mongo.ObjectId().toHexString()),
      intParam: 123,
      stringParam: '123'
    );

    final object2 = TestModel(
      id: TestModelId(mongo.ObjectId().toHexString()),
      intParam: 456,
      stringParam: '456'
    );

    setUpAll(() {
      mongoCollection = mongo.DbCollection(db, nanoid(10));
      mongoCollection.insertAll([
        object1.json..addAll({'_id': mongo.ObjectId.fromHexString(object1.id.json)})..remove('id'),
        object2.json..addAll({'_id': mongo.ObjectId.fromHexString(object2.id.json)})..remove('id')
      ]);
    });

    tearDownAll(() {
      mongoCollection.drop();
    });

    test('findOne', () async {
      final collection = TestMongoCollection(mongoCollection);
      final found = await collection.findOne(object1.id);
      expect(found, isNotNull);
      expect(found.json, object1.json);
    });

    test('find', () async {
      final collection = TestMongoCollection(mongoCollection);
      final found = await collection.find(mongo.where.lt('intParam', 500));
      expect(found.map((obj) => obj.json), emitsInAnyOrder([object1.json, object2.json]));
    });
  });

  group('update tests', () {
    mongo.DbCollection mongoCollection;

    final object1 = TestModel(
      id: TestModelId(mongo.ObjectId().toHexString()),
      intParam: 123,
      stringParam: '123'
    );

    final object2 = TestModel(
      id: TestModelId(mongo.ObjectId().toHexString()),
      intParam: 456,
      stringParam: '456'
    );

    setUpAll(() {
      mongoCollection = mongo.DbCollection(db, nanoid(10));
      mongoCollection.insertAll([
        object1.json..addAll({'_id': mongo.ObjectId.fromHexString(object1.id.json)})..remove('id'),
        object2.json..addAll({'_id': mongo.ObjectId.fromHexString(object2.id.json)})..remove('id')
      ]);
    });

    tearDownAll(() {
      mongoCollection.drop();
    });

    test('update', () async {
      final collection = TestMongoCollection(mongoCollection);
      object1.intParam = 234;
      object1.stringParam = '234';
      final updated = await collection.update(object1);
      expect(updated.json, object1.json);
    });

    test('replace', () async {
      final collection = TestMongoCollection(mongoCollection);
      object1.intParam = object2.intParam;
      object1.stringParam = null;
      final replaced = await collection.replace(object1);
      expect(replaced.json, object1.json..remove('stringParam'));
    });
  });
  
  group('delete test', () {
    mongo.DbCollection mongoCollection;

    final object1 = TestModel(
      id: TestModelId(mongo.ObjectId().toHexString()),
      intParam: 123,
      stringParam: '123'
    );

    setUpAll(() {
      mongoCollection = mongo.DbCollection(db, nanoid(10));
      mongoCollection.insert(
        object1.json..addAll({'_id': mongo.ObjectId.fromHexString(object1.id.json)})..remove('id'),
      );
    });

    tearDownAll(() {
      mongoCollection.drop();
    });

    test('delete', () async {
      final collection = TestMongoCollection(mongoCollection);
      final deleted = await collection.delete(object1.id);
      expect(deleted.json, object1.json);
    });

  });
}
