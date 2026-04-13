import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../services/notification_service.dart';
import '../widget/custom_card_selector.dart';
import '../widget/pin_popup.dart';

class ConfirmTopUpScreen extends StatefulWidget {
  final String selectedAmount;
  final String selectedProvider;
  final String selectedPhoneNumber;

  const ConfirmTopUpScreen({
    super.key,
    required this.selectedAmount,
    required this.selectedProvider,
    required this.selectedPhoneNumber,
  });

  @override
  State<ConfirmTopUpScreen> createState() => _ConfirmTopUpScreenState();
}

class _ConfirmTopUpScreenState extends State<ConfirmTopUpScreen> {
  static const String _otherAmountKey = '__other_amount__';
  bool _isSubmitting = false;
  String? _selectedCardId;
  String _selectedCardDisplay = '****';

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _amountDisplay() {
    if (widget.selectedAmount == _otherAmountKey) {
      return _t('Số khác', 'Other');
    }
    return '${widget.selectedAmount} VND';
  }

  int _parseAmountValue(String rawAmount) {
    final String digitsOnly = rawAmount.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 0;
    }
    return int.tryParse(digitsOnly) ?? 0;
  }

  num _readNumericBalance(dynamic rawBalance) {
    if (rawBalance is num) {
      return rawBalance;
    }

    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final num? direct = num.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }

      final String digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        return 0;
      }
      return num.tryParse(digits) ?? 0;
    }

    return 0;
  }

  String _resolveTransactionUid() {
    final String? fromAuth = FirebaseAuth.instance.currentUser?.uid;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }

    final String? fromService = UserFirestoreService.instance.currentUserDocId;
    if (fromService != null && fromService.isNotEmpty) {
      return fromService;
    }

    final String? fromProfile =
        UserFirestoreService.instance.latestProfile?.uid;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    return '';
  }

  Widget _buildSourceCardText(Color primaryColor) {
    final String uid = _resolveTransactionUid();
    if (uid.isEmpty) {
      return _buildSourceCardRichText(
        primaryColor: primaryColor,
        cardDisplay: _t('Đang tải...', 'Loading...'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        String cardDisplay = _t('Đang tải...', 'Loading...');

        if (snapshot.hasData) {
          final Map<String, dynamic> userData =
              snapshot.data?.data() ?? <String, dynamic>{};
          final String rawCard = CardNumberService.readStoredCardNumber(
            userData,
          );
          if (rawCard.isNotEmpty) {
            cardDisplay = CardNumberService.formatCardNumber(rawCard);
          }
        }

        return _buildSourceCardRichText(
          primaryColor: primaryColor,
          cardDisplay: cardDisplay,
        );
      },
    );
  }

  Widget _buildSourceCardRichText({
    required Color primaryColor,
    required String cardDisplay,
  }) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          color: const Color(0xFF222222),
          fontSize: 14,
        ),
        children: [
          TextSpan(text: '${_t('Số thẻ', 'Card number')}: '),
          TextSpan(
            text: cardDisplay,
            style: GoogleFonts.poppins(
              color: primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmRecharge() async {
    if (_isSubmitting) {
      return;
    }

    final String selectedCardId = (_selectedCardId ?? '').trim().toLowerCase();
    if (selectedCardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.text(context, 'select_source_card')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ignore: avoid_print
    print('--- BẮT ĐẦU GIAO DỊCH ---');

    final int amount = _parseAmountValue(widget.selectedAmount);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Số tiền nạp không hợp lệ.', 'Invalid top-up amount.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    // ignore: avoid_print
    print('User UID: ${user?.uid}');
    // ignore: avoid_print
    print(
      'Fallback UID: ${UserFirestoreService.instance.currentUserDocId ?? UserFirestoreService.instance.latestProfile?.uid}',
    );

    final String uid = _resolveTransactionUid();
    // ignore: avoid_print
    print('Resolved UID dÄ‚Â¹ng d? giao d?ch: $uid');
    // ignore: avoid_print
    print('Firebase projectId hi?n t?i: ${Firebase.app().options.projectId}');

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('L?i: Chua dang nh?p', 'Error: Not logged in')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> rechargeRef = userRef
        .collection('phone_recharge')
        .doc();
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();

    try {
      // ignore: avoid_print
      print('Ã„Âang tÌ€Âm document user: users/$uid');
      final bool ensured = await UserFirestoreService.instance
          .ensureUserDataExists(userId: uid);
      // ignore: avoid_print
      print('ensureUserDataExists(users/$uid) => $ensured');
      // ignore: avoid_print
      print('S? ti?n c?n tr?: $amount');

      // B?t bu?c await d? transaction hoÄ‚Â n t?t tru?c khi di?u hu?ng mÄ‚Â n hÌ€Ânh.
      await firestore.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await transaction
            .get(userRef);

        if (!userDoc.exists) {
          throw Exception('KhÄ‚Â´ng tÌ€Âm th?y document user: users/$uid');
        }

        // ignore: avoid_print
        print(
          'S? du hi?n t?i trÄ‚Âªn Firestore: ${userDoc.data()?['balance']}',
        );

        final Map<String, dynamic> userData =
            userDoc.data() ?? <String, dynamic>{};
        final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
            .collection('cards')
            .doc('standard');
        final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
            .collection('cards')
            .doc('vip');

        final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
            await transaction.get(standardCardRef);
        final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
            await transaction.get(vipCardRef);

        final Map<String, dynamic> standardCardData =
            standardCardSnap.data() ?? <String, dynamic>{};
        final Map<String, dynamic> vipCardData =
            vipCardSnap.data() ?? <String, dynamic>{};
        final Map<String, Map<String, dynamic>> cardsById =
            <String, Map<String, dynamic>>{
              'standard': standardCardData,
              'vip': vipCardData,
            };

        final bool standardAvailable = UserFirestoreService.instance
            .isCardAvailableForTransactions(
              cardId: 'standard',
              cardData: standardCardData,
              userData: userData,
            );
        final bool vipAvailable = UserFirestoreService.instance
            .isCardAvailableForTransactions(
              cardId: 'vip',
              cardData: vipCardData,
              userData: userData,
            );

        final double availableBalance = UserFirestoreService.instance
            .calculateAvailableBalanceFromMaps(
              userData: userData,
              cardsById: cardsById,
            );

        if (availableBalance < amount) {
          throw Exception('S? du khÄ‚Â´ng d?');
        }

        final bool useStandard = selectedCardId == 'standard';
        final bool useVip = selectedCardId == 'vip';
        if (!useStandard && !useVip) {
          throw Exception(AppText.text(context, 'card_unavailable'));
        }

        final bool selectedAvailable = useStandard
            ? standardAvailable
            : vipAvailable;
        if (!selectedAvailable) {
          throw Exception(AppText.text(context, 'card_unavailable'));
        }

        final num selectedBalance = useStandard
            ? _readNumericBalance(standardCardData['balance'])
            : _readNumericBalance(vipCardData['balance']);
        if (selectedBalance < amount) {
          throw Exception('S? du khÄ‚Â´ng d?');
        }

        if (useStandard) {
          transaction.set(standardCardRef, <String, dynamic>{
            'balance': FieldValue.increment(-amount),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          transaction.set(vipCardRef, <String, dynamic>{
            'balance': FieldValue.increment(-amount),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // ignore: avoid_print
        print(
          'Ã„Âang chu?n b? ghi vÄ‚Â o: users/$uid/phone_recharge/ID_TU_DONG',
        );
        // ignore: avoid_print
        print(
          'Ã„Âu?ng d?n th?c t?: users/$uid/phone_recharge/${rechargeRef.id}',
        );
        transaction.set(rechargeRef, <String, dynamic>{
          'uid': uid,
          'cardId': selectedCardId,
          'phoneNumber': widget.selectedPhoneNumber.trim(),
          'provider': widget.selectedProvider.trim(),
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'success',
          'type': 'topup',
        });

        transaction.set(notificationRef, <String, dynamic>{
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'phone_recharge',
          'isNegative': true,
          'serviceName': widget.selectedProvider.trim(),
          'targetAccount': widget.selectedPhoneNumber.trim(),
          'transactionCode': rechargeRef.id,
          'cardId': selectedCardId,
          'status': 'success',
          'isRead': false,
          'relatedId': rechargeRef.id,
          'amount': amount,
        });
      });

      final DocumentSnapshot<Map<String, dynamic>> savedRecharge =
          await rechargeRef.get();
      // ignore: avoid_print
      print('Sau commit, document t?n t?i: ${savedRecharge.exists}');
      if (!savedRecharge.exists) {
        throw Exception('KhÄ‚Â´ng luu du?c hÄ‚Â³a don n?p ti?n');
      }

      final String languageCode = AppText.currentLanguageCode(context);
      final String amountText = '$amount VND';
      await NotificationService().showNotification(
        title: AppText.textByCode(languageCode, 'notify_phone_recharge_title'),
        body: AppText.textByCodeWithParams(
          languageCode,
          'notify_phone_recharge_body',
          <String, String>{
            'amount': amountText,
            'provider': widget.selectedProvider.trim(),
          },
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TopUpReceiptScreen(
            transactionId: rechargeRef.id,
            phoneNumber: widget.selectedPhoneNumber.trim(),
            provider: widget.selectedProvider.trim(),
            amount: amount,
            createdAt: DateTime.now(),
            status: 'success',
            type: 'topup',
          ),
        ),
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('? L?I TH?C T?: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('L?i giao d?ch', 'Transaction error')),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('Ã„ÂÄ‚Â³ng', 'Close')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t('N?p ti?n di?n tho?i', 'Phone Top-Up'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header hi?n th? s? ti?n
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000DC0), Color(0xFF00088C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _amountDisplay(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.selectedAmount == _otherAmountKey
                      ? _t(
                          'Vui lÌ€Â£ng nh?p s? ti?n mong mu?n',
                          'Please enter your desired amount',
                        )
                      : _t('S? ti?n b?n dÃ„Æ’ ch?n', 'Selected amount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDE5FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(
                              'Vui lÌ€Â£ng ki?m tra k? thÄ‚Â´ng tin tru?c khi xÄ‚Â¡c nh?n giao d?ch.',
                              'Please verify details carefully before confirming.',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF2C3A75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // M?c TrÄ‚Â­ch t?
                  Text(
                    _t('TrÄ‚Â­ch t?', 'From account'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: primaryColor,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t('TÄ‚Â i kho?n ngu?n', 'Source account'),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6E7490),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CustomCardSelector(
                          uid: _resolveTransactionUid(),
                          selectedCardId: _selectedCardId,
                          onChanged: (CustomCardSelection selection) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _selectedCardId = selection.id;
                              _selectedCardDisplay = selection.account;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedCardDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                    'KhÄ‚Â´ng tÌ€Âm th?y user',
                                    'User not found',
                                  )
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _t('KhÄ‚Â¡ch hÄ‚Â ng', 'Customer'));

                            return Text(
                              senderName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // M?c ThÄ‚Â´ng tin chi ti?t
                  Text(
                    _t('ThÄ‚Â´ng tin chi ti?t', 'Details'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D7693),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8DEEE)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          _t('Lo?i d?ch v?', 'Service type'),
                          _t('N?p Ã„ÂTDD', 'Mobile top-up'),
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('NhÄ‚Â  cung c?p', 'Provider'),
                          widget.selectedProvider,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('S? di?n tho?i', 'Phone number'),
                          widget.selectedPhoneNumber,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _t('M?nh giÄ‚Â¡ (VND)', 'Amount (VND)'),
                          _amountDisplay(),
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // NÄ‚Âºt XÄ‚Â¡c nh?n
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => PinPopupWidget(
                                  onSuccess: _handleConfirmRecharge,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('XÄ‚Â¡c nh?n', 'Confirm'),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
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

  // Widget con d? v? t?ng dÌ€Â£ng thÄ‚Â´ng tin
  Widget _buildInfoRow(String label, String value, {bool isBlue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1F263D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: isBlue ? const Color(0xFF0046A6) : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopUpReceiptScreen extends StatelessWidget {
  const TopUpReceiptScreen({
    super.key,
    required this.transactionId,
    required this.phoneNumber,
    required this.provider,
    required this.amount,
    required this.createdAt,
    required this.status,
    required this.type,
  });

  final String transactionId;
  final String phoneNumber;
  final String provider;
  final int amount;
  final DateTime createdAt;
  final String status;
  final String type;

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  String _formatAmountWithDots(int value) {
    final String raw = value.toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;

    for (int i = raw.length - 1; i >= 0; i--) {
      buffer.write(raw[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  String _formatDateTime(DateTime dateTime) {
    final String twoDigitMonth = dateTime.month.toString().padLeft(2, '0');
    final String twoDigitDay = dateTime.day.toString().padLeft(2, '0');
    final String twoDigitHour = dateTime.hour.toString().padLeft(2, '0');
    final String twoDigitMinute = dateTime.minute.toString().padLeft(2, '0');
    return '$twoDigitDay/$twoDigitMonth/${dateTime.year} $twoDigitHour:$twoDigitMinute';
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D7693),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E2747),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF000DC0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _t(context, 'BiÄ‚Âªn lai n?p ti?n', 'Top-up receipt'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000DC0), Color(0xFF00088C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    context,
                    'Giao d?ch thÄ‚Â nh cÄ‚Â´ng',
                    'Transaction successful',
                  ),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatAmountWithDots(amount)} VND',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8DEEE)),
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      _t(context, 'MÃ„Æ’ giao d?ch', 'Transaction ID'),
                      transactionId,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'S? di?n tho?i', 'Phone number'),
                      phoneNumber,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'NhÄ‚Â  m?ng', 'Provider'),
                      provider,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'S? ti?n', 'Amount'),
                      '${_formatAmountWithDots(amount)} VND',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Th?i gian', 'Created at'),
                      _formatDateTime(createdAt),
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _t(context, 'Tr?ng thÄ‚Â¡i', 'Status'),
                      status,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(_t(context, 'Lo?i', 'Type'), type),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _t(context, 'V? trang ch?', 'Back to home'),
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
}
