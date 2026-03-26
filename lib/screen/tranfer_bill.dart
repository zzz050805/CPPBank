import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      home: const SuccessTransactionScreen(),
    );
  }
}

class SuccessTransactionScreen extends StatelessWidget {
  const SuccessTransactionScreen({super.key});

  // Ảnh minh họa giao dịch thành công từ assets
  final String imageAsset = 'assets/images/bill_tranfer.png';

  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color successGreen = Color(0xFF4ADBB3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // --- PHẦN ẢNH LOGO LỚN ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Image.asset(
                        imageAsset,
                        height: 250,
                        fit: BoxFit.contain,
                        // Hiển thị icon lỗi nếu ảnh assets không tồn tại
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 250,
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Thông báo thành công
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: successGreen,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Bạn đã chuyển tiền thành công",
                          style: GoogleFonts.poppins(
                            color: successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "1.000.000 VND",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
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

                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? 'Không tìm thấy user'
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : 'Khach hang');

                        return Column(
                          children: [
                            const Divider(height: 1),
                            _buildInfoRow(
                              "Từ",
                              "${senderName.toUpperCase()}\n****** 456",
                            ),
                            const Divider(height: 1),
                            _buildInfoRow(
                              "Đến",
                              "TRAN THANH B\nMC-BANK\n312 555 867",
                            ),
                            const Divider(height: 1),
                            _buildInfoRow(
                              "Chuyển lúc",
                              "12/12/2025 , 10:10:21",
                            ),
                            const Divider(height: 1),
                            _buildInfoRow("Phí", "Miễn phí"),
                            const Divider(height: 1),
                            _buildInfoRow("Mã giao dịch", "3421"),
                            const Divider(height: 1),
                          ],
                        );
                      },
                    ),

                    // Nội dung chuyển tiền
                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? 'Không tìm thấy user'
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : 'Khach hang');

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nội dung",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "${senderName.toUpperCase()} CHUYEN TIEN",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- HÀNG NÚT BẤM DƯỚI CÙNG ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  // Nút Đóng
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0F2F8),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          "Đóng",
                          style: GoogleFonts.poppins(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Nút Gửi (Chia sẻ)
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Gửi",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm helper để tạo các dòng thông tin
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
