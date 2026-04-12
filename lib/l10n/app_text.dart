import 'package:flutter/material.dart';

class AppText {
  static const String _defaultLanguageCode = 'vi';

  static const Map<String, Map<String, String>>
  _terms = <String, Map<String, String>>{
    'lookup_result': <String, String>{
      'vi': 'Kết quả tra cứu',
      'en': 'Lookup result',
    },
    'customer_code': <String, String>{
      'vi': 'Mã khách hàng',
      'en': 'Customer code',
    },
    'alias': <String, String>{'vi': 'Tên gợi nhớ', 'en': 'Alias'},
    'billing_cycle': <String, String>{
      'vi': 'Kỳ hóa đơn',
      'en': 'Billing cycle',
    },
    'due_date': <String, String>{'vi': 'Hạn thanh toán', 'en': 'Due date'},
    'payment_amount': <String, String>{
      'vi': 'Số tiền thanh toán',
      'en': 'Payment amount',
    },
    'provider': <String, String>{'vi': 'Nhà cung cấp', 'en': 'Provider'},
    'internet_service': <String, String>{
      'vi': 'Dịch vụ Internet',
      'en': 'Internet service',
    },
    'mobile_postpaid': <String, String>{
      'vi': 'Di động trả sau',
      'en': 'Mobile postpaid',
    },
    'payment_success': <String, String>{
      'vi': 'Thanh toán thành công',
      'en': 'Payment successful',
    },
    'payment_success_title': <String, String>{
      'vi': 'Thanh toán thành công!',
      'en': 'Payment successful!',
    },
    'payment_success_specific': <String, String>{
      'vi': 'Thanh toán hóa đơn {serviceName} thành công!',
      'en': '{serviceName} bill payment successful!',
    },
    'payment_success_body': <String, String>{
      'vi': 'Bạn đã thanh toán {amount} cho hóa đơn {billType}.',
      'en': 'You have paid {amount} for {billType} bill.',
    },
    'payment_notification_body': <String, String>{
      'vi':
          'Bạn đã thanh toán {amount} cho hóa đơn {billType} của {billId}. Số dư hiện tại là: {balance}. Cảm ơn Quý khách!',
      'en':
          'You paid {amount} for the {billType} bill of {billId}. Your current balance is: {balance}. Thank you for banking with us!',
    },
    'insufficient_balance': <String, String>{
      'vi': 'Số dư không đủ.',
      'en': 'Insufficient balance.',
    },
    'view_history': <String, String>{'vi': 'Xem lịch sử', 'en': 'View history'},
    'back_to_home': <String, String>{
      'vi': 'Về trang chủ',
      'en': 'Back to Home',
    },
    'bill_type_electric': <String, String>{
      'vi': 'Tiền điện',
      'en': 'Electricity',
    },
    'bill_type_water': <String, String>{'vi': 'Tiền nước', 'en': 'Water'},
    'bill_type_internet': <String, String>{'vi': 'Internet', 'en': 'Internet'},
    'bill_type_mobile': <String, String>{'vi': 'Di động', 'en': 'Mobile'},
    'service': <String, String>{'vi': 'Dịch vụ', 'en': 'Service'},
    'no_valid_login_session': <String, String>{
      'vi': 'Không tìm thấy phiên đăng nhập hợp lệ.',
      'en': 'No valid login session found.',
    },
    'user_account_not_exists': <String, String>{
      'vi': 'Không tìm thấy tài khoản người dùng.',
      'en': 'User account does not exist.',
    },
    'tab_cards': <String, String>{'vi': 'Thẻ', 'en': 'Cards'},
    'card_standard': <String, String>{
      'vi': 'Thẻ Thường',
      'en': 'Standard Card',
    },
    'card_vip': <String, String>{'vi': 'Thẻ VIP', 'en': 'VIP Card'},
    'status_active': <String, String>{'vi': 'Đang hoạt động', 'en': 'Active'},
    'status_locked': <String, String>{'vi': 'Đã khóa', 'en': 'Locked'},
    'lock_card': <String, String>{'vi': 'Khóa thẻ', 'en': 'Lock card'},
    'unlock_card': <String, String>{'vi': 'Mở thẻ', 'en': 'Unlock card'},
  };

  static String tr(BuildContext context, String vi, String en) {
    return currentLanguageCode(context) == 'en' ? en : vi;
  }

  static String currentLanguageCode(BuildContext context) {
    final String code = Localizations.localeOf(context).languageCode;
    if (code == 'vi' || code == 'en') {
      return code;
    }
    return _defaultLanguageCode;
  }

  static String systemLanguageCode() {
    final String code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (code == 'vi' || code == 'en') {
      return code;
    }
    return _defaultLanguageCode;
  }

  static String text(BuildContext context, String key) {
    return textByCode(currentLanguageCode(context), key);
  }

  static String textWithParams(
    BuildContext context,
    String key,
    Map<String, String> params,
  ) {
    return _applyParams(text(context, key), params);
  }

  static String textByCode(String languageCode, String key) {
    final Map<String, String>? entry = _terms[key];
    if (entry == null) {
      return key;
    }

    return entry[languageCode] ??
        entry[_defaultLanguageCode] ??
        entry['en'] ??
        key;
  }

  static String textByCodeWithParams(
    String languageCode,
    String key,
    Map<String, String> params,
  ) {
    return _applyParams(textByCode(languageCode, key), params);
  }

  static String lookupResult(BuildContext context) {
    return text(context, 'lookup_result');
  }

  static String customerCode(BuildContext context) {
    return text(context, 'customer_code');
  }

  static String alias(BuildContext context) {
    return text(context, 'alias');
  }

  static String billingCycle(BuildContext context) {
    return text(context, 'billing_cycle');
  }

  static String dueDate(BuildContext context) {
    return text(context, 'due_date');
  }

  static String paymentAmount(BuildContext context) {
    return text(context, 'payment_amount');
  }

  static String provider(BuildContext context) {
    return text(context, 'provider');
  }

  static String paymentSuccessTitle(BuildContext context) {
    return text(context, 'payment_success_title');
  }

  static String paymentSuccessTitleByCode(String languageCode) {
    return textByCode(languageCode, 'payment_success_title');
  }

  static String paymentSuccessSpecificTitle(
    BuildContext context, {
    required String serviceName,
  }) {
    return textWithParams(context, 'payment_success_specific', <String, String>{
      'serviceName': serviceName,
    });
  }

  static String paymentSuccessSpecificTitleByCode(
    String languageCode, {
    required String serviceName,
  }) {
    return textByCodeWithParams(
      languageCode,
      'payment_success_specific',
      <String, String>{'serviceName': serviceName},
    );
  }

  static String paymentNotificationBody(
    BuildContext context, {
    required String amount,
    required String billType,
    required String billId,
    required String balance,
  }) {
    return textWithParams(
      context,
      'payment_notification_body',
      <String, String>{
        'amount': amount,
        'billType': billType,
        'billId': billId,
        'balance': balance,
      },
    );
  }

  static String paymentNotificationBodyByCode(
    String languageCode, {
    required String amount,
    required String billType,
    required String billId,
    required String balance,
  }) {
    return textByCodeWithParams(
      languageCode,
      'payment_notification_body',
      <String, String>{
        'amount': amount,
        'billType': billType,
        'billId': billId,
        'balance': balance,
      },
    );
  }

  static String _applyParams(String template, Map<String, String> params) {
    String result = template;
    params.forEach((String key, String value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
