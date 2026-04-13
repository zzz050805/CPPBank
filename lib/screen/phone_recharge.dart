import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../l10n/app_text.dart';
import 'phone_recharge_1.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TopUpScreen(),
    );
  }
}

class PhoneRechargeScreen extends StatelessWidget {
  const PhoneRechargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TopUpScreen();
  }
}

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const String _providerPlaceholderAsset =
      'assets/images/nhacungcap.jpg';
  static const String _otherAmountKey = '__other_amount__';

  late final AnimationController _controller;
  late final Animation<double> _providerFade;
  late final Animation<Offset> _providerSlide;
  late final Animation<double> _phoneFade;
  late final Animation<Offset> _phoneSlide;
  late final Animation<double> _amountFade;
  late final Animation<Offset> _amountSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  // Danh sách nhà m?ng
  final List<String> providers = [
    'Viettel',
    'Mobifone',
    'Vinaphone',
    'Vietnamobile',
    'Gmobile',
  ];
  String? selectedProvider;

  // Danh sách m?nh giá
  final List<String> amounts = [
    '10.000',
    '20.000',
    '30.000',
    '50.000',
    '100.000',
    '200.000',
    '300.000',
    '500.000',
    _otherAmountKey,
  ];
  String? selectedAmount;
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _providerError;
  String? _phoneError;
  String? _customAmountError;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  void _openConfirmScreen({
    required String amount,
    required String provider,
    required String phoneNumber,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmTopUpScreen(
          selectedAmount: amount,
          selectedProvider: provider,
          selectedPhoneNumber: phoneNumber,
        ),
      ),
    );
  }

  String _formatAmountWithDots(String rawDigits) {
    final String cleaned = rawDigits.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';

    final String reversed = cleaned.split('').reversed.join();
    final List<String> chunks = [];

    for (int i = 0; i < reversed.length; i += 3) {
      final int end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      chunks.add(reversed.substring(i, end));
    }

    return chunks.join('.').split('').reversed.join();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _providerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _providerSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
          ),
        );

    _phoneFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
    );
    _phoneSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _amountFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOut),
    );
    _amountSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic),
          ),
        );

    _buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _customAmountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedSection({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  IconData _providerIcon(String provider) {
    switch (provider) {
      case 'Viettel':
        return Icons.wifi_tethering_rounded;
      case 'Mobifone':
        return Icons.phone_iphone_rounded;
      case 'Vinaphone':
        return Icons.network_cell_rounded;
      case 'Vietnamobile':
        return Icons.signal_cellular_alt_rounded;
      default:
        return Icons.settings_input_antenna_rounded;
    }
  }

  String? _providerLogoAsset(String provider) {
    switch (provider) {
      case 'Viettel':
        return 'assets/images/viettel.jpg';
      case 'Mobifone':
        return 'assets/images/mobifone.jpg';
      case 'Vinaphone':
        return 'assets/images/vinaphone.jpg';
      case 'Vietnamobile':
        return 'assets/images/vietnamobile.jpg';
      case 'Gmobile':
        return 'assets/images/Gmobile.jpg';
      default:
        return null;
    }
  }

  Widget _buildProviderAvatar(
    String provider, {
    double size = 34,
    double iconSize = 18,
  }) {
    final String? assetPath = _providerLogoAsset(provider);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primaryBlue.withOpacity(0.1),
      ),
      child: ClipOval(
        child: assetPath == null
            ? Icon(_providerIcon(provider), color: _primaryBlue, size: iconSize)
            : Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    _providerIcon(provider),
                    color: _primaryBlue,
                    size: iconSize,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProviderPlaceholderAvatar({
    double size = 34,
    double iconSize = 18,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primaryBlue.withOpacity(0.1),
      ),
      child: ClipOval(
        child: Image.asset(
          _providerPlaceholderAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.settings_input_antenna_rounded,
              color: _primaryBlue,
              size: iconSize,
            );
          },
        ),
      ),
    );
  }

  Future<void> _showProviderPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEEE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _t('Ch?n nhà cung c?p', 'Select provider'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF19213D),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final String provider = providers[index];
                      final bool isSelected = selectedProvider == provider;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            selectedProvider = provider;
                            _providerError = null;
                            if (_phoneError ==
                                _t(
                                  'Vui ḷng ch?n nhà cung c?p tru?c khi nh?p s? di?n tho?i.',
                                  'Please select a provider before entering phone number.',
                                )) {
                              _phoneError = null;
                            }
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEAF0FF)
                                : const Color(0xFFF9FAFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryBlue
                                  : const Color(0xFFD7DDEE),
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildProviderAvatar(provider),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  provider,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _primaryBlue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t('N?p ti?n di?n tho?i', 'Phone Top-Up'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Ph?n n?i dung chính (Cho phép cu?n)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),

                  _buildAnimatedSection(
                    fade: _providerFade,
                    slide: _providerSlide,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE5FF)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.phone_iphone_rounded,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t(
                                'N?p ti?n nhanh trong vài giây, an toàn và ti?n l?i.',
                                'Top up in seconds with a safe and seamless flow.',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFF2C3A75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  _buildAnimatedSection(
                    fade: _providerFade,
                    slide: _providerSlide,
                    child: Text(
                      _t('Nhà cung c?p', 'Provider'),
                      style: GoogleFonts.poppins(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Dropdown ch?n nhà cung c?p ---
                  _buildAnimatedSection(
                    fade: _providerFade,
                    slide: _providerSlide,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showProviderPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFD8DEEE)),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            selectedProvider == null
                                ? _buildProviderPlaceholderAvatar()
                                : _buildProviderAvatar(selectedProvider!),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedProvider ??
                                    _t('Ch?n nhà cung c?p', 'Select provider'),
                                style: GoogleFonts.poppins(
                                  color: selectedProvider == null
                                      ? const Color(0xFF78819E)
                                      : const Color(0xFF1A1A1A),
                                  fontWeight: selectedProvider == null
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF5F6B99),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_providerError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _providerError!,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),
                  _buildAnimatedSection(
                    fade: _phoneFade,
                    slide: _phoneSlide,
                    child: Text(
                      _t('S? di?n tho?i', 'Phone number'),
                      style: GoogleFonts.poppins(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Ô nh?p s? di?n tho?i ---
                  _buildAnimatedSection(
                    fade: _phoneFade,
                    slide: _phoneSlide,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD8DEEE)),
                        color: selectedProvider == null
                            ? const Color(0xFFF3F5FA)
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _phoneController,
                        readOnly: selectedProvider == null,
                        onTap: () {
                          if (selectedProvider == null) {
                            setState(() {
                              _providerError = _t(
                                'Vui ḷng ch?n nhà cung c?p tru?c.',
                                'Please select a provider first.',
                              );
                              _phoneError = _t(
                                'Vui ḷng ch?n nhà cung c?p tru?c khi nh?p s? di?n tho?i.',
                                'Please select a provider before entering phone number.',
                              );
                            });
                          }
                        },
                        onChanged: (value) {
                          if (_phoneError != null) {
                            setState(() {
                              if (value.isEmpty) {
                                _phoneError = _t(
                                  'Vui ḷng nh?p s? di?n tho?i tru?c.',
                                  'Please enter phone number first.',
                                );
                              } else if (value.length < 10) {
                                _phoneError = _t(
                                  'S? di?n tho?i ph?i d? 10 s?.',
                                  'Phone number must have 10 digits.',
                                );
                              } else {
                                _phoneError = null;
                              }
                            });
                          }
                        },
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: _t(
                            'Nh?p s? di?n tho?i',
                            'Enter phone number',
                          ),
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                          fillColor: Colors.transparent,
                          filled: true,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_phoneError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _phoneError!,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),
                  _buildAnimatedSection(
                    fade: _amountFade,
                    slide: _amountSlide,
                    child: Text(
                      _t('Ch?n m?nh giá', 'Select amount'),
                      style: GoogleFonts.poppins(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (selectedAmount == _otherAmountKey) ...[
                    _buildAnimatedSection(
                      fade: _amountFade,
                      slide: _amountSlide,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD8DEEE)),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _customAmountController,
                          onChanged: (_) {
                            if (_customAmountError != null) {
                              setState(() {
                                _customAmountError = null;
                              });
                            }
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: _t('Nh?p s? ti?n', 'Enter amount'),
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade400,
                            ),
                            fillColor: Colors.transparent,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_customAmountError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _customAmountError!,
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                  ],

                  // --- Grid m?nh giá ---
                  _buildAnimatedSection(
                    fade: _amountFade,
                    slide: _amountSlide,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                      itemCount: amounts.length,
                      itemBuilder: (context, index) {
                        final String amount = amounts[index];
                        final bool isCustomAmount = amount == _otherAmountKey;
                        final String displayAmount = isCustomAmount
                            ? _t('S? khác', 'Other')
                            : amount;

                        return InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            setState(() {
                              selectedAmount = amount;
                              if (amount != _otherAmountKey) {
                                _customAmountError = null;
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedAmount == amount
                                  ? const Color(0xFFEAF0FF)
                                  : const Color(0xFFFDFEFF),
                              border: Border.all(
                                color: selectedAmount == amount
                                    ? _primaryBlue
                                    : const Color(0xFFD7DDEE),
                                width: selectedAmount == amount ? 1.6 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: selectedAmount == amount
                                  ? [
                                      BoxShadow(
                                        color: _primaryBlue.withOpacity(0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayAmount,
                                  style: GoogleFonts.poppins(
                                    color: selectedAmount == amount
                                        ? _primaryBlue
                                        : const Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (!isCustomAmount)
                                  Text(
                                    "VND",
                                    style: GoogleFonts.poppins(
                                      color: selectedAmount == amount
                                          ? _primaryBlue
                                          : const Color(0xFF1F2A44),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // --- Nút Ti?p theo ? du?i cùng ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildAnimatedSection(
              fade: _buttonFade,
              slide: _buttonSlide,
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    final String phoneNumber = _phoneController.text.trim();

                    if (selectedProvider == null) {
                      setState(() {
                        _providerError = _t(
                          'Vui ḷng ch?n nhà cung c?p tru?c.',
                          'Please select a provider first.',
                        );
                        _phoneError = _t(
                          'Vui ḷng ch?n nhà cung c?p tru?c khi nh?p s? di?n tho?i.',
                          'Please select a provider before entering phone number.',
                        );
                      });
                      return;
                    }

                    if (phoneNumber.isEmpty) {
                      setState(() {
                        _phoneError = _t(
                          'Vui ḷng nh?p s? di?n tho?i tru?c.',
                          'Please enter phone number first.',
                        );
                      });
                      return;
                    }

                    if (phoneNumber.length < 10) {
                      setState(() {
                        _phoneError = _t(
                          'S? di?n tho?i ph?i d? 10 s?.',
                          'Phone number must have 10 digits.',
                        );
                      });
                      return;
                    }

                    setState(() {
                      _providerError = null;
                      _phoneError = null;
                    });

                    if (selectedAmount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _t(
                              'Vui ḷng ch?n m?nh giá tru?c.',
                              'Please select an amount first.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    String amountToConfirm = selectedAmount!;

                    if (selectedAmount == _otherAmountKey) {
                      final String rawValue = _customAmountController.text
                          .trim();
                      if (rawValue.isEmpty) {
                        setState(() {
                          _customAmountError = _t(
                            'Vui ḷng nh?p s? ti?n cho m?c S? khác.',
                            'Please enter amount for Other option.',
                          );
                        });
                        return;
                      }

                      setState(() {
                        _customAmountError = null;
                      });
                      amountToConfirm = _formatAmountWithDots(rawValue);
                    }

                    _openConfirmScreen(
                      amount: amountToConfirm,
                      provider: selectedProvider!,
                      phoneNumber: phoneNumber,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    _t('Ti?p theo', 'Next'),
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
