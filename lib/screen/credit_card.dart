import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../widget/pressable_scale.dart';
import '../widget/shimmer_box.dart';
import 'branch_screen.dart';

class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({super.key});

  static const double _vipEligibilityThreshold = 200000000;

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  String formatCardNumber(String cardNumber) {
    return CardNumberService.formatCardNumber(cardNumber);
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = UserFirestoreService.instance.currentUserDocId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: const Color(0xFF000DC0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t(context, 'Thẻ tín dụng', 'Credit card'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF111111),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: userId == null || userId.isEmpty
          ? _StatusBox(
              message: _t(
                context,
                'Bạn chưa đăng nhập.',
                'You are not signed in.',
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const _CreditCardSkeleton();
                }

                if (userSnapshot.hasError) {
                  return _StatusBox(
                    message: _t(
                      context,
                      'Không thể tải dữ liệu người dùng.',
                      'Unable to load user data.',
                    ),
                  );
                }

                final Map<String, dynamic> userData =
                    userSnapshot.data?.data() ?? <String, dynamic>{};
                final String holderName =
                    (userData['fullname'] ??
                            userData['fullName'] ??
                            'CCPBANK USER')
                        .toString()
                        .toUpperCase();
                final bool isStandardLocked =
                    userData['is_standard_locked'] == true;
                final bool isVipLocked = userData['is_vip_locked'] == true;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('cards')
                      .snapshots(),
                  builder: (context, cardsSnapshot) {
                    if (cardsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const _CreditCardSkeleton();
                    }

                    if (cardsSnapshot.hasError) {
                      return _StatusBox(
                        message: _t(
                          context,
                          'Không thể tải dữ liệu thẻ.',
                          'Unable to load card data.',
                        ),
                      );
                    }

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs =
                        cardsSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    final _CardData regularCard = _resolveCard(
                      context: context,
                      docs: docs,
                      preferredId: 'standard',
                    );
                    final _CardData vipCard = _resolveCard(
                      context: context,
                      docs: docs,
                      preferredId: 'vip',
                    );

                    final bool vipEligibleByStandardBalance =
                        regularCard.balance >= _vipEligibilityThreshold;

                    final bool showStandardCard = !isStandardLocked;
                    final bool showVipCard =
                        vipEligibleByStandardBalance && !isVipLocked;

                    if (!showStandardCard && !showVipCard) {
                      return _StatusBox(
                        message: _t(
                          context,
                          'Hiện chưa có thẻ khả dụng.',
                          'No available cards at the moment.',
                        ),
                      );
                    }

                    final List<Widget> cardSections = <Widget>[];
                    int staggeredIndex = 0;

                    void addEntry(Widget child) {
                      cardSections.add(
                        _StaggeredEntry(index: staggeredIndex, child: child),
                      );
                      staggeredIndex += 1;
                    }

                    void addGap(double height) {
                      cardSections.add(SizedBox(height: height));
                    }

                    if (showStandardCard) {
                      addEntry(
                        _SectionTitle(
                          text: _t(context, 'Thẻ Thường', 'Regular Card'),
                        ),
                      );
                      addGap(10);
                      addEntry(
                        _RegularCardVisual(
                          holderName: holderName,
                          cardNumber: regularCard.cardNumberDisplay,
                          isLocked: false,
                          cardTypeLabel: _t(
                            context,
                            'THẺ THƯỜNG',
                            'REGULAR CARD',
                          ),
                        ),
                      );
                      addGap(12);
                      addEntry(
                        _BalanceRow(
                          label: _t(context, 'Số dư:', 'Balance:'),
                          amount: regularCard.balance,
                        ),
                      );
                      addGap(10);
                      addEntry(
                        _TopUpAtBranchButton(
                          title: _t(
                            context,
                            'Nạp tiền tại quầy',
                            'Top up at branch',
                          ),
                        ),
                      );
                      if (!vipEligibleByStandardBalance) {
                        addGap(10);
                        addEntry(
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F8FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDCE6FF),
                              ),
                            ),
                            child: Text(
                              AppText.text(context, 'vip_condition_msg'),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    if (showVipCard) {
                      final String cardType = 'VIP';
                      if (showStandardCard) {
                        addGap(20);
                        addEntry(
                          _SmallHintTitle(
                            text: _t(
                              context,
                              'Thẻ VIP của bạn',
                              'Your VIP card',
                            ),
                          ),
                        );
                        addGap(10);
                      }

                      addEntry(
                        _SectionTitle(text: _t(context, 'Thẻ VIP', 'VIP Card')),
                      );
                      addGap(10);
                      addEntry(
                        _VipCardVisual(
                          holderName: holderName,
                          cardNumber: vipCard.cardNumberDisplay,
                          isLocked: false,
                          cardTypeLabel: _t(context, 'THẺ VIP', 'VIP CARD'),
                        ),
                      );
                      addGap(12);
                      addEntry(
                        _BalanceRow(
                          label: _t(context, 'Số dư:', 'Balance:'),
                          amount: vipCard.balance,
                        ),
                      );
                      addGap(10);
                      addEntry(
                        _TopUpAtBranchButton(
                          title: _t(
                            context,
                            'Nạp tiền tại quầy',
                            'Top up at branch',
                          ),
                        ),
                      );
                      if (cardType == 'VIP') {
                        addGap(10);
                        addEntry(_VipPrivilegesBox(t: _t));
                      }
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: cardSections,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  _CardData _resolveCard({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String preferredId,
  }) {
    QueryDocumentSnapshot<Map<String, dynamic>>? selected;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      if (doc.id.toLowerCase() == preferredId.toLowerCase()) {
        selected = doc;
        break;
      }
    }

    if (selected == null) {
      return _CardData(
        balance: 0,
        cardNumberDisplay: AppText.text(context, 'loading'),
      );
    }

    final Map<String, dynamic> data = selected.data();
    final dynamic rawBalance = data['balance'];
    final String rawCard = CardNumberService.readStoredCardNumber(data);
    final String cardDisplay = rawCard.isEmpty
        ? AppText.text(context, 'loading')
        : formatCardNumber(rawCard);

    double balance = 0;
    if (rawBalance is num) {
      balance = rawBalance.toDouble();
    } else if (rawBalance is String) {
      balance = double.tryParse(rawBalance) ?? 0;
    }

    return _CardData(balance: balance, cardNumberDisplay: cardDisplay);
  }
}

class _CardData {
  const _CardData({required this.balance, required this.cardNumberDisplay});

  final double balance;
  final String cardNumberDisplay;
}

class _VipPrivilegesBox extends StatelessWidget {
  const _VipPrivilegesBox({required this.t});

  final String Function(BuildContext context, String vi, String en) t;

  @override
  Widget build(BuildContext context) {
    final List<String> items = <String>[
      AppText.text(context, 'vip_perk_interest'),
      AppText.text(context, 'vip_perk_fee'),
      AppText.text(context, 'vip_perk_support'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E1FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppText.text(context, 'vip_perks_title'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C2A6E),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF334155),
                      ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: const Color(0xFF161616),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SmallHintTitle extends StatelessWidget {
  const _SmallHintTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: const Color(0xFF5B647F),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RegularCardVisual extends StatelessWidget {
  const _RegularCardVisual({
    required this.holderName,
    required this.cardNumber,
    required this.isLocked,
    required this.cardTypeLabel,
  });

  final String holderName;
  final String cardNumber;
  final bool isLocked;
  final String cardTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C248B), Color(0xFF0A0F58)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000A6A).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -58,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -56,
                  bottom: -84,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cardTypeLabel,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'CCPBANK',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 48,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF9D886), Color(0xFFE1B95A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cardNumber,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        holderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isLocked) const _CardLockOverlay(),
      ],
    );
  }
}

class _VipCardVisual extends StatelessWidget {
  const _VipCardVisual({
    required this.holderName,
    required this.cardNumber,
    required this.isLocked,
    required this.cardTypeLabel,
  });

  final String holderName;
  final String cardNumber;
  final bool isLocked;
  final String cardTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E3520), Color(0xFFB68A2A), Color(0xFF2C2414)],
              stops: [0.0, 0.48, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D5A15).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  top: -32,
                  right: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Positioned(
                  left: -24,
                  bottom: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cardTypeLabel,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFF6D8),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'CCPBANK PREMIUM',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFF6D8),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 48,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF9ECB9), Color(0xFFD4B469)],
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cardNumber,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFF6D8),
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        holderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(
                            0xFFFFF6D8,
                          ).withValues(alpha: 0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isLocked) const _CardLockOverlay(),
      ],
    );
  }
}

class _CardLockOverlay extends StatelessWidget {
  const _CardLockOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_rounded, size: 58, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  AppText.text(context, 'status_locked').toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatter = NumberFormat('#,##0', 'en_US');
    final String formatted = formatter.format(amount);

    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFF5B647F),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$formatted VND',
          style: GoogleFonts.poppins(
            color: const Color(0xFF000DC0),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _TopUpAtBranchButton extends StatelessWidget {
  const _TopUpAtBranchButton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: PressableScale(
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFF000DC0).withValues(alpha: 0.12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BranchMapScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF000DC0), width: 1.4),
            color: Colors.white,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF000DC0),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int delayMs = 70 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 16),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }
}

class _CreditCardSkeleton extends StatelessWidget {
  const _CreditCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: const [
        ShimmerBox(width: 140, height: 24, radius: 8),
        SizedBox(height: 12),
        ShimmerBox(width: double.infinity, height: 210, radius: 22),
        SizedBox(height: 14),
        ShimmerBox(width: 180, height: 24, radius: 8),
        SizedBox(height: 12),
        ShimmerBox(width: double.infinity, height: 48, radius: 14),
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8DEEE)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF5A647E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
