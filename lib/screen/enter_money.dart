import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'confirm_money.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: const TransferScreen(),
    );
  }
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  static const int _availableBalance = 1000000000;
  final TextEditingController _amountController = TextEditingController();
  String? _amountError;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _validateAmount(String value) {
    final int amount = int.tryParse(value) ?? 0;

    setState(() {
      if (value.isEmpty) {
        _amountError = null;
      } else if (amount > _availableBalance) {
        _amountError = _t(
          "Số dư trong tài khoản không đủ",
          "Insufficient account balance",
        );
      } else {
        _amountError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0000CC); // Màu xanh đậm chủ đạo

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              _t('Hủy', 'Cancel'),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),

                    // --- Số dư tài khoản ---
                    Text(
                      _t('Số dư tài khoản', 'Account balance'),
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCustomBox(
                      child: Text(
                        "1.000.000.000 VND",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- Khung chuyển tiền (Từ -> Đến) ---
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Từ tài khoản', 'From account'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          StreamBuilder<UserProfileData?>(
                            stream: UserFirestoreService.instance
                                .currentUserProfileStream(),
                            initialData:
                                UserFirestoreService.instance.latestProfile,
                            builder: (context, snapshot) {
                              final UserProfileData? profile =
                                  snapshot.data ??
                                  UserFirestoreService.instance.latestProfile;
                              final String senderName = snapshot.hasError
                                  ? _t('Không tìm thấy user', 'User not found')
                                  : ((profile?.fullname.isNotEmpty == true)
                                        ? profile!.fullname
                                        : _t('Khách hàng', 'Customer'));

                              return _buildAccountInfoCard(
                                name: senderName.toUpperCase(),
                                id: '123 568 567 456',
                                isBlue: false,
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _t('Đến tài khoản', 'To account'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _buildAccountInfoCard(
                            name: "TRAN THANH B",
                            id: "312 555 867",
                            bank: "MC-BANK",
                            isBlue: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- Nhập số tiền ---
                    _buildInputLabel(""),
                    _buildCustomBox(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              onChanged: _validateAmount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: _t('Nhập số tiền', 'Enter amount'),
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "VND",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_amountError != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          _amountError!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // --- Nhập nội dung ---
                    _buildInputLabel(""),
                    _buildCustomBox(
                      height: 120,
                      alignment: Alignment.topLeft,
                      child: TextField(
                        maxLines: null,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ỹà-ỹ\s]"),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: _t('Nhập nội dung', 'Enter message'),
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- Nút Tiếp theo ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          _validateAmount(_amountController.text);
                          if (_amountError != null) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConfirmTransferScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _t('Tiếp theo', 'Next'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget: Tiêu đề nhỏ phía trên ô nhập
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Widget: Ô nhập liệu/hiển thị bo tròn có đổ bóng nhẹ
  Widget _buildCustomBox({
    required Widget child,
    double? height,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: double.infinity,
      height: height ?? 60,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // Widget: Thẻ thông tin tài khoản (Trắng hoặc Xanh)
  Widget _buildAccountInfoCard({
    required String name,
    required String id,
    String? bank,
    bool isBlue = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isBlue ? const Color(0xFF0000CC) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isBlue ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              color: isBlue ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (bank != null)
            Text(
              bank,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              if (isBlue)
                const Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 16,
                ),
              if (isBlue) const SizedBox(width: 5),
              Text(
                id,
                style: GoogleFonts.poppins(
                  color: isBlue ? Colors.white : Colors.black54,
                  fontWeight: isBlue ? FontWeight.w500 : FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
