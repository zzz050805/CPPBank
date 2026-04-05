import 'package:flutter/material.dart';

class AppTranslations {
  AppTranslations._();

  static const String _defaultLanguageCode = 'vi';

  static const Map<String, Map<String, String>>
  _translations = <String, Map<String, String>>{
    'service_store': <String, String>{
      'vi': 'Cửa hàng dịch vụ',
      'en': 'Service Store',
    },
    'confirm_payment': <String, String>{
      'vi': 'Xác nhận thanh toán',
      'en': 'Confirm Payment',
    },
    'payment_review': <String, String>{
      'vi': 'Rà soát giao dịch',
      'en': 'Payment Review',
    },
    'cancel': <String, String>{'vi': 'Hủy', 'en': 'Cancel'},
    'confirm': <String, String>{'vi': 'Xác nhận', 'en': 'Confirm'},
    'confirm_and_pay': <String, String>{
      'vi': 'Xác nhận và Thanh toán',
      'en': 'Confirm & Pay',
    },
    'transaction_authentication': <String, String>{
      'vi': 'Xác thực giao dịch',
      'en': 'Transaction Authentication',
    },
    'enter_smart_otp_code': <String, String>{
      'vi': 'Nhập mã Smart OTP',
      'en': 'Enter Smart OTP Code',
    },
    'invalid_email': <String, String>{
      'vi': 'Vui lòng nhập email hợp lệ.',
      'en': 'Please enter a valid email address.',
    },
    'invalid_icloud_email': <String, String>{
      'vi': 'Vui lòng nhập email iCloud hợp lệ.',
      'en': 'Please enter a valid iCloud email address.',
    },
    'invalid_input': <String, String>{
      'vi': 'Dữ liệu không hợp lệ.',
      'en': 'Invalid input.',
    },
    'invalid_recipient_account': <String, String>{
      'vi': 'Thông tin tài khoản thụ hưởng không hợp lệ.',
      'en': 'Recipient account details are invalid.',
    },
    'no_valid_login_session': <String, String>{
      'vi': 'Không tìm thấy phiên đăng nhập hợp lệ.',
      'en': 'No valid login session found.',
    },
    'smart_otp_not_set_up': <String, String>{
      'vi': 'Tài khoản chưa cài đặt Smart OTP PIN.',
      'en': 'Smart OTP PIN is not set up.',
    },
    'incorrect_pin_try_again': <String, String>{
      'vi': 'Mã PIN không chính xác. Vui lòng thử lại.',
      'en': 'Incorrect PIN. Please try again.',
    },
    'verification_failed_try_again': <String, String>{
      'vi': 'Xác thực thất bại. Vui lòng thử lại.',
      'en': 'Verification failed. Please try again.',
    },
    'payment_failed': <String, String>{
      'vi': 'Thanh toán thất bại. Vui lòng thử lại.',
      'en': 'Payment failed. Please try again.',
    },
    'payment_successful': <String, String>{
      'vi': 'Thanh toán thành công!',
      'en': 'Payment Successful!',
    },
    'success_title': <String, String>{
      'vi': 'Thành công',
      'en': 'Payment Successful',
    },
    'transaction_success': <String, String>{
      'vi': 'Giao dịch thành công',
      'en': 'Transaction successful',
    },
    'shopping_payment_body': <String, String>{
      'vi': 'Thanh toán dịch vụ {service} - {amount} VND',
      'en': 'Successfully paid for {service} - {amount} VND',
    },
    'transfer_success_title': <String, String>{
      'vi': 'Chuyển khoản thành công',
      'en': 'Transfer successful',
    },
    'transfer_success_body': <String, String>{
      'vi': 'Đã chuyển {amount} VND đến {receiver}',
      'en': 'Transferred {amount} VND to {receiver}',
    },
    'withdraw_success_title': <String, String>{
      'vi': 'Rút tiền thành công',
      'en': 'Withdrawal successful',
    },
    'withdraw_success_body': <String, String>{
      'vi': 'Rút tiền mặt {amount} VND tại điểm giao dịch',
      'en': 'Withdrew cash {amount} VND at the service point',
    },
    'withdraw_notification_title': <String, String>{
      'vi': 'Rút tiền mặt',
      'en': 'Cash withdrawal',
    },
    'withdraw_notification_body': <String, String>{
      'vi': 'Mã {code} - {amount} VND',
      'en': 'Code {code} - {amount} VND',
    },
    'banner_fallback_label': <String, String>{'vi': 'Biểu ngữ', 'en': 'Banner'},
    'paid_for': <String, String>{'vi': 'Đã thanh toán cho', 'en': 'Paid for'},
    'top_up_for': <String, String>{'vi': 'Đã nạp tiền cho', 'en': 'Top-up for'},
    'transferred_to': <String, String>{
      'vi': 'Đã chuyển tiền đến',
      'en': 'Transferred to',
    },
    'payment_success_content': <String, String>{
      'vi': 'Giao dịch thanh toán đã hoàn tất thành công.',
      'en': 'Your payment has been completed successfully.',
    },
    'transaction_receipt': <String, String>{
      'vi': 'Hóa đơn giao dịch',
      'en': 'Transaction Receipt',
    },
    'transaction_id': <String, String>{
      'vi': 'Mã giao dịch',
      'en': 'Transaction ID',
    },
    'from': <String, String>{'vi': 'Chuyển từ', 'en': 'From'},
    'service': <String, String>{'vi': 'Dịch vụ', 'en': 'Service'},
    'package': <String, String>{'vi': 'Gói cước', 'en': 'Package'},
    'recipient_account': <String, String>{
      'vi': 'Tài khoản nhận',
      'en': 'Recipient Account',
    },
    'fee': <String, String>{'vi': 'Phí', 'en': 'Fee'},
    'total': <String, String>{'vi': 'Tổng cộng', 'en': 'Total'},
    'time': <String, String>{'vi': 'Thời gian', 'en': 'Time'},
    'back_to_home': <String, String>{
      'vi': 'Về trang chủ',
      'en': 'Back to Home',
    },
    'top_up': <String, String>{'vi': 'Nạp', 'en': 'Top Up'},
    'shopping_payment_title': <String, String>{
      'vi': 'Thanh toán Mua sắm - Giải trí',
      'en': 'Shopping/Entertainment Payment',
    },
    'mobile_plan': <String, String>{'vi': 'Gói Mobile', 'en': 'Mobile Plan'},
    'basic_plan': <String, String>{'vi': 'Gói Basic', 'en': 'Basic Plan'},
    'premium_plan': <String, String>{'vi': 'Gói Premium', 'en': 'Premium Plan'},
    'mini_plan': <String, String>{'vi': 'Gói Mini', 'en': 'Mini Plan'},
    'individual_plan': <String, String>{
      'vi': 'Gói Individual',
      'en': 'Individual Plan',
    },
    'family_plan': <String, String>{'vi': 'Gói Family', 'en': 'Family Plan'},
    'student_plan': <String, String>{'vi': 'Gói Student', 'en': 'Student Plan'},
    'plus_plan': <String, String>{'vi': 'Gói Plus', 'en': 'Plus Plan'},
    'pro_plan': <String, String>{'vi': 'Gói Pro', 'en': 'Pro Plan'},
    'starter_plan': <String, String>{'vi': 'Gói Starter', 'en': 'Starter Plan'},
    'advanced_plan': <String, String>{
      'vi': 'Gói Advanced',
      'en': 'Advanced Plan',
    },
    'ultra_plan': <String, String>{'vi': 'Gói Ultra', 'en': 'Ultra Plan'},
  };

