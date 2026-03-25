import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import 'branch_screen.dart';

class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({super.key});

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
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
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF000DC0)),
                  );
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
                final bool hasVipCard = userData['hasVipCard'] == true;
                final String holderName =
                    (userData['fullname'] ??
                            userData['fullName'] ??
                            'CCPBANK USER')
                        .toString()
                        .toUpperCase();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('cards')
                      .snapshots(),
                  builder: (context, cardsSnapshot) {
                    if (cardsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF000DC0),
                        ),
                      );
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
                      docs: docs,
                      preferredId: 'standard',
                      fallbackEnding: '1010',
                    );
                    final _CardData vipCard = _resolveCard(
                      docs: docs,
                      preferredId: 'vip',
                      fallbackEnding: '2020',
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            text: _t(context, 'Thẻ Thường', 'Regular Card'),
                          ),
                          const SizedBox(height: 10),
                          _RegularCardVisual(
                            holderName: holderName,
                            cardNumber: regularCard.maskedNumber,
                          ),
                          const SizedBox(height: 12),
                          _BalanceRow(
                            label: _t(context, 'Số dư:', 'Balance:'),
                            amount: regularCard.balance,
                          ),
                          const SizedBox(height: 10),
                          _TopUpAtBranchButton(
                            title: _t(
                              context,
                              'Nạp tiền tại quầy',
                              'Top up at branch',
                            ),
                          ),
                          if (hasVipCard) ...[
                            const SizedBox(height: 26),
                            _SectionTitle(
                              text: _t(context, 'Thẻ VIP', 'VIP Card'),
                            ),
                            const SizedBox(height: 10),
                            _VipCardVisual(
                              holderName: holderName,
                              cardNumber: vipCard.maskedNumber,
                            ),
                            const SizedBox(height: 12),
                            _BalanceRow(
                              label: _t(context, 'Số dư:', 'Balance:'),
                              amount: vipCard.balance,
                            ),
                            const SizedBox(height: 10),
                            _TopUpAtBranchButton(
                              title: _t(
                                context,
                                'Nạp tiền tại quầy',
                                'Top up at branch',
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  _CardData _resolveCard({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String preferredId,
    required String fallbackEnding,
  }) {
    QueryDocumentSnapshot<Map<String, dynamic>>? selected;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      if (doc.id.toLowerCase() == preferredId.toLowerCase()) {
        selected = doc;
        break;
      }
    }

    selected ??= docs.isNotEmpty ? docs.first : null;

    if (selected == null) {
      return _CardData(
        maskedNumber: '**** **** **** $fallbackEnding',
        balance: 0,
      );
    }

    final Map<String, dynamic> data = selected.data();
    final dynamic rawBalance = data['balance'];
    final dynamic rawCardNumber = data['cardNumber'];

    double balance = 0;
    if (rawBalance is num) {
      balance = rawBalance.toDouble();
    } else if (rawBalance is String) {
      balance = double.tryParse(rawBalance) ?? 0;
    }

    final String raw = (rawCardNumber ?? '').toString();
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final String suffix = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : fallbackEnding;

    return _CardData(maskedNumber: '**** **** **** $suffix', balance: balance);
  }
}

class _CardData {
  const _CardData({required this.maskedNumber, required this.balance});

  final String maskedNumber;
  final double balance;
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

class _RegularCardVisual extends StatelessWidget {
  const _RegularCardVisual({
    required this.holderName,
    required this.cardNumber,
  });

  final String holderName;
  final String cardNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: const Color(0xFF000A6A).withOpacity(0.35),
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
                  color: Colors.white.withOpacity(0.08),
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
                  color: Colors.cyanAccent.withOpacity(0.06),
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
                        'THẺ THƯỜNG',
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
                  Text(
                    cardNumber,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
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
    );
  }
}

class _VipCardVisual extends StatelessWidget {
  const _VipCardVisual({required this.holderName, required this.cardNumber});

  final String holderName;
  final String cardNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: const Color(0xFF7D5A15).withOpacity(0.35),
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
                  color: Colors.white.withOpacity(0.15),
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
                  color: Colors.black.withOpacity(0.16),
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
                        'THẺ VIP',
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
                  Text(
                    cardNumber,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFF6D8),
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    holderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFF6D8).withOpacity(0.92),
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
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BranchScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF000DC0), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.white,
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: const Color(0xFF000DC0),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
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
