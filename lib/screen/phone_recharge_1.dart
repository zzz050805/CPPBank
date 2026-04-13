import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';
import '../services/notification_service.dart';
import '../services/user_firestore_service.dart';
import '../widget/custom_card_selector.dart';
import '../widget/pin_popup.dart';

class ConfirmTopUpScreen extends StatefulWidget {
  const ConfirmTopUpScreen({
    super.key,
    required this.selectedAmount,
    required this.selectedProvider,
    required this.selectedPhoneNumber,
  });

  final String selectedAmount;
  final String selectedProvider;
  final String selectedPhoneNumber;

  @override
  State<ConfirmTopUpScreen> createState() => _ConfirmTopUpScreenState();
}

class _ConfirmTopUpScreenState extends State<ConfirmTopUpScreen> {
  static const String _otherAmountKey = '__other_amount__';

  bool _isSubmitting = false;
  String? _selectedCardId;
  String _selectedCardDisplay = '****';

  String _tx(String key) => AppText.text(context, key);

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

  String _amountDisplay() {
    if (widget.selectedAmount == _otherAmountKey) {
      return _tx('topup_other_amount');
    }
    return '${widget.selectedAmount} VND';
  }

  String _statusDisplay() {
    return _tx('payment_success');
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

    final int amount = _parseAmountValue(widget.selectedAmount);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tx('topup_invalid_amount')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String uid = _resolveTransactionUid();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tx('topup_not_logged_in')),
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
    final DocumentReference<Map<String, dynamic>> transactionRef = userRef
        .collection('transactions')
        .doc();
    final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
        .collection('cards')
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
        .collection('cards')
        .doc('vip');

    final String network = widget.selectedProvider.trim();
    final String phoneNumber = widget.selectedPhoneNumber.trim();
    final DateTime completedAt = DateTime.now();

    try {
      await firestore.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await transaction
            .get(userRef);

        if (!userDoc.exists) {
          throw Exception(_tx('topup_user_not_found'));
        }

        final Map<String, dynamic> userData =
            userDoc.data() ?? <String, dynamic>{};

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

        final bool useStandard = selectedCardId == 'standard';
        final bool useVip = selectedCardId == 'vip';
        if (!useStandard && !useVip) {
          throw Exception(_tx('card_unavailable'));
        }

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

        final bool selectedAvailable = useStandard
            ? standardAvailable
            : vipAvailable;
        if (!selectedAvailable) {
          throw Exception(_tx('card_unavailable'));
        }

        final double availableBalance = UserFirestoreService.instance
            .calculateAvailableBalanceFromMaps(
              userData: userData,
              cardsById: cardsById,
            );
        if (availableBalance < amount) {
          throw Exception(_tx('insufficient_balance'));
        }

        final num selectedBalance = useStandard
            ? _readNumericBalance(standardCardData['balance'])
            : _readNumericBalance(vipCardData['balance']);
        if (selectedBalance < amount) {
          throw Exception(_tx('insufficient_balance'));
        }

        final DocumentReference<Map<String, dynamic>> selectedCardRef =
            useStandard ? standardCardRef : vipCardRef;

        transaction.set(selectedCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(rechargeRef, <String, dynamic>{
          'uid': uid,
          'cardId': selectedCardId,
          'phoneNumber': phoneNumber,
          'provider': network,
          'network': network,
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAt_client': Timestamp.fromDate(completedAt),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'success',
          'type': 'phone_topup',
        });

        transaction.set(notificationRef, <String, dynamic>{
          'type': 'phone_topup',
          'amount': amount,
          'network': network,
          'phone': phoneNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedId': rechargeRef.id,
          'cardId': selectedCardId,
        });

        transaction.set(transactionRef, <String, dynamic>{
          'type': 'phone_topup',
          'amount': amount,
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
          'timestamp_client': Timestamp.fromDate(completedAt),
          'createdAt': FieldValue.serverTimestamp(),
          'createdAt_client': Timestamp.fromDate(completedAt),
          'details': 'Nạp tiền điện thoại',
          'network': network,
          'phoneNumber': phoneNumber,
          'relatedId': rechargeRef.id,
          'cardId': selectedCardId,
          'isNegative': true,
        });
      });

      if (!mounted) {
        return;
      }

      final String languageCode = AppText.currentLanguageCode(context);
      final String amountText = '${_formatAmountWithDots(amount)} VND';

      await NotificationService().showNotification(
        title: AppText.textByCode(languageCode, 'notify_topup_title'),
        body: AppText.textByCodeWithParams(
          languageCode,
          'notify_topup_body',
          <String, String>{'amount': amountText, 'phone': phoneNumber},
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
            phoneNumber: phoneNumber,
            provider: network,
            amount: amount,
            createdAt: completedAt,
            status: _statusDisplay(),
            type: 'phone_topup',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tx('topup_transaction_error')),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tx('action_cancel')),
            ),
          ],
        ),
      );
    }
  }

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
          _tx('topup_confirm_title'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
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
                      ? _tx('topup_enter_custom_amount_hint')
                      : _tx('topup_selected_amount'),
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
                            _tx('topup_verify_before_confirm'),
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
                  Text(
                    _tx('source_account'),
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
                              _tx('source_card'),
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
                                ? _tx('user_account_not_exists')
                                : ((profile?.fullname.isNotEmpty == true)
                                      ? profile!.fullname
                                      : _tx('customer_label'));

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
                  Text(
                    _tx('topup_details_title'),
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
                          _tx('service'),
                          _tx('topup_service_name'),
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _tx('provider'),
                          widget.selectedProvider,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _tx('topup_phone_label'),
                          widget.selectedPhoneNumber,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          _tx('topup_amount_label'),
                          _amountDisplay(),
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
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
                              _tx('action_confirm'),
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

  String _tx(BuildContext context, String key) => AppText.text(context, key);

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
          _tx(context, 'topup_receipt_title'),
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
                  _tx(context, 'topup_success_title'),
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
                      _tx(context, 'topup_transaction_id'),
                      transactionId,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _tx(context, 'topup_phone_label'),
                      phoneNumber,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(_tx(context, 'provider'), provider),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _tx(context, 'topup_amount_label'),
                      '${_formatAmountWithDots(amount)} VND',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _tx(context, 'created_at_label'),
                      _formatDateTime(createdAt),
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(_tx(context, 'topup_status_label'), status),
                    const Divider(height: 1),
                    _buildInfoTile(
                      _tx(context, 'topup_type_label'),
                      _tx(context, 'topup_service_name'),
                    ),
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
                  _tx(context, 'back_to_home'),
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
