import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../services/card_number_service.dart';
import '../services/notification_service.dart';
import '../widget/ccp_app_bar.dart';
import '../widget/custom_card_selector.dart';
import '../widget/pin_popup.dart';
import '../widget/custom_confirm_dialog.dart';
import 'withdraw_receipt_screen.dart';

class WithdrawATMPage extends StatefulWidget {
  const WithdrawATMPage({super.key});

  @override
  State<WithdrawATMPage> createState() => _WithdrawATMPageState();
}

class _WithdrawReceiptData {
  const _WithdrawReceiptData({
    required this.code,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
  });

  final String code;
  final int amount;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class _WithdrawATMPageState extends State<WithdrawATMPage> {
  static const int _minWithdrawAmount = 50000;
  static const int _maxWithdrawAmount = 100000000;
  static const int _withdrawStep = 50000;

  final TextEditingController _amountController = TextEditingController();
  final List<int> _quickAmounts = <int>[
    50000,
    100000,
    200000,
    500000,
    1000000,
    2000000,
  ];

  int? _selectedQuickAmount;
  late final Stream<UserProfileData?> _profileStream;
  double _lastKnownTotalBalance = 0;
  bool _hasLoadedBalance = false;
  bool _isSubmitting = false;
  String? _selectedCardId;
  List<_WithdrawSourceCardOption> _sourceCards = <_WithdrawSourceCardOption>[];

  final Color _brandColor = const Color(0xFF000DC0);
  final Color _bgColor = const Color(0xFFF8F9FE);

  @override
  void initState() {
    super.initState();
    _profileStream = UserFirestoreService.instance.currentUserProfileStream();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _resolveUid() {
    final String fromService =
        (UserFirestoreService.instance.currentUserDocId ?? '').trim();
    if (fromService.isNotEmpty) {
      return fromService;
    }

    final String fromAuth = (FirebaseAuth.instance.currentUser?.uid ?? '')
        .trim();
    if (fromAuth.isNotEmpty) {
      return fromAuth;
    }

    return '';
  }

  int get _enteredAmount {
    return int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ??
        0;
  }

  bool get _hasInsufficientBalance {
    if (!_hasLoadedBalance) {
      return false;
    }
    return _enteredAmount > _lastKnownTotalBalance;
  }

  int get _maxAllowedAmount {
    if (!_hasLoadedBalance) {
      return _maxWithdrawAmount;
    }

    final int availableByBalance = _lastKnownTotalBalance.floor();
    if (availableByBalance <= 0) {
      return 0;
    }
    if (availableByBalance > _maxWithdrawAmount) {
      return _maxWithdrawAmount;
    }
    return availableByBalance;
  }

  bool get _isOutOfRange {
    return _enteredAmount > 0 &&
        (_enteredAmount < _minWithdrawAmount ||
            _enteredAmount > _maxAllowedAmount);
  }

  bool get _isInvalidStep {
    if (_enteredAmount == 0) {
      return false;
    }
    return _enteredAmount % _withdrawStep != 0;
  }

  bool get _isValidAmount {
    return _hasLoadedBalance &&
        _enteredAmount >= _minWithdrawAmount &&
        _enteredAmount <= _maxAllowedAmount &&
        !_hasInsufficientBalance &&
        !_isInvalidStep;
  }

  String? get _amountErrorText {
    if (_hasInsufficientBalance) {
      return AppText.text(context, 'insufficient_balance');
    }
    if (_isOutOfRange || _isInvalidStep) {
      return AppText.text(context, 'withdraw_invalid_amount');
    }
    return null;
  }

  String _formatCurrency(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy HH:mm').format(value);
  }

  String _formatBalanceAmount(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatIntAmount(int value) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  List<_WithdrawSourceCardOption> _buildSourceCards(
    Map<String, dynamic> userData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double parseBalance(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        return double.tryParse(raw) ?? 0;
      }
      return 0;
    }

    final bool hasVipCard = userData['hasVipCard'] == true;
    final bool isStandardLocked = userData['is_standard_locked'] == true;
    final bool isVipLocked = userData['is_vip_locked'] == true;
    const double vipEligibilityThreshold = 200000000;

    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      byId[doc.id.toLowerCase()] = doc.data();
    }

    final String rawCard = CardNumberService.readStoredCardNumber(userData);
    final String formattedCard = rawCard.isEmpty
        ? '****'
        : CardNumberService.formatCardNumber(rawCard);

    final List<_WithdrawSourceCardOption> cards = <_WithdrawSourceCardOption>[];
    final double standardCardBalance = parseBalance(
      (byId['standard'] ?? <String, dynamic>{})['balance'],
    );
    final bool vipHasAccess =
        !isVipLocked &&
        (hasVipCard || standardCardBalance >= vipEligibilityThreshold);

    if (!isStandardLocked) {
      cards.add(
        _WithdrawSourceCardOption(
          id: 'standard',
          title: AppText.text(context, 'card_standard'),
          account: formattedCard,
          balance: parseBalance(
            (byId['standard'] ?? <String, dynamic>{})['balance'],
          ),
        ),
      );
    }

    if (vipHasAccess) {
      cards.add(
        _WithdrawSourceCardOption(
          id: 'vip',
          title: AppText.text(context, 'card_vip'),
          account: formattedCard,
          balance: parseBalance(
            (byId['vip'] ?? <String, dynamic>{})['balance'],
          ),
        ),
      );
    }

    return cards;
  }

  _WithdrawSourceCardOption? _findSelectedSourceCard() {
    final String selected = (_selectedCardId ?? '').trim();
    if (selected.isEmpty) {
      return null;
    }

    for (final _WithdrawSourceCardOption option in _sourceCards) {
      if (option.id == selected) {
        return option;
      }
    }
    return null;
  }

  void _syncSourceCards(List<_WithdrawSourceCardOption> nextOptions) {
    final _WithdrawSourceCardOption? currentSelected =
        _findSelectedSourceCard();
    final bool hasCurrentSelected = nextOptions.any(
      (_WithdrawSourceCardOption option) => option.id == currentSelected?.id,
    );

    final _WithdrawSourceCardOption? nextSelected = nextOptions.isEmpty
        ? null
        : hasCurrentSelected
        ? nextOptions.firstWhere(
            (_WithdrawSourceCardOption option) =>
                option.id == currentSelected!.id,
          )
        : nextOptions.first;

    bool optionsChanged = _sourceCards.length != nextOptions.length;
    if (!optionsChanged) {
      for (int i = 0; i < _sourceCards.length; i++) {
        final _WithdrawSourceCardOption oldOption = _sourceCards[i];
        final _WithdrawSourceCardOption newOption = nextOptions[i];
        if (oldOption.id != newOption.id ||
            oldOption.title != newOption.title ||
            oldOption.account != newOption.account ||
            oldOption.balance != newOption.balance) {
          optionsChanged = true;
          break;
        }
      }
    }

    final String? nextSelectedId = nextSelected?.id;
    final double nextBalance = nextSelected?.balance ?? 0;

    if (!optionsChanged &&
        _selectedCardId == nextSelectedId &&
        _lastKnownTotalBalance == nextBalance &&
        _hasLoadedBalance) {
      return;
    }

    setState(() {
      _sourceCards = nextOptions;
      _selectedCardId = nextSelectedId;
      _lastKnownTotalBalance = nextBalance;
      _hasLoadedBalance = true;
    });
  }

  void _onQuickSelect(int value) {
    setState(() {
      _selectedQuickAmount = value;
      _amountController.text = NumberFormat('#,###', 'vi_VN').format(value);
    });
  }

  void _onAmountChanged(String value) {
    setState(() {
      _selectedQuickAmount = null;
    });
  }

  String _generateSixDigitCode() {
    final Random random = Random.secure();
    return random.nextInt(1000000).toString().padLeft(6, '0');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _withdrawHistoryStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('atm_withdrawals')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<_WithdrawReceiptData> _createWithdrawCodeAfterPin({
    required String uid,
    required int amount,
    required String selectedCardId,
  }) async {
    double parseCardBalance(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) {
          return 0;
        }
        final double? direct = double.tryParse(trimmed.replaceAll(',', '.'));
        if (direct != null) {
          return direct;
        }
        final String normalized = trimmed.replaceAll(RegExp(r'[^0-9.-]'), '');
        if (normalized.isEmpty || normalized == '-' || normalized == '.') {
          return 0;
        }
        return double.tryParse(normalized) ?? 0;
      }
      return 0;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
        .collection('cards')
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
        .collection('cards')
        .doc('vip');
    final DocumentReference<Map<String, dynamic>> withdrawalRef = userRef
        .collection('atm_withdrawals')
        .doc();
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();
    final DocumentReference<Map<String, dynamic>> transactionRef = userRef
        .collection('transactions')
        .doc();

    final String code = _generateSixDigitCode();
    final DateTime createdAt = DateTime.now();
    final DateTime expiresAt = createdAt.add(const Duration(minutes: 15));
    final String languageCode = AppText.currentLanguageCode(context);
    final String title = AppText.textByCode(languageCode, 'atm_withdrawal');
    final String body = AppText.textByCodeWithParams(
      languageCode,
      'atm_withdrawal_code_created_heads_up',
      <String, String>{'code': code},
    );

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await transaction
          .get(userRef);
      if (!userSnap.exists) {
        throw Exception(AppText.text(context, 'no_valid_login_session'));
      }

      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);

      final Map<String, dynamic> userData =
          userSnap.data() ?? <String, dynamic>{};
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
        throw Exception(AppText.text(context, 'insufficient_balance'));
      }

