import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            HelpHero(),
            HelpCategories(),
            HelpFAQ(),
            HelpContact(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// --- 1. HERO SECTION ---
class HelpHero extends StatelessWidget {
  const HelpHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient Background
        Container(
          height: 380,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF001DC0), Color(0xFF000A80)],
            ),
          ),
        ),
        // Nội dung Hero
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo & Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "B",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "TRUNG TÂM TRỢ GIÚP",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  "Chúng tôi có thể\ngiúp gì cho bạn?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Tìm kiếm câu trả lời nhanh chóng hoặc liên hệ trực tiếp với đội ngũ chuyên viên",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Tìm kiếm câu hỏi, chủ đề...",
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF001DC0), Color(0xFF4D5FFF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- 2. CATEGORIES SECTION ---
class HelpCategories extends StatelessWidget {
  const HelpCategories({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        "icon": LucideIcons.creditCard,
        "title": "Thẻ & Tài khoản",
        "desc": "Mở thẻ, khoá thẻ, hạn mức",
      },
      {
        "icon": LucideIcons.repeat,
        "title": "Chuyển tiền",
        "desc": "Nội địa, quốc tế, lịch sử",
      },
      {
        "icon": LucideIcons.shieldCheck,
        "title": "Bảo mật",
        "desc": "Mật khẩu, OTP, sinh trắc",
      },
      {
        "icon": LucideIcons.smartphone,
        "title": "Ứng dụng",
        "desc": "Cài đặt, cập nhật, lỗi",
      },
      {
        "icon": LucideIcons.wallet,
        "title": "Tiết kiệm & Vay",
        "desc": "Lãi suất, kỳ hạn, hồ sơ",
      },
      {
        "icon": LucideIcons.helpCircle,
        "title": "Khác",
        "desc": "Phí dịch vụ, khuyến mãi",
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DANH MỤC",
            style: TextStyle(
              color: Color(0xFF001DC0),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Chọn chủ đề bạn cần hỗ trợ",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return LuxuryCard(
                icon: categories[index]['icon'] as IconData,
                title: categories[index]['title'] as String,
                desc: categories[index]['desc'] as String,
              );
            },
          ),
        ],
      ),
    );
  }
}

class LuxuryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const LuxuryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000DC0).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF001DC0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF001DC0), size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// --- 3. FAQ SECTION ---
class HelpFAQ extends StatelessWidget {
  const HelpFAQ({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "q": "Làm sao để khoá thẻ khẩn cấp?",
        "a":
            "Mở ứng dụng → Quản lý thẻ → Chọn thẻ cần khoá → Nhấn \"Khoá thẻ\".",
      },
      {
        "q": "Phí chuyển tiền liên ngân hàng là bao nhiêu?",
        "a": "Miễn phí cho giao dịch dưới 10 triệu qua Napas 24/7.",
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "FAQ",
            style: TextStyle(
              color: Color(0xFF001DC0),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Câu hỏi thường gặp",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                title: Text(
                  faq['q']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq['a']!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
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
}

// --- 4. CONTACT SECTION ---
class HelpContact extends StatelessWidget {
  const HelpContact({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const ContactTile(
            icon: LucideIcons.phone,
            title: "Tổng đài 24/7",
            detail: "1900 xxxx",
            color: Color(0xFF001DC0),
          ),
          const SizedBox(height: 12),
          const ContactTile(
            icon: LucideIcons.messageCircle,
            title: "Chat trực tuyến",
            detail: "Bắt đầu ngay",
            color: Colors.black,
          ),
          const SizedBox(height: 24),
          // Online Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Đội ngũ hỗ trợ đang trực tuyến",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const ContactTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(LucideIcons.arrowUpRight, size: 18, color: Colors.grey),
        ],
      ),
    );
  }
}
