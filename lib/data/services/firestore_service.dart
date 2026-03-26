import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> update({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserField({
    required String uid,
    required String field,
    required String value,
  }) async {
    await update(uid: uid, data: <String, dynamic>{field: value});
  }
}
