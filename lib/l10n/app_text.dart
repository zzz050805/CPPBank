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
    'vip_perks_title': <String, String>{
      'vi': '👑 Đặc quyền thẻ VIP:',
      'en': '👑 VIP card privileges:',
    },
    'vip_perk_interest': <String, String>{
      'vi': '+ 7.5% lãi suất tiết kiệm mỗi năm',
      'en': '+ 7.5% annual savings interest',
    },
    'vip_perk_fee': <String, String>{
      'vi': 'Miễn phí 100% phí giao dịch',
      'en': '100% transaction fee waiver',
    },
    'vip_perk_support': <String, String>{
      'vi': 'Đặc quyền chăm sóc khách hàng 24/7',
      'en': '24/7 premium customer care',
    },
    'select_source_card': <String, String>{
      'vi': 'Chọn nguồn tiền',
      'en': 'Select source card',
    },
    'source_card': <String, String>{'vi': 'Thẻ', 'en': 'Source card'},
    'card_unavailable': <String, String>{
      'vi': 'Thẻ không khả dụng',
      'en': 'Card unavailable',
    },
    'status_active': <String, String>{'vi': 'Đang hiệu lực', 'en': 'Active'},
    'status_expired': <String, String>{'vi': 'Đã hết hạn', 'en': 'Expired'},
    'status_cancelled': <String, String>{'vi': 'Đã hủy', 'en': 'Cancelled'},
    'status_locked': <String, String>{'vi': 'Đã khóa', 'en': 'Locked'},
    'lock_card': <String, String>{'vi': 'Khóa thẻ', 'en': 'Lock card'},
    'unlock_card': <String, String>{'vi': 'Mở thẻ', 'en': 'Unlock card'},
    'title_transfer': <String, String>{
      'vi': 'Chuyển khoản thành công',
      'en': 'Transfer successful',
    },
    'notify_transfer_title': <String, String>{
      'vi': 'Chuyển tiền thành công',
      'en': 'Transfer successful',
    },
    'desc_transfer': <String, String>{
      'vi': 'Bạn đã chuyển {amount} đến {receiverName}.',
      'en': 'You transferred {amount} to {receiverName}.',
    },
    'notify_transfer_body': <String, String>{
      'vi': 'Bạn đã chuyển {amount} đến {name}',
      'en': 'You transferred {amount} to {name}',
    },
    'title_withdraw': <String, String>{
      'vi': 'Rút tiền thành công',
      'en': 'Withdrawal successful',
    },
    'notify_withdraw_title': <String, String>{
      'vi': 'Rút tiền thành công',
      'en': 'Withdrawal successful',
    },
    'desc_withdraw': <String, String>{
      'vi': 'Bạn đã rút {amount} tại điểm giao dịch.',
      'en': 'You withdrew {amount} at the service point.',
    },
    'notify_withdraw_body': <String, String>{
      'vi': 'Số tiền {amount} đã được rút về tài khoản liên kết',
      'en': '{amount} has been withdrawn to the linked account',
    },
    'atm_withdrawal': <String, String>{
      'vi': 'Rút tiền ATM',
      'en': 'ATM withdrawal',
    },
    'withdraw_history': <String, String>{
      'vi': 'Lịch sử rút tiền',
      'en': 'Withdrawal history',
    },
    'withdraw_code_created': <String, String>{
      'vi': 'Mã rút tiền đã được tạo: {code}',
      'en': 'Withdrawal code created: {code}',
    },
    'create_code': <String, String>{'vi': 'Tạo mã', 'en': 'Create code'},
    'cancel_code': <String, String>{'vi': 'Hủy mã', 'en': 'Cancel code'},
    'confirm_delete_service_title': <String, String>{
      'vi': 'Xác nhận xóa',
      'en': 'Confirm deletion',
    },
    'confirm_delete_service_message': <String, String>{
      'vi':
          'Bạn có chắc chắn muốn xóa dịch vụ {serviceName} không? Hành động này không thể hoàn tác và sẽ xóa dịch vụ khỏi màn hình của người dùng ngay lập tức.',
      'en':
          'Are you sure you want to delete service {serviceName}? This action cannot be undone and will remove the service from user screens immediately.',
    },
    'service_deleted_success': <String, String>{
      'vi': 'Đã xóa dịch vụ thành công',
      'en': 'Service deleted successfully',
    },
    'delete_account_title': <String, String>{
      'vi': 'Xóa tài khoản',
      'en': 'Delete account',
    },
    'delete_account_confirm_message': <String, String>{
      'vi':
          'Bạn có chắc chắn muốn xóa tài khoản này không? Mọi dữ liệu giao dịch và số dư sẽ bị xóa vĩnh viễn và không thể khôi phục.',
      'en':
          'Are you sure you want to delete this account? All transaction data and balances will be permanently removed and cannot be restored.',
    },
    'chat_delete_history_title': <String, String>{
      'vi': 'Xóa lịch sử?',
      'en': 'Delete history?',
    },
    'chat_delete_history_confirm': <String, String>{
      'vi': 'Bạn có chắc chắn muốn xóa toàn bộ cuộc hội thoại này?',
      'en': 'Are you sure you want to delete this entire conversation?',
    },
    'withdraw_invalid_amount': <String, String>{
      'vi': 'Số tiền không hợp lệ. Vui lòng nhập bội số của 50.000đ.',
      'en': 'Invalid amount. Please enter a multiple of 50,000 VND.',
    },
    'withdraw_create_failed': <String, String>{
      'vi': 'Không thể tạo mã rút tiền. Vui lòng thử lại.',
      'en': 'Failed to create withdrawal code. Please try again.',
    },
    'withdraw_code_cancelled': <String, String>{
      'vi': 'Đã hủy mã rút tiền.',
      'en': 'Withdrawal code has been cancelled.',
    },
    'withdraw_cancel_failed': <String, String>{
      'vi': 'Không thể hủy mã rút tiền. Vui lòng thử lại.',
      'en': 'Failed to cancel withdrawal code. Please try again.',
    },
    'remaining_time': <String, String>{
      'vi': 'Thời gian còn lại: {time}',
      'en': 'Remaining time: {time}',
    },
    'loading': <String, String>{'vi': 'Đang tải...', 'en': 'Loading...'},
    'source_account': <String, String>{
      'vi': 'TÀI KHOẢN NGUỒN',
      'en': 'SOURCE ACCOUNT',
    },
    'available_balance': <String, String>{
      'vi': 'SỐ DƯ KHẢ DỤNG',
      'en': 'AVAILABLE BALANCE',
    },
    'enter_withdraw_amount': <String, String>{
      'vi': 'Nhập số tiền muốn rút',
      'en': 'Enter withdrawal amount',
    },
    'max_transaction_limit': <String, String>{
      'vi': 'Hạn mức tối đa theo số dư khả dụng: {amount}',
      'en': 'Maximum limit based on available balance: {amount}',
    },
    'currency_vnd': <String, String>{'vi': 'VNĐ', 'en': 'VND'},
    'quick_amount_selection': <String, String>{
      'vi': 'Chọn nhanh mệnh giá',
      'en': 'Quick amount selection',
    },
    'withdraw_limit_text': <String, String>{
      'vi': 'Hạn mức rút: {min}đ - {max}đ / lần',
      'en': 'Withdrawal limit: {min} VND - {max} VND / transaction',
    },
    'security_ssl_notice': <String, String>{
      'vi': 'Giao dịch được bảo mật bởi SSL 256-bit',
      'en': 'Transactions are secured by 256-bit SSL',
    },
    'no_withdraw_history': <String, String>{
      'vi': 'Chưa có lịch sử rút tiền ATM.',
      'en': 'No ATM withdrawal history yet.',
    },
    'code_label': <String, String>{'vi': 'Mã', 'en': 'Code'},
    'created_at_label': <String, String>{'vi': 'Tạo lúc', 'en': 'Created at'},
    'menu_settings': <String, String>{'vi': 'Cài đặt', 'en': 'Settings'},
    'menu_switch_language': <String, String>{
      'vi': 'Ngôn ngữ (VI/EN)',
      'en': 'Language (VI/EN)',
    },
    'menu_logout': <String, String>{'vi': 'Đăng xuất', 'en': 'Logout'},
    'confirm_logout_title': <String, String>{
      'vi': 'Xác nhận đăng xuất',
      'en': 'Confirm logout',
    },
    'confirm_logout_msg': <String, String>{
      'vi': 'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống Admin?',
      'en': 'Are you sure you want to log out of the Admin system?',
    },
    'confirm_logout_msg_user': <String, String>{
      'vi': 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
      'en': 'Are you sure you want to log out of this account?',
    },
    'cancel_withdraw_code_title': <String, String>{
      'vi': 'Xác nhận hủy mã',
      'en': 'Confirm code cancellation',
    },
    'cancel_withdraw_code_confirm': <String, String>{
      'vi': 'Bạn có chắc chắn muốn hủy mã không?',
      'en': 'Are you sure you want to cancel this code?',
    },
    'atm_withdrawal_code_created_heads_up': <String, String>{
      'vi': 'Mã rút tiền ATM {code} đã được tạo thành công. Hiệu lực 15 phút.',
      'en':
          'ATM withdrawal code {code} has been created successfully. Valid for 15 minutes.',
    },
    'btn_yes': <String, String>{'vi': 'Có', 'en': 'Yes'},
    'btn_no': <String, String>{'vi': 'Không', 'en': 'No'},
    'btn_understand': <String, String>{'vi': 'Đã hiểu', 'en': 'Understood'},
    'btn_cancel': <String, String>{'vi': 'Hủy', 'en': 'Cancel'},
    'btn_delete': <String, String>{'vi': 'Xóa', 'en': 'Delete'},
    'action_confirm': <String, String>{'vi': 'Xác nhận', 'en': 'Confirm'},
    'action_cancel': <String, String>{'vi': 'Hủy', 'en': 'Cancel'},
    'logout_failed': <String, String>{
      'vi': 'Không thể đăng xuất. Vui lòng thử lại.',
      'en': 'Unable to log out. Please try again.',
    },
    'select_language': <String, String>{
      'vi': 'Chọn ngôn ngữ',
      'en': 'Choose language',
    },
    'language_vietnamese': <String, String>{
      'vi': 'Tiếng Việt',
      'en': 'Vietnamese',
    },
    'language_english': <String, String>{'vi': 'English', 'en': 'English'},
    'title_shopping': <String, String>{
      'vi': 'Thanh toán mua sắm thành công',
      'en': 'Shopping payment successful',
    },
    'notify_shopping_title': <String, String>{
      'vi': 'Thanh toán thành công',
      'en': 'Payment successful',
    },
    'desc_shopping': <String, String>{
      'vi': 'Bạn đã thanh toán {amount} cho gói {serviceName}.',
      'en': 'You paid {amount} for the {serviceName} package.',
    },
    'notify_shopping_body': <String, String>{
      'vi': 'Đã thanh toán {amount} cho dịch vụ {service}',
      'en': 'Paid {amount} for service {service}',
    },
    'notify_new_service_title': <String, String>{
      'vi': 'Dịch vụ mới xuất hiện!',
      'en': 'New service arrived!',
    },
    'notify_new_service_body': <String, String>{
      'vi': '{serviceName} đã có mặt trên CCPBank. Khám phá ngay!',
      'en': '{serviceName} is now available on CCPBank. Explore now!',
    },
    'notification_default_title': <String, String>{
      'vi': 'Thông báo mới',
      'en': 'New notification',
    },
    'notification_no_description': <String, String>{
      'vi': 'Không có mô tả',
      'en': 'No description',
    },
    'account_locked_title': <String, String>{
      'vi': 'Tài khoản bị khóa',
      'en': 'Account locked',
    },
    'account_locked_msg': <String, String>{
      'vi':
          'Tài khoản của bạn đã bị Quản lý khóa. Vui lòng liên hệ bộ phận hỗ trợ.',
      'en':
          'Your account has been locked by the manager. Please contact support.',
    },
    'customer_label': <String, String>{'vi': 'Khách hàng', 'en': 'Customer'},
    'topup_confirm_title': <String, String>{
      'vi': 'Xác nhận nạp tiền điện thoại',
      'en': 'Confirm phone top-up',
    },
    'topup_receipt_title': <String, String>{
      'vi': 'Biên lai nạp tiền',
      'en': 'Top-up receipt',
    },
    'topup_success_title': <String, String>{
      'vi': 'Giao dịch thành công',
      'en': 'Transaction successful',
    },
    'topup_other_amount': <String, String>{
      'vi': 'Số khác',
      'en': 'Other amount',
    },
    'topup_selected_amount': <String, String>{
      'vi': 'Số tiền bạn đã chọn',
      'en': 'Selected amount',
    },
    'topup_enter_custom_amount_hint': <String, String>{
      'vi': 'Vui lòng nhập số tiền mong muốn',
      'en': 'Please enter your desired amount',
    },
    'topup_verify_before_confirm': <String, String>{
      'vi': 'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận giao dịch.',
      'en': 'Please verify details carefully before confirming.',
    },
    'topup_details_title': <String, String>{
      'vi': 'Thông tin chi tiết',
      'en': 'Details',
    },
    'topup_service_name': <String, String>{
      'vi': 'Nạp tiền điện thoại',
      'en': 'Phone top-up',
    },
    'topup_phone_label': <String, String>{
      'vi': 'Số điện thoại',
      'en': 'Phone number',
    },
    'topup_amount_label': <String, String>{
      'vi': 'Mệnh giá (VND)',
      'en': 'Amount (VND)',
    },
    'topup_transaction_id': <String, String>{
      'vi': 'Mã giao dịch',
      'en': 'Transaction ID',
    },
    'topup_status_label': <String, String>{'vi': 'Trạng thái', 'en': 'Status'},
    'topup_type_label': <String, String>{'vi': 'Loại', 'en': 'Type'},
    'topup_invalid_amount': <String, String>{
      'vi': 'Số tiền nạp không hợp lệ.',
      'en': 'Invalid top-up amount.',
    },
    'topup_not_logged_in': <String, String>{
      'vi': 'Lỗi: Chưa đăng nhập',
      'en': 'Error: Not logged in',
    },
    'topup_user_not_found': <String, String>{
      'vi': 'Không tìm thấy tài khoản người dùng.',
      'en': 'User account does not exist.',
    },
    'topup_transaction_error': <String, String>{
      'vi': 'Lỗi giao dịch',
      'en': 'Transaction error',
    },
    'notify_topup_title': <String, String>{
      'vi': 'Nạp tiền điện thoại thành công',
      'en': 'Phone top-up successful',
    },
    'notify_topup_body': <String, String>{
      'vi': 'Nạp thành công {amount} cho số điện thoại {phone}',
      'en': 'Top-up successful: {amount} for phone number {phone}',
    },
    'otp_notification_title': <String, String>{
      'vi': 'CCP BANK',
      'en': 'CCP BANK',
    },
    'otp_notification_body': <String, String>{
      'vi': 'Mã OTP của bạn là {otp}. Vui lòng không chia sẻ cho bất kỳ ai.',
      'en': 'Your OTP code is {otp}. Please do not share it with anyone.',
    },
    'notify_phone_recharge_title': <String, String>{
      'vi': 'Nạp tiền điện thoại thành công',
      'en': 'Phone top-up successful',
    },
    'notify_phone_recharge_body': <String, String>{
      'vi': 'Đã nạp {amount} cho {provider}.',
      'en': 'Top-up {amount} for {provider}.',
    },
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
