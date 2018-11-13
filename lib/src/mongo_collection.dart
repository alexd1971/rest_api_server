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
      getObjectsByQuery(selector ?? mongo.where);

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
    final objectList = await getObjectsByQuery(mongo.where.eq('_id', id)).toList();
    if (objectList.length == 0) return null;
    return objectList.first;
  }

  /// Takes objects from database according to query
  @protected
  Stream<T> getObjectsByQuery(mongo.SelectorBuilder query) {
    if (query == null) throw (ArgumentError.notNull('query'));
    return collection.aggregateToStream(buildPipeline(query)).map((data) => createModel(data));
  }

  /// Builds aggregation pipeline based on query.
  /// 
  /// Basic pipeline contains only following stages:
  /// - $match if `query` contains some criteria
  /// - $addFields adds `id` field as string representation of `_id`
  /// - $project removes unnessesary `_id` field
  /// - $sort sorts objects if `orderby` exists in `query`
  /// - $skip skips objects
  /// - $limit limits object count
  /// 
  /// In more comlicated cases it is enough to override this method
  @protected
  List<Map<String, dynamic>> buildPipeline(mongo.SelectorBuilder query) {
    final pipeline = <Map<String, dynamic>>[];
    if (query.map.containsKey('\$query')) {
      pipeline.add({'\$match': query.map['\$query']});
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
    if (query.map.containsKey('orderby')) pipeline.add({
      '\$sort': query.map['orderby']
    });
    if (query.paramSkip != 0) pipeline.add({
      '\$skip': query.paramSkip
    });
    if (query.paramLimit != 0) pipeline.add({
      '\$limit': query.paramLimit
    });
    return pipeline;
  }

  /// Creates model object from data
  @protected
  T createModel(Map<String, dynamic> data);
}
