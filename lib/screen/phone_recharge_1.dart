import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';

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
    const Color primaryColor = Color(0xFF1A1A9E); // Màu xanh đậm chủ đạo

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t(context, 'Nạp tiền điện thoại', 'Phone Top-Up'),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header hiển thị số tiền
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25),
            color: primaryColor,
            child: Column(
              children: [
                Text(
                  _amountDisplay(context),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  selectedAmount == 'Số khác'
                      ? _t(
                          context,
                          'Vui lòng nhập số tiền mong muốn',
                          'Please enter your desired amount',
                        )
                      : _t(context, 'Số tiền bạn đã chọn', 'Selected amount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
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
                  // Mục Trích từ
                  Text(
                    _t(context, 'Trích từ', 'From account'),
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(text: "STK: "),
                              TextSpan(
                                text: "123 568 567 456",
                                style: GoogleFonts.poppins(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          builder: (context, snapshot) {
                            final String senderName = snapshot.hasError
                                ? _t(
                                    context,
                                    'Không tìm thấy user',
                                    'User not found',
                                  )
                                : (snapshot.data?.fullname ?? '...');

                            return Text(
                              senderName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
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
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
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
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Xử lý xác nhận giao dịch
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0000CD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        _t(context, 'Xác nhận', 'Confirm'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isBlue ? Colors.blue.shade900 : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