  static String currentLanguageCode(BuildContext context) {
    final String code = Localizations.localeOf(context).languageCode;
    if (code == 'vi' || code == 'en') {
      return code;
    }
    return _defaultLanguageCode;
  }

  static String getText(BuildContext context, String key) {
    return getTextByCode(currentLanguageCode(context), key);
  }

  static String getTextWithParams(
    BuildContext context,
    String key,
    Map<String, String> params,
  ) {
    return _applyParams(getText(context, key), params);
  }

  static String getTextByCode(String languageCode, String key) {
    final Map<String, String>? entry = _translations[key];
    if (entry == null) {
      return key;
    }

    return entry[languageCode] ??
        entry[_defaultLanguageCode] ??
        entry['en'] ??
        (entry.isNotEmpty ? entry.values.first : key);
  }

  static String getTextByCodeWithParams(
    String languageCode,
    String key,
    Map<String, String> params,
  ) {
    return _applyParams(getTextByCode(languageCode, key), params);
  }

  static String fromLocalizedMap(
    Map<String, String> localizedMap,
    String languageCode,
  ) {
    if (localizedMap.isEmpty) {
      return '';
    }

    return localizedMap[languageCode] ??
        localizedMap[_defaultLanguageCode] ??
        localizedMap['en'] ??
        localizedMap.values.first;
  }

  static String _applyParams(String template, Map<String, String> params) {
    String result = template;
    params.forEach((String key, String value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
