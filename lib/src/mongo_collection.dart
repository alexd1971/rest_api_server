import 'dart:async';

import 'package:meta/meta.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:data_model/data_model.dart';

/// Basic mongo-collection operations interface
abstract class MongoCollection<T extends Model, Id extends ObjectId> {
  @protected
  final mongo.DbCollection collection;

  MongoCollection(this.collection);

  /// Inserts new document into collection
  ///
  /// Returns inserted data model
  Future<T> insert(T object) async {
    final id = mongo.ObjectId();
    await collection.insert(object.json
      ..addAll({'_id': id})
      ..remove('id'));
    return getObjectById(id);
  }

  /// Finds document by id
  ///
  /// Returns data model object of type `T`
  Future<T> findOne(Id id) =>
      getObjectById(mongo.ObjectId.fromHexString(id.value));

  /// Finds documents by criteria
  ///
  /// [selector] looks like the following expression:
  ///
  ///     where.eq('name', 'Paul').and(where.eq('lastname','McCartney'))
  Stream<T> find([mongo.SelectorBuilder selector]) =>
      buildQuery(selector ?? mongo.where).map((data) => createModel(data));

  /// Updates any attribute set of object
  ///
  /// Only attributes with non `null` values are updated
  Future<T> update(T object) async {
    final mongoId = mongo.ObjectId.fromHexString(object.id.json);
    await collection.update(
        mongo.where.eq('_id', mongoId), {'\$set': object.json..remove('id')});
    return getObjectById(mongoId);
  }

  /// Replaces the whole object
  Future<T> replace(T object) async {
    final mongoId = mongo.ObjectId.fromHexString(object.id.json);
    await collection.update(
        mongo.where.eq('_id', mongoId), object.json..remove('id'));
    return getObjectById(mongoId);
  }

  /// Removes object from collection
  Future<T> delete(Id id) async {
    final mongoId = mongo.ObjectId.fromHexString(id.json);
    final deletedObject = await getObjectById(mongoId);
    await collection.remove(mongo.where.eq('_id', mongoId));
    return deletedObject;
  }

  /// Gets model by its id
  @protected
  Future<T> getObjectById(mongo.ObjectId id) async {
    final data = await buildQuery(mongo.where.eq('_id', id)).toList();
    if (data.length == 0) return null;
    return createModel(data.first);
  }

  /// Use `getObjectById` instead
  @protected
  @Deprecated('Is going to be removed in future release')
  Future<T> getObjectByMongoId(mongo.ObjectId id) => getObjectById(id);

  /// Builds mongo database query
  Stream<Map<String, dynamic>> buildQuery(mongo.SelectorBuilder selector) {
    
    if (selector == null) throw (ArgumentError.notNull('selector'));

    final pipeline = <Map<String, dynamic>>[];
    if (selector.map.isNotEmpty) {
      pipeline.add({'\$match': selector.map['\$query']});
    }
    pipeline.addAll([
      {
        '\$addFields': {
          'id': {'\$toString': '\$_id'}
        }
      },
      {
        '\$project': {
          '_id': false,
        }
      }
    ]);
    if (selector.paramSkip != 0) pipeline.add({
      '\$skip': selector.paramSkip
    });
    if (selector.paramLimit != 0) pipeline.add({
      '\$limit': selector.paramLimit
    });
    return collection.aggregateToStream(pipeline);
  }

  /// Creates model object from data
  T createModel(Map<String, dynamic> data);
}
