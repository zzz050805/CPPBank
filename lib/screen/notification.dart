import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Danh sách các tab tương ứng với React
  final List<String> tabs = ["Giao dịch", "Ưu đãi", "Thông báo"];
  static const Color _activeTabColor = Color(0xFF000DC0);
  int _selectedTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F4F6,
      ), // Tương đương bg-muted (xám nhạt)
      appBar: AppBar(
        backgroundColor: Colors.white, // Tương đương bg-card
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0, // Sát lại gần icon back
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: Row(
              children: List.generate(tabs.length, (index) {
                final bool isActive = _selectedTabIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = index),
                    child: SizedBox(
                      height: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            tabs[index],
                            style: TextStyle(
                              color: isActive
                                  ? _activeTabColor
                                  : const Color(0xFF374151),
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: isActive ? 50 : 0,
                            height: 2.2,
                            color: _activeTabColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: const [
          Center(child: Text("Nội dung Giao dịch")),
          Center(child: Text("Nội dung Ưu đãi")),
          Center(child: Text("Nội dung Thông báo")),
        ],
      ),
    );
  }
}
