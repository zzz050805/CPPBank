import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'), // Hoặc font tương đương
      home: const SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isFaceIdEnabled = false;
  int _selectedBottomIndex = 3;
  static const Duration _navAnimationDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cài đặt',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 25),

              // Nhóm cài đặt chính
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildSettingItem("Xác thực khuôn mặt"),
                    _buildDivider(),
                    _buildSettingItem("CCP Safe key"),
                    _buildDivider(),
                    _buildSettingItem("Quản lý thiết bị truy cập"),
                    _buildDivider(),
                    _buildSettingItem("Đổi mật khẩu"),
                    _buildDivider(),
                    _buildSettingItem("Đổi tên truy cập"),
                    _buildDivider(),
                    _buildSwitchItem("Kích hoạt Face ID"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Nhóm thông báo
              Container(
                decoration: _cardDecoration(),
                child: _buildSettingItem("Quản lý thông báo"),
              ),

              const SizedBox(height: 30),

              // Nút Đăng xuất
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F4F7),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Đăng xuất',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomTab(),
    );
  }

  // Widget cho các mục cài đặt thông thường
  Widget _buildSettingItem(String title) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0033CC),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF0033CC)),
      onTap: () {},
    );
  }

  // Widget cho mục có Switch (Face ID)
  Widget _buildSwitchItem(String title) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0033CC),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: Switch(
        value: _isFaceIdEnabled,
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFF0033CC),
        onChanged: (value) {
          setState(() {
            _isFaceIdEnabled = value;
          });
        },
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(color: const Color(0xFFF0F0F0)),
    );
  }

  // Thanh Bottom Navigation tùy chỉnh
  Widget _buildBottomTab() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
              _bottomNavItem(Icons.home_outlined, '', 0),
              _bottomNavItem(Icons.search, '', 1),
              _bottomNavItem(Icons.mail_outline, '', 2),
              _bottomNavItem(Icons.settings, 'Setting', 3),
            ],
          ),
        ),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Widget _bottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedBottomIndex == index;
    final bool hasLabel = label.isNotEmpty;
    final bool isPillSelected = isSelected && hasLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _onBottomNavTap(index),
        child: AnimatedContainer(
          duration: _navAnimationDuration,
          curve: Curves.easeOutCubic,
          width: isPillSelected ? 99 : 44,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3F37C9) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedSwitcher(
            duration: _navAnimationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: isPillSelected
                ? Row(
                    key: ValueKey('setting_selected_$index'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 19),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    icon,
                    key: ValueKey('setting_icon_$index'),
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 21,
                  ),
          ),
        ),
      ),
    );
  }
}