      final double standardBalance = parseCardBalance(
        standardCardData['balance'],
      );
      final double vipBalance = parseCardBalance(vipCardData['balance']);

      final String normalizedCardId = selectedCardId.trim().toLowerCase();
      final bool useStandard = normalizedCardId == 'standard';
      final bool useVip = normalizedCardId == 'vip';
      final bool selectedAvailable = useStandard
          ? standardAvailable
          : vipAvailable;
      final double selectedBalance = useStandard ? standardBalance : vipBalance;
      final Map<String, dynamic> selectedCardData =
          cardsById[normalizedCardId] ?? <String, dynamic>{};
      final String selectedRawCardNumberFromCard =
          CardNumberService.readStoredCardNumber(selectedCardData);
      final String selectedRawCardNumber =
          selectedRawCardNumberFromCard.isNotEmpty
          ? selectedRawCardNumberFromCard
          : CardNumberService.readStoredCardNumber(userData);

      if (!useStandard && !useVip) {
        throw Exception(AppText.text(context, 'card_unavailable'));
      }
      if (!selectedAvailable) {
        throw Exception(AppText.text(context, 'card_unavailable'));
      }
      if (selectedBalance < amount) {
        throw Exception(AppText.text(context, 'insufficient_balance'));
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

      transaction.update(userRef, <String, dynamic>{
        'total_transactions': FieldValue.increment(1),
        'total_spent': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(withdrawalRef, <String, dynamic>{
        'uid': uid,
        'amount': amount,
        'code': code,
        'target_account': selectedRawCardNumber,
        'targetAccount': selectedRawCardNumber,
        'card_number': selectedRawCardNumber,
        'status': 'active',
        'type': 'withdraw',
        'created_at': FieldValue.serverTimestamp(),
        'created_at_client': Timestamp.fromDate(createdAt),
        'expires_at': Timestamp.fromDate(expiresAt),
      });

      transaction.set(notificationRef, <String, dynamic>{
        'title': title,
        'body': body,
        'titleKey': 'atm_withdrawal',
        'bodyKey': 'atm_withdrawal_code_created_heads_up',
        'bodyParams': <String, String>{'code': code},
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'atm_withdrawal',
        'status': 'success',
        'isRead': false,
        'isNegative': true,
        'amount': amount,
        'withdrawCode': code,
        'relatedId': withdrawalRef.id,
      });

      transaction.set(transactionRef, <String, dynamic>{
        'type': 'atm_withdrawal',
        'amount': amount,
        'cardId': normalizedCardId,
        'target_account': selectedRawCardNumber,
        'targetAccount': selectedRawCardNumber,
        'card_number': selectedRawCardNumber,
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'timestamp_client': Timestamp.fromDate(createdAt),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAt_client': Timestamp.fromDate(createdAt),
        'withdrawCode': code,
        'transactionCode': code,
        'relatedId': withdrawalRef.id,
        'isNegative': true,
      });
    });

    await NotificationService().showNotification(
      title: title,
      body: body,
      lightVibration: true,
    );

    return _WithdrawReceiptData(
      code: code,
      amount: amount,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Future<void> _onSubmitCreateCode() async {
    if (_isSubmitting) {
      return;
    }

    final int amount = _enteredAmount;
    if (!_isValidAmount || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.text(context, 'withdraw_invalid_amount')),
        ),
      );
      return;
    }

