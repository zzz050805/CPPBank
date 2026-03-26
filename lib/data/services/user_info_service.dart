import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_info_model.dart';

class UserInfoService {
  UserInfoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserInfoModel?> watchUserInfo(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      return UserInfoModel.fromMap(uid: uid, data: data);
    });
  }
}
