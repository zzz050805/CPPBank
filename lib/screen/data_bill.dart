import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'data_bill_pay.dart';

class DataBillScreen extends StatefulWidget {
  const DataBillScreen({super.key, this.sourceCardId});

  final String? sourceCardId;

  @override
  State<DataBillScreen> createState() => _DataBillScreenState();
}

class _DataBillScreenState extends State<DataBillScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _surface = Color(0xFFF6F7FF);

  final TextEditingController _phoneController = TextEditingController();
  late final AnimationController _introController;

  int _selectedCycle = 0;
  int _selectedPackage = 0;

  final List<_DataPackageItem> _dailyPackages = const <_DataPackageItem>[
    _DataPackageItem(
      badge: 'HOT',
      dataText: '5GB/ngày',
      code: 'Gói ST15K',
      priceText: '15.000đ',
      background: Colors.white,
      icon: Icons.flash_on_rounded,
    ),
    _DataPackageItem(
      badge: 'TIẾT KIỆM',
      dataText: '3GB/ngày',
      code: 'Gói ST10K',
      priceText: '10.000đ',
      background: Colors.white,
      icon: Icons.auto_awesome_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: '1GB/ngày',
      code: 'Gói ST5K',
      priceText: '5.000đ',
      background: Colors.white,
      icon: Icons.cloud_queue_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: 'UNLIMITED',
      code: 'Gói VIP',
      priceText: '30.000đ',
      background: Color(0xFFF9E6F4),
      icon: Icons.diamond_rounded,
    ),
  ];

  final List<_DataPackageItem> _weeklyPackages = const <_DataPackageItem>[
    _DataPackageItem(
      badge: 'HOT',
      dataText: '15GB/tuần',
      code: 'Gói WT49',
      priceText: '49.000đ',
      background: Colors.white,
      icon: Icons.flash_on_rounded,
    ),
    _DataPackageItem(
      badge: 'TIẾT KIỆM',
      dataText: '10GB/tuần',
      code: 'Gói WT35',
      priceText: '35.000đ',
      background: Colors.white,
      icon: Icons.auto_awesome_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: '6GB/tuần',
      code: 'Gói WT25',
      priceText: '25.000đ',
      background: Colors.white,
      icon: Icons.cloud_queue_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: 'UNLIMITED',
      code: 'Gói VIP Tuần',
      priceText: '79.000đ',
      background: Color(0xFFF9E6F4),
      icon: Icons.diamond_rounded,
    ),
  ];

  final List<_DataPackageItem> _monthlyPackages = const <_DataPackageItem>[
    _DataPackageItem(
      badge: 'HOT',
      dataText: '60GB/tháng',
      code: 'Gói MT149',
      priceText: '149.000đ',
      background: Colors.white,
      icon: Icons.flash_on_rounded,
    ),
    _DataPackageItem(
      badge: 'TIẾT KIỆM',
      dataText: '45GB/tháng',
      code: 'Gói MT119',
      priceText: '119.000đ',
      background: Colors.white,
      icon: Icons.auto_awesome_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: '30GB/tháng',
      code: 'Gói MT89',
      priceText: '89.000đ',
      background: Colors.white,
      icon: Icons.cloud_queue_rounded,
    ),
    _DataPackageItem(
      badge: '',
      dataText: 'UNLIMITED',
      code: 'Gói VIP Tháng',
      priceText: '199.000đ',
      background: Color(0xFFF9E6F4),
      icon: Icons.diamond_rounded,
    ),
  ];

  List<_DataPackageItem> get _activePackages {
    switch (_selectedCycle) {
      case 1:
        return _weeklyPackages;
      case 2:
        return _monthlyPackages;
      default:
        return _dailyPackages;
    }
  }

  _DataPackageItem get _selectedPlan => _activePackages[_selectedPackage];

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^0\d{9}$').hasMatch(phone);
  }

  Widget _reveal(int index, Widget child) {
    final double start = (index * 0.1).clamp(0, 0.75);
    final double end = (start + 0.28).clamp(0, 1).toDouble();
    final CurvedAnimation animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildProgressLine() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: GoogleFonts.poppins(
          color: const Color(0xFF2B2E45),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.smartphone_rounded,
            color: _primaryBlue.withValues(alpha: 0.65),
            size: 20,
          ),
          hintText: _t('Nhập số điện thoại', 'Enter phone number'),
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFA3A7BE),
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: Icon(
            Icons.sim_card_rounded,
            color: _primaryBlue.withValues(alpha: 0.65),
            size: 18,
          ),
          filled: true,
          fillColor: const Color(0xFFDCD2FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCycleTabs() {
    final List<String> tabs = <String>[
      _t('Theo ngày', 'Daily'),
      _t('Theo tuần', 'Weekly'),
      _t('Theo tháng', 'Monthly'),
    ];

    return Row(
      children: List<Widget>.generate(tabs.length, (int index) {
        final bool selected = _selectedCycle == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() {
                  _selectedCycle = index;
                  _selectedPackage = 0;
                });
              },
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? _primaryBlue.withValues(alpha: 0.82)
                      : const Color(0xFFE4DCF9),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF676D87),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPackageCard(_DataPackageItem item, int index) {
    final bool selected = _selectedPackage == index;
    final Color mainText = item.dataText == 'UNLIMITED'
        ? const Color(0xFFB53676)
        : const Color(0xFF32375A);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedPackage = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _primaryBlue.withValues(alpha: 0.82)
                : const Color(0xFFE7E9F6),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.badge.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.badge,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8D93AE),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            if (item.badge.isNotEmpty) const SizedBox(height: 8),
            Text(
              item.dataText,
              style: GoogleFonts.poppins(
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                color: mainText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.code,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF848AA3),
              ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Text(
                  item.priceText,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: mainText,
                  ),
                ),
                const Spacer(),
                Icon(
                  item.icon,
                  color: _primaryBlue.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: CCPAppBar(
        title: _t('Thanh toán hoá đơn', 'Bill payment'),
        backgroundColor: _surface,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _reveal(
                0,
                Row(
                  children: <Widget>[
                    Text(
                      _t('BƯỚC 1/3', 'STEP 1/3'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _t('Chọn gói cước', 'Choose package'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF8E94AE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _reveal(1, _buildProgressLine()),
              const SizedBox(height: 20),
              _reveal(
                2,
                Text(
                  _t('Số điện thoại nạp', 'Top-up number'),
                  style: GoogleFonts.poppins(
                    fontSize: 31,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF23274B),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _reveal(3, _buildPhoneField()),
              const SizedBox(height: 8),
              _reveal(
                4,
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_rounded,
                      size: 14,
                      color: _primaryBlue.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _t(
                        'Ưu đãi lên tới 20% cho thuê bao trả trước',
                        'Up to 20% offer for prepaid subscribers',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF8C92AB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _reveal(5, _buildCycleTabs()),
              const SizedBox(height: 16),
              _reveal(
                6,
                GridView.builder(
                  itemCount: _activePackages.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.14,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _buildPackageCard(_activePackages[index], index);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _reveal(
                7,
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      final String phone = _phoneController.text.trim();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _t(
                                'Vui lòng nhập số điện thoại.',
                                'Please enter phone number.',
                              ),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      if (!_isValidPhone(phone)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _t(
                                'Số điện thoại không hợp lệ. Vui lòng nhập đúng định dạng (10 số và bắt đầu bằng 0).',
                                'Invalid phone number. Please enter a valid format (10 digits and starts with 0).',
                              ),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final _DataPackageItem plan = _selectedPlan;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DataBillConfirmScreen(
                            phoneNumber: phone,
                            planName: plan.code,
                            planData: plan.dataText,
                            planPriceText: plan.priceText,
                            sourceCardId: widget.sourceCardId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _t('MUA NGAY', 'BUY NOW'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataPackageItem {
  const _DataPackageItem({
    required this.badge,
    required this.dataText,
    required this.code,
    required this.priceText,
    required this.background,
    required this.icon,
  });

  final String badge;
  final String dataText;
  final String code;
  final String priceText;
  final Color background;
  final IconData icon;
}
