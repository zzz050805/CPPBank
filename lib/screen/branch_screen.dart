import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';
import 'setting_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'chat_placeholder_screen.dart';

class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  int? selectedBranchId;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> mockBranches = [
    {
      "id": 1,
      "name": "Chi nhánh Lý Tự Trọng",
      "address": "126 Lý Tự Trọng, Phường Bến Thành, Quận 1, TP.HCM",
      "phone": "028 3822 1234",
      "hours": "08:00 - 17:00",
      "distance": "0.5 km",
      "isOpen": true,
      "pos": const Offset(0.25, 0.3), // Tọa độ giả lập trên map
    },
    {
      "id": 2,
      "name": "Chi nhánh Nguyễn Thị Minh Khai",
      "address": "45 Nguyễn Thị Minh Khai, Quận 1, TP.HCM",
      "phone": "028 3822 5678",
      "hours": "08:00 - 17:00",
      "distance": "1.2 km",
      "isOpen": true,
      "pos": const Offset(0.55, 0.45),
    },
    {
      "id": 3,
      "name": "Chi nhánh Trần Hưng Đạo",
      "address": "210 Trần Hưng Đạo, Quận 1, TP.HCM",
      "phone": "028 3836 9012",
      "hours": "08:00 - 17:00",
      "distance": "1.8 km",
      "isOpen": false,
      "pos": const Offset(0.7, 0.2),
    },
    {
      "id": 4,
      "name": "Chi nhánh Nguyễn Tất Thành",
      "address": "90 Nguyễn Tất Thành, Quận 4, TP.HCM",
      "phone": "028 3940 3456",
      "hours": "08:00 - 17:00",
      "distance": "2.5 km",
      "isOpen": true,
      "pos": const Offset(0.4, 0.6),
    },
  ];

  List<Map<String, dynamic>> get filteredBranches {
    if (searchQuery.isEmpty) return mockBranches;
    return mockBranches
        .where(
          (b) =>
              b['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
              b['address'].toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. MOCKUP MAP (Nền dưới cùng)
          _buildMapPlaceholder(),

          // 2. CUSTOM HEADER (Dải trắng trên cùng)
          _buildHeader(),

          // 3. TẤM KÉO DANH SÁCH (Draggable Sheet)
          _buildDraggableSheet(),

          // 4. BOTTOM NAV (Nằm trên cùng)
          _buildPillBottomNav(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 50, bottom: 15, left: 10),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Text(
              _t("Chi nhánh", "Branch"),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFFEDEFF7),
        child: Stack(
          children: [
            // Vẽ đường kẻ giả lập (Roads)
            Center(child: Container(width: 2, color: Colors.black12)),
            Positioned(
              top: 200,
              left: 0,
              right: 0,
              child: Container(height: 2, color: Colors.black12),
            ),

            // Vẽ các Pin (Ghim) chi nhánh
            ...mockBranches.map((b) {
              bool isSelected = selectedBranchId == b['id'];
              return Positioned(
                left: MediaQuery.of(context).size.width * b['pos'].dx,
                top: MediaQuery.of(context).size.height * b['pos'].dy,
                child: Column(
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          b['name'].split(" ").last,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Icon(
                      Icons.location_on,
                      color: isSelected
                          ? Colors.orange
                          : const Color(0xFF000DC0),
                      size: isSelected ? 40 : 30,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, size: 20),
                      hintText: _t("Tìm chi nhánh...", "Find branch..."),
                    ),
                  ),
                ),
              ),

              // Danh sách
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredBranches.length,
                  itemBuilder: (context, index) {
                    final b = filteredBranches[index];
                    bool isSelected = selectedBranchId == b['id'];

                    return GestureDetector(
                      onTap: () => setState(
                        () => selectedBranchId = isSelected ? null : b['id'],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF0F2FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF000DC0).withOpacity(0.3)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFF000DC0,
                                  ).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF000DC0),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            b['name'],
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            b['distance'],
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        b['address'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: b['isOpen']
                                                  ? Colors.green[50]
                                                  : Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              b['isOpen']
                                                  ? _t("Đang mở cửa", "Open")
                                                  : _t("Đã đóng cửa", "Closed"),
                                              style: GoogleFonts.poppins(
                                                color: b['isOpen']
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            b['hours'],
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Chi tiết mở rộng (giống code React của bro)
                            if (isSelected) ...[
                              const Divider(height: 25),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Color(0xFF000DC0),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b['phone'],
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(
                                        Icons.navigation,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _t("Chỉ đường", "Directions"),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF000DC0,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: Text(_t("Gọi", "Call")),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF000DC0),
                                      side: const BorderSide(
                                        color: Color(0xFF000DC0),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 80), // Chừa chỗ cho Bottom Nav
            ],
          ),
        );
      },
    );
  }

  // Reuse PillBottomNav từ các turn trước
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
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, 5),
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
    // Trang này không nằm trong 4 nút chính nên ta check index thủ công
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
        // Vì Chi nhánh thuộc mục Tìm kiếm nên ta cho nút Tìm kiếm sáng lên (index 1)
        decoration: index == 1
            ? BoxDecoration(
                color: const Color(0xFF000DC0),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: index == 1 ? Colors.white : Colors.grey[600],
              size: 22,
            ),
            if (index == 1 && label.isNotEmpty) ...[
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
