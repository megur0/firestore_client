import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_stub/firebase_stub.dart';
import 'package:firestore_client/firestore_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// flutter test --plain-name 'firestore'
void main() {
  group("firestore", () {
    final firestoreClient = FirestoreClient(FirebaseFirestoreStub(), true);
    const uid = "uid";
    for (final ({
      FirestoreCollection firestoreCollection,
      Map<FirestoreCollection, String> idList,
      String collectionPath,
      String collectionId,
      String documentPath,
      String documentId,
    }) testData in [
      (
        firestoreCollection: _DummyCollection.rooms,
        idList: {},
        collectionPath: "/rooms",
        collectionId: "rooms",
        documentPath: "/rooms/${CollectionReferenceStub.dummyAutoId()}",
        documentId: CollectionReferenceStub.dummyAutoId()
      ),
      (
        firestoreCollection: _DummyCollection.rooms,
        idList: {_DummyCollection.rooms: 'roomId'},
        collectionPath: "/rooms",
        collectionId: "rooms",
        documentPath: "/rooms/roomId",
        documentId: "roomId"
      ),
      (
        firestoreCollection: _DummyCollection.messages,
        idList: {_DummyCollection.rooms: 'roomId'},
        collectionPath: "/rooms/roomId/messages",
        collectionId: "messages",
        documentPath:
            "/rooms/roomId/messages/${CollectionReferenceStub.dummyAutoId()}",
        documentId: CollectionReferenceStub.dummyAutoId()
      ),
      (
        firestoreCollection: _DummyCollection.userDatas,
        idList: {_DummyCollection.userDatas: uid},
        collectionPath: "/userDatas",
        collectionId: "userDatas",
        documentPath: "/userDatas/$uid",
        documentId: uid
      ),
      (
        firestoreCollection: _DummyCollection.messages,
        idList: {_DummyCollection.rooms: uid},
        collectionPath: "/rooms/$uid/messages",
        collectionId: "messages",
        documentPath:
            "/rooms/$uid/messages/${CollectionReferenceStub.dummyAutoId()}",
        documentId: CollectionReferenceStub.dummyAutoId()
      ),
      (
        firestoreCollection: _DummyCollection.messages,
        idList: {},
        collectionPath:
            "/rooms/${CollectionReferenceStub.dummyAutoId()}/messages",
        collectionId: "messages",
        documentPath:
            "/rooms/${CollectionReferenceStub.dummyAutoId()}/messages/${CollectionReferenceStub.dummyAutoId()}",
        documentId: CollectionReferenceStub.dummyAutoId()
      ),
    ]) {
      test("getRef test", () async {
        final res = firestoreClient.getRef(
          testData.firestoreCollection,
          testData.idList,
        );
        expect(res.collectionReference.path, testData.collectionPath);
        expect(res.collectionReference.id, testData.collectionId);
        expect(res.documentReference.path, testData.documentPath);
        expect(res.documentReference.id, testData.documentId);
      });
    }

    test("getRef test(exception)", () async {
      try {
        firestoreClient.getRef(
            _DummyCollection.messages, {_DummyCollection.userDatas: "xxxx"});
      } catch (e) {
        e.toString();
        expect(e.runtimeType, InvaidDocumentIdMapException);
        return;
      }
      throw Exception("test failed");
    });

    for (final ({
      Map<String, dynamic> Function() data,
      Type? expectException,
    }) testData in [
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: clock.now(),
              updatedAt: clock.now(),
              deletedAt: null));
          return d;
        },
        expectException: null
      ),
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: clock.now(),
              updatedAt: clock.now(),
              deletedAt: null));
          d.remove(_DummyField.createdAt.fieldName);
          return d;
        },
        expectException: NotEnoughFieldOnDocumentException
      ),
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: clock.now(),
              updatedAt: clock.now(),
              deletedAt: null));
          d.remove(_DummyField.addedField.fieldName);
          return d;
        },
        expectException: NotEnoughFieldOnDocumentException
      ),
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: DateTime.parse(addedFieldStartAtToUse),
              updatedAt: clock.now(),
              deletedAt: null));
          d.remove(_DummyField.addedField.fieldName);
          return d;
        },
        expectException: NotEnoughFieldOnDocumentException
      ),
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: DateTime.parse(addedFieldStartAtToUse)
                  .subtract(const Duration(seconds: 1)),
              updatedAt: clock.now(),
              deletedAt: null));
          d.remove(_DummyField.addedField.fieldName);
          return d;
        },
        expectException: null
      ),
      (
        data: () {
          final d = _DummyModel.toFirestore(_DummyModel(
              id: "",
              message: "",
              members: const [],
              addedField: "",
              createdAt: clock.now(),
              updatedAt: clock.now(),
              deletedAt: null));
          d.addAll({"notExistField": ""});
          return d;
        },
        expectException: NotAllowFieldOnDocumentException
      ),
    ]) {
      test("checkField test", () async {
        try {
          firestoreClient.checkFields(
            "dummyId",
            testData.data(),
            _DummyField.values,
          );
        } catch (e) {
          if (testData.expectException == null) {
            throw Exception("test failed: $e");
          }
          e.toString();
          expect(e.runtimeType, testData.expectException);
          return;
        }
        if (testData.expectException != null) {
          throw Exception("test failed");
        }
      });
    }

    for (final ({
      FirestoreCollection collection,
      List<
          ({
            FirestoreCollectionField field,
            dynamic value,
            WhereQueryType whereQueryType
          })> where,
    }) testData in [
      (
        collection: _DummyCollection.rooms,
        where: [],
      ),
      (
        collection: _DummyCollection.rooms,
        where: [
          (
            field: _DummyField.members,
            whereQueryType: WhereQueryType.arrayContains,
            value: uid,
          ),
        ],
      ),
      (
        collection: _DummyCollection.rooms,
        where: [
          (
            field: _DummyField.members,
            whereQueryType: WhereQueryType.arrayContainsAny,
            value: [uid],
          ),
        ],
      ),
      (
        collection: _DummyCollection.rooms,
        where: [
          (
            field: _DummyField.updatedAt,
            whereQueryType: WhereQueryType.equal,
            value: Timestamp.fromDate(clock.now()),
          ),
          (
            field: _DummyField.members,
            whereQueryType: WhereQueryType.arrayContains,
            value: uid,
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.equal,
            value: "a",
          ),
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.isNull,
            value: true,
          ),
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.whereIn,
            value: ["a", "b", "c"],
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.whereNotIn,
            value: ["a", "b", "c"],
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.isNull,
            value: true,
          ),
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.equal,
            value: "a",
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.whereIn,
            value: ["a", "b", "c"],
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.message,
            whereQueryType: WhereQueryType.notEqualTo,
            value: "a",
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.createdAt,
            whereQueryType: WhereQueryType.lessThan,
            value: DateTime(2000),
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.createdAt,
            whereQueryType: WhereQueryType.lessThanOrEqualTo,
            value: DateTime(2000),
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.createdAt,
            whereQueryType: WhereQueryType.greaterThan,
            value: DateTime(2000),
          ),
        ],
      ),
      (
        collection: _DummyCollection.messages,
        where: [
          (
            field: _DummyField.createdAt,
            whereQueryType: WhereQueryType.greaterThanOrEqualTo,
            value: DateTime(2000),
          ),
        ],
      ),
    ]) {
      // descriptionに"no expect"と記載しているテストは
      // カバレッジ（コードをなぞる）のみのテストとなる。

      test("queryWrapper test(no expect)", () async {
        firestoreClient.queryWrapper(
            testData.collection.fields,
            firestoreClient.getRef(
              testData.collection,
              {},
            ).collectionReference,
            whereList: testData.where,
            limit: 10,
            limitToLast: 10,
            startAfter: [],
            startAt: [],
            endAt: [],
            endBefore: [],
            order: null);
      });
    }

    test("queryWrapper exception test", () async {
      try {
        firestoreClient.queryWrapper(
            _DummyCollection.messages.fields,
            firestoreClient.getRef(
              _DummyCollection.messages,
              {},
            ).collectionReference,
            whereList: [
              (
                field: const _DummyField2(),
                whereQueryType: WhereQueryType.greaterThanOrEqualTo,
                value: DateTime(2000),
              )
            ],
            limit: 10,
            limitToLast: 10,
            startAfter: [],
            startAt: [],
            endAt: [],
            endBefore: [],
            order: null);
      } catch (e) {
        e.toString();
        expect(e.runtimeType, InvaidFieldOnQueryException);
        return;
      }
      throw Exception("test failed");
    });

    test("queryWrapper exception test", () async {
      try {
        firestoreClient.queryWrapper(
            _DummyCollection.messages.fields,
            firestoreClient.getRef(
              _DummyCollection.messages,
              {},
            ).collectionReference,
            whereList: [],
            limit: 10,
            limitToLast: 10,
            startAfter: [],
            startAt: [],
            endAt: [],
            endBefore: [],
            order: (field: const _DummyField2(), descending: true));
      } catch (e) {
        e.toString();
        expect(e.runtimeType, InvaidFieldOnQueryException);
        return;
      }
      throw Exception("test failed");
    });

    test("create test(no expect)", () async {
      await FirestoreClient(_FirebaseFirestoreStub())
          .createOrUpdateDocument(_DummyParam(), 0);
    });

    test("delete test(no expect)", () async {
      await FirestoreClient(_FirebaseFirestoreStub()).deleteDocument(
        _DummyParam(),
      );
    });

    test("fetch document test(no expect)", () async {
      await FirestoreClient(_FirebaseFirestoreStub()).fetchDocument(
        _DummyParam(),
      );
    });

    test("create error test", () async {
      final error = await FirestoreClient(_FirebaseFirestoreStubForError())
          .createOrUpdateDocument(_DummyParam(), 0, (e, s) => e);
      expect(error != null, true);
    });

    test("delete error test", () async {
      final error = await FirestoreClient(_FirebaseFirestoreStubForError())
          .deleteDocument(_DummyParam(), (e, s) => e);
      expect(error != null, true);
    });

    test("fetch document error test", () async {
      final result = await FirestoreClient(_FirebaseFirestoreStubForError())
          .fetchDocument(_DummyParam(), (e, s) => e);
      expect(result.error != null, true);
      expect(result.data == null, true);
    });
  });
}

