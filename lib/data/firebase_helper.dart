import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hàm mẫu: Lấy số dư của người dùng theo ID
  Future<double> getUserBalance(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc['balance'] ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print("Lỗi lấy số dư: $e");
      return 0.0;
    }
  }
}