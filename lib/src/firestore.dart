import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

abstract interface class FirestoreCollectionField {
  String get fieldName;
  DateTime? get startAtToUse;
}

@immutable
abstract interface class FirestoreCollection<T> {
  String get collectionName;
  FirestoreCollection? get parent;
  List<FirestoreCollectionField> get fields;
  T fromFirestore(
    String id,
    Map<String, dynamic> jsonMap,
  );
  Map<String, dynamic> toFirestore(T data);
}

abstract base class FirestoreCollectionParam<T> extends FirestoreParam<T> {
  FirestoreCollectionParam(super.collection, super.documentIdMap,
      {this.limit,
      this.limitToLast,
      this.whereList = const [],
      this.order,
      this.startAt,
      this.startAfter,
      this.endAt,
      this.endBefore});

  final int? limit;
  final int? limitToLast;
  final List<
      ({
        FirestoreCollectionField field,
        WhereQueryType whereQueryType,
        dynamic value
      })> whereList;
  final ({FirestoreCollectionField field, bool descending})? order;
  final Iterable<Object?>? startAt;
  final Iterable<Object?>? startAfter;
  final Iterable<Object?>? endAt;
  final Iterable<Object?>? endBefore;
}

abstract base class FirestoreParam<T> {
  FirestoreParam(
    this.collection,
    this.documentIdMap,
  );

  final FirestoreCollection<T> collection;
  final Map<FirestoreCollection, String> documentIdMap;
}

enum WhereQueryType {
  equal,
  notEqualTo,
  lessThan,
  lessThanOrEqualTo,
  greaterThan,
  greaterThanOrEqualTo,
  whereIn,
  whereNotIn,
  isNull,
  arrayContains,
  arrayContainsAny,
}

class FirestoreClient {
  FirestoreClient(this.firestoreInstance, [this._debug = false]);
  final FirebaseFirestore firestoreInstance;
  final bool _debug;

  StreamSubscription<List<({T data, DocumentChangeType type})>>
      getCollectionSubscription<T>(FirestoreCollectionParam<T> param,
          Function(List<({T data, DocumentChangeType type})> l) onData,
          [Function(Object? error, StackTrace? stackTrace)? errorHandler]) {
    return queryWrapper(
      param.collection.fields,
      getRef(
        param.collection,
        param.documentIdMap,
      ).collectionReference,
      limit: param.limit,
      limitToLast: param.limitToLast,
      order: param.order,
      whereList: param.whereList,
      startAfter: param.startAfter,
      startAt: param.startAt,
      endAt: param.endAt,
      endBefore: param.endBefore,
    ).snapshots().map((snapshot) {
      if (snapshot.docChanges.isEmpty) {
        return <({T data, DocumentChangeType type})>[];
      } else {
        final list = snapshot.docChanges.map((change) {
          // coverage:ignore-start
          assert(change.doc.data() != null,
              "Unexpected: DocumentSnapshot.data()はnullableとして定義されているものの、docChangesが返すDocumentSnapshotに関してはdata()はnullを返さない想定をしている。ただし、ドキュメント上ではこの点について記載が見つからなかった。したがって備忘を兼ねて念の為にassertを入れている");
          // coverage:ignore-end
          checkFields(
              change.doc.id, change.doc.data()!, param.collection.fields);
          return (
            data: param.collection
                .fromFirestore(change.doc.id, change.doc.data()!),
            type: change.type
          );
        }).toList();
        return list;
      }
    }).listen(onData, onError: (e, s) {
      if (errorHandler != null) {
        errorHandler(e, s);
      }
    });
  }

  StreamSubscription<T?> getDocumentSubscription<T>(
      FirestoreParam<T> param, Function(T? data) onData,
      [Function(Object? error, StackTrace? stackTrace)? errorHandler]) {
    return getRef(
      param.collection,
      param.documentIdMap,
    ).documentReference.snapshots().map((snapshot) {
      if (snapshot.data() == null) return null;
      checkFields(snapshot.id, snapshot.data()!, param.collection.fields);
      return param.collection.fromFirestore(snapshot.id, snapshot.data()!);
    }).listen(onData, onError: (e, s) {
      if (errorHandler != null) {
        errorHandler(e, s);
      }
    });
  }

