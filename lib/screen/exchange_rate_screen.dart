import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../data/models/currency_rate.dart';
import '../services/exchange_rate_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

class ExchangeRateScreen extends StatefulWidget {
  const ExchangeRateScreen({super.key});

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen>
    with SingleTickerProviderStateMixin {
  final ExchangeRateService _service = ExchangeRateService();

  late final AnimationController _transitionController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Future<List<CurrencyRate>>? _futureRates;
  Locale? _lastLocale;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _transitionController,
            curve: Curves.easeOutCubic,
          ),
        );

    _transitionController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale || _futureRates == null) {
      _lastLocale = currentLocale;
      _reload();
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _reload() {
    final bool isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() {
      _futureRates = _service.fetchRates(isEnglish: isEn);
    });
  }

  Widget _headerCell(String text, {required int flex, TextAlign? align}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align ?? TextAlign.left,
        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
      ),
    );
  }

  Widget _rateRow(CurrencyRate item) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.flagUrl,
                        width: 28,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 28,
                            height: 20,
                            color: Colors.grey.withValues(alpha: 0.2),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${item.countryName}(${item.code})',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF343434),
                        ),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.buyPrice,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.sellPrice,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A75),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey.withValues(alpha: 0.1), height: 1),
      ],
    );
  }

  Widget _shimmerRow() {
    Widget box({
      required double width,
      required double height,
      BorderRadius? r,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r ?? BorderRadius.circular(6),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                box(width: 28, height: 20, r: BorderRadius.circular(4)),
                const SizedBox(width: 12),
                Expanded(child: box(width: double.infinity, height: 14)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: box(width: 70, height: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: box(width: 70, height: 14),
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
        title: _t('Tỷ giá hối đoái', 'Exchange rates'),
        backgroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _headerCell(_t('Quốc gia', 'Country'), flex: 5),
                        _headerCell(
                          _t('Mua vào', 'Buy'),
                          flex: 3,
                          align: TextAlign.right,
                        ),
                        _headerCell(
                          _t('Bán ra', 'Sell'),
                          flex: 3,
                          align: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CurrencyRate>>(
                  future: _futureRates,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Shimmer.fromColors(
                        baseColor: Colors.grey.withValues(alpha: 0.15),
                        highlightColor: Colors.grey.withValues(alpha: 0.05),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          itemCount: ExchangeRateService.supportedCurrencyCount,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.grey.withValues(alpha: 0.1),
                            height: 1,
                          ),
                          itemBuilder: (context, index) => _shimmerRow(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _t(
                                  'Không thể tải tỷ giá lúc này. Vui lòng kiểm tra mạng và thử lại.',
                                  "Can't load exchange rates right now. Please check your connection and try again.",
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF343434),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: _reload,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A1A75),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _t('Thử lại', 'Retry'),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final List<CurrencyRate> items = snapshot.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            child: Text(
                              _t(
                                '*Tỷ giá có thể thay đổi theo từng thời điểm giao dịch thực tế.*',
                                '*Rates may change by real transaction time.*',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return _rateRow(items[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
