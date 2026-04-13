import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../data/models/currency_rate.dart';
import '../services/exchange_rate_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final String stripped = newValue.text.replaceAll('.', '');
    final double? value = double.tryParse(stripped);
    if (value == null) {
      return oldValue;
    }

    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    final String formatted = formatter.format(value).replaceAll(',', '.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CurrencyConvertScreen extends StatefulWidget {
  const CurrencyConvertScreen({super.key});

  @override
  State<CurrencyConvertScreen> createState() => _CurrencyConvertScreenState();
}

class _CurrencyConvertScreenState extends State<CurrencyConvertScreen>
    with SingleTickerProviderStateMixin {
  final ExchangeRateService _service = ExchangeRateService();

  final TextEditingController _fromController = TextEditingController();
  final FocusNode _fromFocusNode = FocusNode();

  late final AnimationController _pageController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Timer? _refreshTimer;

  bool _isRatesLoading = true;
  bool _swapPressed = false;

  String? _errorMessage;

  List<Map<String, String>> _currencies = const [
    {'code': 'VND', 'name': 'Việt Nam đồng'},
    {'code': 'USD', 'name': 'Đô la Mỹ'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'JPY', 'name': 'Yên Nhật'},
  ];

  final Map<String, double> _sellRates = {'VND': 1};

  String fromCurrency = 'USD';
  String toCurrency = 'VND';

  String _toAmountText = '--';
  int _toAmountVersion = 0;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic),
        );
    _pageController.forward();

    _fromFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRates();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _loadRates(showShimmer: false),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    _fromController.dispose();
    _fromFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRates({bool showShimmer = true}) async {
    if (!mounted) {
      return;
    }

    if (showShimmer) {
      setState(() {
        _isRatesLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bool isEnglish =
          Localizations.localeOf(context).languageCode == 'en';
      final List<CurrencyRate> rates = await _service.fetchRates(
        isEnglish: isEnglish,
      );

      final Map<String, double> fetchedSellRates = {'VND': 1};
      final List<Map<String, String>> fetchedCurrencies = [
        {'code': 'VND', 'name': _t('Việt Nam đồng', 'Vietnamese Dong')},
      ];

      for (final CurrencyRate item in rates) {
        fetchedSellRates[item.code] = _parseVndFormatted(item.sellPrice);
        fetchedCurrencies.add({'code': item.code, 'name': item.countryName});
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sellRates
          ..clear()
          ..addAll(fetchedSellRates);
        _currencies = fetchedCurrencies;

        if (!_sellRates.containsKey(fromCurrency)) {
          fromCurrency = 'USD';
        }
        if (!_sellRates.containsKey(toCurrency)) {
          toCurrency = 'VND';
        }

        _isRatesLoading = false;
        _errorMessage = null;
      });
      _handleConvert();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRatesLoading = false;
        _errorMessage = _t(
          'Không thể tải tỷ giá mới. Vui lòng kiểm tra mạng và thử lại.',
          'Unable to load latest rates. Please check your connection and retry.',
        );
      });
    }
  }

  double _parseVndFormatted(String formatted) {
    return double.tryParse(formatted.replaceAll('.', '')) ?? 0;
  }

  double _inputAmount() {
    return double.tryParse(_fromController.text.replaceAll('.', '')) ?? 0;
  }

  double _toAmountFromInput() {
    final double amount = _inputAmount();
    final double fromRate = _sellRates[fromCurrency] ?? 1;
    final double toRate = _sellRates[toCurrency] ?? 1;

    if (toRate == 0) {
      return 0;
    }

    final double valueInVnd = amount * fromRate;
    return valueInVnd / toRate;
  }

  String _formatByCurrency(double value, String code) {
    final bool isVnd = code == 'VND';
    final NumberFormat formatter = NumberFormat(
      isVnd ? '#,###' : '#,###.##',
      'vi_VN',
    );
    return formatter.format(value).replaceAll(',', '.');
  }

  void _handleConvert() {
    if (_fromController.text.isEmpty) {
      setState(() {
        _toAmountText = '--';
        _toAmountVersion++;
      });
      return;
    }

    final double converted = _toAmountFromInput();

    setState(() {
      _toAmountText = _formatByCurrency(converted, toCurrency);
      _toAmountVersion++;
    });
  }

  void _handleSwap() {
    setState(() {
      final String temp = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = temp;
    });
    _handleConvert();
  }

  String get _rateLabel {
    final double fromRate = _sellRates[fromCurrency] ?? 1;
    final double toRate = _sellRates[toCurrency] ?? 1;
    if (toRate == 0) {
      return '--';
    }

    final double value = fromRate / toRate;
    final String formatted = NumberFormat(
      '#,###.##',
      'vi_VN',
    ).format(value).replaceAll(',', '.');

    return '1 $fromCurrency = $formatted $toCurrency';
  }

  void _showCurrencyPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('Chọn đơn vị tiền tệ', 'Select currency'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _currencies.length,
                itemBuilder: (context, index) {
                  final Map<String, String> c = _currencies[index];
                  final bool isSelected = isFrom
                      ? fromCurrency == c['code']
                      : toCurrency == c['code'];

                  return ListTile(
                    title: Text(
                      '${c['code']} (${c['name']})',
                      style: GoogleFonts.poppins(
                        color: isSelected
                            ? const Color(0xFF000DC0)
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF000DC0))
                        : null,
                    onTap: () {
                      setState(() {
                        if (isFrom) {
                          fromCurrency = c['code']!;
                        } else {
                          toCurrency = c['code']!;
                        }
                      });
                      Navigator.pop(context);
                      _handleConvert();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.2),
      highlightColor: Colors.grey.withValues(alpha: 0.08),
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildTopRates() {
    const List<String> topCodes = ['USD', 'EUR', 'JPY'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Top Tỷ giá hôm nay', 'Top Rates Today'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF171C2F),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: topCodes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final String code = topCodes[index];
              final double rate = _sellRates[code] ?? 0;

              return Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9EDFA)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF08104F).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF000DC0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate == 0
                          ? '--'
                          : '${_formatByCurrency(rate, 'VND')} VND',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF40465B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAFD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: Color(0xFF000DC0),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'Bạn có biết? Hạng Centurion sẽ nhận được tỷ giá ưu đãi hơn 0.5% khi quy đổi ngoại tệ tại quầy.',
                'Did you know? Centurion tier receives an extra 0.5% preferential exchange rate at the counter.',
              ),
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.45,
                color: const Color(0xFF2B334A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CCPAppBar(
        title: _t('Quy đổi tiền tệ', 'Currency converter'),
        backgroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.asset(
                    'assets/search/quydoitiente.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF060D46).withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInputBox(
                        label: _t('Từ', 'From'),
                        controller: _fromController,
                        code: fromCurrency,
                        onPick: () => _showCurrencyPicker(true),
                        isReadOnly: false,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            _rateLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF000DC0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: GestureDetector(
                          onTapDown: (_) => setState(() => _swapPressed = true),
                          onTapCancel: () =>
                              setState(() => _swapPressed = false),
                          onTapUp: (_) {
                            setState(() => _swapPressed = false);
                            _handleSwap();
                          },
                          child: AnimatedScale(
                            scale: _swapPressed ? 0.92 : 1,
                            duration: const Duration(milliseconds: 120),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4FB),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.swap_vert_rounded,
                                color: Color(0xFF000DC0),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildInputBox(
                        label: _t('Thành', 'To'),
                        controller: null,
                        code: toCurrency,
                        onPick: () => _showCurrencyPicker(false),
                        isReadOnly: true,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildTopRates(),
                const SizedBox(height: 14),
                _buildHintCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required String label,
    required TextEditingController? controller,
    required String code,
    required VoidCallback onPick,
    required bool isReadOnly,
  }) {
    final bool isFocused = isReadOnly ? false : _fromFocusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFF),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF3B58FF)
                  : const Color(0xFFE4E8F4),
              width: isFocused ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              if (isFocused)
                BoxShadow(
                  color: const Color(0xFF3B58FF).withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: isReadOnly
                      ? SizedBox(
                          height: 70,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _isRatesLoading
                                ? _resultShimmer()
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                    child: Text(
                                      _toAmountText,
                                      key: ValueKey<int>(_toAmountVersion),
                                      style: GoogleFonts.poppins(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF131A2E),
                                      ),
                                    ),
                                  ),
                          ),
                        )
                      : TextField(
                          focusNode: _fromFocusNode,
                          controller: controller,
                          readOnly: false,
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsSeparatorInputFormatter()],
                          style: GoogleFonts.poppins(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF131A2E),
                          ),
                          decoration: InputDecoration(
                            hintText: _t('Nhập số tiền', 'Enter amount'),
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFFB2B8CA),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => _handleConvert(),
                        ),
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE1E5F2)),
              InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Text(
                        code,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E2743),
                        ),
                      ),
                      const Icon(
                        Icons.unfold_more,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