  Future<Object?> createOrUpdateDocument<T>(FirestoreParam<T> param, T data,
      [Object? Function(Object? error, StackTrace? stackTrace)?
          errorHandler]) async {
    final json = param.collection.toFirestore(data);
    checkFields(null, json, param.collection.fields);
    final ref = getRef(
      param.collection,
      param.documentIdMap,
    );
    try {
      await ref.documentReference
          .set(param.collection.toFirestore(data), SetOptions(merge: true));
    } catch (e, s) {
      if (errorHandler == null) {
        rethrow;
      }
      final error = errorHandler(e, s);
      return error;
    }
    return null;
  }

  Future<Object?> deleteDocument<T>(FirestoreParam<T> param,
      [Object? Function(Object? error, StackTrace? stackTrace)?
          errorHandler]) async {
    final ref = getRef(
      param.collection,
      param.documentIdMap,
    );
    try {
      await ref.documentReference.delete();
    } catch (e, s) {
      if (errorHandler == null) {
        rethrow;
      }
      final error = errorHandler(e, s);
      return error;
    }
    return null;
  }

  Future<({T? data, Object? error})> fetchDocument<T>(FirestoreParam<T> param,
      [Object? Function(Object? error, StackTrace? stackTrace)?
          errorHandler]) async {
    final ref = getRef(
      param.collection,
      param.documentIdMap,
    );
    late DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref.documentReference.get();
    } catch (e, s) {
      if (errorHandler == null) {
        rethrow;
      }
      final error = errorHandler(e, s);
      return (data: null, error: error);
    }
    if (doc.data() != null) {
      checkFields(doc.id, doc.data()!, param.collection.fields);
      return (
        data: param.collection.fromFirestore(doc.id, doc.data()!),
        error: null
      );
    } else {
      return (data: null, error: null);
    }
  }

  Future<({List<T>? data, Object? error})> fetchCollection<T>(
      FirestoreCollectionParam<T> param,
      [Object? Function(Object? error, StackTrace? stackTrace)?
          errorHandler]) async {
    final ref = queryWrapper(
        param.collection.fields,
        getRef(
          param.collection,
          param.documentIdMap,
        ).collectionReference,
        limit: param.limit,
        limitToLast: param.limitToLast,
        order: param.order,
        whereList: param.whereList,
        startAfter: param.startAfter,
        startAt: param.startAt,
        endAt: param.endAt,
        endBefore: param.endBefore);
    try {
      final docs = (await ref.get()).docs.map((snapShot) {
        checkFields(snapShot.id, snapShot.data(), param.collection.fields);
        return param.collection.fromFirestore(snapShot.id, snapShot.data());
      }).toList();
      return (data: docs, error: null);
    } catch (e, s) {
      if (errorHandler == null) {
        rethrow;
      }
      final error = errorHandler(e, s);
      return (data: null, error: error);
    }
  }

  @visibleForTesting
  void checkFields(String? id, Map<String, dynamic> data,
      List<FirestoreCollectionField> fields) {
    final fieldKeyList = fields.map((e) => e.fieldName);

    for (final key in data.keys) {
      if (!fieldKeyList.contains(key)) {
        throw NotAllowFieldOnDocumentException(
            "The key $key in document(id:$id) does not exist in defined fields $fields");
      }
    }

    for (final field in fields) {
      if (!data.keys.contains(field.fieldName)) {
        if (field.startAtToUse == null ||
            (data["createdAt"] != null &&
                !(data["createdAt"] as Timestamp)
                    .toDate()
                    .isBefore(field.startAtToUse!))) {
          throw NotEnoughFieldOnDocumentException(
              "field ${field.fieldName} does not exist in document(id:$id)");
        }
      }
    }
  }

  ({
    CollectionReference<Map<String, dynamic>> collectionReference,
    DocumentReference<Map<String, dynamic>> documentReference
  }) getRef<T>(
    FirestoreCollection<T> collection,
    Map<FirestoreCollection, String> documentIdMap,
  ) {
    List<FirestoreCollection> collectionList = [collection];
    while (collectionList.first.parent != null) {
      collectionList = [collectionList.first.parent!, ...collectionList];
    }

    CollectionReference<Map<String, dynamic>>? collectionRef;
    DocumentReference<Map<String, dynamic>>? documentRef;

    for (final co in documentIdMap.keys) {
      if (!collectionList.contains(co)) {
        throw InvaidDocumentIdMapException(
            "collection $co is not parent for ${collection.collectionName}");
      }
    }

    for (final currentCollectionPath in collectionList) {
      final collectionName = currentCollectionPath.collectionName;
      collectionRef = currentCollectionPath == collectionList.first
          ? firestoreInstance.collection(collectionName)
          : documentRef!.collection(collectionName);

      documentRef = collectionRef.doc(documentIdMap[currentCollectionPath]);
    }
    if (_debug) {
      debugPrint(
          "document path: ${documentRef!.path}, collectin path: ${collectionRef!.path}");
    }
    return (
      collectionReference: collectionRef!,
      documentReference: documentRef!
    );
  }

  @visibleForTesting
  Query<Map<String, dynamic>> queryWrapper(
      List<FirestoreCollectionField> collectionFields,
      CollectionReference<Map<String, dynamic>> collectionReference,
      {required List<
              ({
                FirestoreCollectionField field,
                WhereQueryType whereQueryType,
                dynamic value
              })>
          whereList,
      required ({FirestoreCollectionField field, bool descending})? order,
      required Iterable<Object?>? startAt,
      required Iterable<Object?>? startAfter,
      required Iterable<Object?>? endAt,
      required Iterable<Object?>? endBefore,
      required int? limit,
      required int? limitToLast}) {
    Query<Map<String, dynamic>> query = collectionReference;
    for (final where in whereList) {
      if (!collectionFields.contains(where.field)) {
        throw InvaidFieldOnQueryException("${where.field}");
      }
      switch (where.whereQueryType) {
        case WhereQueryType.equal:
          query = query.where(where.field.fieldName, isEqualTo: where.value);
        case WhereQueryType.notEqualTo:
          query = query.where(where.field.fieldName, isNotEqualTo: where.value);
        case WhereQueryType.greaterThan:
          query =
              query.where(where.field.fieldName, isGreaterThan: where.value);
        case WhereQueryType.greaterThanOrEqualTo:
          query = query.where(where.field.fieldName,
              isGreaterThanOrEqualTo: where.value);
        case WhereQueryType.lessThan:
          query = query.where(where.field.fieldName, isLessThan: where.value);
        case WhereQueryType.lessThanOrEqualTo:
          query = query.where(where.field.fieldName,
              isLessThanOrEqualTo: where.value);
        case WhereQueryType.whereIn:
          query =
              query.where(where.field.fieldName, whereIn: where.value as List);
        case WhereQueryType.whereNotIn:
          query = query.where(where.field.fieldName,
              whereNotIn: where.value as List);
        case WhereQueryType.isNull:
          query =
              query.where(where.field.fieldName, isNull: where.value as bool);
        case WhereQueryType.arrayContains:
          query =
              query.where(where.field.fieldName, arrayContains: where.value);
        case WhereQueryType.arrayContainsAny:
          query =
              query.where(where.field.fieldName, arrayContainsAny: where.value);
      }
    }

    if (order != null) {
      if (!collectionFields.contains(order.field)) {
        throw InvaidFieldOnQueryException("${order.field}");
      }
      query =
          query.orderBy(order.field.fieldName, descending: order.descending);
    }

    query = startAt != null ? query.startAt(startAt) : query;
    query = startAfter != null ? query.startAfter(startAfter) : query;
    query = endAt != null ? query.endAt(endAt) : query;
    query = endBefore != null ? query.endBefore(endBefore) : query;
    query = limit != null ? query.limit(limit) : query;
    query = limitToLast != null ? query.limitToLast(limitToLast) : query;

    if (_debug) debugPrint(query.parameters.toString());

    return query;
  }
}

base class InvaidFieldOnQueryException implements Exception {
  InvaidFieldOnQueryException(this._info);

  @override
  String toString() {
    return "Invalid field on query: $info";
  }

  final String _info;
  String get info => _info;
}

base class InvaidDocumentIdMapException implements Exception {
  InvaidDocumentIdMapException(this._info);

  @override
  String toString() {
    return "Invalid document id map: $info";
  }

  final String _info;
  String get info => _info;
}

base class NotEnoughFieldOnDocumentException implements Exception {
  NotEnoughFieldOnDocumentException(this._info);

  @override
  String toString() {
    return "Not enough field on document: $info";
  }

  final String _info;
  String get info => _info;
}

base class NotAllowFieldOnDocumentException implements Exception {
  NotAllowFieldOnDocumentException(this._info);

  @override
  String toString() {
    return "Not allow field on document: $info";
  }

  final String _info;
  String get info => _info;
}
