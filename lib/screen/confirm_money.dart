import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import 'otp_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Thiết lập font Poppins làm mặc định toàn app
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const ConfirmTransferScreen(),
    );
  }
}

class ConfirmTransferScreen extends StatelessWidget {
  const ConfirmTransferScreen({super.key});

  // Màu xanh chủ đạo bạn yêu cầu
  static const Color primaryBlue = Color(0xFF000DC0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              "Hủy",
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Xác nhận chuyển tiền",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "1.000.000 VND",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, // Đen nhẹ
                    ),
                  ),
                  Text(
                    "Một triệu đồng",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Khung bao quanh thông tin tài khoản
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel("Từ tài khoản"),
                        const SizedBox(height: 10),
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          builder: (context, snapshot) {
                            final String senderName = snapshot.hasError
                                ? 'Không tìm thấy user'
                                : (snapshot.data?.fullname ?? '...');

                            return _buildAccountCard(
                              name: senderName.toUpperCase(),
                              id: "123 568 567 456",
                              isSource: true,
                            );
                          },
                        ),
                        const SizedBox(height: 25),
                        _buildSectionLabel("Đến tài khoản"),
                        const SizedBox(height: 10),
                        _buildAccountCard(
                          name: "TRAN THANH B",
                          bank: "MC-BANK",
                          id: "312 555 867",
                          isSource: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nút Xác nhận ở dưới cùng
          Padding(
            padding: const EdgeInsets.all(25),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const OTPScreen(phoneNumber: '(+84) 0398829xxx'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Xác nhận",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Widget hiển thị nhãn "Từ tài khoản / Đến tài khoản"
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: Colors.grey.shade500,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Widget hiển thị thẻ tài khoản (Trắng hoặc Xanh)
  Widget _buildAccountCard({
    required String name,
    required String id,
    String? bank,
    required bool isSource,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isSource ? Colors.white : primaryBlue,
        borderRadius: BorderRadius.circular(15),
        border: isSource ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              color: isSource ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (bank != null)
            Text(
              bank,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: isSource ? Colors.grey : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                id,
                style: GoogleFonts.poppins(
                  color: isSource ? Colors.grey.shade600 : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
