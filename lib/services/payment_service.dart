import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_preferences.dart';
import '../services/user_firestore_service.dart';
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
    String? sourceCardId,
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

    final String notificationTitle = AppText.paymentSuccessSpecificTitleByCode(
      languageCode,
      serviceName: billTypeLabel,
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
    final DocumentReference<Map<String, dynamic>> billPaymentRef = userRef
        .collection('bill_payment')
        .doc(payBillRef.id);
    final DocumentReference<Map<String, dynamic>> transactionRef = userRef
        .collection('transactions')
        .doc(payBillRef.id);
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

      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);

      final Map<String, dynamic> standardCardData =
          standardCardSnap.data() ?? <String, dynamic>{};
      final Map<String, dynamic> vipCardData =
          vipCardSnap.data() ?? <String, dynamic>{};
      final Map<String, Map<String, dynamic>> cardsById =
          <String, Map<String, dynamic>>{
            'standard': standardCardData,
            'vip': vipCardData,
          };

      final bool standardAvailable = UserFirestoreService.instance
          .isCardAvailableForTransactions(
            cardId: 'standard',
            cardData: standardCardData,
            userData: userData,
          );
      final bool vipAvailable = UserFirestoreService.instance
          .isCardAvailableForTransactions(
            cardId: 'vip',
            cardData: vipCardData,
            userData: userData,
          );

      final double availableBalance = UserFirestoreService.instance
          .calculateAvailableBalanceFromMaps(
            userData: userData,
            cardsById: cardsById,
          );

      if (availableBalance < amount) {
        throw PaymentServiceException(insufficientBalanceMessage);
      }

      final double standardBalance = _parseBalance(standardCardData['balance']);
      final double vipBalance = _parseBalance(vipCardData['balance']);

      final String requestedCardId = (sourceCardId ?? '').trim().toLowerCase();
      final bool hasRequestedCard =
          requestedCardId == 'standard' || requestedCardId == 'vip';
      final String effectiveCardId = hasRequestedCard ? requestedCardId : '';

      double remaining = amount;
      double standardDeduction = 0;
      double vipDeduction = 0;

      if (hasRequestedCard) {
        final bool selectedAvailable = effectiveCardId == 'standard'
            ? standardAvailable
            : vipAvailable;
        final double selectedBalance = effectiveCardId == 'standard'
            ? standardBalance
            : vipBalance;

        if (!selectedAvailable) {
          throw PaymentServiceException(
            AppText.textByCode(languageCode, 'card_unavailable'),
          );
        }

        if (selectedBalance < amount) {
          throw PaymentServiceException(insufficientBalanceMessage);
        }

        if (effectiveCardId == 'standard') {
          standardDeduction = amount;
        } else {
          vipDeduction = amount;
        }
        remaining = 0;
      }

      if (!hasRequestedCard && standardAvailable && remaining > 0) {
        standardDeduction = remaining <= standardBalance
            ? remaining
            : standardBalance;
        remaining -= standardDeduction;
      }

      if (!hasRequestedCard && vipAvailable && remaining > 0) {
        vipDeduction = remaining <= vipBalance ? remaining : vipBalance;
        remaining -= vipDeduction;
      }

      if (remaining > 0) {
        throw PaymentServiceException(insufficientBalanceMessage);
      }

      if (standardDeduction > 0) {
        transaction.set(standardCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-standardDeduction),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (vipDeduction > 0) {
        transaction.set(vipCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-vipDeduction),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final double nextAvailableBalance = availableBalance - amount;
      currentBalanceAfterPayment = nextAvailableBalance < 0
          ? 0
          : nextAvailableBalance;

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
      final Map<String, String> titleParams = <String, String>{
        'serviceName': billTypeLabel,
      };
      final Map<String, String> bodyParams = <String, String>{
        'amount': amountText,
        'billType': billTypeLabel,
        'billId': billId,
        'balance': balanceText,
      };

      final Map<String, dynamic> spendingStatsUpdate = <String, dynamic>{
        'bill': FieldValue.increment(amount),
        'thanh_toan_hoa_don': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (spendingKey == 'phone') {
        spendingStatsUpdate['phone'] = FieldValue.increment(amount);
      }

      final Map<String, dynamic> userBalanceAndStatsUpdate = <String, dynamic>{
        'balance': FieldValue.increment(-amount),
        'availableBalance': FieldValue.increment(-amount),
        'totalBalance': FieldValue.increment(-amount),
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
        if (effectiveCardId.isNotEmpty) 'cardId': effectiveCardId,
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

      transaction.set(billPaymentRef, <String, dynamic>{
        'type': 'bill_payment',
        'billType': billType,
        if (effectiveCardId.isNotEmpty) 'cardId': effectiveCardId,
        'id': billId,
        'customerCode': billId,
        'amount': amount,
        'amountText': amountText,
        'isNegative': true,
        'date': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'timestamp_client': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAt_client': Timestamp.fromDate(now),
        'status': 'completed',
        'transactionCode': payBillRef.id,
        'relatedId': payBillRef.id,
      }, SetOptions(merge: true));

      transaction.set(transactionRef, <String, dynamic>{
        'type': 'bill_payment',
        'billType': billType,
        if (effectiveCardId.isNotEmpty) 'cardId': effectiveCardId,
        'amount': amount,
        'amountText': amountText,
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'timestamp_client': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAt_client': Timestamp.fromDate(now),
        'transactionCode': payBillRef.id,
        'relatedId': payBillRef.id,
        'customerCode': billId,
        'isNegative': true,
      }, SetOptions(merge: true));

      transaction.set(notificationRef, <String, dynamic>{
        'title': notificationTitle,
        'titleKey': 'payment_success_specific',
        'titleParams': titleParams,
        'serviceType': billType,
        'serviceTypeKey': billTypeKey,
        'body': notificationBody,
        'bodyKey': 'payment_notification_body',
        'bodyParams': bodyParams,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'bill_payment',
        'isRead': false,
        'isNegative': true,
        'status': 'completed',
        'amount': amount,
        'billType': billType,
        if (effectiveCardId.isNotEmpty) 'cardId': effectiveCardId,
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
