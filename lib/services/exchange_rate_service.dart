import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../data/models/currency_rate.dart';

class ExchangeRateService {
  static const String _apiKey = '04a8fc4d30b3c2b56e6e8d0c';
  static final Uri _endpoint = Uri.parse(
    'https://v6.exchangerate-api.com/v6/$_apiKey/latest/VND',
  );
  static const List<_CurrencyMeta> _currencies = <_CurrencyMeta>[
    _CurrencyMeta(
      code: 'USD',
      countryVi: 'Mỹ',
      countryEn: 'United States',
      flagCountryCode: 'us',
    ),
    _CurrencyMeta(
      code: 'GBP',
      countryVi: 'Anh',
      countryEn: 'United Kingdom',
      flagCountryCode: 'gb',
    ),
    _CurrencyMeta(
      code: 'EUR',
      countryVi: 'Khu vực Euro',
      countryEn: 'Eurozone',
      flagCountryCode: 'eu',
    ),
    _CurrencyMeta(
      code: 'CHF',
      countryVi: 'Thụy Sĩ',
      countryEn: 'Switzerland',
      flagCountryCode: 'ch',
    ),
    _CurrencyMeta(
      code: 'JPY',
      countryVi: 'Nhật Bản',
      countryEn: 'Japan',
      flagCountryCode: 'jp',
    ),
    _CurrencyMeta(
      code: 'SGD',
      countryVi: 'Singapore',
      countryEn: 'Singapore',
      flagCountryCode: 'sg',
    ),
    _CurrencyMeta(
      code: 'CAD',
      countryVi: 'Canada',
      countryEn: 'Canada',
      flagCountryCode: 'ca',
    ),
    _CurrencyMeta(
      code: 'AUD',
      countryVi: 'Úc',
      countryEn: 'Australia',
      flagCountryCode: 'au',
    ),
    _CurrencyMeta(
      code: 'THB',
      countryVi: 'Thái Lan',
      countryEn: 'Thailand',
      flagCountryCode: 'th',
    ),
    _CurrencyMeta(
      code: 'CNY',
      countryVi: 'Trung Quốc',
      countryEn: 'China',
      flagCountryCode: 'cn',
    ),
    _CurrencyMeta(
      code: 'KRW',
      countryVi: 'Hàn Quốc',
      countryEn: 'South Korea',
      flagCountryCode: 'kr',
    ),
    _CurrencyMeta(
      code: 'HKD',
      countryVi: 'Hong Kong',
      countryEn: 'Hong Kong',
      flagCountryCode: 'hk',
    ),
    _CurrencyMeta(
      code: 'TWD',
      countryVi: 'Đài Loan',
      countryEn: 'Taiwan',
      flagCountryCode: 'tw',
    ),
    _CurrencyMeta(
      code: 'RUB',
      countryVi: 'Nga',
      countryEn: 'Russia',
      flagCountryCode: 'ru',
    ),
    _CurrencyMeta(
      code: 'INR',
      countryVi: 'Ấn Độ',
      countryEn: 'India',
      flagCountryCode: 'in',
    ),
    _CurrencyMeta(
      code: 'MYR',
      countryVi: 'Malaysia',
      countryEn: 'Malaysia',
      flagCountryCode: 'my',
    ),
    _CurrencyMeta(
      code: 'NZD',
      countryVi: 'New Zealand',
      countryEn: 'New Zealand',
      flagCountryCode: 'nz',
    ),
    _CurrencyMeta(
      code: 'NOK',
      countryVi: 'Na Uy',
      countryEn: 'Norway',
      flagCountryCode: 'no',
    ),
    _CurrencyMeta(
      code: 'SEK',
      countryVi: 'Thụy Điển',
      countryEn: 'Sweden',
      flagCountryCode: 'se',
    ),
    _CurrencyMeta(
      code: 'DKK',
      countryVi: 'Đan Mạch',
      countryEn: 'Denmark',
      flagCountryCode: 'dk',
    ),
    _CurrencyMeta(
      code: 'KWD',
      countryVi: 'Kuwait',
      countryEn: 'Kuwait',
      flagCountryCode: 'kw',
    ),
  ];

  static int get supportedCurrencyCount => _currencies.length;

  static final NumberFormat _vndFormat = NumberFormat.decimalPattern('vi_VN');

  Future<List<CurrencyRate>> fetchRates({required bool isEnglish}) async {
    final response = await http.get(_endpoint);

    if (response.statusCode != 200) {
      throw Exception('Không thể tải tỷ giá (HTTP ${response.statusCode}).');
    }

    final Map<String, dynamic> jsonBody =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final String? result = jsonBody['result'] as String?;
    if (result != 'success') {
      final String? errorType = jsonBody['error-type'] as String?;
      throw Exception('API lỗi${errorType == null ? '' : ': $errorType'}');
    }

    final conversionRatesRaw = jsonBody['conversion_rates'];
    if (conversionRatesRaw is! Map<String, dynamic>) {
      throw Exception('Dữ liệu tỷ giá không hợp lệ.');
    }

    final List<CurrencyRate> resultList = [];

    for (final meta in _currencies) {
      final ratePerVnd = conversionRatesRaw[meta.code];
      if (ratePerVnd is! num) {
        continue;
      }

      if (ratePerVnd == 0) {
        continue;
      }

      // API gives: 1 VND = X foreign currency
      // We need: 1 foreign currency = ? VND => 1 / X
      final double vndPerForeign = 1.0 / ratePerVnd;

      // Spread: buy lower 1.5%, sell higher 1.5%
      final double buy = vndPerForeign * 0.985;
      final double sell = vndPerForeign * 1.015;

      final String buyText = _formatVnd0(buy);
      final String sellText = _formatVnd0(sell);

      resultList.add(
        CurrencyRate(
          code: meta.code,
          countryName: isEnglish ? meta.countryEn : meta.countryVi,
          buyPrice: buyText,
          sellPrice: sellText,
          flagUrl: 'https://flagcdn.com/w40/${meta.flagCountryCode}.png',
        ),
      );
    }

    return resultList;
  }

  String _formatVnd0(double value) {
    final int rounded = value.round();
    return _vndFormat.format(rounded).replaceAll(',', '.');
  }
}

class _CurrencyMeta {
  final String code;
  final String countryVi;
  final String countryEn;
  final String flagCountryCode;

  const _CurrencyMeta({
    required this.code,
    required this.countryVi,
    required this.countryEn,
    required this.flagCountryCode,
  });
}
