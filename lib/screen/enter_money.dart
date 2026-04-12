import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/app_translations.dart';
import '../data/user_firestore_service.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'confirm_money.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: const TransferScreen(),
    );
  }
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    this.bankName,
    this.bankId,
    this.accountNumber,
    this.accountName,
    this.isAlreadySaved = false,
  });

  final String? bankName;
  final String? bankId;
  final String? accountNumber;
  final String? accountName;
  final bool isAlreadySaved;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class Bank {
  final String name;
  final String shortName;
  final String logo;
  final String bin;

  Bank({
    required this.name,
    required this.shortName,
    required this.logo,
    required this.bin,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      name: (json['name'] ?? '').toString(),
      shortName: (json['shortName'] ?? '').toString(),
      logo: (json['logo'] ?? '').toString(),
      bin: (json['bin'] ?? '').toString(),
    );
  }
}

class _TransferScreenState extends State<TransferScreen> {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color pageBackground = Color(0xFFF8F9FD);
  final NumberFormat _amountInputFormatter = NumberFormat('#,###', 'en_US');

  List<Bank> _banks = <Bank>[];
  Bank? _selectedBank;
  bool _isFetchingBanks = false;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  Timer? _lookupDebounce;
  String _recipientName = '';
  String _recipientLookupMessage = '';
  bool _isSaveContactPressed = false;
  bool _isLookingUpRecipient = false;
  bool _hasShownMissingApiKeySnackBar = false;
  int _lookupRequestId = 0;
  String? _amountError;
  bool _isProcessing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cardsSub;
  bool _hasVipCard = false;
  double _standardBalance = 0;
  double _vipBalance = 0;
  bool _hasUserSnapshot = false;
  bool _hasCardsSnapshot = false;
  bool _isFormattingAmountInput = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  void _applyIncomingPrefill() {
    final String incomingAccount = widget.accountNumber?.trim() ?? '';
    final String incomingName = widget.accountName?.trim() ?? '';

    if (incomingAccount.isNotEmpty) {
      _accountController.text = incomingAccount;
    }

    if (incomingName.isNotEmpty) {
      _recipientName = incomingName.toUpperCase();
      _recipientLookupMessage = '';
    }
  }

