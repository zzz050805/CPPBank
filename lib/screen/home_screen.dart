import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import '../data/notification_firestore_service.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/pressable_scale.dart';
import '../widget/shimmer_box.dart';
import 'search_screen.dart';
import 'setting_screen.dart';
import 'transfer_money.dart';
import 'phone_recharge.dart';
import 'bill.dart';
import 'QR.dart';
import 'credit_card.dart';
import 'chat_placeholder_screen.dart';
import 'notification.dart';
import 'withdraw_money.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;
  bool _isBalanceVisible = false;
  int _currentBannerIndex = 0;
  late final Stream<UserProfileData?> _profileStream;
  double _lastKnownTotalBalance = 0;
  bool _hasLoadedBalance = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _formatCurrency(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
  }

  void _pushPremium(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _replacePremium(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  bool _parseHasVipCard(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String _resolveUid() {
    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromProfile =
        UserFirestoreService.instance.latestProfile?.uid;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  num _readNumericValue(dynamic raw) {
    if (raw is num) {
      return raw;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return 0;
      }
      final num? direct = num.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }
      final String digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isEmpty) {
        return 0;
      }
      return num.tryParse(digitsOnly) ?? 0;
    }

    return 0;
  }

  Widget _buildNotificationBell() {
    final String uid = _resolveUid();

    if (uid.isEmpty) {
      return _buildNotificationBellWithCount(0);
    }

    return StreamBuilder<int>(
      stream: NotificationFirestoreService.instance.unreadCountStream(uid),
      builder: (context, snapshot) {
        final int unreadCount = snapshot.data ?? 0;
        return _buildNotificationBellWithCount(unreadCount);
      },
    );
  }

  Widget _buildNotificationBellWithCount(int unreadCount) {
    final String badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return PressableScale(
      onTap: () async {
        final String uid = _resolveUid();
        if (uid.isNotEmpty) {
          await NotificationFirestoreService.instance.markAllAsRead(uid);
        }
        if (!mounted) {
          return;
        }
        _pushPremium(const NotificationScreen());
      },
      borderRadius: BorderRadius.circular(30),
      splashColor: Colors.white24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white, size: 32),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeText,
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
    );
  }

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
      body: widget.showBottomNav
          ? Stack(children: [_buildSlivers(), _buildPillBottomNav()])
          : _buildSlivers(),
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
                          stream: _profileStream,
                          initialData:
                              UserFirestoreService.instance.latestProfile,
                          builder: (context, snapshot) {
                            final UserProfileData? profile =
                                snapshot.data ??
                                UserFirestoreService.instance.latestProfile;

                            if (!snapshot.hasError &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                profile == null) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: ShimmerBox(
                                  width: 140,
                                  height: 22,
                                  radius: 8,
                                ),
                              );
                            }

                            final String name = snapshot.hasError
                                ? _t('Không tìm thấy user', 'User not found')
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t('Khách hàng', 'Customer'));

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
                    _buildNotificationBell(),
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
                            _t(
                              'Tổng số dư khả dụng',
                              'Total available balance',
                            ),
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
                      _buildRealtimeTotalBalance(),
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

  Widget _buildRealtimeTotalBalance() {
    return StreamBuilder<UserProfileData?>(
      stream: _profileStream,
      initialData: UserFirestoreService.instance.latestProfile,
      builder: (context, profileSnapshot) {
        final UserProfileData? profile =
            profileSnapshot.data ?? UserFirestoreService.instance.latestProfile;
        final String? resolvedUserId = profile?.uid;

        if (resolvedUserId == null || resolvedUserId.isEmpty) {
          return _buildHiddenBalanceText();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final bool hasVipCard = _parseHasVipCard(
              userSnapshot.data?.data()?['hasVipCard'],
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(resolvedUserId)
                  .collection('cards')
                  .snapshots(),
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.hasData) {
                  double standardBalance = 0;
                  double vipBalance = 0;

                  for (final doc in cardsSnapshot.data!.docs) {
                    final Map<String, dynamic> data = doc.data();
                    final dynamic rawBalance = data['balance'];

                    double balance = 0;
                    if (rawBalance is num) {
                      balance = rawBalance.toDouble();
                    } else if (rawBalance is String) {
                      balance = double.tryParse(rawBalance) ?? 0;
                    }

                    final String docId = doc.id.toLowerCase();
                    if (docId == 'standard') {
                      standardBalance = balance;
                    } else if (docId == 'vip') {
                      vipBalance = balance;
                    }
                  }

                  _lastKnownTotalBalance = hasVipCard
                      ? standardBalance + vipBalance
                      : standardBalance;
                  _hasLoadedBalance = true;
                }

                if (cardsSnapshot.connectionState == ConnectionState.waiting &&
                    !_hasLoadedBalance) {
                  return _buildBalanceSkeleton();
                }

                if (cardsSnapshot.hasError || userSnapshot.hasError) {
                  if (_hasLoadedBalance) {
                    return _buildBalanceText(_lastKnownTotalBalance);
                  }

                  final String error =
                      (cardsSnapshot.error ?? userSnapshot.error)
                          .toString()
                          .toLowerCase();
                  final bool networkError =
                      error.contains('unavailable') ||
                      error.contains('network') ||
                      error.contains('failed-host-lookup');

                  return Text(
                    networkError
                        ? _t('Mất kết nối mạng', 'No network connection')
                        : _t('Không tải được số dư', 'Unable to load balance'),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                if (!_isBalanceVisible) {
                  return _buildHiddenBalanceText();
                }

                return _buildBalanceText(_lastKnownTotalBalance);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceText(double totalBalance) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: totalBalance),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${_formatCurrency(animatedValue)} ',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'VND',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHiddenBalanceText() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '*** *** ',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'VND',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSkeleton() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerBox(width: 150, height: 28, radius: 8),
        SizedBox(width: 8),
        ShimmerBox(width: 34, height: 16, radius: 6),
      ],
    );
  }

  // --- CÁC PHẦN DƯỚI GIỮ NGUYÊN ---
  Widget _buildActionGrid() {
    final List<_ActionItemData> items = <_ActionItemData>[
      _ActionItemData(
        icon: Icons.account_balance_wallet,
        color: Colors.purple,
        title: _t('Chuyển tiền', 'Transfer'),
        onTap: () => _pushPremium(const TransferMoneyScreen()),
      ),
      _ActionItemData(
        icon: Icons.receipt_long,
        color: Colors.green,
        title: _t('Thanh toán\nhóa đơn', 'Bill\npayment'),
        onTap: () => _pushPremium(const BillScreen()),
      ),
      _ActionItemData(
        icon: Icons.atm,
        color: Colors.blue,
        title: _t('Rút tiền', 'Withdraw'),
        onTap: () => _pushPremium(const WithdrawATMPage()),
      ),
      _ActionItemData(
        icon: Icons.qr_code_scanner,
        color: Colors.pink,
        title: _t('Quét QR', 'Scan QR'),
        onTap: () => _pushPremium(const QrScreen()),
      ),
      _ActionItemData(
        icon: Icons.phone_android,
        color: Colors.orange,
        title: _t('Nạp tiền\nđiện thoại', 'Phone\nTop up'),
        onTap: () => _pushPremium(const PhoneRechargeScreen()),
      ),
      _ActionItemData(
        icon: Icons.credit_card,
        color: Colors.deepOrange,
        title: _t('Thẻ tín dụng', 'Credit card'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreditCardScreen()),
          );
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.25,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
        ),
        itemBuilder: (context, index) {
          final _ActionItemData item = items[index];
          return _actionItem(
            item.icon,
            item.color,
            item.title,
            onTap: item.onTap,
          );
        },
      ),
    );
  }

  Widget _actionItem(
    IconData icon,
    Color color,
    String title, {
    VoidCallback? onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: const Color(0xFF000DC0).withOpacity(0.12),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
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
                _t(
                  'Liên kết ví CCP - Mua sắm Shopee thả ga',
                  'Link CCP wallet - Shop freely on Shopee',
                ),
                _t(
                  'Trải nghiệm thanh toán 1 chạm siêu tốc, không cần nhập mã OTP cho các giao dịch dưới 2.000.000đ.\n• Ưu đãi độc quyền: Tặng ngay Voucher giảm 50K cho đơn hàng đầu tiên (áp dụng khi nhập mã CCP50).\n• Quyền lợi: Hoàn tiền 2% (tối đa 100K/tháng) cho mọi giao dịch thanh toán hóa đơn, nạp điện thoại qua ShopeePay bằng nguồn tiền CCPCredit. Miễn phí thường niên năm đầu tiên.',
                  'Enjoy ultra-fast one-tap payments without OTP for transactions under 2,000,000 VND.\n• Exclusive offer: Get a 50K voucher on your first order (use code CCP50).\n• Benefits: 2% cashback (up to 100K/month) for bill payments and phone top-ups via ShopeePay using CCPCredit funds. First-year annual fee waived.',
                ),
              ),
              _circleImageItem(
                'assets/images/riot.png',
                "Riot Games",
                _t(
                  'Nạp thẻ Riot Games - Nhận VP & RP tức thì',
                  'Riot top-up - Get VP & RP instantly',
                ),
                _t(
                  'Kênh nạp thẻ chính thức, không qua trung gian.\nĐảm bảo 100% an toàn cho valorant và LMHT.',
                  'Official top-up channel with no middleman.\n100% safe for Valorant and League of Legends.',
                ),
              ),
              _circleImageItem(
                'assets/images/netflix.png',
                "Netflix",
                "Premium Family",
                _t(
                  'Đăng ký Premium, quản lý gia hạn gói gia đình dễ dàng.',
                  'Subscribe to Premium and manage family-plan renewals easily.',
                ),
              ),
              _circleImageItem(
                'assets/images/itunes.png',
                "Apple Music",
                _t('Trải nghiệm 3 tháng free', 'Try 3 months free'),
                _t(
                  'Nghe nhạc chất lượng cao, miễn phí 3 tháng đầu.',
                  'Enjoy high-quality music with the first 3 months free.',
                ),
              ),
              _circleImageItem(
                'assets/images/chatgpt.png',
                "Chat GPT",
                _t('Nâng cấp Plus', 'Upgrade to Plus'),
                _t(
                  'Tận hưởng sức mạnh của AI, các tính năng vượt trội.',
                  'Unlock the full AI experience with advanced features.',
                ),
              ),
              _circleImageItem(
                'assets/images/steam.png',
                "Steam",
                _t('Winter Sale - Giảm 70%', 'Winter Sale - Up to 70% off'),
                _t(
                  'Săn game khủng, thanh toán siêu tốc.',
                  'Grab top games with ultra-fast checkout.',
                ),
              ),
              _circleImageItem(
                'assets/images/spotify.png',
                "Spotify",
                "Spotify Family",
                _t(
                  'Nghe nhạc không quảng cáo, gói gia đình siêu tiết kiệm.',
                  'Ad-free listening with a cost-saving family plan.',
                ),
              ),
              _circleImageItem(
                'assets/images/xanhsm.jpg',
                "Xanh SM",
                "Xanh SM",
                _t('Đặt xe điện, ưu đãi 25%.', 'Book EV rides with 25% off.'),
              ),
              _circleImageItem(
                'assets/images/grab.png',
                "Grab",
                "GrabCar 20%",
                _t(
                  'Di chuyển muôn nơi, giảm 20%.',
                  'Travel anywhere with 20% off.',
                ),
              ),
              _circleImageItem(
                'assets/images/gemini.png',
                "Gemini",
                "AI Gemini",
                _t(
                  'Trợ lý AI Gemini Advanced.',
                  'Gemini Advanced AI assistant.',
                ),
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
                    _t('Tiếp tục →', 'Continue →'),
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
    final String uid = _resolveUid();

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
          if (uid.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _t('Bạn chưa đăng nhập.', 'You are not logged in.'),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('phone_recharge')
                  .orderBy('createdAt', descending: true)
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _t(
                        'Không tải được lịch sử giao dịch.',
                        'Unable to load transaction history.',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _t('Chưa có giao dịch nào.', 'No transactions yet.'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final Map<String, dynamic> data = doc.data();
                    final num amountValue = _readNumericValue(data['amount']);
                    final String provider = (data['provider'] ?? '')
                        .toString()
                        .trim();
                    final String phoneNumber = (data['phoneNumber'] ?? '')
                        .toString()
                        .trim();
                    final Timestamp? createdAtTs =
                        data['createdAt'] is Timestamp
                        ? data['createdAt'] as Timestamp
                        : null;
                    final String dateText = createdAtTs != null
                        ? DateFormat('dd/MM/yyyy').format(createdAtTs.toDate())
                        : '--/--/----';

                    final String title = provider.isNotEmpty
                        ? '${_t('Nạp ĐT', 'Top-up')} $provider'
                        : _t('Nạp điện thoại', 'Phone top-up');
                    final String subtitle = phoneNumber.isNotEmpty
                        ? '$phoneNumber • $dateText'
                        : dateText;
                    final String amount =
                        '- ${_formatCurrency(amountValue.toDouble())}';

                    return _transactionItem(
                      Icons.phone_android,
                      title,
                      subtitle,
                      amount,
                      Colors.red,
                    );
                  }).toList(),
                );
              },
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
    return PressableScale(
      onTap: () {
        if (index == 0) {
          _replacePremium(const HomeScreen());
        } else if (index == 1) {
          _replacePremium(const SearchScreen());
        } else if (index == 2) {
          _replacePremium(const ChatPlaceholderScreen());
        } else if (index == 3) {
          _replacePremium(const SettingScreen());
        }
      },
      borderRadius: BorderRadius.circular(20),
      splashColor: const Color(0xFF000DC0).withOpacity(0.12),
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

class _ActionItemData {
  const _ActionItemData({
    required this.icon,
    required this.color,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onTap;
}
