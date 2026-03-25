import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CreditCardScreen(),
    );
  }
}

class CreditCardScreen extends StatefulWidget {
  const CreditCardScreen({super.key});

  @override
  State<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _card1Fade;
  late final Animation<Offset> _card1Slide;
  late final Animation<double> _card2Fade;
  late final Animation<Offset> _card2Slide;
  late final Animation<double> _addButtonFade;
  late final Animation<Offset> _addButtonSlide;
  late final Animation<double> _statsFade;
  late final Animation<Offset> _statsSlide;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _card1Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _card1Slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
          ),
        );

    _card2Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
    );
    _card2Slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _addButtonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
    );
    _addButtonSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 0.78, curve: Curves.easeOutCubic),
          ),
        );

    _statsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );
    _statsSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedSection({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CCPAppBar(title: _t('Thẻ tín dụng', 'Credit card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Thẻ xanh
            _buildAnimatedSection(
              fade: _card1Fade,
              slide: _card1Slide,
              child: const CreditCardWidget(
                cardColor: Color(0xFF1A1A75),
                accentColor: Color(0xFF42A5F5),
                textColor: Colors.white,
                cardType: "CREDIT CARD",
              ),
            ),
            const SizedBox(height: 15),
            // Thẻ đen VIP
            _buildAnimatedSection(
              fade: _card2Fade,
              slide: _card2Slide,
              child: const CreditCardWidget(
                cardColor: Color(0xFF333333),
                accentColor: Color(0xFFE0E0E0),
                textColor: Color(0xFFD4AF37), // Màu vàng gold
                cardType: "CREDIT CARD VIP",
              ),
            ),
            const SizedBox(height: 20),

            // Nút Thêm thẻ mới với viền đứt đoạn
            _buildAnimatedSection(
              fade: _addButtonFade,
              slide: _addButtonSlide,
              child: AddNewCardButton(
                title: _t('Thêm thẻ mới', 'Add new card'),
              ),
            ),

            const SizedBox(height: 25),

            // Phần Thống kê
            _buildAnimatedSection(
              fade: _statsFade,
              slide: _statsSlide,
              child: StatisticsWidget(
                title: _t('Thống kê theo tuần', 'Weekly statistics'),
                mainLegend: _t('Mua sắm-Tiêu dùng', 'Shopping-Spending'),
                subLegend: _t('Giải trí', 'Entertainment'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET THẺ TÍN DỤNG ---
class CreditCardWidget extends StatelessWidget {
  final Color cardColor;
  final Color accentColor;
  final Color textColor;
  final String cardType;

  const CreditCardWidget({
    super.key,
    required this.cardColor,
    required this.accentColor,
    required this.textColor,
    required this.cardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Hiệu ứng vòng tròn trang trí
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: accentColor.withOpacity(0.4),
              ),
            ),
            Positioned(
              right: 20,
              top: -20,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: accentColor.withOpacity(0.6),
              ),
            ),
            // Nội dung trên thẻ
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cardType,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "CCP BANK",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Chip thẻ
                  Container(
                    width: 45,
                    height: 35,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<UserProfileData?>(
                    stream: UserFirestoreService.instance
                        .currentUserProfileStream(),
                    builder: (context, snapshot) {
                      final String fullname = snapshot.hasError
                          ? AppText.tr(
                              context,
                              'Không tìm thấy user',
                              'User not found',
                            )
                          : (snapshot.data?.fullname ?? '...');

                      return Text(
                        fullname.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "123 568 576 456",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      // Logo Mastercard (giả lập bằng 2 hình tròn)
                      Stack(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            left: 15,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET NÚT THÊM THẺ MỚI ---
class AddNewCardButton extends StatelessWidget {
  const AddNewCardButton({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        // Giả lập viền đứt đoạn bằng Border thông thường (Flutter thuần không có dashed border mặc định)
        border: Border.all(
          color: Colors.blue.shade900,
          width: 1,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.blue.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// --- WIDGET THỐNG KÊ ---
class StatisticsWidget extends StatelessWidget {
  const StatisticsWidget({
    super.key,
    required this.title,
    required this.mainLegend,
    required this.subLegend,
  });

  final String title;
  final String mainLegend;
  final String subLegend;

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Icon(Icons.keyboard_arrow_up, size: 20),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "8.600.343 VND",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A75),
            ),
          ),
          const SizedBox(height: 15),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegend(const Color(0xFF1A1A75), mainLegend),
              const SizedBox(width: 15),
              _buildLegend(const Color(0xFF42A5F5), subLegend),
            ],
          ),
          const SizedBox(height: 20),
          // Biểu đồ
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(_t(context, 'T2', 'Mon'), 0.4, 0.2),
                _buildBar(_t(context, 'T3', 'Tue'), 0.6, 0.3),
                _buildBar(_t(context, 'T4', 'Wed'), 0.8, 0.4),
                _buildBar(_t(context, 'T5', 'Thu'), 0.5, 0.3, isSelected: true),
                _buildBar(_t(context, 'T6', 'Fri'), 0.4, 0.2),
                _buildBar(_t(context, 'T7', 'Sat'), 0.7, 0.3),
                _buildBar(_t(context, 'CN', 'Sun'), 0.5, 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildBar(
    String day,
    double height1,
    double height2, {
    bool isSelected = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 8,
              height: 100 * height1,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A75),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              width: 8,
              height: 100 * height2,
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          day,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isSelected ? const Color(0xFF1A1A75) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
