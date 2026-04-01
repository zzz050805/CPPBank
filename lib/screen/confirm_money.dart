import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'smart_otp_transfer_pin_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Thiết lập font Poppins làm mặc định toàn app
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const ConfirmTransferScreen(),
    );
  }
}

class ConfirmTransferScreen extends StatelessWidget {
  const ConfirmTransferScreen({
    super.key,
    this.amountText = '',
    this.transferContent = '',
    this.recipientAccountNumber = '',
    this.recipientAccountName = 'TRAN THANH B',
    this.recipientBankName = 'MC-BANK',
    this.recipientBankId = 'mc_bank',
  });

  final String amountText;
  final String transferContent;
  final String recipientAccountNumber;
  final String recipientAccountName;
  final String recipientBankName;
  final String recipientBankId;

  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF6F8FF);

  String _t(BuildContext context, String vi, String en) =>
      AppText.tr(context, vi, en);

  String _formatAmount(String rawAmount) {
    final String digits = rawAmount.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '0 VND';
    }
    final int value = int.tryParse(digits) ?? 0;
    return '${NumberFormat('#,###', 'en_US').format(value)} VND';
  }

  String _safeRecipientAccount() {
    final String value = recipientAccountNumber.trim();
    if (value.isEmpty) {
      return '312 555 867';
    }
    return value;
  }

  String _safeRecipientName() {
    final String value = recipientAccountName.trim();
    if (value.isEmpty) {
      return 'TRAN THANH B';
    }
    return value.toUpperCase();
  }

  String _safeRecipientBank() {
    final String value = recipientBankName.trim();
    if (value.isEmpty) {
      return 'MC-BANK';
    }
    return value;
  }

  String _recipientInitials() {
    final List<String> parts = _safeRecipientName()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String displayAmount = _formatAmount(amountText);
    final String displayContent = transferContent.trim().isEmpty
        ? _t(context, 'CHUYỂN TIỀN', 'TRANSFER')
        : transferContent.trim();
    final String displayRecipientAccount = _safeRecipientAccount();
    final String displayRecipientName = _safeRecipientName();
    final String displayRecipientBank = _safeRecipientBank();
    final String resolvedBankId = recipientBankId.trim().isEmpty
        ? displayRecipientBank.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
        : recipientBankId.trim();

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: CCPAppBar(
        title: _t(context, 'Xác nhận chuyển tiền', 'Confirm transfer'),
        backgroundColor: pageBackground,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              _t(context, 'Hủy', 'Cancel'),
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D2BCB), Color(0xFF000DC0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000DC0),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  context,
                                  'Số tiền chuyển',
                                  'Transfer amount',
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                displayAmount,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _t(
                                  context,
                                  'Đã nhập: $displayAmount',
                                  'Entered: $displayAmount',
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          context,
                          _t(context, 'Từ tài khoản', 'From account'),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<UserProfileData?>(
                          stream: UserFirestoreService.instance
                              .currentUserProfileStream(),
                          initialData:
                              UserFirestoreService.instance.latestProfile,
                          builder: (context, snapshot) {
                            final UserProfileData? profile =
                                snapshot.data ??
                                UserFirestoreService.instance.latestProfile;
                            final String senderName = snapshot.hasError
                                ? _t(
                                    context,
                                    'Không tìm thấy user',
                                    'User not found',
                                  )
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t(context, 'Khách hàng', 'Customer'));

                            return _buildAccountCard(
                              name: senderName.toUpperCase(),
                              id: '123 568 567 456',
                              isSource: true,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildSectionLabel(
                          context,
                          _t(context, 'Đến tài khoản', 'To account'),
                        ),
                        const SizedBox(height: 10),
                        _buildAccountCard(
                          name: displayRecipientName,
                          bank: displayRecipientBank,
                          id: displayRecipientAccount,
                          isSource: false,
                        ),
                        const SizedBox(height: 16),
                        _buildSectionLabel(
                          context,
                          _t(context, 'Nội dung', 'Content'),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFBFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E7F2)),
                          ),
                          child: Text(
                            displayContent,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF23283A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E9F5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: Color(0xFF68708A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _t(
                                    context,
                                    'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận.',
                                    'Please verify details carefully before confirming.',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF636B83),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  final String? uid =
                      UserFirestoreService.instance.currentUserDocId ??
                      FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null || uid.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t(
                            context,
                            'Không tìm thấy tài khoản để xác thực Smart OTP.',
                            'Account not found for Smart OTP verification.',
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SmartOtpTransferPinScreen(
                        uid: uid,
                        accountNumber: displayRecipientAccount,
                        accountName: displayRecipientName,
                        bankName: displayRecipientBank,
                        bankId: resolvedBankId,
                        initials: _recipientInitials(),
                        amountText: amountText,
                        transferContent: displayContent,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _t(context, 'Xác nhận', 'Confirm'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: const Color(0xFF8B92A6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAccountCard({
    required String name,
    required String id,
    String? bank,
    required bool isSource,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSource ? const Color(0xFFFAFBFF) : primaryBlue,
        borderRadius: BorderRadius.circular(14),
        border: isSource ? Border.all(color: const Color(0xFFE2E7F2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              color: isSource ? const Color(0xFF252A3A) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (bank != null)
            Text(
              bank,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: isSource ? const Color(0xFF7A8195) : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                id,
                style: GoogleFonts.poppins(
                  color: isSource ? const Color(0xFF626A82) : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
