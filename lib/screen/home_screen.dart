import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'search_screen.dart';
import 'setting_screen.dart';
import 'transfer_money.dart';
import 'phone_recharge.dart';
import 'QR.dart';
import 'credit_card.dart';
import 'chat_placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isBalanceVisible = false;
  int _currentBannerIndex = 0;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  // --- DỮ LIỆU BANNER (Kiểm tra kỹ đuôi file máy bro nhé) ---
  final List<String> bannerImages = [
    'assets/images/banner1.jpg', // Sửa .png -> .jpg nếu cần
    'assets/images/banner2.jpg',
    'assets/images/banner3.jpg',
    'assets/images/banner4.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF000DC0,
      ), // Nền xanh để mép header không hở trắng
      body: Stack(children: [_buildSlivers(), _buildPillBottomNav()]),
    );
  }

  Widget _buildSlivers() {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            pinned: true,
            // SỬA CHÍNH: Tạo Header Xanh Bo Tròn Mượt Mà
            backgroundColor: const Color(0xFF000DC0), // Xanh đậm CCP
            elevation: 0,
            expandedHeight: 120, // Tăng nhẹ chiều cao
            collapsedHeight: 120,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ), // Bo mượt phần đuôi header
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _t("Xin chào,", "Hello,"),
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          builder: (context, snapshot) {
                            final String name = snapshot.hasError
                                ? _t('Không tìm thấy user', 'User not found')
                                : (snapshot.data?.fullname ?? '...');

                            return Text(
                              name.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    Stack(
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                          size: 32,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '2',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      // --- PHẦN BODY BÊN DƯỚI ---
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 42, color: const Color(0xFF000DC0)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                clipBehavior: Clip.none,
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 8),
                    _buildActionGrid(),
                    _buildBannerCarousel(),
                    _buildShoppingSection(),
                    _buildSpendingChart(),
                    _buildTransactionHistory(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SỬA CHÍNH: THẺ SỐ DƯ NỔI LÊN, BO GÓC CHUẨN XỊN ---
  Widget _buildBalanceCard() {
    return Transform.translate(
      offset: const Offset(
        0,
        16,
      ), // Giữ vị trí thẻ cân hơn với viền trắng bo góc
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          // Chỉnh gradient và bo góc cho xịn
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3122AB),
                Color(0xFF050C9C),
              ], // Gradient xanh chuyên nghiệp
            ),
            borderRadius: BorderRadius.circular(20), // Bo góc chuẩn 20
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ), // Viền trắng mảnh, dịu hơn
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ), // Bóng đổ sâu
              BoxShadow(
                color: const Color(0xFF000B7A).withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4BD4FF).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ), // Ánh xanh nhẹ thò ra
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(0.6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19.4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 0.7,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.09),
                            Colors.transparent,
                            Colors.cyanAccent.withOpacity(0.04),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Thêm xíu họa tiết vòng tròn chìm cho thẻ nó sang
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -42,
                  top: -74,
                  child: Container(
                    width: 164,
                    height: 164,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -92,
                  bottom: -112,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withOpacity(0.03),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Số dư tài khoản VND",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                              () => _isBalanceVisible = !_isBalanceVisible,
                            ),
                            child: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Chỉnh lại font size cho số dư nổi bật
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _isBalanceVisible
                                  ? "1.000.000.000 "
                                  : "*** *** ",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: "VND",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            _t('Lịch sử giao dịch >', 'Transaction history >'),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                          const Spacer(),
                          // Icon 2 vòng tròn lồng nhau
                          SizedBox(
                            width: 28,
                            height: 18,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.cyan.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CÁC PHẦN DƯỚI GIỮ NGUYÊN ---
  Widget _buildActionGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        children: [
          _actionItem(
            Icons.account_balance_wallet,
            Colors.purple,
            _t("Chuyển tiền", "Transfer"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransferMoneyScreen(),
                ),
              );
            },
          ),
          _actionItem(
            Icons.receipt_long,
            Colors.green,
            _t("Thanh toán\nhóa đơn", "Bill\npayment"),
          ),
          _actionItem(Icons.atm, Colors.blue, _t("Rút tiền", "Withdraw")),
          _actionItem(
            Icons.qr_code_scanner,
            Colors.pink,
            _t("Quét QR", "Scan QR"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QrScreen()),
              );
            },
          ),
          _actionItem(
            Icons.phone_android,
            Colors.orange,
            _t("Nạp tiền\nđiện thoại", "Phone\nTop up"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PhoneRechargeScreen(),
                ),
              );
            },
          ),
          _actionItem(
            Icons.credit_card,
            Colors.deepOrange,
            _t("Thẻ tín dụng", "Credit card"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreditCardScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionItem(
    IconData icon,
    Color color,
    String title, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF343434),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    if (bannerImages.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
      child: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.75),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1E34D8).withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: 146,
                      viewportFraction: 0.86,
                      padEnds: true,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 3),
                      autoPlayAnimationDuration: const Duration(
                        milliseconds: 850,
                      ),
                      autoPlayCurve: Curves.easeInOutCubic,
                      enlargeCenterPage: true,
                      enlargeFactor: 0.16,
                      onPageChanged: (index, reason) {
                        if (_currentBannerIndex != index) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        }
                      },
                    ),
                    items: bannerImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final imagePath = entry.value;
                      final isActive = _currentBannerIndex == index;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isActive ? 0.12 : 0.05,
                              ),
                              blurRadius: isActive ? 10 : 6,
                              offset: Offset(0, isActive ? 5 : 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Text("Banner"),
                                      ),
                                    ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(
                                          isActive ? 0.1 : 0.06,
                                        ),
                                        Colors.transparent,
                                        Colors.black.withOpacity(
                                          isActive ? 0.1 : 0.06,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(bannerImages.length, (index) {
              final isActive = _currentBannerIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: isActive ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isActive
                      ? const Color(0xFF000DC0)
                      : Colors.grey.withOpacity(0.45),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingSection() {
    // Giữ nguyên dùng ảnh thật và Popup của bro
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t("Mua sắm - Giải trí", "Shopping - Entertainment"),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _circleImageItem(
                'assets/images/shopee.png',
                "Shopee",
                "Liên kết ví CCP - Mua sắm Shopee thả ga",
                "Trải nghiệm thanh toán 1 chạm siêu tốc, không cần nhập mã OTP cho các giao dịch dưới 2.000.000đ.\n• Ưu đãi độc quyền: Tặng ngay Voucher giảm 50K cho đơn hàng đầu tiên (áp dụng khi nhập mã CCP50).\n• Quyền lợi: Hoàn tiền 2% (tối đa 100K/tháng) cho mọi giao dịch thanh toán hóa đơn, nạp điện thoại qua ShopeePay bằng nguồn tiền CCPCredit. Miễn phí thường niên năm đầu tiên.",
              ),
              _circleImageItem(
                'assets/images/riot.png',
                "Riot Games",
                "Nạp thẻ Riot Games - Nhận VP & RP tức thì",
                "Kênh nạp thẻ chính thức, không qua trung gian.\nĐảm bảo 100% an toàn cho valorant và LMHT.",
              ),
              _circleImageItem(
                'assets/images/netflix.png',
                "Netflix",
                "Premium Family",
                "Đăng ký Premium, quản lý gia hạn gói gia đình dễ dàng.",
              ),
              _circleImageItem(
                'assets/images/itunes.png',
                "Apple Music",
                "Trải nghiệm 3 tháng free",
                "Nghe nhạc chất lượng cao, miễn phí 3 tháng đầu.",
              ),
              _circleImageItem(
                'assets/images/chatgpt.png',
                "Chat GPT",
                "Nâng cấp Plus",
                "Tận hưởng sức mạnh của AI, các tính năng vượt trội.",
              ),
              _circleImageItem(
                'assets/images/steam.png',
                "Steam",
                "Winter Sale - Giảm 70%",
                "Săn game khủng, thanh toán siêu tốc.",
              ),
              _circleImageItem(
                'assets/images/spotify.png',
                "Spotify",
                "Spotify Family",
                "Nghe nhạc không quảng cáo, gói gia đình siêu tiết kiệm.",
              ),
              _circleImageItem(
                'assets/images/xanhsm.jpg',
                "Xanh SM",
                "Xanh SM",
                "Đặt xe điện, ưu đãi 25%.",
              ),
              _circleImageItem(
                'assets/images/grab.png',
                "Grab",
                "GrabCar 20%",
                "Di chuyển muôn nơi, giảm 20%.",
              ),
              _circleImageItem(
                'assets/images/gemini.png',
                "Gemini",
                "AI Gemini",
                "Trợ lý AI Gemini Advanced.",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleImageItem(
    String imagePath,
    String label,
    String title,
    String description,
  ) {
    return SizedBox(
      width: 50,
      child: GestureDetector(
        onTap: () {
          _showShoppingItemPopup(context, imagePath, label, title, description);
        },
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShoppingItemPopup(
    BuildContext context,
    String imagePath,
    String label,
    String title,
    String description,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[200]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000DC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Tiếp tục →",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpendingChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Thống kê tiêu dùng ⌄', 'Spending statistics ⌄'),
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
            ),
            Text(
              "8.600.343 VND",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF000DC0),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(30),
                _bar(40),
                _bar(70),
                _bar(50, true),
                _bar(30),
                _bar(40),
                _bar(20),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  [
                        _t('T2', 'Mon'),
                        _t('T3', 'Tue'),
                        _t('T4', 'Wed'),
                        _t('T5', 'Thu'),
                        _t('T6', 'Fri'),
                        _t('T7', 'Sat'),
                        _t('CN', 'Sun'),
                      ]
                      .map(
                        (e) => Text(
                          e,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double height, [bool isToday = false]) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: isToday ? Colors.blue : const Color(0xFF000DC0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Giao dịch gần đây', 'Recent transactions'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          _transactionItem(
            Icons.atm,
            _t('Rút tiền', 'Withdraw'),
            "25/04/2026",
            "- 150.000.000",
            Colors.red,
          ),
          _transactionItem(
            Icons.water_drop,
            _t('Thanh toán hóa đơn nước', 'Water bill payment'),
            "18/04/2026",
            "- 1.342.545",
            Colors.red,
          ),
          _transactionItem(
            Icons.electric_bolt,
            _t('Thanh toán hóa đơn điện', 'Electric bill payment'),
            "05/04/2026",
            "- 854.000",
            Colors.red,
          ),
          _transactionItem(
            Icons.account_balance_wallet,
            _t('Nạp tiền', 'Top up'),
            "22/03/2026",
            "+ 1.500.000",
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _transactionItem(
    IconData icon,
    String title,
    String date,
    String amount,
    Color amountColor,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF000DC0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF000DC0)),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        date,
        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
      ),
      trailing: Text(
        "$amount VND",
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

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
            _pillNavItem(Icons.search, "", 1),
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