Map<String, dynamic> _toFirestoreDummy(int m) {
  return {};
}

int _fromFirestoreDummy(
  String id,
  Map<String, dynamic> jsonMap,
) {
  return 0;
}

@immutable
class _DummyModel {
  const _DummyModel({
    required this.id,
    required this.message,
    required this.members,
    required this.createdAt,
    required this.addedField,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String message;
  final List<String> members;
  final String addedField;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  static Map<String, dynamic> toFirestore(_DummyModel roomMessage) {
    return {
      _DummyField.message.fieldName: roomMessage.message,
      _DummyField.members.fieldName: roomMessage.members,
      _DummyField.addedField.fieldName: roomMessage.addedField,
      _DummyField.createdAt.fieldName:
          Timestamp.fromDate(roomMessage.createdAt),
      _DummyField.updatedAt.fieldName:
          Timestamp.fromDate(roomMessage.updatedAt),
      _DummyField.deletedAt.fieldName: roomMessage.deletedAt != null
          ? Timestamp.fromDate(roomMessage.deletedAt!)
          : null,
    };
  }
}

const addedFieldStartAtToUse = "2023-09-04T15:50:00.274164+09:00";

enum _DummyField implements FirestoreCollectionField {
  message(null),
  members(null),
  addedField(addedFieldStartAtToUse),
  createdAt(null),
  updatedAt(null),
  deletedAt(null);

  const _DummyField(this._startAtToUse);

  @override
  get fieldName => name;

  final String? _startAtToUse;

  @override
  DateTime? get startAtToUse =>
      _startAtToUse != null ? DateTime.parse(_startAtToUse) : null;

  dynamic fromFirestoreField(Map<String, dynamic> json) {
    switch (this) {
      case message:
        return (json[name] as String);
      case members:
        List<String> list = [];
        for (final e in json[name] as List<dynamic>) {
          list.add(e);
        }
        return list;
      case addedField:
        return json[name] != null ? (json[name] as String) : "";
      case createdAt:
      case updatedAt:
        return (json[name] as Timestamp).toDate();
      case deletedAt:
        return json[name] != null ? (json[name] as Timestamp).toDate() : null;
    }
  }
}

class _DummyField2 implements FirestoreCollectionField {
  const _DummyField2();

  @override
  get fieldName => "dummy";

  @override
  DateTime? get startAtToUse => null;
}

final class _DummyParam extends FirestoreParam<int> {
  _DummyParam()
      : super(
          _DummyCollection.dummy,
          {},
        );
}

enum _DummyCollection<T> implements FirestoreCollection<T> {
  dummy(null, [], _fromFirestoreDummy, _toFirestoreDummy),
  userDatas(null, [], _fromFirestoreDummy, _toFirestoreDummy),
  rooms(null, _DummyField.values, _fromFirestoreDummy, _toFirestoreDummy),
  messages(rooms, _DummyField.values, _fromFirestoreDummy, _toFirestoreDummy);

  @override
  String get collectionName => name;

  final List<FirestoreCollectionField> _fields;

  @override
  List<FirestoreCollectionField> get fields => _fields;

  @override
  final _DummyCollection? parent;

  final T Function(
    String id,
    Map<String, dynamic> jsonMap,
  ) _fromFirestore;

  @override
  T fromFirestore(
    String id,
    Map<String, dynamic> jsonMap,
  ) =>
      _fromFirestore(id, jsonMap);

  final Map<String, dynamic> Function(T data) _toFirestore;

  @override
  Map<String, dynamic> toFirestore(T data) => _toFirestore(data);

  const _DummyCollection(
      this.parent, this._fields, this._fromFirestore, this._toFirestore);
}

class _FirebaseFirestoreStub extends FirebaseFirestoreStubBase {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _CollectionReferenceStub();
  }
}

// ignore:subtype_of_sealed_class
class _CollectionReferenceStub
    extends CollectionReferenceStubBase<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _DocumentReferenceStub();
  }
}

// ignore:subtype_of_sealed_class
class _DocumentReferenceStub
    extends DocumentReferenceStubBase<Map<String, dynamic>> {
  _DocumentReferenceStub();

  @override
  String get id => "";

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _CollectionReferenceStub();
  }

  @override
  Future<void> delete() async {}

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    return _DocumentSnapshotStub();
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
}

// ignore:subtype_of_sealed_class
class _DocumentSnapshotStub
    extends DocumentSnapshotStubBase<Map<String, dynamic>> {
  @override
  String get id => "xxxx";

  @override
  Map<String, dynamic>? data() => {};
}

class _FirebaseFirestoreStubForError extends FirebaseFirestoreStubBase {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _CollectionReferenceStubForError();
  }
}

// ignore:subtype_of_sealed_class
class _CollectionReferenceStubForError
    extends CollectionReferenceStubBase<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _DocumentReferenceStubForError();
  }
}

// ignore:subtype_of_sealed_class
class _DocumentReferenceStubForError
    extends DocumentReferenceStubBase<Map<String, dynamic>> {
  @override
  String get id => "";

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _CollectionReferenceStub();
  }
}