  String _normalizeBankKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Bank? _resolveIncomingBank(List<Bank> candidates) {
    if (candidates.isEmpty) {
      return null;
    }

    final String incomingBankId = (widget.bankId ?? '').trim().toLowerCase();
    final String incomingBankName = (widget.bankName ?? '').trim();

    if (incomingBankId.isNotEmpty) {
      final String normalizedIncomingId = _normalizeBankKey(incomingBankId);
      for (final Bank bank in candidates) {
        final String bankBin = bank.bin.trim().toLowerCase();
        final String bankShort = _normalizeBankKey(bank.shortName);
        final String bankName = _normalizeBankKey(bank.name);
        if (bankBin == incomingBankId ||
            bankShort == normalizedIncomingId ||
            bankName == normalizedIncomingId) {
          return bank;
        }
      }
    }

    if (incomingBankName.isNotEmpty) {
      final String normalizedIncomingName = _normalizeBankKey(incomingBankName);
      for (final Bank bank in candidates) {
        final String bankShort = _normalizeBankKey(bank.shortName);
        final String bankName = _normalizeBankKey(bank.name);
        if (bankShort == normalizedIncomingName ||
            bankName == normalizedIncomingName ||
            bankShort.contains(normalizedIncomingName) ||
            bankName.contains(normalizedIncomingName)) {
          return bank;
        }
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _applyIncomingPrefill();
    _bindBalanceStreams();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    setState(() {
      _isFetchingBanks = true;
    });

    try {
      final Uri uri = Uri.parse('https://api.vietqr.io/v2/banks');
      final headers = {
        'x-client-id': dotenv.env['VIETQR_CLIENT_ID'] ?? '',
        'x-api-key': dotenv.env['VIETQR_API_KEY'] ?? '',
        'Content-Type': 'application/json',
      };
      final http.Response response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Failed with status ${response.statusCode}');
      }

      final Map<String, dynamic> jsonBody =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> data =
          (jsonBody['data'] as List<dynamic>? ?? <dynamic>[]);

      final List<Bank> fetchedBanks = data
          .whereType<Map<String, dynamic>>()
          .map(Bank.fromJson)
          .where(
            (bank) =>
                bank.name.trim().isNotEmpty || bank.shortName.trim().isNotEmpty,
          )
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      final Bank preferredBank = fetchedBanks.firstWhere(
        (bank) =>
            bank.shortName.toLowerCase() == 'mb bank' ||
            bank.name.toLowerCase().contains('military') ||
            bank.bin == '970422',
        orElse: () => fetchedBanks.isNotEmpty
            ? fetchedBanks.first
            : Bank(name: '', shortName: '', logo: '', bin: ''),
      );

      final Bank? incomingBank = _resolveIncomingBank(fetchedBanks);

      setState(() {
        _banks = fetchedBanks;
        if (incomingBank != null) {
          _selectedBank = incomingBank;
        } else if (_selectedBank == null ||
            _selectedBank!.name.trim().isEmpty) {
          if (preferredBank.name.trim().isNotEmpty) {
            _selectedBank = preferredBank;
          } else if (_banks.isNotEmpty) {
            _selectedBank = _banks.first;
          }
        }
      });

      final String prefilledAccount = _accountController.text.trim();
      if (prefilledAccount.isNotEmpty &&
          (widget.accountName ?? '').trim().isEmpty) {
        _lookupAccountAPI(prefilledAccount);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      // Keep a small fallback list so transfer flow still works if API is down.
      final List<Bank> fallback = <Bank>[
        Bank(name: 'MB Bank', shortName: 'MB Bank', logo: '', bin: '970422'),
        Bank(
          name: 'Vietcombank',
          shortName: 'Vietcombank',
          logo: '',
          bin: '970436',
        ),
        Bank(name: 'BIDV', shortName: 'BIDV', logo: '', bin: '970418'),
        Bank(
          name: 'VietinBank',
          shortName: 'VietinBank',
          logo: '',
          bin: '970415',
        ),
      ];

      final Bank? incomingBank = _resolveIncomingBank(fallback);

      setState(() {
        _banks = fallback;
        _selectedBank = incomingBank ?? _selectedBank ?? fallback.first;
      });

      final String prefilledAccount = _accountController.text.trim();
      if (prefilledAccount.isNotEmpty &&
          (widget.accountName ?? '').trim().isEmpty) {
        _lookupAccountAPI(prefilledAccount);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingBanks = false;
        });
      }
    }
  }