    final String uid = _resolveUid();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.text(context, 'no_valid_login_session')),
        ),
      );
      return;
    }

    final String selectedCardId = (_selectedCardId ?? '').trim();
    if (selectedCardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'select_source_card'))),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return PinPopupWidget(
          onSuccess: () async {
            if (!mounted) {
              return;
            }

            setState(() {
              _isSubmitting = true;
            });

            try {
              final _WithdrawReceiptData receipt =
                  await _createWithdrawCodeAfterPin(
                    uid: uid,
                    amount: amount,
                    selectedCardId: selectedCardId,
                  );

              if (!mounted) {
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WithdrawReceiptScreen(
                    amount: receipt.amount,
                    withdrawCode: receipt.code,
                    createdAt: receipt.createdAt,
                    expiresAt: receipt.expiresAt,
                  ),
                ),
              );
            } catch (_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppText.text(context, 'withdraw_create_failed'),
                  ),
                ),
              );
            } finally {
              if (mounted) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            }
          },
        );
      },
    );
  }

  Widget _buildAvailableBalanceValue() {
    if (!_hasLoadedBalance) {
      return const Text(
        '...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return _buildBalanceNumber(_lastKnownTotalBalance);
  }

  Widget _buildBalanceNumber(double totalBalance) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _formatBalanceAmount(totalBalance),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'VND',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCardText() {
    final _WithdrawSourceCardOption? selected = _findSelectedSourceCard();
    final String display =
        selected?.account ?? AppText.text(context, 'loading');

    return Text(
      display,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildSourceCardSelector() {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomCardSelector(
      uid: uid,
      selectedCardId: _selectedCardId,
      margin: const EdgeInsets.only(bottom: 14),
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      textColor: Colors.white,
      onChanged: (CustomCardSelection selection) {
        final _WithdrawSourceCardOption synthetic = _WithdrawSourceCardOption(
          id: selection.id,
          title: selection.title,
          account: selection.account,
          balance: selection.balance,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _selectedCardId = selection.id;
          _sourceCards = <_WithdrawSourceCardOption>[synthetic];
          _lastKnownTotalBalance = selection.balance;
          _hasLoadedBalance = true;
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF2239E2),
            _brandColor,
            const Color(0xFF031A90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.credit_card, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppText.text(context, 'source_account'),
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildSourceCardText(),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white.withValues(alpha: 0.13)),
                ),
                _buildSourceCardSelector(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppText.text(context, 'available_balance'),
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildAvailableBalanceValue(),
                      ],
                    ),
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.white.withValues(alpha: 0.34),
                      size: 40,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppText.text(context, 'enter_withdraw_amount'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF727C96),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                final String digits = newValue.text.replaceAll(
                  RegExp(r'\D'),
                  '',
                );
                if (digits.isEmpty) {
                  return const TextEditingValue(text: '');
                }

                final int? parsed = int.tryParse(digits);
                if (parsed == null) {
                  return oldValue;
                }

                final String formatted = NumberFormat(
                  '#,###',
                  'vi_VN',
                ).format(parsed);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E2745),
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFB2B8CA),
                fontWeight: FontWeight.w600,
              ),
              errorText: _amountErrorText,
              suffixIcon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppText.text(context, 'currency_vnd'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7F879E),
                    fontSize: 12,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 0,
                minWidth: 0,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _brandColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _brandColor, width: 2),
              ),
            ),
            onChanged: _onAmountChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppText.text(context, 'quick_amount_selection'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF727C96),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _quickAmounts.length,
            itemBuilder: (context, index) {
              final int val = _quickAmounts[index];
              final bool isSelected = _selectedQuickAmount == val;
              return GestureDetector(
                onTap: () => _onQuickSelect(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? _brandColor : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: _brandColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : <BoxShadow>[],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatCurrency(val),
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _onSubmitCreateCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B1CA3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: !_isSubmitting ? 8 : 0,
          shadowColor: const Color(0xFF2B1CA3).withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_rounded),
            const SizedBox(width: 10),
            Text(
              AppText.text(context, 'create_code'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.shield, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          AppText.text(context, 'security_ssl_notice'),
          style: GoogleFonts.poppins(
            color: Colors.grey.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          AppText.text(context, 'no_valid_login_session'),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _withdrawHistoryStream(uid),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data!.docs;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  AppText.text(context, 'no_withdraw_history'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, int index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                    docs[index];
                return _WithdrawHistoryCard(
                  key: ValueKey<String>(doc.id),
                  docRef: doc.reference,
                  data: doc.data(),
                  formatCurrency: _formatCurrency,
                  formatDateTime: _formatDateTime,
                );
              },
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: CCPAppBar(title: AppText.text(context, 'atm_withdrawal')),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 20),
                    _buildAmountInput(),
                    const SizedBox(height: 16),
                    _buildQuickSelectGrid(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD6E0FF)),
                      ),
                      child: Text(
                        AppText.textWithParams(
                          context,
                          'withdraw_limit_text',
                          <String, String>{
                            'min': _formatIntAmount(_minWithdrawAmount),
                            'max': _formatIntAmount(_maxAllowedAmount),
                          },
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF405086),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                    _buildSecurityBadge(),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppText.text(context, 'withdraw_history'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildHistorySection(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WithdrawHistoryCard extends StatefulWidget {
  const _WithdrawHistoryCard({
    super.key,
    required this.docRef,
    required this.data,
    required this.formatCurrency,
    required this.formatDateTime,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;
  final String Function(int amount) formatCurrency;
  final String Function(DateTime value) formatDateTime;

  @override
  State<_WithdrawHistoryCard> createState() => _WithdrawHistoryCardState();
}

class _WithdrawHistoryCardState extends State<_WithdrawHistoryCard> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isMarkingExpired = false;
  bool _isCancellingCode = false;

  static const Duration _activeWindow = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _WithdrawHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String oldStatus = (oldWidget.data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String newStatus = (widget.data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String oldCode = (oldWidget.data['code'] ?? '').toString();
    final String newCode = (widget.data['code'] ?? '').toString();

    if (oldStatus != newStatus || oldCode != newCode) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  DateTime? _readCreatedAt() {
    final dynamic rawServer = widget.data['created_at'];
    if (rawServer is Timestamp) {
      return rawServer.toDate();
    }

    final dynamic rawClient = widget.data['created_at_client'];
    if (rawClient is Timestamp) {
      return rawClient.toDate();
    }

    return null;
  }

  String get _status {
    return (widget.data['status'] ?? '').toString().trim().toLowerCase();
  }

  Duration _computeRemaining() {
    final DateTime? createdAt = _readCreatedAt();
    if (createdAt == null) {
      return _activeWindow;
    }
    final Duration elapsed = DateTime.now().difference(createdAt);
    final Duration remaining = _activeWindow - elapsed;
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  Future<void> _markExpiredIfNeeded() async {
    if (_isMarkingExpired || _status != 'active') {
      return;
    }

    _isMarkingExpired = true;
    try {
      await widget.docRef.set(<String, dynamic>{
        'status': 'expired',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep UI responsive if status update fails.
    } finally {
      _isMarkingExpired = false;
    }
  }

  Future<void> _confirmCancelCode() async {
    if (_isCancellingCode || _status != 'active') {
      return;
    }

    await showCustomConfirmDialog(
      context: context,
      title: AppText.text(context, 'cancel_withdraw_code_title'),
      message: AppText.text(context, 'cancel_withdraw_code_confirm'),
      confirmText: AppText.text(context, 'btn_yes'),
      cancelText: AppText.text(context, 'btn_no'),
      confirmColor: const Color(0xFFB42318),
      onConfirm: _cancelCode,
    );
  }

  Future<void> _cancelCode() async {
    if (_isCancellingCode || _status != 'active' || !mounted) {
      return;
    }

    setState(() {
      _isCancellingCode = true;
    });

    try {
      await widget.docRef.set(<String, dynamic>{
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.text(context, 'withdraw_code_cancelled')),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.text(context, 'withdraw_cancel_failed')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancellingCode = false;
        });
      }
    }
  }

  void _syncTimer() {
    _countdownTimer?.cancel();

    if (_status != 'active') {
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
      return;
    }

    void tick() {
      final Duration next = _computeRemaining();
      if (!mounted) {
        return;
      }

      setState(() {
        _remaining = next;
      });

      if (next == Duration.zero) {
        _countdownTimer?.cancel();
        _markExpiredIfNeeded();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick();
    });
  }

  String _formatRemaining(Duration value) {
    final int minutes = value.inMinutes;
    final int seconds = value.inSeconds.remainder(60);
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final String code = (widget.data['code'] ?? '').toString();
    final int amount = (widget.data['amount'] as num?)?.toInt() ?? 0;
    final DateTime? createdAt = _readCreatedAt();

    final bool isActive = _status == 'active';
    final bool isExpired = _status == 'expired';
    final bool isSuccess = _status == 'success';
    final bool isCancelled = _status == 'cancelled';

    final Color borderColor = isActive
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFE4E7EC);

    String statusText;
    TextStyle statusStyle;

    if (isActive) {
      statusText = AppText.textWithParams(
        context,
        'remaining_time',
        <String, String>{'time': _formatRemaining(_remaining)},
      );
      statusStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1D4ED8),
        fontStyle: FontStyle.italic,
      );
    } else if (isSuccess) {
      statusText = AppText.text(context, 'title_withdraw');
      statusStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF15803D),
      );
    } else if (isExpired) {
      statusText = AppText.text(context, 'status_expired');
      statusStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF98A2B3),
      );
    } else if (isCancelled) {
      statusText = AppText.text(context, 'status_cancelled');
      statusStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFB42318),
      );
    } else {
      statusText = AppText.text(context, 'status_active');
      statusStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF344054),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.atm_rounded,
                color: isActive
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF667085),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppText.text(context, 'code_label')}: $code',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${AppText.text(context, 'payment_amount')}: ${widget.formatCurrency(amount)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF344054),
            ),
          ),
          if (createdAt != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${AppText.text(context, 'created_at_label')}: ${widget.formatDateTime(createdAt)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(statusText, style: statusStyle),
          if (isActive) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isCancellingCode ? null : _confirmCancelCode,
                icon: _isCancellingCode
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 16),
                label: Text(AppText.text(context, 'cancel_code')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFFDA29B)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WithdrawSourceCardOption {
  const _WithdrawSourceCardOption({
    required this.id,
    required this.title,
    required this.account,
    required this.balance,
  });

  final String id;
  final String title;
  final String account;
  final double balance;
}
