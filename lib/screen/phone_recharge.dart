import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _providerFade;
  late final Animation<Offset> _providerSlide;
  late final Animation<double> _phoneFade;
  late final Animation<Offset> _phoneSlide;
  late final Animation<double> _amountFade;
  late final Animation<Offset> _amountSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  // Danh sách nhà mạng
  final List<String> providers = [
    'Viettel',
    'Mobifone',
    'Vinaphone',
    'Vietnamobile',
    'Gmobile',
  ];
  String? selectedProvider;

  // Danh sách mệnh giá
  final List<String> amounts = [
    '10.000',
    '20.000',
    '30.000',
    '50.000',
    '100.000',
    '200.000',
    '300.000',
    '500.000',
    'Số khác',
  ];
  String? selectedAmount;
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _providerError;
  String? _phoneError;
  String? _customAmountError;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nạp tiền điện thoại',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Phần nội dung chính (Cho phép cuộn)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // --- Dropdown chọn nhà cung cấp ---
                  _buildAnimatedSection(
                    fade: _providerFade,
                    slide: _providerSlide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Chọn nhà cung cấp"),
                          value: selectedProvider,
                          items: providers.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              selectedProvider = newValue;
                              _providerError = null;
                              if (_phoneError ==
                                  'Vui lòng chọn nhà cung cấp trước khi nhập số điện thoại.') {
                                _phoneError = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_providerError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _providerError!,
                      style: const TextStyle(
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
                    child: const Text(
                      "Số điện thoại",
                      style: TextStyle(
                        color: Color(0xFF000DC0),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Ô nhập số điện thoại ---
                  _buildAnimatedSection(
                    fade: _phoneFade,
                    slide: _phoneSlide,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _phoneController,
                        readOnly: selectedProvider == null,
                        onTap: () {
                          if (selectedProvider == null) {
                            setState(() {
                              _providerError =
                                  'Vui lòng chọn nhà cung cấp trước.';
                              _phoneError =
                                  'Vui lòng chọn nhà cung cấp trước khi nhập số điện thoại.';
                            });
                          }
                        },
                        onChanged: (value) {
                          if (_phoneError != null) {
                            setState(() {
                              if (value.isEmpty) {
                                _phoneError =
                                    'Vui lòng nhập số điện thoại trước.';
                              } else if (value.length < 10) {
                                _phoneError = 'Số điện thoại phải đủ 10 số.';
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
                          hintText: "Nhập số điện thoại",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          fillColor: Colors.white,
                          filled: true,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
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
                      style: const TextStyle(
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
                    child: const Text(
                      "Chọn mệnh giá",
                      style: TextStyle(
                        color: Color(0xFF000DC0),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (selectedAmount == 'Số khác') ...[
                    _buildAnimatedSection(
                      fade: _amountFade,
                      slide: _amountSlide,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.25),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
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
                            hintText: "Nhập số tiền",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
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
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                  ],

                  // --- Grid mệnh giá ---
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
                        final bool isCustomAmount = amount == 'Số khác';

                        return InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            setState(() {
                              selectedAmount = amount;
                              if (amount != 'Số khác') {
                                _customAmountError = null;
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedAmount == amount
                                  ? const Color(0xFFE8EBFF)
                                  : Colors.white,
                              border: Border.all(
                                color: selectedAmount == amount
                                    ? const Color(0xFF000DC0)
                                    : Colors.grey.shade300,
                                width: selectedAmount == amount ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  amount,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (!isCustomAmount)
                                  const Text(
                                    "VND",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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

          // --- Nút Tiếp theo ở dưới cùng ---
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
                        _providerError = 'Vui lòng chọn nhà cung cấp trước.';
                        _phoneError =
                            'Vui lòng chọn nhà cung cấp trước khi nhập số điện thoại.';
                      });
                      return;
                    }

                    if (phoneNumber.isEmpty) {
                      setState(() {
                        _phoneError = 'Vui lòng nhập số điện thoại trước.';
                      });
                      return;
                    }

                    if (phoneNumber.length < 10) {
                      setState(() {
                        _phoneError = 'Số điện thoại phải đủ 10 số.';
                      });
                      return;
                    }

                    setState(() {
                      _providerError = null;
                      _phoneError = null;
                    });

                    if (selectedAmount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn mệnh giá trước.'),
                        ),
                      );
                      return;
                    }

                    String amountToConfirm = selectedAmount!;

                    if (selectedAmount == 'Số khác') {
                      final String rawValue = _customAmountController.text
                          .trim();
                      if (rawValue.isEmpty) {
                        setState(() {
                          _customAmountError =
                              'Vui lòng nhập số tiền cho mục Số khác.';
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
                    backgroundColor: const Color(0xFF000DC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Tiếp theo",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
