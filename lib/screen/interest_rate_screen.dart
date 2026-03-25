import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../widget/ccp_app_bar.dart';
import '../widget/interest_calculator.dart';
import '../widget/interest_chart.dart';
import '../widget/interest_table.dart';

/// Formatter thêm dấu phẩy hàng nghìn ngay khi người dùng nhập.
/// Ví dụ: 1000000 -> 1,000,000
class CurrencyInputFormatter extends TextInputFormatter {
  CurrencyInputFormatter() : _numberFormat = NumberFormat('#,###', 'en_US');

  final NumberFormat _numberFormat;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int number = int.parse(digitsOnly);
    final String formatted = _numberFormat.format(number);

    // Giữ con trỏ gần vị trí người dùng đang nhập, tránh nhảy về đầu dòng.
    final int selectionFromRight =
        newValue.text.length - newValue.selection.extentOffset;
    int newOffset = formatted.length - selectionFromRight;
    if (newOffset < 0) newOffset = 0;
    if (newOffset > formatted.length) newOffset = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class InterestRateScreen extends StatefulWidget {
  const InterestRateScreen({super.key});

  @override
  State<InterestRateScreen> createState() => _InterestRateScreenState();
}

class _InterestRateScreenState extends State<InterestRateScreen> {
  final CurrencyInputFormatter _currencyInputFormatter =
      CurrencyInputFormatter();

  final TextEditingController _amountController = TextEditingController(
    text: '100,000,000',
  );

  // Dữ liệu xu hướng 6 tháng gần nhất cho biểu đồ.
  final List<String> _months = const ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];
  final List<double> _trendRates = const [5.5, 5.6, 5.8, 5.7, 6.0, 6.1];

  // Bảng lãi suất theo kỳ hạn (tham khảo).
  final Map<int, double> _rateByTerm = const {
    1: 3.2,
    3: 3.8,
    6: 5.4,
    9: 5.7,
    12: 6.1,
    18: 6.4,
    24: 6.6,
    36: 6.9,
  };

  int _selectedTerm = 12;
  double _principal = 100000000;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // Tìm lãi suất gần nhất dựa trên kỳ hạn người dùng chọn.
  double get _currentRate {
    final List<int> terms = _rateByTerm.keys.toList()..sort();
    for (final int term in terms) {
      if (_selectedTerm <= term) {
        return _rateByTerm[term]!;
      }
    }
    return _rateByTerm[terms.last]!;
  }

  // Công thức tính lãi đơn theo kỳ hạn gửi (ngân hàng tiết kiệm thông dụng).
  // Tiền lãi = Số tiền gửi * Lãi suất năm * (Số tháng / 12)
  double get _estimatedInterest {
    return _principal * (_currentRate / 100) * (_selectedTerm / 12);
  }

  void _onAmountChanged(String value) {
    // Bỏ toàn bộ dấu phẩy trước khi đổi sang số để tính toán.
    final String rawNumber = value.replaceAll(',', '');
    setState(() {
      _principal = double.tryParse(rawNumber) ?? 0;
    });
  }

  void _onTermChanged(int value) {
    setState(() => _selectedTerm = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: const CCPAppBar(title: 'Lãi suất'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            children: [
              InterestChart(monthLabels: _months, rates: _trendRates),
              const SizedBox(height: 14),
              InterestCalculator(
                amountController: _amountController,
                amountInputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _currencyInputFormatter,
                ],
                term: _selectedTerm,
                currentRate: _currentRate,
                estimatedInterest: _estimatedInterest,
                onAmountChanged: _onAmountChanged,
                onTermChanged: _onTermChanged,
              ),
              const SizedBox(height: 14),
              InterestTable(
                rateByTerm: _rateByTerm,
                selectedTerm: _selectedTerm,
                onTermTap: _onTermChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
