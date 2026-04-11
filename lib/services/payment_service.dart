import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_preferences.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'home_cache_service.dart';
import 'notification_service.dart';

class PaymentProcessResult {
  const PaymentProcessResult({
    required this.transactionId,
    required this.amount,
    required this.billType,
    required this.billId,
    required this.processedAt,
  });

  final String transactionId;
  final double amount;
  final String billType;
  final String billId;
  final DateTime processedAt;
}

class PaymentServiceException implements Exception {
  const PaymentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  String _resolveUid() {
    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromProfile =
        UserFirestoreService.instance.latestProfile?.uid;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  String _languageCode() {
    final String code = AppPreferences.instance.locale.languageCode
        .toLowerCase();
    return code == 'en' ? 'en' : 'vi';
  }

  double _parseBalance(dynamic rawBalance) {
    if (rawBalance is num) {
      return rawBalance.toDouble();
    }

    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      final double? direct = double.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }

      final String digits = trimmed.replaceAll(RegExp(r'[^0-9-]'), '');
      if (digits.isEmpty || digits == '-') {
        return 0;
      }
      return double.tryParse(digits) ?? 0;
    }

    return 0;
  }

  bool _parseHasVipCard(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return false;
  }

  String _mapBillTypeToKey(String billType) {
    switch (billType) {
      case 'electric':
        return 'bill_type_electric';
      case 'water':
        return 'bill_type_water';
      case 'internet':
        return 'bill_type_internet';
      case 'mobile':
      case 'mobile_postpaid':
        return 'bill_type_mobile';
      default:
        return 'service';
    }
  }

  String _mapBillTypeToSpendingKey(String billType) {
    switch (billType) {
      case 'mobile':
      case 'mobile_postpaid':
        return 'phone';
      case 'electric':
      case 'water':
      case 'internet':
      default:
        return 'bill';
    }
  }

  String _formatAmountByLanguage(double amount, String languageCode) {
    if (languageCode == 'en') {
      final NumberFormat format = NumberFormat('#,##0.##', 'en_US');
      return '${format.format(amount)} VND';
    }

    final NumberFormat format = NumberFormat.decimalPattern('vi_VN');
    return '${format.format(amount)} VND';
  }

  Future<PaymentProcessResult> processPayment({
    required double amount,
    required String billType,
    required String billId,
  }) async {
    final String uid = _resolveUid();
    final String languageCode = _languageCode();

    if (uid.isEmpty) {
      throw PaymentServiceException(
        AppText.textByCode(languageCode, 'no_valid_login_session'),
      );
    }

    final String insufficientBalanceMessage = AppText.textByCode(
      languageCode,
      'insufficient_balance',
    );

    final HomeCacheData cache = HomeCacheService.instance.notifier.value;
    if (cache.isReady && cache.totalBalance < amount) {
      throw PaymentServiceException(insufficientBalanceMessage);
    }

    final String billTypeKey = _mapBillTypeToKey(billType);
    final String spendingKey = _mapBillTypeToSpendingKey(billType);
    final String billTypeLabel = AppText.textByCode(languageCode, billTypeKey);
    final String amountText = _formatAmountByLanguage(amount, languageCode);

    final String notificationTitle = AppText.paymentSuccessTitleByCode(
      languageCode,
    );

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
        .collection('cards')
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
        .collection('cards')
        .doc('vip');
    final DocumentReference<Map<String, dynamic>> payBillRef = userRef
        .collection('pay_bill')
        .doc();
    final DocumentReference<Map<String, dynamic>> spendingStatsRef = userRef
        .collection('spending_stats')
        .doc('summary');
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();

    double currentBalanceAfterPayment = 0;

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw PaymentServiceException(
          AppText.textByCode(languageCode, 'user_account_not_exists'),
        );
      }

      final Map<String, dynamic> userData =
          userSnapshot.data() ?? <String, dynamic>{};
      final bool hasVipCard = _parseHasVipCard(userData['hasVipCard']);
      final double userBalance = _parseBalance(userData['balance']);

      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);

      double standardBalance = _parseBalance(
        standardCardSnap.data()?['balance'],
      );
      double vipBalance = _parseBalance(vipCardSnap.data()?['balance']);

      final double cardsBalance = hasVipCard
          ? (standardBalance + vipBalance)
          : standardBalance;
      final bool hasAnyCardBalance = cardsBalance > 0;
      final double currentBalance = hasAnyCardBalance
          ? cardsBalance
          : userBalance;

      if (currentBalance < amount) {
        throw PaymentServiceException(insufficientBalanceMessage);
      }

      double newBalance;

      if (hasAnyCardBalance) {
        if (standardBalance >= amount) {
          standardBalance -= amount;
        } else {
          final double remaining = amount - standardBalance;
          standardBalance = 0;

          if (!hasVipCard || vipBalance < remaining) {
            throw PaymentServiceException(insufficientBalanceMessage);
          }

          vipBalance -= remaining;
        }

        newBalance = hasVipCard
            ? (standardBalance + vipBalance)
            : standardBalance;

        transaction.set(standardCardRef, <String, dynamic>{
          'balance': standardBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (hasVipCard) {
          transaction.set(vipCardRef, <String, dynamic>{
            'balance': vipBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        newBalance = userBalance - amount;
      }

      currentBalanceAfterPayment = newBalance;

      final String balanceText = _formatAmountByLanguage(
        currentBalanceAfterPayment,
        languageCode,
      );
      final String notificationBody = AppText.paymentNotificationBodyByCode(
        languageCode,
        amount: amountText,
        billType: billTypeLabel,
        billId: billId,
        balance: balanceText,
      );

      final Map<String, dynamic> spendingStatsUpdate = <String, dynamic>{
        'bill': FieldValue.increment(amount),
        'thanh_toan_hoa_don': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (spendingKey == 'phone') {
        spendingStatsUpdate['phone'] = FieldValue.increment(amount);
      }

      final Map<String, dynamic> userBalanceAndStatsUpdate = <String, dynamic>{
        'balance': newBalance,
        'spending_stats.bill': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (spendingKey == 'phone') {
        userBalanceAndStatsUpdate['spending_stats.phone'] =
            FieldValue.increment(amount);
      }

      transaction.set(
        userRef,
        userBalanceAndStatsUpdate,
        SetOptions(merge: true),
      );

      transaction.set(
        spendingStatsRef,
        spendingStatsUpdate,
        SetOptions(merge: true),
      );

      transaction.set(payBillRef, <String, dynamic>{
        'type': billType,
        'billType': billType,
        'id': billId,
        'customerCode': billId,
        'amount': amount,
        'amountText': amountText,
        'isNegative': true,
        'date': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'transactionCode': payBillRef.id,
        'relatedId': payBillRef.id,
      }, SetOptions(merge: true));

      transaction.set(notificationRef, <String, dynamic>{
        'title': notificationTitle,
        'body': notificationBody,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'payment',
        'isRead': false,
        'status': 'completed',
        'amount': amount,
        'billType': billType,
        'billId': billId,
        'relatedId': payBillRef.id,
      }, SetOptions(merge: true));
    });

    final String balanceText = _formatAmountByLanguage(
      currentBalanceAfterPayment,
      languageCode,
    );
    final String notificationBody = AppText.paymentNotificationBodyByCode(
      languageCode,
      amount: amountText,
      billType: billTypeLabel,
      billId: billId,
      balance: balanceText,
    );

    HomeCacheService.instance.applyPaymentDeduction(amount);

    await NotificationService().showPaymentSuccessHeadsUp(
      title: notificationTitle,
      body: notificationBody,
    );

    return PaymentProcessResult(
      transactionId: payBillRef.id,
      amount: amount,
      billType: billType,
      billId: billId,
      processedAt: now,
    );
  }
}
