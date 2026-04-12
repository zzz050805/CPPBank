import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import 'main_tab_shell.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      home: const SuccessTransactionScreen(),
    );
  }
}

class SuccessTransactionScreen extends StatefulWidget {
  const SuccessTransactionScreen({
    super.key,
    this.receiverName = '',
    this.receiverCardNumber = '',
    this.bankName = '',
    this.transactionCode = '',
    this.transferContent = '',
    this.transferAmount,
    this.transferredAt,
  });

  final String receiverName;
  final String receiverCardNumber;
  final String bankName;
  final String transactionCode;
  final String transferContent;
  final int? transferAmount;
  final DateTime? transferredAt;

  @override
  State<SuccessTransactionScreen> createState() =>
      _SuccessTransactionScreenState();
}

class _SuccessTransactionScreenState extends State<SuccessTransactionScreen> {
  bool _redirected = false;

  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF6F8FF);

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _unknownLabel() => _t('Không xác định', 'Unknown');

  String _valueOrUnknown(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _unknownLabel();
    }
    return trimmed;
  }

  String _formatAmount(int? amount) {
    if (amount == null || amount <= 0) {
      return _unknownLabel();
    }
    return '${NumberFormat('#,###', 'en_US').format(amount)} VND';
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return _unknownLabel();
    }
    return DateFormat('dd/MM/yyyy, HH:mm:ss').format(value);
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

  String _formatReceiverCard(String raw) {
    final String formatted = CardNumberService.formatCardNumber(raw);
    if (formatted.isEmpty) {
      return _unknownLabel();
    }
    return formatted;
  }

  void _continueTransfer() {
    if (!mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (_) => false,
    );
  }

  void _goHome() {
    if (!mounted || _redirected) {
      return;
    }
    _redirected = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String amountText = _formatAmount(widget.transferAmount);
    final String receiverName = _valueOrUnknown(widget.receiverName);
    final String receiverBank = _valueOrUnknown(widget.bankName);
    final String receiverCard = _formatReceiverCard(widget.receiverCardNumber);
    final String transactionCode = _valueOrUnknown(widget.transactionCode);
    final String transferredAtText = _formatTimestamp(widget.transferredAt);
    final String transferContent = widget.transferContent.trim().isEmpty
        ? _t('CHUYỂN TIỀN', 'TRANSFER')
        : widget.transferContent.trim();

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B29CA), Color(0xFF000DC0)],
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
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              'Bạn đã chuyển tiền thành công',
                              'Transfer completed successfully',
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            amountText,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? _t('Không tìm thấy user', 'User not found')
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : _t('Khách hàng', 'Customer'));

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Builder(
                            builder: (BuildContext context) {
                              final String uid = _resolveUid();
                              if (uid.isEmpty) {
                                return Column(
                                  children: [
                                    _buildInfoRow(
                                      _t('Từ', 'From'),
                                      '${senderName.toUpperCase()}\n${_unknownLabel()}',
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoRow(
                                      _t('Đến', 'To'),
                                      '$receiverName\n$receiverBank\n$receiverCard',
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoRow(
                                      _t('Chuyển lúc', 'Transferred at'),
                                      transferredAtText,
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoRow(
                                      _t('Phí', 'Fee'),
                                      _t('Miễn phí', 'Free'),
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoRow(
                                      _t('Mã giao dịch', 'Transaction ID'),
                                      transactionCode,
                                    ),
                                  ],
                                );
                              }

                              return StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .snapshots(),
                                builder: (context, userSnapshot) {
                                  final Map<String, dynamic> userData =
                                      userSnapshot.data?.data() ??
                                      <String, dynamic>{};
                                  final String rawSenderCard =
                                      CardNumberService.readStoredCardNumber(
                                        userData,
                                      );
                                  final String senderCard =
                                      CardNumberService.formatCardNumber(
                                        rawSenderCard,
                                      );
                                  final String senderCardDisplay =
                                      senderCard.isEmpty
                                      ? _unknownLabel()
                                      : senderCard;

                                  return Column(
                                    children: [
                                      _buildInfoRow(
                                        _t('Từ', 'From'),
                                        '${senderName.toUpperCase()}\n$senderCardDisplay',
                                      ),
                                      const Divider(height: 18),
                                      _buildInfoRow(
                                        _t('Đến', 'To'),
                                        '$receiverName\n$receiverBank\n$receiverCard',
                                      ),
                                      const Divider(height: 18),
                                      _buildInfoRow(
                                        _t('Chuyển lúc', 'Transferred at'),
                                        transferredAtText,
                                      ),
                                      const Divider(height: 18),
                                      _buildInfoRow(
                                        _t('Phí', 'Fee'),
                                        _t('Miễn phí', 'Free'),
                                      ),
                                      const Divider(height: 18),
                                      _buildInfoRow(
                                        _t('Mã giao dịch', 'Transaction ID'),
                                        transactionCode,
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<UserProfileData?>(
                      stream: UserFirestoreService.instance
                          .currentUserProfileStream(),
                      initialData: UserFirestoreService.instance.latestProfile,
                      builder: (context, snapshot) {
                        final UserProfileData? profile =
                            snapshot.data ??
                            UserFirestoreService.instance.latestProfile;
                        final String senderName = snapshot.hasError
                            ? _t('Không tìm thấy user', 'User not found')
                            : ((profile?.fullname.isNotEmpty == true)
                                  ? profile!.fullname
                                  : _t('Khách hàng', 'Customer'));

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('Nội dung', 'Content'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF8A91A6),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                transferContent,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF23283A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _continueTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _t('Chuyển tiếp', 'Continue transfer'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _goHome,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF2FB),
                          side: const BorderSide(color: Color(0xFFDDE3F1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _t('Đóng', 'Close'),
                          style: GoogleFonts.poppins(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF8A91A6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF24293A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
