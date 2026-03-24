import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'branch_screen.dart';
import 'exchange_rate_screen.dart';
import 'currency_convert_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // ĐẶT MẶC ĐỊNH LÀ 1 để nút Tìm kiếm active
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      // Sử dụng Stack để đè thanh Bottom Nav lên trên nội dung
      body: Stack(
        children: [
          _buildBodyContent(),
          _buildPillBottomNav(),
        ],
      ),
    );
  }

  // Tách phần nội dung chính ra cho gọn
  Widget _buildBodyContent() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(top: 50, left: 10, right: 20, bottom: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "Tìm kiếm",
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // 1. CHI NHÁNH
                _buildSearchCard(
                  title: "Chi nhánh",
                  desc: "Tìm kiếm chi nhánh",
                  imagePath: "assets/search/banklogo.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BranchScreen()),
                    );
                  },
                ),

                // 2. LÃI SUẤT
                _buildSearchCard(
                  title: "Lãi suất",
                  desc: "Tra cứu lãi suất tiết kiệm\n& vay",
                  imagePath: "assets/search/laisuat.png",
                  onTap: () {
                    // Bro có thể thêm Navigator cho trang Lãi suất tại đây
                  },
                ),

                // 3. TỶ GIÁ HỐI ĐOÁI - ĐÃ GẮN LINK
                _buildSearchCard(
                  title: "Tỷ giá hối đoái",
                  desc: "Cập nhật tỷ giá ngoại tệ\nmới nhất",
                  imagePath: "assets/search/tygiadoihoai.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ExchangeRateScreen()),
                    );
                  },
                ),

                // 4. QUY ĐỔI TIỀN TỆ
                _buildSearchCard(
                  title: "Quy đổi tiền tệ",
                  desc: "Công cụ tính toán chuyển\nđổi tiền tệ",
                  imagePath: "assets/search/quydoitiente.png",
                  onTap: () { 
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CurrencyConvertScreen()),
                    );
                  },
                ),
                const SizedBox(height: 120), // Khoảng trống cho Bottom Nav
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard({
    required String title,
    required String desc,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF343434))),
                      const SizedBox(height: 6),
                      Text(desc, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500], height: 1.4)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.account_balance_rounded, size: 60, color: const Color(0xFF000DC0).withOpacity(0.1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- THANH BOTTOM NAV Y HỆT TRANG HOME ---
  Widget _buildPillBottomNav() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _pillNavItem(Icons.home, "Trang chính", 0),
            _pillNavItem(Icons.search, "Tìm kiếm", 1),
            _pillNavItem(Icons.chat_bubble_outline, "", 2),
            _pillNavItem(Icons.settings_outlined, "", 3),
          ],
        ),
      ),
    );
  }

  Widget _pillNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) { // Bấm vào Trang chủ
          Navigator.pop(context); // Quay lại trang HomeScreen
        }
        // Nếu là index 1 thì không làm gì vì đang ở chính nó
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFF000DC0),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 22,
            ),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}