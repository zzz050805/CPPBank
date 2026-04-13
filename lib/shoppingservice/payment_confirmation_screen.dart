import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app_preferences.dart';
import '../core/app_translations.dart';
import '../l10n/app_text.dart';
import '../services/user_firestore_service.dart';
import '../services/card_number_service.dart';
import '../widget/custom_card_selector.dart';
import '../widget/pin_popup.dart';
import 'payment_success_screen.dart';
import 'service_model.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({
    super.key,
    required this.service,
    required this.selectedAmount,
  });

  final ServiceModel service;
  final int selectedAmount;

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _lightBlue = Color(0xFFEAF0FF);
  static const Color _silverGray = Color(0xFF98A2B3);

  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;
  late final Map<String, String?> _fieldErrors;
  TextEditingController? _emailController;

  bool _isProcessing = false;
  bool _isButtonEnabled = false;
  bool _isEmailValid = true;
  String? _selectedCardId;
  String _sourceAccount = '****';

  List<ServiceAccountField> get _accountFields => widget.service.accountFields;

  String get _languageCode => AppPreferences.instance.locale.languageCode;

  String _formatAmount(int value) {
    final String locale = _languageCode == 'en' ? 'en_US' : 'vi_VN';
    return NumberFormat.currency(
      locale: locale,
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  String _buildPackageLabel() {
    final String topUp = AppTranslations.getTextByCode(_languageCode, 'top_up');
    final String serviceName = widget.service.localizedName(_languageCode);
    return '$topUp ${_formatAmount(widget.selectedAmount)} $serviceName';
  }

  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  bool _isEmailType(ServiceAccountField field) {
    return field.type == ServiceAccountInputType.email ||
        field.type == ServiceAccountInputType.icloud;
  }

  void _onEmailChanged() {
    final String email = _emailController?.text.trim() ?? '';
    final bool nextIsValid = email.isEmpty ? true : _isValidEmail(email);
    if (_isEmailValid == nextIsValid) {
      return;
    }
    setState(() {
      _isEmailValid = nextIsValid;
    });
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

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return uid;
    }
    return '';
  }

  String _maskAccount(String raw) {
    final String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return raw.isEmpty ? '****' : raw;
    }
    return '**** ${digits.substring(digits.length - 4)}';
  }

  TextEditingController _controllerOf(ServiceAccountField field) {
    return _controllers[field.id]!;
  }

  String? _errorOf(ServiceAccountField field) {
    return _fieldErrors[field.id];
  }

  TextInputType _keyboardTypeFor(ServiceAccountField field) {
    switch (field.type) {
      case ServiceAccountInputType.phone:
      case ServiceAccountInputType.steamId:
        return TextInputType.number;
      case ServiceAccountInputType.email:
      case ServiceAccountInputType.icloud:
        return TextInputType.emailAddress;
      case ServiceAccountInputType.riotTag:
      case ServiceAccountInputType.userId:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _formattersFor(ServiceAccountField field) {
    final List<TextInputFormatter> formatters = <TextInputFormatter>[];
    if (field.digitsOnly) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    }
    if (field.maxLength != null) {
      formatters.add(LengthLimitingTextInputFormatter(field.maxLength));
    }
    if (formatters.isEmpty) {
      return null;
    }
    return formatters;
  }

  String? _validateField(ServiceAccountField field, String raw) {
    final String value = raw.trim();

    if (value.isEmpty) {
      return null;
    }

    if (_isEmailType(field)) {
      if (!_isValidEmail(value)) {
        return AppTranslations.getTextByCode(_languageCode, 'invalid_email');
      }
      if (field.type == ServiceAccountInputType.icloud &&
          !value.toLowerCase().endsWith('@icloud.com')) {
        return AppTranslations.getTextByCode(
          _languageCode,
          'invalid_icloud_email',
        );
      }
    }

    final String? regexPattern = field.regexPattern;
    if (regexPattern == null || regexPattern.isEmpty) {
      return null;
    }

    final bool valid = RegExp(regexPattern).hasMatch(value);
    if (valid) {
      return null;
    }

    return field.localizedErrorText(_languageCode) ??
        AppTranslations.getTextByCode(_languageCode, 'invalid_input');
  }

  String _fieldValue(ServiceAccountField field) {
    return _controllerOf(field).text.trim();
  }

  bool _isFormValid() {
    if (_accountFields.isEmpty) {
      return false;
    }

    if (!_isEmailValid) {
      return false;
    }

    for (final ServiceAccountField field in _accountFields) {
      final String value = _fieldValue(field);
      if (value.isEmpty) {
        return false;
      }
      final String? error = _validateField(field, value);
      if (error != null) {
        return false;
      }
    }

    return true;
  }

  void _onFormChanged() {
    bool shouldRebuild = false;

    bool nextIsEmailValid = true;
    for (final ServiceAccountField field in _accountFields) {
      if (!_isEmailType(field)) {
        continue;
      }
      final String value = _fieldValue(field);
      if (value.isNotEmpty && !_isValidEmail(value)) {
        nextIsEmailValid = false;
        break;
      }
    }
    if (_isEmailValid != nextIsEmailValid) {
      _isEmailValid = nextIsEmailValid;
      shouldRebuild = true;
    }

    for (final ServiceAccountField field in _accountFields) {
      final String? nextError = _validateField(field, _fieldValue(field));
      if (_fieldErrors[field.id] != nextError) {
        _fieldErrors[field.id] = nextError;
        shouldRebuild = true;
      }
    }

    final bool nextEnabled = _isFormValid();
    if (_isButtonEnabled != nextEnabled) {
      _isButtonEnabled = nextEnabled;
      shouldRebuild = true;
    }

    if (shouldRebuild && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSourceAccount() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await firestore
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, dynamic> userData =
          userDoc.data() ?? <String, dynamic>{};
      final String userAccount = CardNumberService.readCardNumber(userData);

      if (userAccount.trim().isNotEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sourceAccount = CardNumberService.formatCardNumber(userAccount);
        });
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> cardDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc('standard')
          .get();
      final String cardNumber = CardNumberService.readCardNumber(
        cardDoc.data() ?? <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _sourceAccount = cardNumber.isEmpty
            ? _maskAccount(uid)
            : CardNumberService.formatCardNumber(cardNumber);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceAccount = '****';
      });
    }
  }

  Map<String, String> _buildTargetAccountFields() {
    final Map<String, String> result = <String, String>{};
    for (final ServiceAccountField field in _accountFields) {
      result[field.id] = _fieldValue(field);
    }
    return result;
  }

  String _buildTargetAccountSummary(Map<String, String> fields) {
    final List<String> parts = <String>[];
    for (final ServiceAccountField field in _accountFields) {
      final String value = fields[field.id] ?? '';
      if (value.isEmpty) {
        continue;
      }
      parts.add('${field.localizedLabel(_languageCode)}: $value');
    }
    return parts.join(' | ');
  }

  String _formatNotificationAmount(int value) {
    final String locale = _languageCode == 'en' ? 'en_US' : 'vi_VN';
    return NumberFormat('#,###', locale).format(value);
  }

  String _resolvePaymentErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return _languageCode == 'en'
              ? 'You do not have permission to complete this payment.'
              : 'Ban khong co quyen thuc hien thanh toan nay.';
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return _languageCode == 'en'
              ? 'Network issue detected. Please try again.'
              : 'Mang dang loi. Vui long thu lai.';
        default:
          final String message = (error.message ?? '').trim();
          if (message.isNotEmpty) {
            return message;
          }
      }
    }

    if (error is Exception) {
      final String text = error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return AppTranslations.getText(context, 'payment_failed');
  }

  num _readBalance(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final String text = value.trim();
      if (text.isEmpty) {
        return 0;
      }
      return num.tryParse(text) ?? 0;
    }
    return 0;
  }

  Future<_ShoppingReceiptData> _processShoppingTransaction() async {
    final String uid = _resolveUid();
    if (uid.isEmpty) {
      throw Exception(
        AppTranslations.getTextByCode(_languageCode, 'no_valid_login_session'),
      );
    }

    if (!_isFormValid()) {
      throw Exception(
        AppTranslations.getTextByCode(
          _languageCode,
          'invalid_recipient_account',
        ),
      );
    }

    final String selectedCardId = (_selectedCardId ?? '').trim().toLowerCase();
    if (selectedCardId.isEmpty) {
      throw Exception(AppText.text(context, 'select_source_card'));
    }

    final Map<String, String> targetAccountFields = _buildTargetAccountFields();
    final String targetAccount = _buildTargetAccountSummary(
      targetAccountFields,
    );

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DateTime now = DateTime.now();
    final String transactionCode =
        'SHOP${now.microsecondsSinceEpoch.toString().substring(7)}';
    final String serviceName = widget.service.localizedName(_languageCode);
    final String packageName = _buildPackageLabel();
    final String amountText = _formatAmount(widget.selectedAmount);
    final String notificationAmountText =
        '${_formatNotificationAmount(widget.selectedAmount)} VND';
    final Map<String, String> bodyParams = <String, String>{
      'service': serviceName,
      'serviceName': serviceName,
      'amount': notificationAmountText,
    };

    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> standardCardRef = userRef
        .collection('cards')
        .doc('standard');
    final DocumentReference<Map<String, dynamic>> vipCardRef = userRef
        .collection('cards')
        .doc('vip');
    final DocumentReference<Map<String, dynamic>> shoppingRef = userRef
        .collection('Shopping')
        .doc();
    final DocumentReference<Map<String, dynamic>> notificationRef = userRef
        .collection('notifications')
        .doc();
    final DocumentReference<Map<String, dynamic>> transactionRef = userRef
        .collection('transactions')
        .doc();

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await transaction
          .get(userRef);
      if (!userDoc.exists) {
        throw Exception(
          AppTranslations.getTextByCode(
            _languageCode,
            'no_valid_login_session',
          ),
        );
      }

      final Map<String, dynamic> userData =
          userDoc.data() ?? <String, dynamic>{};
      final DocumentSnapshot<Map<String, dynamic>> standardCardSnap =
          await transaction.get(standardCardRef);
      final DocumentSnapshot<Map<String, dynamic>> vipCardSnap =
          await transaction.get(vipCardRef);
      final num paymentAmount = widget.selectedAmount;

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

      if (availableBalance < paymentAmount) {
        throw Exception(
          _languageCode == 'en' ? 'Insufficient balance.' : 'Số dư không đủ.',
        );
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
          ? _readBalance(standardCardData['balance'])
          : _readBalance(vipCardData['balance']);
      if (selectedBalance < paymentAmount) {
        throw Exception(
          _languageCode == 'en' ? 'Insufficient balance.' : 'Số dư không đủ.',
        );
      }

      if (useStandard) {
        transaction.set(standardCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-paymentAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        transaction.set(vipCardRef, <String, dynamic>{
          'balance': FieldValue.increment(-paymentAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.set(shoppingRef, <String, dynamic>{
        'uid': uid,
        'cardId': selectedCardId,
        'serviceId': widget.service.id,
        'serviceName': serviceName,
        'amount': widget.selectedAmount,
        'targetAccount': targetAccount,
        'timestamp': FieldValue.serverTimestamp(),
        'title': AppTranslations.getTextByCode(
          _languageCode,
          'shopping_payment_title',
        ),
        'type': 'shopping',
        'isNegative': true,
        'amountText': amountText,
        'packageName': packageName,
        'targetAccountFields': targetAccountFields,
        'transactionCode': transactionCode,
        'fee': 0,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, <String, dynamic>{
        'titleKey': 'notify_shopping_title',
        'bodyKey': 'notify_shopping_body',
        'bodyParams': bodyParams,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'shopping',
        'service': serviceName,
        'serviceName': serviceName,
        'targetAccount': targetAccount,
        'amount': widget.selectedAmount,
        'transactionCode': transactionCode,
        'cardId': selectedCardId,
        'relatedId': shoppingRef.id,
        'status': 'success',
        'isNegative': true,
        'isRead': false,
      });

      transaction.set(transactionRef, <String, dynamic>{
        'type': 'shopping',
        'amount': widget.selectedAmount,
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'timestamp_client': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'createdAt_client': Timestamp.fromDate(now),
        'serviceName': serviceName,
        'targetAccount': targetAccount,
        'transactionCode': transactionCode,
        'cardId': selectedCardId,
        'relatedId': shoppingRef.id,
        'isNegative': true,
      });
    });

    return _ShoppingReceiptData(
      transactionCode: transactionCode,
      serviceName: serviceName,
      packageName: packageName,
      targetAccount: targetAccount,
      targetAccountFields: targetAccountFields,
      amount: widget.selectedAmount,
      sourceAccount: _sourceAccount,
      createdAt: now,
      logoPath: widget.service.logoPath,
    );
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final _ShoppingReceiptData receipt = await _processShoppingTransaction();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            service: widget.service,
            amount: widget.selectedAmount,
            targetAccount: receipt.targetAccount,
            transactionCode: receipt.transactionCode,
            paidAt: receipt.createdAt,
            sourceAccount: receipt.sourceAccount,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_resolvePaymentErrorMessage(e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _silverGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _buildServiceValue() {
    return Row(
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _silverGray.withOpacity(0.25)),
          ),
          child: ClipOval(
            child: Image.asset(
              widget.service.logoPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.image_outlined,
                  size: 14,
                  color: _silverGray,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.service.localizedName(_languageCode),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  String _accountFieldHint(ServiceAccountField field) {
    if (_isEmailType(field)) {
      return AppTranslations.getTextByCodeWithParams(
        _languageCode,
        'enter_account_email',
        <String, String>{
          'serviceName': widget.service.localizedName(_languageCode),
        },
      );
    }
    return field.localizedHint(_languageCode);
  }

  Widget _buildAccountField(ServiceAccountField field, int index) {
    final TextEditingController controller = _controllerOf(field);
    final bool isLast = index == _accountFields.length - 1;
    final bool isEmailField = _isEmailType(field);
    final TextInputType keyboardType = _keyboardTypeFor(field);
    final List<TextInputFormatter>? inputFormatters = _formattersFor(field);
    final String? errorText = _errorOf(field);

    final Widget input = TextField(
      controller: controller,
      focusNode: _focusNodes[field.id],
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) {
        if (isLast) {
          FocusScope.of(context).unfocus();
        } else {
          FocusScope.of(
            context,
          ).requestFocus(_focusNodes[_accountFields[index + 1].id]);
        }
      },
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _primaryBlue,
      ),
      decoration: InputDecoration(
        hintText: _accountFieldHint(field),
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: _silverGray),
        filled: true,
        fillColor: isEmailField ? Colors.white : const Color(0xFFF6F8FC),
        prefixIcon: isEmailField
            ? Icon(Icons.email_outlined, color: Colors.grey[500], size: 20)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isEmailField ? 12 : 14),
          borderSide: BorderSide(
            color: isEmailField
                ? const Color(0xFFE5E7EB)
                : _silverGray.withOpacity(0.24),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isEmailField ? 12 : 14),
          borderSide: BorderSide(
            color: isEmailField
                ? const Color(0xFFE5E7EB)
                : _silverGray.withOpacity(0.24),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isEmailField ? 12 : 14),
          borderSide: BorderSide(
            color: isEmailField ? const Color(0xFFCBD5E1) : _primaryBlue,
            width: isEmailField ? 1.2 : 1.4,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            field.localizedLabel(_languageCode),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          isEmailField
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: input,
                )
              : input,
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              errorText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _controllers = <String, TextEditingController>{
      for (final ServiceAccountField field in _accountFields)
        field.id: TextEditingController(),
    };

    _focusNodes = <String, FocusNode>{
      for (final ServiceAccountField field in _accountFields)
        field.id: FocusNode(),
    };

    _fieldErrors = <String, String?>{
      for (final ServiceAccountField field in _accountFields) field.id: null,
    };

    for (final TextEditingController controller in _controllers.values) {
      controller.addListener(_onFormChanged);
    }

    for (final ServiceAccountField field in _accountFields) {
      if (_isEmailType(field)) {
        _emailController = _controllers[field.id];
        break;
      }
    }
    _emailController?.addListener(_onEmailChanged);

    _loadSourceAccount();
    _onFormChanged();
  }

  @override
  void dispose() {
    _emailController?.removeListener(_onEmailChanged);

    for (final TextEditingController controller in _controllers.values) {
      controller
        ..removeListener(_onFormChanged)
        ..dispose();
    }
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String totalText = _formatAmount(widget.selectedAmount);
    final String feeText = _languageCode == 'en' ? '0 VND' : '0đ';

    return Scaffold(
      backgroundColor: _lightBlue,
      appBar: AppBar(
        backgroundColor: _lightBlue,
        elevation: 0,
        centerTitle: true,
        foregroundColor: _primaryBlue,
        title: Text(
          AppTranslations.getText(context, 'confirm_payment'),
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < _accountFields.length; i++)
                      _buildAccountField(_accountFields[i], i),
                    const SizedBox(height: 2),
                    CustomCardSelector(
                      uid: _resolveUid(),
                      selectedCardId: _selectedCardId,
                      margin: const EdgeInsets.only(bottom: 12),
                      onChanged: (CustomCardSelection selection) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _selectedCardId = selection.id;
                          _sourceAccount = selection.account;
                        });
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _silverGray.withOpacity(0.20),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            AppTranslations.getText(
                              context,
                              'transaction_review',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalText,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(color: _silverGray.withOpacity(0.28)),
                          _detailRow(
                            AppTranslations.getText(context, 'from'),
                            Text(
                              _sourceAccount,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Divider(color: _silverGray.withOpacity(0.22)),
                          _detailRow(
                            AppTranslations.getText(context, 'service'),
                            _buildServiceValue(),
                          ),
                          Divider(color: _silverGray.withOpacity(0.22)),
                          _detailRow(
                            AppTranslations.getText(context, 'package'),
                            Text(
                              _buildPackageLabel(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Divider(color: _silverGray.withOpacity(0.22)),
                          _detailRow(
                            AppTranslations.getText(context, 'fee'),
                            Text(
                              feeText,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _silverGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _DashedDivider(color: _silverGray.withOpacity(0.35)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    AppTranslations.getText(context, 'total'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: const Color(0xFF0F2A8A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    totalText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      color: const Color(0xFF0F2A8A),
                                      fontWeight: FontWeight.w800,
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
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                color: _lightBlue,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_isButtonEnabled)
                        ? null
                        : () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) {
                                return PinPopupWidget(
                                  onSuccess: _handlePaymentSuccess,
                                );
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isButtonEnabled
                          ? _primaryBlue
                          : _silverGray.withOpacity(0.65),
                      disabledBackgroundColor: _silverGray.withOpacity(0.65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            AppTranslations.getText(context, 'confirm_and_pay'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const double thickness = 1;
    const double dashWidth = 6;
    const double dashGap = 4;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int dashCount = (constraints.maxWidth / (dashWidth + dashGap))
            .floor();

        return Row(
          children: List<Widget>.generate(dashCount, (int index) {
            return Container(
              width: dashWidth,
              height: thickness,
              margin: EdgeInsets.only(
                right: index == dashCount - 1 ? 0 : dashGap,
              ),
              color: color,
            );
          }),
        );
      },
    );
  }
}

class _ShoppingReceiptData {
  const _ShoppingReceiptData({
    required this.transactionCode,
    required this.serviceName,
    required this.packageName,
    required this.targetAccount,
    required this.targetAccountFields,
    required this.amount,
    required this.sourceAccount,
    required this.createdAt,
    required this.logoPath,
  });

  final String transactionCode;
  final String serviceName;
  final String packageName;
  final String targetAccount;
  final Map<String, String> targetAccountFields;
  final int amount;
  final String sourceAccount;
  final DateTime createdAt;
  final String logoPath;
}
