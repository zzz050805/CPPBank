import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../widget/ccp_app_bar.dart';
import 'package:doan_nganhang/screen/enter_money.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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

String _deriveInitials(String fullName) {
  final List<String> parts = fullName
      .trim()
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

Map<String, dynamic> _recipientPayload({
  required String accountNumber,
  required String accountName,
  required String bankName,
  required String bankId,
  required String initials,
}) {
  return <String, dynamic>{
    'card_number': accountNumber,
    'cardNumber': accountNumber,
    'accountNumber': accountNumber,
    'accountName': accountName,
    'bankName': bankName,
    'bankId': bankId,
    'initials': initials,
    'timestamp': FieldValue.serverTimestamp(),
  };
}

Future<void> saveRecipientToFirestore({
  required String accountNumber,
  required String accountName,
  required String bankName,
  required String bankId,
  String? initials,
}) async {
  await _saveRecipientToFirestore(
    accountNumber: accountNumber,
    accountName: accountName,
    bankName: bankName,
    bankId: bankId,
    initials: initials,
  );
}

Future<void> _saveRecipientToFirestore({
  required String accountNumber,
  required String accountName,
  required String bankName,
  required String bankId,
  String? initials,
}) async {
  final String? userId =
      UserFirestoreService.instance.currentUserDocId ??
      FirebaseAuth.instance.currentUser?.uid;
  if (userId == null || userId.isEmpty) {
    return;
  }

  final String normalizedAccount = accountNumber.trim();
  if (normalizedAccount.isEmpty) {
    return;
  }

  final String normalizedName = accountName.trim().isEmpty
      ? 'UNKNOWN USER'
      : accountName.trim().toUpperCase();
  final String normalizedBankName = bankName.trim().isEmpty
      ? 'UNKNOWN BANK'
      : bankName.trim();
  final String normalizedBankId = bankId.trim().isEmpty
      ? normalizedBankName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
      : bankId.trim();
  final String effectiveInitials = (initials ?? '').trim().isEmpty
      ? _deriveInitials(normalizedName)
      : initials!.trim().toUpperCase();

  final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId);

  final CollectionReference<Map<String, dynamic>> savedRecipientsRef = userRef
      .collection('saved_recipients');
  final CollectionReference<Map<String, dynamic>> recentTransfersRef = userRef
      .collection('recent_transfers');

  final DocumentReference<Map<String, dynamic>> savedDocRef = savedRecipientsRef
      .doc(normalizedAccount);
  final DocumentSnapshot<Map<String, dynamic>> savedDoc = await savedDocRef
      .get();

  final Map<String, dynamic> payload = _recipientPayload(
    accountNumber: normalizedAccount,
    accountName: normalizedName,
    bankName: normalizedBankName,
    bankId: normalizedBankId,
    initials: effectiveInitials,
  );

  if (!savedDoc.exists) {
    await savedDocRef.set(payload);
  }

  await recentTransfersRef.add(payload);
}

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF6F8FF);
  final NumberFormat _vndFormat = NumberFormat('#,###', 'en_US');

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        return 0;
      }
      return double.tryParse(digits) ?? 0;
    }
    return 0;
  }

  double _extractTransferAmount(Map<String, dynamic> data) {
    final dynamic rawAmount =
        data['amount'] ?? data['transferAmount'] ?? data['amountVnd'];
    if (rawAmount != null) {
      return _toDouble(rawAmount);
    }

    return _toDouble(data['amountText']);
  }

  String _formatAmountVnd(double amount) {
    return '${_vndFormat.format(amount.round())} VND';
  }

  String? get _userId =>
      UserFirestoreService.instance.currentUserDocId ??
      FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _savedRecipientsStream() {
    final String? uid = _userId;
    if (uid == null || uid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_recipients')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _recentTransfersStream() {
    final String? uid = _userId;
    if (uid == null || uid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recent_transfers')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyRecipientFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return docs;
    }

    return docs
        .where((doc) {
          final Map<String, dynamic> data = doc.data();
          final String accountName = (data['accountName'] ?? '')
              .toString()
              .toLowerCase();
          final String accountNumber = CardNumberService.readCardNumber(
            data,
          ).toLowerCase();
          final String bankName = (data['bankName'] ?? '')
              .toString()
              .toLowerCase();

          return accountName.contains(query) ||
              accountNumber.contains(query) ||
              bankName.contains(query);
        })
        .toList(growable: false);
  }

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
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildEmptyRecipientsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        _t('Chưa có người nhận', 'No recipients yet'),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFF8B92A6),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSavedSection() {
    final String? uid = _userId;
    if (uid == null || uid.isEmpty) {
      return _buildEmptyRecipientsText();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _savedRecipientsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator(color: primaryBlue)),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            _applyRecipientFilter(snapshot.data?.docs ?? []);

        if (docs.isEmpty) {
          return _buildEmptyRecipientsText();
        }

        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final Map<String, dynamic> data = docs[index].data();
              final String name = (data['accountName'] ?? '').toString();
              final String bank = (data['bankName'] ?? '').toString();
              final String bankId = (data['bankId'] ?? '').toString();
              final String accountNumber = CardNumberService.readCardNumber(
                data,
              );
              final String initials = (data['initials'] ?? '').toString();
              final String displayInitials = initials.trim().isNotEmpty
                  ? initials.trim().toUpperCase()
                  : _deriveInitials(name);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransferScreen(
                          bankName: bank,
                          bankId: bankId,
                          accountNumber: accountNumber,
                          accountName: name,
                          isAlreadySaved: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 118,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6EAF5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFECF0FF),
                          child: Text(
                            displayInitials,
                            style: GoogleFonts.poppins(
                              color: primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2D3E),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          bank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF8C93A7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentSection() {
    final String? uid = _userId;
    if (uid == null || uid.isEmpty) {
      return _buildEmptyRecipientsText();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recentTransfersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator(color: primaryBlue)),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            _applyRecipientFilter(snapshot.data?.docs ?? []);

        if (docs.isEmpty) {
          return _buildEmptyRecipientsText();
        }

        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final Map<String, dynamic> data = docs[index].data();
            final String name = (data['accountName'] ?? '').toString();
            final String accountNumber = CardNumberService.readCardNumber(data);
            final String displayCardNumber = CardNumberService.formatCardNumber(
              accountNumber,
            );
            final double amount = _extractTransferAmount(data);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6EAF5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEEF1FF),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 17,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFF2A2D3E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayCardNumber.isEmpty
                              ? accountNumber
                              : displayCardNumber,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8B92A6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount > 0
                            ? _formatAmountVnd(amount)
                            : _t('Chưa có số tiền', 'No amount'),
                        style: GoogleFonts.poppins(
                          color: amount > 0
                              ? const Color(0xFF000DC0)
                              : const Color(0xFF8B92A6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFA0A7BA),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: CCPAppBar(
        title: _t('Chuyển tiền', 'Transfer'),
        backgroundColor: pageBackground,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2CCB), Color(0xFF000DC0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('Chuyển tiền nhanh', 'Quick transfer'),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t(
                                'Lưu người nhận để chuyển tiền chỉ trong vài giây.',
                                'Save beneficiaries to transfer money in seconds.',
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransferScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          _t('Thêm', 'Add'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E9F4)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: _t('Tìm người nhận', 'Search beneficiary'),
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF9FA6BA),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF7E8598),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('Đã lưu', 'Saved'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF242738),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSavedSection(),
                const SizedBox(height: 18),
                Text(
                  _t('Gần đây', 'Recent'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF242738),
                  ),
                ),
                const SizedBox(height: 10),
                _buildRecentSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
