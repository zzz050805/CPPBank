import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'success_screen.dart';

class ConfirmTopUpScreen extends StatelessWidget {
  final String selectedAmount;
  final String selectedProvider;
  final String selectedPhoneNumber;

  const ConfirmTopUpScreen({
    super.key,
    required this.selectedAmount,
    required this.selectedProvider,
    required this.selectedPhoneNumber,
  });

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  String _amountDisplay(BuildContext context) {
    if (selectedAmount == 'Số khác') {
      return _t(context, 'Số khác', 'Other');
    }
    return '$selectedAmount VND';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t(context, 'Nạp tiền điện thoại', 'Phone Top-Up'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header hiển thị số tiền
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000DC0), Color(0xFF00088C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _amountDisplay(context),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedAmount == 'Số khác'
                      ? _t(
                          context,
                          'Vui lòng nhập số tiền mong muốn',
                          'Please enter your desired amount',
                        )
                      : _t(context, 'Số tiền bạn đã chọn', 'Selected amount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
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
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(
                              context,
                              'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận giao dịch.',
                              'Please verify details carefully before confirming.',
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

                  const SizedBox(height: 18),

                  // Mục Trích từ
                  Text(
                    _t(context, 'Trích từ', 'From account'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: primaryColor,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t(context, 'Tài khoản nguồn', 'Source account'),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6E7490),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF222222),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(text: "STK: "),
                              TextSpan(
                                text: "123 568 567 456",
                                style: GoogleFonts.poppins(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                ? _t(
                                    context,
                                    'Không tìm thấy user',
                                    'User not found',
                                  )
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t(context, 'Khách hàng', 'Customer'));

                            return Text(
                              senderName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mục Thông tin chi tiết
                  Text(
                    _t(context, 'Thông tin chi tiết', 'Details'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          _t(context, 'Loại dịch vụ', 'Service type'),
                          _t(context, 'Nạp ĐTDD', 'Mobile top-up'),
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t(context, 'Nhà cung cấp', 'Provider'),
                          selectedProvider,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t(context, 'Số điện thoại', 'Phone number'),
                          selectedPhoneNumber,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t(context, 'Mệnh giá (VND)', 'Amount (VND)'),
                          _amountDisplay(context),
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Nút Xác nhận
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SuccessScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        _t(context, 'Xác nhận', 'Confirm'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để vẽ từng dòng thông tin
  Widget _buildInfoRow(String label, String value, {bool isBlue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1F263D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: isBlue ? const Color(0xFF0046A6) : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
