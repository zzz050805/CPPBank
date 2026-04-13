import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserInfoModel {
  const UserInfoModel({
    required this.uid,
    required this.fullName,
    required this.idNumber,
    required this.idDate,
    required this.idPlace,
    required this.expiryDate,
    required this.gender,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.membershipTier,
    required this.hasVipCard,
  });

  final String uid;
  final String? fullName;
  final String? idNumber;
  final String? idDate;
  final String? idPlace;
  final String? expiryDate;
  final String? gender;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final String membershipTier;
  final bool hasVipCard;

  static String? _asText(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(value.toDate());
    }
    if (value is DateTime) {
      return DateFormat('dd/MM/yyyy').format(value);
    }

    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  factory UserInfoModel.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final bool hasVipCard = data['hasVipCard'] == true;
    final String membershipTier =
        _asText(data['membershipTier']) ?? 'Thành viên';

    return UserInfoModel(
      uid: uid,
      fullName: _asText(data['fullName'] ?? data['fullname']),
      idNumber: _asText(data['idNumber'] ?? data['cccd']),
      idDate: _asText(data['idDate'] ?? data['issueDate']),
      idPlace: _asText(data['idPlace']),
      expiryDate: _asText(data['expiryDate']),
      gender: _asText(data['gender']),
      phoneNumber: _asText(data['phoneNumber']),
      email: _asText(data['email']),
      address: _asText(data['address']),
      membershipTier: membershipTier,
      hasVipCard: hasVipCard,
    );
  }
}
