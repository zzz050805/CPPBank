import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationFirestoreService {
  NotificationFirestoreService._();

  static final NotificationFirestoreService instance =
      NotificationFirestoreService._();

  CollectionReference<Map<String, dynamic>> userNotificationsRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Future<void> createNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    num? amount,
  }) async {
    await userNotificationsRef(uid).add(<String, dynamic>{
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'isRead': false,
      if (relatedId != null && relatedId.isNotEmpty) 'relatedId': relatedId,
      'amount': ?amount,
    });
  }

  Stream<int> unreadCountStream(String uid) {
    return userNotificationsRef(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.length,
        );
  }

  Future<void> markAllAsRead(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> unreadSnapshot =
        await userNotificationsRef(uid).where('isRead', isEqualTo: false).get();

    if (unreadSnapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in unreadSnapshot.docs) {
      batch.update(doc.reference, <String, dynamic>{'isRead': true});
    }

    await batch.commit();
  }
}
