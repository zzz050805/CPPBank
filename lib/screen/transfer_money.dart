import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'choose_a_bank.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ContactListScreen(),
    );
  }
}

class TransferMoneyScreen extends StatelessWidget {
  const TransferMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContactListScreen();
  }
}

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF000DC0);

  final List<Map<String, String>> recentContacts = List.generate(
    10,
    (index) => {
      'name': index % 2 == 0 ? 'TRINH TRAN PHUONG TUAN' : 'PHUNG THANH DO',
      'id': index % 2 == 0 ? '534132' : '534 795 032',
    },
  );

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CCPAppBar(
        title: 'Chuyển tiền',
        backgroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Thanh tìm kiếm
                    TextField(
                      decoration: InputDecoration(
                        hintText: _t("Tìm kiếm", "Search"),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Nút Thêm người nhận mới
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddBeneficiaryScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t("Thêm người nhận mới", "Add new beneficiary"),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.add_circle,
                              color: primaryBlue,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _t("Đã lưu", "Saved"),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),

              // Danh sách "Đã lưu" nằm ngang
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: primaryBlue,
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "NGUYEN THANH B",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _t("Gần đây", "Recent"),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),

              // Danh sách "Gần đây" nằm dọc
              Expanded(
                child: ListView.separated(
                  itemCount: recentContacts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = recentContacts[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.account_balance,
                        color: Colors.black87,
                      ),
                      title: Text(
                        contact['name']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        contact['id']!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {},
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