  void _onAccountChanged(String value) {
    final String accountNumber = value.trim();
    if (mounted) {
      setState(() {
        _isSaveContactPressed = false;
      });
    }
    // ignore: avoid_print
    print('Đang tìm kiếm cho số thẻ: $accountNumber');

    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 500), () {
      _lookupAccountAPI(accountNumber);
    });
  }

  Future<String> _lookupRecipientFromFirestore(String accountNumber) async {
    final String normalizedAccount = accountNumber.trim();
    if (normalizedAccount.isEmpty) {
      return '';
    }

    final CollectionReference<Map<String, dynamic>> usersRef = FirebaseFirestore
        .instance
        .collection('users');

    // 1) Match by document id.
    final DocumentSnapshot<Map<String, dynamic>> doc = await usersRef
        .doc(normalizedAccount)
        .get();
    if (doc.exists) {
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    // 2) Match by phone number.
    final QuerySnapshot<Map<String, dynamic>> byCardSnake = await usersRef
        .where('card_number', isEqualTo: normalizedAccount)
        .limit(1)
        .get();
    if (byCardSnake.docs.isNotEmpty) {
      final Map<String, dynamic> data = byCardSnake.docs.first.data();
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> byCardCamel = await usersRef
        .where('cardNumber', isEqualTo: normalizedAccount)
        .limit(1)
        .get();
    if (byCardCamel.docs.isNotEmpty) {
      final Map<String, dynamic> data = byCardCamel.docs.first.data();
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> byLegacyAccount = await usersRef
        .where('accountNumber', isEqualTo: normalizedAccount)
        .limit(1)
        .get();
    if (byLegacyAccount.docs.isNotEmpty) {
      final Map<String, dynamic> data = byLegacyAccount.docs.first.data();
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    // 3) Match by phone number.
    final QuerySnapshot<Map<String, dynamic>> byPhone = await usersRef
        .where('phoneNumber', isEqualTo: normalizedAccount)
        .limit(1)
        .get();
    if (byPhone.docs.isNotEmpty) {
      final Map<String, dynamic> data = byPhone.docs.first.data();
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    // 4) Match by id number for legacy input behavior.
    final QuerySnapshot<Map<String, dynamic>> byIdNumber = await usersRef
        .where('idNumber', isEqualTo: normalizedAccount)
        .limit(1)
        .get();
    if (byIdNumber.docs.isNotEmpty) {
      final Map<String, dynamic> data = byIdNumber.docs.first.data();
      final String name = (data['fullname'] ?? data['fullName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return '';
  }

  Future<void> _lookupAccountAPI(String accountNumber) async {
    final String clientId = dotenv.get('VIETQR_CLIENT_ID', fallback: '');
    final String apiKey = dotenv.get('VIETQR_API_KEY', fallback: '');

    // ignore: avoid_print
    print('Kiểm tra .env: ${dotenv.env.keys}');
    // ignore: avoid_print
    print('Client ID: $clientId');

    final String normalizedAccount = accountNumber.trim();
    final String selectedBin = _selectedBank?.bin.trim() ?? '';
    final bool isMissingApiConfig = clientId.isEmpty || apiKey.isEmpty;

    // ignore: avoid_print
    print('Lookup BIN: $selectedBin');
    // ignore: avoid_print
    print('Lookup account: $normalizedAccount');

    if (normalizedAccount.length < 6) {
      if (mounted) {
        setState(() {
          _recipientName = '';
          _recipientLookupMessage = '';
          _isLookingUpRecipient = false;
        });
      }
      return;
    }

    final int requestId = ++_lookupRequestId;

    if (mounted) {
      setState(() {
        _isLookingUpRecipient = true;
        _recipientLookupMessage = _t(
          'Đang kiểm tra tên chủ thẻ...',
          'Looking up card holder name...',
        );
      });

      if (isMissingApiConfig && !_hasShownMissingApiKeySnackBar) {
        _hasShownMissingApiKeySnackBar = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Lỗi cấu hình API (thiếu Key)',
                'API configuration error (missing key)',
              ),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }

      if (!isMissingApiConfig) {
        _hasShownMissingApiKeySnackBar = false;
      }
    }

    try {
      String accountName = '';
      bool fromFirestoreFallback = false;

      if (selectedBin.isNotEmpty && !isMissingApiConfig) {
        final Uri uri = Uri.parse('https://api.vietqr.io/v2/lookup');
        final headers = {
          'x-client-id': clientId,
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        };
        final String body = jsonEncode(<String, dynamic>{
          'bin': selectedBin,
          'accountNumber': normalizedAccount,
          'accountNo': normalizedAccount,
        });

        final http.Response response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 12));

        // ignore: avoid_print
        print('VietQR lookup response: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonBody =
              json.decode(response.body) as Map<String, dynamic>;
          final String code = (jsonBody['code'] ?? '').toString();
          if (code == '00') {
            final Map<String, dynamic> data =
                (jsonBody['data'] as Map<String, dynamic>? ??
                <String, dynamic>{});
            accountName = (data['accountName'] ?? data['name'] ?? '')
                .toString()
                .trim();
          } else {
            // ignore: avoid_print
            print('VietQR returned non-success code: $code');
          }
        } else {
          // ignore: avoid_print
          print('VietQR HTTP error: ${response.statusCode}');
        }
      }

      if (accountName.isEmpty) {
        final String firestoreName = await _lookupRecipientFromFirestore(
          normalizedAccount,
        );
        if (firestoreName.trim().isNotEmpty) {
          accountName = firestoreName;
          fromFirestoreFallback = true;
        }
      }

      if (!mounted || requestId != _lookupRequestId) {
        return;
      }

      setState(() {
        _recipientName = accountName.toUpperCase();
        if (_recipientName.isEmpty) {
          _recipientLookupMessage = _t(
            'Không tìm thấy tên chủ thẻ cho số này.',
            'Cannot find card holder name for this card number.',
          );
        } else if (fromFirestoreFallback) {
          _recipientLookupMessage = _t(
            'Đã dùng dữ liệu tên trong hệ thống.',
            'Using account name from internal system.',
          );
        } else {
          _recipientLookupMessage = _t(
            'Đã xác thực tên chủ thẻ.',
            'Card holder verified.',
          );
        }
      });
    } on TimeoutException catch (_) {
      // ignore: avoid_print
      print('VietQR lookup timeout');

      if (!mounted || requestId != _lookupRequestId) {
        return;
      }

      final String fallbackName = await _lookupRecipientFromFirestore(
        normalizedAccount,
      );

      setState(() {
        _recipientName = fallbackName.toUpperCase();
        _recipientLookupMessage = _recipientName.isEmpty
            ? _t(
                'VietQR timeout và không có dữ liệu dự phòng.',
                'VietQR timeout and no fallback data found.',
              )
            : _t(
                'VietQR timeout, đã dùng dữ liệu hệ thống.',
                'VietQR timeout, using internal system data.',
              );
      });
    } catch (e) {
      // ignore: avoid_print
      print('VietQR lookup error: $e');
      if (!mounted || requestId != _lookupRequestId) {
        return;
      }

      final String fallbackName = await _lookupRecipientFromFirestore(
        normalizedAccount,
      );

      setState(() {
        _recipientName = fallbackName.toUpperCase();
        _recipientLookupMessage = _recipientName.isEmpty
            ? _t(
                'Không tra cứu được từ VietQR và cũng không thấy trong hệ thống.',
                'Lookup failed from VietQR and no matching user in system.',
              )
            : _t(
                'Không tra cứu được VietQR, đã dùng dữ liệu hệ thống.',
                'VietQR lookup failed, using internal system data.',
              );
      });
    } finally {
      if (mounted && requestId == _lookupRequestId) {
        setState(() {
          _isLookingUpRecipient = false;
        });
      }
    }
  }

  String? _resolveUid() {
    return FirebaseAuth.instance.currentUser?.uid ??
        UserFirestoreService.instance.currentUserDocId;
  }

  void _bindBalanceStreams() {
    final String? uid = _resolveUid();
    if (uid == null || uid.isEmpty) {
      return;
    }

    final CollectionReference<Map<String, dynamic>> cardsRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('cards');

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) {
            return;
          }

          setState(() {
            _hasVipCard = snapshot.data()?['hasVipCard'] == true;
            _hasUserSnapshot = true;
          });
        });

    _cardsSub = cardsRef.snapshots().listen(
      (snapshot) {
        double standardBalance = 0;
        double vipBalance = 0;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final String id = doc.id.toLowerCase();
          final double balance = _toDouble(doc.data()['balance']);
          if (id == 'standard') {
            standardBalance = balance;
          } else if (id == 'vip') {
            vipBalance = balance;
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _standardBalance = standardBalance;
          _vipBalance = vipBalance;
          _hasCardsSnapshot = true;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasCardsSnapshot = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _userSub?.cancel();
    _cardsSub?.cancel();
    _accountController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _validateAmount(String value) {
    final double amount = _parseAmount(value);

    setState(() {
      if (value.isEmpty) {
        _amountError = null;
      } else if (amount <= 0) {
        _amountError = _t(
          'Số tiền phải lớn hơn 0',
          'Amount must be greater than 0',
        );
      } else {
        _amountError = null;
      }
    });
  }

  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  String _formatAmountWithComma(String rawInput) {
    final String digits = _extractDigits(rawInput);
    if (digits.isEmpty) {
      return '';
    }

    final int value = int.tryParse(digits) ?? 0;
    if (value <= 0) {
      return '';
    }

    return _amountInputFormatter.format(value);
  }

  double _parseAmount(String input) {
    final String digits = _extractDigits(input);
    if (digits.isEmpty) {
      return 0;
    }
    return double.tryParse(digits) ?? 0;
  }

  void _onAmountChanged(String value) {
    if (_isFormattingAmountInput) {
      return;
    }

    final String formatted = _formatAmountWithComma(value);
    if (formatted != value) {
      _isFormattingAmountInput = true;
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isFormattingAmountInput = false;
    }

    _validateAmount(formatted);
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
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

  Future<void> _saveTransferContacts({
    required String accountNumber,
    required String accountName,
    required String bankName,
    required String bankId,
    required double amount,
  }) async {
    final String? uid = _resolveUid();
    if (uid == null || uid.isEmpty) {
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> userRef = firestore
        .collection('users')
        .doc(uid);

    await firestore.runTransaction((transaction) async {
      final CollectionReference<Map<String, dynamic>> savedRecipientsRef =
          userRef.collection('saved_recipients');
      final CollectionReference<Map<String, dynamic>> recentTransfersRef =
          userRef.collection('recent_transfers');

      final DocumentReference<Map<String, dynamic>> savedDocRef =
          savedRecipientsRef.doc(accountNumber);
      final DocumentSnapshot<Map<String, dynamic>> savedDoc = await transaction
          .get(savedDocRef);

      final Map<String, dynamic> payload = <String, dynamic>{
        'card_number': accountNumber,
        'cardNumber': accountNumber,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'bankName': bankName,
        'bankId': bankId,
        'initials': _deriveInitials(accountName),
        'timestamp': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> recentPayload = <String, dynamic>{
        ...payload,
        'amount': amount,
        'amountText': _amountInputFormatter.format(amount.round()),
        'currency': 'VND',
      };

      // Always keep transfer history for Recent list.
      final DocumentReference<Map<String, dynamic>> recentDocRef =
          recentTransfersRef.doc();
      transaction.set(recentDocRef, recentPayload);

      // Save recipient only when user explicitly taps Save.
      if (_isSaveContactPressed && !savedDoc.exists) {
        transaction.set(savedDocRef, payload);
      }
    });
  }

  Future<void> _handleTransfer() async {
    if (_isProcessing) {
      return;
    }

    final String accountNumber = _accountController.text.trim();
    final String amountRaw = _amountController.text.trim();
    final double amount = _parseAmount(amountRaw);

    if (accountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Số thẻ người nhận không được để trống.',
              'Recipient card number cannot be empty.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount <= 0) {
      setState(() {
        _amountError = _t(
          'Số tiền phải lớn hơn 0',
          'Amount must be greater than 0',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Số tiền phải lớn hơn 0', 'Amount must be greater than 0'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String recipientName = _recipientName.trim().isNotEmpty
        ? _recipientName.trim()
        : 'TRAN THANH B';
    final Bank? selectedBank = _selectedBank;
    final String recipientBankName =
        selectedBank?.shortName.trim().isNotEmpty == true
        ? selectedBank!.shortName.trim()
        : (selectedBank?.name.trim().isNotEmpty == true
              ? selectedBank!.name.trim()
              : 'MB Bank');
    final String recipientBankId = selectedBank?.bin.trim().isNotEmpty == true
        ? selectedBank!.bin.trim()
        : recipientBankName.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          );

    try {
      await _saveTransferContacts(
        accountNumber: accountNumber,
        accountName: recipientName,
        bankName: recipientBankName,
        bankId: recipientBankId,
        amount: amount,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Không thể lưu nhanh người nhận lúc này, bạn vẫn có thể tiếp tục giao dịch.',
                'Unable to save recipient quickly right now, you can still continue.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF7D859C),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmTransferScreen(
          amountText: amountRaw,
          transferContent: _messageController.text.trim(),
          recipientAccountNumber: accountNumber,
          recipientAccountName: recipientName,
          recipientBankName: recipientBankName,
          recipientBankId: recipientBankId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
    });
  }

  void _showBankPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _t('Chọn ngân hàng', 'Select bank'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: _isFetchingBanks
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: CircularProgressIndicator(color: primaryBlue),
                        ),
                      )
                    : _banks.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _t(
                                'Không tải được danh sách ngân hàng.',
                                'Unable to load banks.',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6C7388),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _fetchBanks();
                              },
                              child: Text(
                                _t('Tải lại', 'Retry'),
                                style: GoogleFonts.poppins(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _banks.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final Bank bank = _banks[index];
                          final bool selected =
                              _selectedBank != null &&
                              _selectedBank!.bin == bank.bin;
                          final String displayName =
                              bank.shortName.trim().isNotEmpty
                              ? bank.shortName
                              : bank.name;

                          return ListTile(
                            leading: _buildBankAvatar(bank.logo, size: 24),
                            title: Text(
                              displayName,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            subtitle:
                                bank.name.trim().isNotEmpty &&
                                    bank.name.trim() != displayName
                                ? Text(
                                    bank.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF7B8298),
                                    ),
                                  )
                                : null,
                            trailing: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: primaryBlue,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedBank = bank;
                                _isSaveContactPressed = false;
                              });
                              _lookupAccountAPI(_accountController.text);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankAvatar(String logoUrl, {double size = 24}) {
    final double iconSize = size * 0.6;
    final double radius = size * 0.28;

    if (logoUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          Icons.account_balance_rounded,
          size: iconSize,
          color: primaryBlue,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: iconSize,
              color: primaryBlue,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipientLookupBox() {
    final bool hasName = _recipientName.trim().isNotEmpty;
    final bool hasMessage = _recipientLookupMessage.trim().isNotEmpty;

    if (!hasName && !hasMessage && !_isLookingUpRecipient) {
      return const SizedBox.shrink();
    }

    final String displayText = _isLookingUpRecipient
        ? _recipientLookupMessage
        : (hasName ? _recipientName : _recipientLookupMessage);

    final Color backgroundColor = Colors.white;
    final Color borderColor = const Color(0xFFD4DCEE);
    final Color textColor = hasName ? primaryBlue : const Color(0xFF5F6780);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1A6A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Tên người nhận', 'Recipient name'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF7A8297),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: hasName ? 20 : 13,
                    color: textColor,
                    fontWeight: hasName ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasName && !widget.isAlreadySaved) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _isSaveContactPressed
                  ? null
                  : () {
                      setState(() {
                        _isSaveContactPressed = true;
                      });
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: BorderSide(
                  color: _isSaveContactPressed
                      ? const Color(0xFFB8CCFF)
                      : primaryBlue,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                minimumSize: const Size(78, 34),
              ),
              child: Text(
                _isSaveContactPressed
                    ? _t('✓ Đã lưu', '✓ Saved')
                    : _t('+ Lưu', '+ Save'),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _applyQuickAmount(int value) {
    final String formatted = _formatAmountWithComma(value.toString());
    _amountController.text = formatted;
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
    _validateAmount(formatted);
  }

  String _formatWithDot(int value) {
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

  String _formatCurrency(double value) {
    final int rounded = value.round();
    return '${_formatWithDot(rounded)} VND';
  }

  Widget _buildRealtimeAvailableBalance() {
    final String? uid = _resolveUid();

    if (uid == null || uid.isEmpty) {
      return Text(
        _t('Số dư khả dụng: --', 'Available balance: --'),
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF8A90A3),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (!_hasUserSnapshot || !_hasCardsSnapshot) {
      return Text(
        _t('Số dư khả dụng: --', 'Available balance: --'),
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF8A90A3),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final double availableBalance = _hasVipCard
        ? (_standardBalance + _vipBalance)
        : _standardBalance;

    return Text(
      '${_t('Số dư khả dụng', 'Available balance')}: ${_formatCurrency(availableBalance)}',
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: const Color(0xFF5E667F),
        fontWeight: FontWeight.w600,
      ),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000DC0),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Chuyển đến', 'Transfer to'),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C2236),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFDFF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDCE3F3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: _showBankPicker,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      10,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        _selectedBank != null
                                            ? _buildBankAvatar(
                                                _selectedBank!.logo,
                                                size: 20,
                                              )
                                            : const Icon(
                                                Icons.account_balance_rounded,
                                                size: 18,
                                                color: primaryBlue,
                                              ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _t(
                                                  'Ngân hàng thụ hưởng',
                                                  'Beneficiary bank',
                                                ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(
                                                    0xFF7A829A,
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedBank == null
                                                    ? _t(
                                                        'Chọn ngân hàng',
                                                        'Select bank',
                                                      )
                                                    : (_selectedBank!.shortName
                                                              .trim()
                                                              .isNotEmpty
                                                          ? _selectedBank!
                                                                .shortName
                                                          : _selectedBank!
                                                                .name),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF1D2438,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF7A829A),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFE4E9F5),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppTranslations.getText(
                                          context,
                                          'card_number_label',
                                        ),
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF5F6780),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _accountController,
                                        onChanged: _onAccountChanged,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(20),
                                        ],
                                        decoration: InputDecoration(
                                          hintText: _t(
                                            'Nhập số thẻ',
                                            'Enter card number',
                                          ),
                                          hintStyle: GoogleFonts.poppins(
                                            color: const Color(0xFF9AA1B5),
                                            fontSize: 15,
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 2,
                                                vertical: 8,
                                              ),
                                          border: InputBorder.none,
                                          suffixIconConstraints:
                                              const BoxConstraints(
                                                minWidth: 56,
                                              ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_accountController.text
                                                  .trim()
                                                  .isNotEmpty)
                                                GestureDetector(
                                                  onTap: () {
                                                    _accountController.clear();
                                                    _onAccountChanged('');
                                                    setState(() {});
                                                  },
                                                  child: const Icon(
                                                    Icons.cancel_rounded,
                                                    size: 18,
                                                    color: Color(0xFFA2AABC),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                _isLookingUpRecipient
                                                    ? Icons.sync_rounded
                                                    : Icons
                                                          .contact_page_outlined,
                                                size: 18,
                                                color: const Color(0xFF6D7590),
                                              ),
                                            ],
                                          ),
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 28,
                                          height: 1,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF232A3C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isLookingUpRecipient ||
                              _recipientName.trim().isNotEmpty ||
                              _recipientLookupMessage.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildRecipientLookupBox(),
                          ],
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
                          Text(
                            _t(
                              'Thông tin giao dịch',
                              'Transaction information',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2A2D3E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: Color(0xFF6B7389),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: _buildRealtimeAvailableBalance()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            onChanged: _onAmountChanged,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: _t('Nhập số tiền', 'Enter amount'),
                              hintStyle: GoogleFonts.poppins(
                                color: const Color(0xFFA1A8BC),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              suffixText: 'VND',
                              suffixStyle: GoogleFonts.poppins(
                                color: const Color(0xFF6A7186),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFBFF),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE6E9F2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: primaryBlue,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          if (_amountError != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                _amountError!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [50000, 100000, 500000, 1000000]
                                .map((amount) {
                                  final bool selected =
                                      _parseAmount(
                                        _amountController.text,
                                      ).round() ==
                                      amount;
                                  return ChoiceChip(
                                    label: Text(
                                      _formatWithDot(amount),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF50566B),
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: primaryBlue,
                                    backgroundColor: const Color(0xFFF1F3F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      side: BorderSide(
                                        color: selected
                                            ? primaryBlue
                                            : const Color(0xFFE0E5F0),
                                      ),
                                    ),
                                    onSelected: (_) =>
                                        _applyQuickAmount(amount),
                                  );
                                })
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 3,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              hintText: _t('Nhập lời nhắn', 'Enter message'),
                              hintStyle: GoogleFonts.poppins(
                                color: const Color(0xFF9AA1B5),
                                fontSize: 13,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 40),
                                child: Icon(
                                  Icons.notes_rounded,
                                  color: Color(0xFF6E768A),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFBFF),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE6E9F2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: primaryBlue,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2A2D3E),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
                  onPressed: _isProcessing ? null : _handleTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _t('Tiếp tục', 'Continue'),
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
      ),
    );
  }
}
