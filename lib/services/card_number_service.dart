import 'dart:math';

class CardNumberService {
  CardNumberService._();

  static final Random _random = Random();

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _ensureCccdBase(String cccd) {
    final String digits = _digitsOnly(cccd);
    if (digits.isEmpty) {
      return '000000000000';
    }
    if (digits.length >= 12) {
      return digits.substring(0, 12);
    }
    return digits.padRight(12, '0');
  }

  static String _random4Digits() {
    return (_random.nextInt(9000) + 1000).toString();
  }

  static String _phoneLast4Digits(String phone) {
    final String digits = _digitsOnly(phone);
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    return digits.padLeft(4, '0');
  }

  static String generateCardNumber(String cccd, String phone, bool isVip) {
    final String base = _ensureCccdBase(cccd);
    final String suffix = isVip ? _phoneLast4Digits(phone) : _random4Digits();
    return '$base$suffix';
  }

  static String generatePermanentCardNumber(Map<String, dynamic> user) {
    final bool isVip =
        user['hasVipCard'] == true ||
        (user['membershipTier'] ?? '').toString().toLowerCase() == 'prive';
    final String cccd = (user['cccd'] ?? user['idNumber'] ?? '').toString();
    final String phone = (user['phoneNumber'] ?? '').toString();
    return generateCardNumber(cccd, phone, isVip);
  }

  static String readStoredCardNumber(Map<String, dynamic> data) {
    final String cardSnake = (data['card_number'] ?? '').toString().trim();
    if (cardSnake.isNotEmpty) {
      return cardSnake;
    }
    final String cardCamel = (data['cardNumber'] ?? '').toString().trim();
    if (cardCamel.isNotEmpty) {
      return cardCamel;
    }
    return '';
  }

  static String formatCardNumber(String rawCardNumber) {
    final String digits = _digitsOnly(rawCardNumber);
    if (digits.isEmpty) {
      return '';
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final bool shouldAddSpace = (i + 1) % 4 == 0 && i != digits.length - 1;
      if (shouldAddSpace) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  static String readCardNumber(Map<String, dynamic> data) {
    final String stored = readStoredCardNumber(data);
    if (stored.isNotEmpty) {
      return stored;
    }

    final String accountSnake = (data['account_number'] ?? '')
        .toString()
        .trim();
    if (accountSnake.isNotEmpty) {
      return accountSnake;
    }

    return (data['accountNumber'] ?? '').toString().trim();
  }
}
