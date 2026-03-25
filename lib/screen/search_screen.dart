import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'branch_screen.dart';
import 'exchange_rate_screen.dart';
import 'currency_convert_screen.dart';
import 'interest_rate_screen.dart';
import 'home_screen.dart';
import 'setting_screen.dart';
import 'chat_placeholder_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // ĐẶT MẶC ĐỊNH LÀ 1 để nút Tìm kiếm active
  int _selectedIndex = 1;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: CCPAppBar(
        title: _t("Tìm kiếm", "Search"),
        onBackPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        },
      ),
      // Sử dụng Stack để đè thanh Bottom Nav lên trên nội dung
      body: Stack(children: [_buildBodyContent(), _buildPillBottomNav()]),
    );
  }

  // Tách phần nội dung chính ra cho gọn
  Widget _buildBodyContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // 1. CHI NHÁNH
                _buildSearchCard(
                  title: _t("Chi nhánh", "Branch"),
                  desc: _t("Tìm kiếm chi nhánh", "Find branch"),
                  imagePath: "assets/search/banklogo.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BranchScreen(),
                      ),
                    );
                  },
                ),

                // 2. LÃI SUẤT
                _buildSearchCard(
                  title: _t("Lãi suất", "Interest rates"),
                  desc: _t(
                    "Tra cứu lãi suất tiết kiệm\n& vay",
                    "Check savings and loan\nrates",
                  ),
                  imagePath: "assets/search/laisuat.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InterestRateScreen(),
                      ),
                    );
                  },
                ),

                // 3. TỶ GIÁ HỐI ĐOÁI - ĐÃ GẮN LINK
                _buildSearchCard(
                  title: _t("Tỷ giá hối đoái", "Exchange rates"),
                  desc: _t(
                    "Cập nhật tỷ giá ngoại tệ\nmới nhất",
                    "Latest foreign exchange\nupdates",
                  ),
                  imagePath: "assets/search/tygiadoihoai.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExchangeRateScreen(),
                      ),
                    );
                  },
                ),

                // 4. QUY ĐỔI TIỀN TỆ
                _buildSearchCard(
                  title: _t("Quy đổi tiền tệ", "Currency converter"),
                  desc: _t(
                    "Công cụ tính toán chuyển\nđổi tiền tệ",
                    "Currency conversion\ncalculator",
                  ),
                  imagePath: "assets/search/quydoitiente.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CurrencyConvertScreen(),
                      ),
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
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF343434),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.account_balance_rounded,
                      size: 60,
                      color: const Color(0xFF000DC0).withOpacity(0.1),
                    ),
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
            _pillNavItem(Icons.home, _t("Trang chính", "Home"), 0),
            _pillNavItem(Icons.search, _t("Tìm kiếm", "Search"), 1),
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
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatPlaceholderScreen(),
            ),
          );
        } else if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SettingScreen()),
          );
        }
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
