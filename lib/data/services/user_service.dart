import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_info_model.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserInfoModel?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      return UserInfoModel.fromMap(uid: uid, data: data);
    });
  }

  Future<void> updateUserField({
    required String uid,
    required String fieldKey,
    required String value,
  }) async {
    const Set<String> editableFields = <String>{
      'phoneNumber',
      'email',
      'address',
    };

    if (!editableFields.contains(fieldKey)) {
      throw ArgumentError('Field is not allowed to update: $fieldKey');
    }

    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      fieldKey: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSmartOtpPin({
    required String uid,
    required String newPin,
  }) async {
    if (newPin.length != 6 || int.tryParse(newPin) == null) {
      throw ArgumentError('Smart OTP PIN must be 6 digits');
    }

    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      'smartOtpPin': newPin,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
