import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_text.dart';

const List<String> _kTransactionCollections = <String>[
  'Shopping',
  'shopping',
  'bill_payment',
  'pay_bill',
  'paybill',
  'phone_recharge',
  'recent_tranfer',
  'recent_transfer',
  'recent_transfers',
  'withdraw',
];

DateTime? parseTransactionTime(dynamic timeData) {
  if (timeData == null) {
    return null;
  }

  if (timeData is Timestamp) {
    return timeData.toDate();
  }

  if (timeData is DateTime) {
    return timeData;
  }

  if (timeData is int) {
    final int value = timeData;
    // Accept both seconds (10-digit) and milliseconds (13-digit) epochs.
    if (value.abs() < 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (timeData is String) {
    final String raw = timeData.trim();
    if (raw.isEmpty) {
      return null;
    }

    final DateTime? iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso;
    }

    const List<String> patterns = <String>[
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
      'd/M/yyyy HH:mm:ss',
      'd/M/yyyy HH:mm',
      'd/M/yyyy',
      'd-M-yyyy HH:mm:ss',
      'd-M-yyyy HH:mm',
      'd-M-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ];

    for (final String pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(raw);
      } catch (_) {
        // Try next known pattern.
      }
    }
  }

  return null;
}

DateTime? _extractTransactionTime(Map<String, dynamic> data) {
  return parseTransactionTime(data['timestamp']) ??
      parseTransactionTime(data['date']) ??
      parseTransactionTime(data['createdAt']) ??
      parseTransactionTime(data['updatedAt']) ??
      parseTransactionTime(data['time']) ??
      parseTransactionTime(data['paidAt']);
}

bool _isTimeInRange(DateTime? value, DateTimeRange range) {
  if (value == null) {
    return false;
  }
  return !value.isBefore(range.start) && value.isBefore(range.end);
}

String _transactionTypeFromCollection(String collectionName) {
  switch (collectionName) {
    case 'Shopping':
    case 'shopping':
      return 'Mua sắm';
    case 'bill_payment':
      return 'Thanh toán hóa đơn';
    case 'pay_bill':
    case 'paybill':
      return 'Chi trả hóa đơn';
    case 'phone_recharge':
      return 'Nạp điện thoại';
    case 'recent_tranfer':
    case 'recent_transfer':
    case 'recent_transfers':
      return 'Chuyển khoản';
    case 'withdraw':
      return 'Rút tiền';
    default:
      return collectionName;
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _primaryBlue = Color(0xFF000DC0);
  static const Color _pageBg = Color(0xFFF5F7FF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedTab = 0;
  late Stream<int> _totalTransactionsCountStream;

  static const List<({IconData icon, String vi, String en})> _tabConfig =
      <({IconData icon, String vi, String en})>[
        (icon: Icons.dashboard_rounded, vi: 'Dashboard', en: 'Dashboard'),
        (icon: Icons.people_alt_rounded, vi: 'Người dùng', en: 'Users'),
        (icon: Icons.price_change_rounded, vi: 'Dịch vụ', en: 'Services'),
        (icon: Icons.photo_library_rounded, vi: 'Banner', en: 'Banners'),
      ];

  @override
  void initState() {
    super.initState();
    _totalTransactionsCountStream = _allUsersTotalTransactionsCountStream()
        .asBroadcastStream();
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  CollectionReference<Map<String, dynamic>> _adminCollection(String path) {
    return _firestore.collection('admin').doc('settings').collection(path);
  }

  String _formatVnd(int amount) {
    return '${NumberFormat.decimalPattern('vi_VN').format(amount)} VND';
  }

  String _formatCommaAmount(double amount) {
    return '${NumberFormat('#,###', 'en_US').format(amount.round())} VND';
  }

  String _formatVndDouble(double amount) {
    return _formatVnd(amount.round());
  }

  List<int> _parsePositivePrices(List<dynamic> raw) {
    return raw
        .map((dynamic item) => int.tryParse(item.toString()) ?? 0)
        .where((int value) => value > 0)
        .toList(growable: false);
  }

  double _toDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      final double? direct = double.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }
      final String digits = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
      if (digits.isEmpty) {
        return 0;
      }
      return double.tryParse(digits) ?? 0;
    }
    return 0;
  }

  String _readUserName(Map<String, dynamic> data) {
    final String fullName = (data['fullName'] ?? '').toString().trim();
    final String fullname = (data['fullname'] ?? '').toString().trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (fullname.isNotEmpty) {
      return fullname;
    }
    return '-';
  }

  String _readUserAccount(Map<String, dynamic> data) {
    final String phone = (data['phoneNumber'] ?? '').toString().trim();
    final String cccd = (data['cccd'] ?? '').toString().trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    if (cccd.isNotEmpty) {
      return cccd;
    }
    return '-';
  }

  String _readUserPhone(Map<String, dynamic> data) {
    final String phone = (data['phoneNumber'] ?? '').toString().trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    return '-';
  }

  String _readUserCccd(Map<String, dynamic> data) {
    final String cccd = (data['cccd'] ?? data['idNumber'] ?? '')
        .toString()
        .trim();
    if (cccd.isNotEmpty) {
      return cccd;
    }
    return '-';
  }

  String _readUserAddress(Map<String, dynamic> data) {
    final String address =
        (data['address'] ??
                data['homeAddress'] ??
                data['permanentAddress'] ??
                '')
            .toString()
            .trim();
    if (address.isNotEmpty) {
      return address;
    }
    return '-';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return _firestore
        .collection('users')
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _cardsStream() {
    return _firestore
        .collectionGroup('cards')
        .snapshots(includeMetadataChanges: true);
  }

  Map<String, _UserCardBalances> _buildCardBalancesByUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, _UserCardBalances> result = <String, _UserCardBalances>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final DocumentReference<Map<String, dynamic>>? userRef =
          doc.reference.parent.parent;
      if (userRef == null || userRef.parent.id != 'users') {
        continue;
      }

      final String cardId = doc.id.toLowerCase();
      final _UserCardBalances current =
          result[userRef.id] ?? const _UserCardBalances();
      final double balance = _toDouble(doc.data()['balance']);

      if (cardId == 'standard') {
        result[userRef.id] = current.copyWith(balanceNormal: balance);
      } else if (cardId == 'vip') {
        result[userRef.id] = current.copyWith(balanceVip: balance);
      }
    }

    return result;
  }

  double _readUserNormalBalance(Map<String, dynamic> data) {
    return _toDouble(
      data['balance_normal'] ??
          data['standardBalance'] ??
          data['balanceNormal'] ??
          data['balance'] ??
          0,
    );
  }

  double _readUserVipBalance(Map<String, dynamic> data) {
    return _toDouble(
      data['balance_vip'] ?? data['vipBalance'] ?? data['balanceVip'] ?? 0,
    );
  }

  double _readUserTotalBalance(Map<String, dynamic> data) {
    return _readUserNormalBalance(data) + _readUserVipBalance(data);
  }

  double _parseBalanceInput(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return 0;
    }

    return double.tryParse(digitsOnly) ?? 0;
  }

  void _openUsersManagementTab() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTab = 1;
    });
  }

  DateTimeRange _rangeForFilter(
    _AdminHistoryFilterType filterType,
    DateTime selectedPoint,
  ) {
    final DateTime base = DateTime(
      selectedPoint.year,
      selectedPoint.month,
      selectedPoint.day,
    );

    switch (filterType) {
      case _AdminHistoryFilterType.day:
        return DateTimeRange(
          start: base,
          end: base.add(const Duration(days: 1)),
        );
      case _AdminHistoryFilterType.month:
        final DateTime monthStart = DateTime(base.year, base.month, 1);
        final DateTime monthEnd = DateTime(base.year, base.month + 1, 1);
        return DateTimeRange(start: monthStart, end: monthEnd);
      case _AdminHistoryFilterType.year:
        final DateTime yearStart = DateTime(base.year, 1, 1);
        final DateTime yearEnd = DateTime(base.year + 1, 1, 1);
        return DateTimeRange(start: yearStart, end: yearEnd);
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _readUserSubCollectionDocs({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String subCollection,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await userRef
          .collection(subCollection)
          .get();
      return snapshot.docs;
    } catch (_) {
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _deepScanAllTransactions({
    _AdminHistoryFilterType? filterType,
    DateTime? selectedPoint,
  }) async {
    final DateTimeRange? range = (filterType != null && selectedPoint != null)
        ? _rangeForFilter(filterType, selectedPoint)
        : null;
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .get();

    final List<Future<List<Map<String, dynamic>>>> userTasks = usersSnapshot
        .docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> userDoc) async {
          final String userName = _readUserName(userDoc.data());
          final DocumentReference<Map<String, dynamic>> userRef =
              userDoc.reference;

          final List<Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
          subCollectionTasks = _kTransactionCollections
              .map(
                (String subCollection) => _readUserSubCollectionDocs(
                  userRef: userRef,
                  subCollection: subCollection,
                ),
              )
              .toList(growable: false);

          final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          subCollectionResults = await Future.wait(subCollectionTasks);

          final List<Map<String, dynamic>> transactionsForUser =
              <Map<String, dynamic>>[];

          for (int i = 0; i < subCollectionResults.length; i++) {
            final String subCollection = _kTransactionCollections[i];
            final String transactionType = _transactionTypeFromCollection(
              subCollection,
            );

            for (final QueryDocumentSnapshot<Map<String, dynamic>> txDoc
                in subCollectionResults[i]) {
              final Map<String, dynamic> txData = Map<String, dynamic>.from(
                txDoc.data(),
              );
              final DateTime? parsedTime = _extractTransactionTime(txData);
              if (range != null && !_isTimeInRange(parsedTime, range)) {
                continue;
              }

              txData['userId'] = userDoc.id;
              txData['userName'] = userName;
              txData['transactionType'] = transactionType;
              txData['_parsedTime'] = parsedTime;
              txData['_sourceCollection'] = subCollection;
              transactionsForUser.add(txData);
            }
          }

          return transactionsForUser;
        })
        .toList(growable: false);

    final List<List<Map<String, dynamic>>> userResults = await Future.wait(
      userTasks,
    );
    final List<Map<String, dynamic>> allTransactions =
        userResults
            .expand((List<Map<String, dynamic>> userTx) => userTx)
            .toList(growable: false)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final DateTime? atA = a['_parsedTime'] as DateTime?;
            final DateTime? atB = b['_parsedTime'] as DateTime?;
            if (atA == null && atB == null) {
              return 0;
            }
            if (atA == null) {
              return 1;
            }
            if (atB == null) {
              return -1;
            }
            return atB.compareTo(atA);
          });

    return allTransactions;
  }

  List<_AdminUserTransactionStat> _buildUserStatsFromTransactions(
    List<Map<String, dynamic>> allTransactions,
  ) {
    final Map<String, ({String userName, int count})> byUser =
        <String, ({String userName, int count})>{};

    for (final Map<String, dynamic> tx in allTransactions) {
      final String userId = (tx['userId'] ?? '').toString();
      if (userId.isEmpty) {
        continue;
      }
      final String userName = (tx['userName'] ?? '-').toString();
      final ({String userName, int count}) current =
          byUser[userId] ?? (userName: userName, count: 0);
      byUser[userId] = (userName: current.userName, count: current.count + 1);
    }

    final List<_AdminUserTransactionStat> stats =
        byUser.entries
            .map(
              (MapEntry<String, ({String userName, int count})> entry) =>
                  _AdminUserTransactionStat(
                    userId: entry.key,
                    userName: entry.value.userName,
                    count: entry.value.count,
                  ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final int countDiff = b.count.compareTo(a.count);
            if (countDiff != 0) {
              return countDiff;
            }
            return a.userName.compareTo(b.userName);
          });

    return stats;
  }

  Stream<List<_AdminUserTransactionStat>> _allUsersTransactionStatsStream({
    required _AdminHistoryFilterType filterType,
    required DateTime selectedPoint,
  }) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> usersTrigger = _firestore
        .collection('users')
        .snapshots(includeMetadataChanges: true);
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> sourceTriggers =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collectionGroup(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return MergeStream<Object>(<Stream<Object>>[
      usersTrigger,
      ...sourceTriggers,
    ]).startWith(const Object()).switchMap((Object _) {
      return Stream.fromFuture(
        _deepScanAllTransactions(
          filterType: filterType,
          selectedPoint: selectedPoint,
        ).then(_buildUserStatsFromTransactions),
      );
    }).asBroadcastStream();
  }

  Stream<int> _allUsersTotalTransactionsCountStream() {
    final Stream<QuerySnapshot<Map<String, dynamic>>> usersTrigger = _firestore
        .collection('users')
        .snapshots(includeMetadataChanges: true);
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> sourceTriggers =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collectionGroup(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return MergeStream<Object>(<Stream<Object>>[
      usersTrigger,
      ...sourceTriggers,
    ]).startWith(const Object()).switchMap((Object _) {
      return Stream.fromFuture(
        _deepScanAllTransactions().then(
          (List<Map<String, dynamic>> allTransactions) =>
              allTransactions.length,
        ),
      );
    });
  }

  Future<void> _showSystemBalancesOverlay() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'system-balance-overlay',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 860,
                        maxHeight: 620,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _t(
                                      'Tổng số dư hệ thống theo người dùng',
                                      'System balances by user',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: _usersStream(),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >
                                      snapshot,
                                    ) {
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final List<
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >
                                      users =
                                          snapshot.data!.docs.toList(
                                            growable: false,
                                          )..sort((a, b) {
                                            final String aName = _readUserName(
                                              a.data(),
                                            );
                                            final String bName = _readUserName(
                                              b.data(),
                                            );
                                            return aName.compareTo(bName);
                                          });

                                      if (users.isEmpty) {
                                        return Center(
                                          child: Text(
                                            _t(
                                              'Chưa có user',
                                              'No users found',
                                            ),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        );
                                      }

                                      return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: _cardsStream(),
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<
                                                QuerySnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >
                                              cardsSnapshot,
                                            ) {
                                              final Map<
                                                String,
                                                _UserCardBalances
                                              >
                                              cardBalancesByUser =
                                                  cardsSnapshot.hasData
                                                  ? _buildCardBalancesByUser(
                                                      cardsSnapshot.data!.docs,
                                                    )
                                                  : const <
                                                      String,
                                                      _UserCardBalances
                                                    >{};

                                              return SingleChildScrollView(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: DataTable(
                                                    columnSpacing: 22,
                                                    headingRowHeight: 44,
                                                    dataRowMinHeight: 50,
                                                    dataRowMaxHeight: 56,
                                                    columns: <DataColumn>[
                                                      DataColumn(
                                                        label: Text(
                                                          _t('Tên', 'Name'),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                          _t(
                                                            'Số dư Thẻ thường',
                                                            'Normal Card Balance',
                                                          ),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                          _t(
                                                            'Số dư Thẻ VIP',
                                                            'VIP Card Balance',
                                                          ),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                    rows: users
                                                        .map((
                                                          QueryDocumentSnapshot<
                                                            Map<String, dynamic>
                                                          >
                                                          doc,
                                                        ) {
                                                          final Map<
                                                            String,
                                                            dynamic
                                                          >
                                                          data = doc.data();
                                                          final _UserCardBalances?
                                                          cardData =
                                                              cardBalancesByUser[doc
                                                                  .id];
                                                          final double
                                                          normalBalance =
                                                              cardData
                                                                  ?.balanceNormal ??
                                                              _readUserNormalBalance(
                                                                data,
                                                              );
                                                          final double
                                                          vipBalance =
                                                              cardData
                                                                  ?.balanceVip ??
                                                              _readUserVipBalance(
                                                                data,
                                                              );

                                                          return DataRow(
                                                            cells: <DataCell>[
                                                              DataCell(
                                                                Text(
                                                                  _readUserName(
                                                                    data,
                                                                  ),
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Text(
                                                                  _formatVndDouble(
                                                                    normalBalance,
                                                                  ),
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Text(
                                                                  _formatVndDouble(
                                                                    vipBalance,
                                                                  ),
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        })
                                                        .toList(
                                                          growable: false,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                      );
                                    },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
      transitionBuilder:
          (BuildContext context, Animation<double> animation, _, Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
    );
  }

  Future<void> _showTodayTransactionsByUserDialog() async {
    _AdminHistoryFilterType filterType = _AdminHistoryFilterType.day;
    DateTime selectedPoint = DateTime.now();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'today-transactions-overlay',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                String filterLabel() {
                  if (filterType == _AdminHistoryFilterType.day) {
                    return DateFormat('dd/MM/yyyy').format(selectedPoint);
                  }
                  if (filterType == _AdminHistoryFilterType.month) {
                    return DateFormat('MM/yyyy').format(selectedPoint);
                  }
                  return DateFormat('yyyy').format(selectedPoint);
                }

                Future<void> pickDate() async {
                  final DateTime now = DateTime.now();
                  final DateTime? picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: selectedPoint,
                    firstDate: DateTime(2000, 1, 1),
                    lastDate: DateTime(now.year + 2, 12, 31),
                    helpText: _t('Chọn mốc thời gian', 'Pick date point'),
                    cancelText: _t('Hủy', 'Cancel'),
                    confirmText: _t('Chọn', 'Select'),
                  );
                  if (picked == null) {
                    return;
                  }
                  setDialogState(() {
                    if (filterType == _AdminHistoryFilterType.day) {
                      selectedPoint = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    } else if (filterType == _AdminHistoryFilterType.month) {
                      selectedPoint = DateTime(picked.year, picked.month, 1);
                    } else {
                      selectedPoint = DateTime(picked.year, 1, 1);
                    }
                  });
                }

                return Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 760,
                            maxHeight: 640,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        _t(
                                          'Giao dịch theo User (đa nguồn)',
                                          'Transactions by user (multi-source)',
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    ChoiceChip(
                                      label: Text(
                                        _t('Hôm nay', 'Today'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.day,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.day;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        _t('Tháng này', 'This month'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.month,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.month;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        _t('Năm nay', 'This year'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected:
                                          filterType ==
                                          _AdminHistoryFilterType.year,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          filterType =
                                              _AdminHistoryFilterType.year;
                                        });
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: pickDate,
                                      icon: const Icon(
                                        Icons.event_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        filterLabel(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: StreamBuilder<List<_AdminUserTransactionStat>>(
                                    stream: _allUsersTransactionStatsStream(
                                      filterType: filterType,
                                      selectedPoint: selectedPoint,
                                    ),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<
                                            List<_AdminUserTransactionStat>
                                          >
                                          snapshot,
                                        ) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }

                                          final List<_AdminUserTransactionStat>
                                          stats =
                                              snapshot.data ??
                                              const <
                                                _AdminUserTransactionStat
                                              >[];
                                          if (stats.isEmpty) {
                                            return Center(
                                              child: Text(
                                                _t(
                                                  'Không có giao dịch trong khoảng thời gian đã chọn',
                                                  'No transactions in selected range',
                                                ),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }

                                          return ListView.separated(
                                            itemCount: stats.length,
                                            separatorBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) => const Divider(height: 1),
                                            itemBuilder: (BuildContext context, int index) {
                                              final _AdminUserTransactionStat
                                              item = stats[index];
                                              return ListTile(
                                                title: Text(
                                                  '${item.userName} - ${item.count} ${_t('giao dịch', 'transactions')}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                trailing: const Icon(
                                                  Icons.chevron_right_rounded,
                                                ),
                                                onTap: () {
                                                  Navigator.pop(dialogContext);
                                                  if (!mounted) {
                                                    return;
                                                  }
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          _AdminUserTransactionHistoryScreen(
                                                            userId: item.userId,
                                                            userName:
                                                                item.userName,
                                                            initialFilterType:
                                                                filterType,
                                                            initialSelectedPoint:
                                                                selectedPoint,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
      transitionBuilder:
          (BuildContext context, Animation<double> animation, _, Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
    );
  }

  List<_AdminUserSummary> _buildUserSummaries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    Map<String, _UserCardBalances> cardBalancesByUser =
        const <String, _UserCardBalances>{},
  }) {
    return docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final _UserCardBalances? cardBalances = cardBalancesByUser[doc.id];
          final double balanceNormal =
              cardBalances?.balanceNormal ?? _readUserNormalBalance(data);
          final double balanceVip =
              cardBalances?.balanceVip ?? _readUserVipBalance(data);
          final double totalBalance =
              cardBalances?.totalBalance ?? _readUserTotalBalance(data);

          return _AdminUserSummary(
            id: doc.id,
            fullName: _readUserName(data),
            account: _readUserAccount(data),
            phoneNumber: _readUserPhone(data),
            cccd: _readUserCccd(data),
            address: _readUserAddress(data),
            role: (data['role'] ?? 'user').toString(),
            isLocked: data['isLocked'] == true,
            balanceNormal: balanceNormal,
            balanceVip: balanceVip,
            totalBalance: totalBalance,
          );
        })
        .toList(growable: false);
  }

  Future<void> _showUserDetails(_AdminUserSummary user) async {
    final BuildContext parentContext = context;
    final TextEditingController nameController = TextEditingController(
      text: user.fullName == '-' ? '' : user.fullName,
    );
    final TextEditingController phoneController = TextEditingController(
      text: user.phoneNumber == '-' ? '' : user.phoneNumber,
    );
    final TextEditingController cccdController = TextEditingController(
      text: user.cccd == '-' ? '' : user.cccd,
    );
    final TextEditingController addressController = TextEditingController(
      text: user.address == '-' ? '' : user.address,
    );
    final TextEditingController normalBalanceController = TextEditingController(
      text: user.balanceNormal.round().toString(),
    );
    final TextEditingController vipBalanceController = TextEditingController(
      text: user.balanceVip.round().toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            22 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('Thông tin người dùng', 'User details'),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 10),
                _sheetTextField(
                  controller: nameController,
                  label: _t('Họ tên', 'Full name'),
                ),
                const SizedBox(height: 8),
                _sheetTextField(
                  controller: phoneController,
                  label: _t('Số điện thoại', 'Phone number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                _sheetTextField(
                  controller: cccdController,
                  label: _t('CCCD', 'Citizen ID'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                _sheetTextField(
                  controller: addressController,
                  label: _t('Địa chỉ nhà', 'Home address'),
                ),
                const SizedBox(height: 8),
                _sheetTextField(
                  controller: normalBalanceController,
                  label: _t('Số dư Thẻ Thường', 'Normal Card Balance'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                _sheetTextField(
                  controller: vipBalanceController,
                  label: _t('Số dư Thẻ VIP', 'VIP Card Balance'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          _t('Hủy', 'Cancel'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final String nextName = nameController.text.trim();
                          final String nextPhone = phoneController.text.trim();
                          final String nextCccd = cccdController.text.trim();
                          final String nextAddress = addressController.text
                              .trim();
                          final double nextNormalBalance = _parseBalanceInput(
                            normalBalanceController.text,
                          );
                          final double nextVipBalance = _parseBalanceInput(
                            vipBalanceController.text,
                          );
                          final double nextTotalBalance =
                              nextNormalBalance + nextVipBalance;

                          if (nextName.isEmpty) {
                            if (!parentContext.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _t(
                                    'Vui lòng nhập họ tên',
                                    'Please enter full name',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            final DocumentReference<Map<String, dynamic>>
                            userRef = _firestore
                                .collection('users')
                                .doc(user.id);
                            final WriteBatch batch = _firestore.batch();

                            batch.set(
                              userRef.collection('cards').doc('standard'),
                              <String, dynamic>{
                                'balance': nextNormalBalance,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );

                            batch.set(
                              userRef.collection('cards').doc('vip'),
                              <String, dynamic>{
                                'balance': nextVipBalance,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );

                            batch.set(userRef, <String, dynamic>{
                              'fullName': nextName,
                              'fullname': nextName,
                              'phoneNumber': nextPhone,
                              'cccd': nextCccd,
                              'idNumber': nextCccd,
                              'address': nextAddress,
                              'balance_normal': nextNormalBalance,
                              'balance_vip': nextVipBalance,
                              'balance': nextTotalBalance,
                              'totalBalance': nextTotalBalance,
                              'availableBalance': nextTotalBalance,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            await batch.commit();

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }

                            if (!parentContext.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Cập nhật thành công!'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          } catch (_) {
                            if (!parentContext.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _t('Cập nhật thất bại', 'Update failed'),
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        },
                        child: Text(
                          _t('Lưu', 'Save'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: GoogleFonts.poppins(
        fontWeight: readOnly ? FontWeight.w700 : FontWeight.w500,
        color: readOnly ? const Color(0xFF0F172A) : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBalanceChartCard(List<_AdminUserSummary> users) {
    final List<_AdminUserSummary> topUsers = users
        .take(6)
        .toList(growable: false);
    final double maxY = topUsers.isEmpty
        ? 1
        : (topUsers.first.totalBalance <= 0
              ? 1
              : topUsers.first.totalBalance * 1.2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Biểu đồ số dư user', 'User balance chart'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: topUsers.isEmpty
                ? Center(
                    child: Text(
                      _t('Chưa có dữ liệu', 'No data available'),
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF334155),
                          tooltipRoundedRadius: 8,
                          getTooltipItem:
                              (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
                                return BarTooltipItem(
                                  _formatCommaAmount(rod.toY),
                                  GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                );
                              },
                        ),
                      ),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int idx = value.toInt();
                              if (idx < 0 || idx >= topUsers.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${idx + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                NumberFormat.compact(
                                  locale: 'vi',
                                ).format(value),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List<BarChartGroupData>.generate(
                        topUsers.length,
                        (int index) => BarChartGroupData(
                          x: index,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: topUsers[index].totalBalance,
                              width: 18,
                              color: _primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (topUsers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List<Widget>.generate(topUsers.length, (int idx) {
                final _AdminUserSummary user = topUsers[idx];
                return Text(
                  '${idx + 1}. ${user.fullName}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserBalancesCard(List<_AdminUserSummary> users) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Tổng số dư từng user', 'User balances'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final _AdminUserSummary user = users[index];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showUserDetails(user),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: _primaryBlue.withValues(alpha: 0.12),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.account,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatVndDouble(user.totalBalance),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserLock(
    DocumentReference<Map<String, dynamic>> ref,
    bool next,
  ) async {
    await ref.set(<String, dynamic>{
      'isLocked': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _editPackagePrices(
    DocumentReference<Map<String, dynamic>> ref,
    List<dynamic> packages,
  ) async {
    final String initial = packages.map((dynamic e) => e.toString()).join(', ');
    final TextEditingController controller = TextEditingController(
      text: initial,
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _t('Sửa gói giá', 'Edit package prices'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _t(
                'Nhập giá mới, cách nhau bằng dấu phẩy',
                'Enter new prices separated by commas',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Hủy', 'Cancel'), style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final List<int> values = controller.text
                    .split(',')
                    .map((String e) => int.tryParse(e.trim()) ?? 0)
                    .where((int v) => v > 0)
                    .toList(growable: false);

                if (values.isEmpty) {
                  return;
                }

                await ref.set(<String, dynamic>{
                  'packages': values,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: Text(
                _t('Lưu', 'Save'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editBanner(
    DocumentReference<Map<String, dynamic>> ref,
    String imageUrl,
    bool isActive,
  ) async {
    final TextEditingController urlController = TextEditingController(
      text: imageUrl,
    );
    bool active = isActive;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _t('Sửa banner', 'Edit banner'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: _t(
                        'Link ảnh hoặc assets/...',
                        'Image URL or assets/...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: active,
                    onChanged: (bool value) {
                      setDialogState(() {
                        active = value;
                      });
                    },
                    title: Text(
                      _t('Đang hiển thị', 'Is active'),
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    _t('Hủy', 'Cancel'),
                    style: GoogleFonts.poppins(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String url = urlController.text.trim();
                    if (url.isEmpty) {
                      return;
                    }
                    await ref.set(<String, dynamic>{
                      'imageUrl': url,
                      'isActive': active,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    _t('Lưu', 'Save'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addBanner() async {
    final TextEditingController urlController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _t('Thêm banner', 'Add banner'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: _t(
                'Link ảnh hoặc assets/...',
                'Image URL or assets/...',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Hủy', 'Cancel'), style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final String url = urlController.text.trim();
                if (url.isEmpty) {
                  return;
                }

                final CollectionReference<Map<String, dynamic>> collection =
                    _adminCollection('home_banners');
                final DocumentReference<Map<String, dynamic>> ref = collection
                    .doc();

                await ref.set(<String, dynamic>{
                  'imageUrl': url,
                  'isActive': true,
                  'order': DateTime.now().millisecondsSinceEpoch,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: Text(
                _t('Thêm', 'Add'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cardsStream(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                cardsSnapshot,
              ) {
                final Map<String, _UserCardBalances> cardBalancesByUser =
                    cardsSnapshot.hasData
                    ? _buildCardBalancesByUser(cardsSnapshot.data!.docs)
                    : const <String, _UserCardBalances>{};

                final List<_AdminUserSummary> users = _buildUserSummaries(
                  docs,
                  cardBalancesByUser: cardBalancesByUser,
                )..sort((a, b) => b.totalBalance.compareTo(a.totalBalance));

                final int totalUsers = users.length;
                final double totalBalance = users.fold<double>(
                  0,
                  (double sum, _AdminUserSummary user) =>
                      sum + user.totalBalance,
                );

                return StreamBuilder<int>(
                  stream: _totalTransactionsCountStream,
                  builder:
                      (BuildContext context, AsyncSnapshot<int> txSnapshot) {
                        final String txCountText = txSnapshot.hasData
                            ? '${txSnapshot.data ?? 0}'
                            : '...';

                        return LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final double width = constraints.maxWidth;
                                final int crossAxisCount = width >= 1200
                                    ? 3
                                    : width >= 760
                                    ? 2
                                    : 1;
                                final double childAspectRatio =
                                    crossAxisCount == 1 ? 2.55 : 3.1;

                                final List<Widget> metricCards = <Widget>[
                                  _metricCard(
                                    title: _t('Tổng User', 'Total users'),
                                    value: '$totalUsers',
                                    icon: Icons.people_alt_rounded,
                                    onTap: _openUsersManagementTab,
                                  ),
                                  _metricCard(
                                    title: _t(
                                      'Tổng số dư hệ thống',
                                      'System total balance',
                                    ),
                                    value: _formatVndDouble(totalBalance),
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: _showSystemBalancesOverlay,
                                  ),
                                  _metricCard(
                                    title: _t('Giao dịch', 'Transactions'),
                                    value: txCountText,
                                    icon: Icons.receipt_long_rounded,
                                    onTap: _showTodayTransactionsByUserDialog,
                                  ),
                                ];

                                final Widget metricsSection =
                                    crossAxisCount == 1
                                    ? Column(
                                        children: metricCards
                                            .map(
                                              (Widget card) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Center(
                                                  child: FractionallySizedBox(
                                                    widthFactor: 0.9,
                                                    child: card,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(growable: false),
                                      )
                                    : GridView.count(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: childAspectRatio,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        children: metricCards,
                                      );

                                return ListView(
                                  children: <Widget>[
                                    metricsSection,
                                    const SizedBox(height: 14),
                                    _buildBalanceChartCard(users),
                                    const SizedBox(height: 14),
                                    _buildUserBalancesCard(users),
                                  ],
                                );
                              },
                        );
                      },
                );
              },
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cardsStream(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                cardsSnapshot,
              ) {
                final Map<String, _UserCardBalances> cardBalancesByUser =
                    cardsSnapshot.hasData
                    ? _buildCardBalancesByUser(cardsSnapshot.data!.docs)
                    : const <String, _UserCardBalances>{};

                final List<_AdminUserSummary> users = _buildUserSummaries(
                  docs,
                  cardBalancesByUser: cardBalancesByUser,
                );

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 18,
                          horizontalMargin: 10,
                          headingRowHeight: 44,
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: 58,
                          columns: <DataColumn>[
                            DataColumn(
                              label: Text(
                                _t('Họ tên', 'Full name'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                _t('Trạng thái', 'Status'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                _t('Hành động', 'Action'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          rows: users
                              .map((_AdminUserSummary user) {
                                final bool canToggle = user.role != 'admin';
                                final DocumentReference<Map<String, dynamic>>
                                ref = _firestore
                                    .collection('users')
                                    .doc(user.id);

                                return DataRow(
                                  cells: <DataCell>[
                                    DataCell(
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _showUserDetails(user),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            user.fullName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        user.isLocked
                                            ? _t('Đã khóa', 'Locked')
                                            : _t('Đang hoạt động', 'Active'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: user.isLocked
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ElevatedButton(
                                        onPressed: canToggle
                                            ? () => _toggleUserLock(
                                                ref,
                                                !user.isLocked,
                                              )
                                            : null,
                                        child: Text(
                                          user.isLocked
                                              ? _t('Mở khóa', 'Unlock')
                                              : _t('Khóa', 'Lock'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    );
                  },
                );
              },
        );
      },
    );
  }

  Widget _buildServicesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _adminCollection('services_pricing')
          .where('kind', isEqualTo: 'shopping_bundle')
          .snapshots(includeMetadataChanges: true),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs.toList(growable: false)..sort((a, b) {
              final String aName = (a.data()['nameVi'] ?? a.id).toString();
              final String bName = (b.data()['nameVi'] ?? b.id).toString();
              return aName.compareTo(bName);
            });

        if (docs.isEmpty) {
          return Center(
            child: Text(
              _t('Chưa có dịch vụ để quản lý', 'No services available yet'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
            final Map<String, dynamic> data = doc.data();
            final String name = _t(
              (data['nameVi'] ?? doc.id).toString(),
              (data['nameEn'] ?? doc.id).toString(),
            );
            final String logoPath = (data['logoPath'] ?? '').toString();
            final List<int> values = _parsePositivePrices(
              (data['packages'] as List<dynamic>?) ?? <dynamic>[],
            );
            final String priceLabel = values.isEmpty
                ? _t('Chưa có mức giá', 'No prices yet')
                : values.map(_formatVnd).join(' | ');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoPath.startsWith('http')
                        ? Image.network(
                            logoPath,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                          )
                        : Image.asset(
                            logoPath,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475467),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _t('Chỉnh sửa giá', 'Edit prices'),
                    onPressed: () => _editPackagePrices(doc.reference, values),
                    icon: const Icon(Icons.edit_rounded),
                    color: _primaryBlue,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _adminCollection('home_banners')
          .orderBy('order', descending: false)
          .snapshots(includeMetadataChanges: true),
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addBanner,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(
                  _t('Thêm banner', 'Add banner'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                      docs[index];
                  final Map<String, dynamic> data = doc.data();
                  final String imageUrl = (data['imageUrl'] ?? '').toString();
                  final bool isActive = data['isActive'] == true;

                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 64,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFECEFF8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const Icon(
                                        Icons.broken_image_outlined,
                                      );
                                    },
                              )
                            : Image.asset(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const Icon(
                                        Icons.image_not_supported_outlined,
                                      );
                                    },
                              ),
                      ),
                      title: Text(
                        imageUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      subtitle: Text(
                        isActive
                            ? _t('Đang hiển thị', 'Active')
                            : _t('Đã ẩn', 'Hidden'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () =>
                                _editBanner(doc.reference, imageUrl, isActive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildServicesTab();
      case 3:
        return _buildBannersTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _sidebarItem({
    required int index,
    required IconData icon,
    required String label,
    bool compact = false,
  }) {
    final bool selected = _selectedTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      splashColor: _primaryBlue.withValues(alpha: 0.1),
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? _primaryBlue.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? _primaryBlue : Colors.grey.shade600),
            if (!compact) ...<Widget>[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _primaryBlue : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List<Widget>.generate(_tabConfig.length, (int index) {
            final ({IconData icon, String vi, String en}) tab =
                _tabConfig[index];

            return Padding(
              padding: EdgeInsets.only(
                right: index == _tabConfig.length - 1 ? 0 : 8,
              ),
              child: _mobileTabChip(
                index: index,
                icon: tab.icon,
                label: _t(tab.vi, tab.en),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _mobileTabChip({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _selectedTab == index;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? _primaryBlue.withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected
                ? _primaryBlue.withValues(alpha: 0.22)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? _primaryBlue : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _primaryBlue : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopSidebar(bool wide) {
    return Container(
      width: wide ? 260 : 86,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          Text(
            wide ? _t('Quản trị', 'Administration') : 'ADM',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          _sidebarItem(
            index: 0,
            icon: Icons.dashboard_rounded,
            label: _t('Dashboard', 'Dashboard'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 1,
            icon: Icons.people_alt_rounded,
            label: _t('Người dùng', 'Users'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 2,
            icon: Icons.price_change_rounded,
            label: _t('Dịch vụ', 'Services'),
            compact: !wide,
          ),
          _sidebarItem(
            index: 3,
            icon: Icons.photo_library_rounded,
            label: _t('Banner', 'Banners'),
            compact: !wide,
          ),
        ],
      ),
    );
  }

  Widget _contentPanel({EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _t('CCPBank Admin Dashboard', 'CCPBank Admin Dashboard'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: wide
          ? Row(
              children: <Widget>[
                _desktopSidebar(wide),
                Expanded(child: _contentPanel()),
              ],
            )
          : Column(
              children: <Widget>[
                _mobileTabBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: _contentPanel(margin: EdgeInsets.zero),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserCardBalances {
  const _UserCardBalances({this.balanceNormal = 0, this.balanceVip = 0});

  final double balanceNormal;
  final double balanceVip;

  double get totalBalance => balanceNormal + balanceVip;

  _UserCardBalances copyWith({double? balanceNormal, double? balanceVip}) {
    return _UserCardBalances(
      balanceNormal: balanceNormal ?? this.balanceNormal,
      balanceVip: balanceVip ?? this.balanceVip,
    );
  }
}

class _AdminUserSummary {
  const _AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.account,
    required this.phoneNumber,
    required this.cccd,
    required this.address,
    required this.role,
    required this.isLocked,
    required this.balanceNormal,
    required this.balanceVip,
    required this.totalBalance,
  });

  final String id;
  final String fullName;
  final String account;
  final String phoneNumber;
  final String cccd;
  final String address;
  final String role;
  final bool isLocked;
  final double balanceNormal;
  final double balanceVip;
  final double totalBalance;
}

enum _AdminHistoryFilterType { day, month, year }

class _AdminUserTransactionStat {
  const _AdminUserTransactionStat({
    required this.userId,
    required this.userName,
    required this.count,
  });

  final String userId;
  final String userName;
  final int count;
}

class _AdminMergedTransaction {
  const _AdminMergedTransaction({
    required this.sourceKey,
    required this.typeLabel,
    required this.amount,
    required this.occurredAt,
  });

  final String sourceKey;
  final String typeLabel;
  final double amount;
  final DateTime? occurredAt;
}

class _AdminUserTransactionHistoryScreen extends StatefulWidget {
  const _AdminUserTransactionHistoryScreen({
    required this.userId,
    required this.userName,
    required this.initialFilterType,
    required this.initialSelectedPoint,
  });

  final String userId;
  final String userName;
  final _AdminHistoryFilterType initialFilterType;
  final DateTime initialSelectedPoint;

  @override
  State<_AdminUserTransactionHistoryScreen> createState() =>
      _AdminUserTransactionHistoryScreenState();
}

class _AdminUserTransactionHistoryScreenState
    extends State<_AdminUserTransactionHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late _AdminHistoryFilterType _filterType;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _selectedDate = widget.initialSelectedPoint;
  }

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  DateTimeRange _currentRange() {
    final DateTime base = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    switch (_filterType) {
      case _AdminHistoryFilterType.day:
        return DateTimeRange(
          start: base,
          end: base.add(const Duration(days: 1)),
        );
      case _AdminHistoryFilterType.month:
        final DateTime monthStart = DateTime(base.year, base.month, 1);
        final DateTime monthEnd = DateTime(base.year, base.month + 1, 1);
        return DateTimeRange(start: monthStart, end: monthEnd);
      case _AdminHistoryFilterType.year:
        final DateTime yearStart = DateTime(base.year, 1, 1);
        final DateTime yearEnd = DateTime(base.year + 1, 1, 1);
        return DateTimeRange(start: yearStart, end: yearEnd);
    }
  }

  String _sourceLabel(String sourceKey) {
    switch (sourceKey) {
      case 'Shopping':
      case 'shopping':
        return _t('Mua sắm', 'Shopping');
      case 'bill_payment':
        return _t('Thanh toán hóa đơn', 'Bill payment');
      case 'pay_bill':
      case 'paybill':
        return _t('Chi trả hóa đơn', 'Pay bill');
      case 'phone_recharge':
        return _t('Nạp điện thoại', 'Phone recharge');
      case 'recent_tranfer':
      case 'recent_transfer':
      case 'recent_transfers':
        return _t('Chuyển khoản', 'Transfer');
      case 'withdraw':
        return _t('Rút tiền', 'Withdraw');
      default:
        return sourceKey;
    }
  }

  double _readAmount(Map<String, dynamic> data) {
    final dynamic raw =
        data['amount'] ??
        data['money'] ??
        data['transactionAmount'] ??
        data['price'] ??
        data['value'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final String clean = raw.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(clean) ?? 0;
    }
    return 0;
  }

  Stream<List<_AdminMergedTransaction>> _userTransactionsStream() {
    final DateTimeRange range = _currentRange();
    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams =
        _kTransactionCollections
            .map(
              (String source) => _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection(source)
                  .snapshots(includeMetadataChanges: true),
            )
            .toList(growable: false);

    return CombineLatestStream.list<QuerySnapshot<Map<String, dynamic>>>(
      streams,
    ).map((List<QuerySnapshot<Map<String, dynamic>>> snapshots) {
      final List<_AdminMergedTransaction> merged = <_AdminMergedTransaction>[];

      for (int i = 0; i < snapshots.length; i++) {
        final String sourceKey = _kTransactionCollections[i];
        final QuerySnapshot<Map<String, dynamic>> sourceSnapshot = snapshots[i];

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in sourceSnapshot.docs) {
          final Map<String, dynamic> data = doc.data();
          final DateTime? txTime = _extractTransactionTime(data);
          if (!_isTimeInRange(txTime, range)) {
            continue;
          }

          merged.add(
            _AdminMergedTransaction(
              sourceKey: sourceKey,
              typeLabel: _sourceLabel(sourceKey),
              amount: _readAmount(data),
              occurredAt: txTime,
            ),
          );
        }
      }

      merged.sort((a, b) {
        final DateTime? atA = a.occurredAt;
        final DateTime? atB = b.occurredAt;
        if (atA == null && atB == null) {
          return 0;
        }
        if (atA == null) {
          return 1;
        }
        if (atB == null) {
          return -1;
        }
        return atB.compareTo(atA);
      });

      return merged;
    });
  }

  String _selectedDateText() {
    switch (_filterType) {
      case _AdminHistoryFilterType.day:
        return DateFormat('dd/MM/yyyy').format(_selectedDate);
      case _AdminHistoryFilterType.month:
        return DateFormat('MM/yyyy').format(_selectedDate);
      case _AdminHistoryFilterType.year:
        return DateFormat('yyyy').format(_selectedDate);
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: _t('Chọn mốc thời gian', 'Pick date point'),
      cancelText: _t('Hủy', 'Cancel'),
      confirmText: _t('Chọn', 'Select'),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (_filterType == _AdminHistoryFilterType.day) {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      } else if (_filterType == _AdminHistoryFilterType.month) {
        _selectedDate = DateTime(picked.year, picked.month, 1);
      } else {
        _selectedDate = DateTime(picked.year, 1, 1);
      }
    });
  }

  String _formatMoney(double value) {
    return '${NumberFormat.decimalPattern('vi_VN').format(value.round())} VND';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _t(
            'Lịch sử giao dịch: ${widget.userName}',
            'Transaction history: ${widget.userName}',
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(
                          _t('Ngày', 'Day'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.day,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.day;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          _t('Tháng', 'Month'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.month,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.month;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          _t('Năm', 'Year'),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        selected: _filterType == _AdminHistoryFilterType.year,
                        onSelected: (_) {
                          setState(() {
                            _filterType = _AdminHistoryFilterType.year;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _t(
                            'Mốc lọc: ${_selectedDateText()}',
                            'Filter point: ${_selectedDateText()}',
                          ),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          _t('Chọn ngày', 'Pick date'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<List<_AdminMergedTransaction>>(
                  stream: _userTransactionsStream(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<_AdminMergedTransaction>> snapshot,
                      ) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final List<_AdminMergedTransaction> docs =
                            snapshot.data ?? const <_AdminMergedTransaction>[];

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              _t(
                                'Không có giao dịch trong khoảng thời gian đã chọn',
                                'No transactions in selected range',
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    _t(
                                      'Tổng ${docs.length} giao dịch',
                                      'Total ${docs.length} transactions',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 20,
                                    headingRowHeight: 42,
                                    dataRowMinHeight: 44,
                                    dataRowMaxHeight: 52,
                                    columns: <DataColumn>[
                                      DataColumn(
                                        label: Text(
                                          _t(
                                            'Loại giao dịch',
                                            'Transaction type',
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          _t('Số tiền', 'Amount'),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          _t('Thời gian', 'Time'),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: docs
                                        .map((_AdminMergedTransaction item) {
                                          final String timeText =
                                              item.occurredAt == null
                                              ? '-'
                                              : DateFormat(
                                                  'dd/MM/yyyy HH:mm',
                                                ).format(item.occurredAt!);
                                          return DataRow(
                                            cells: <DataCell>[
                                              DataCell(
                                                Text(
                                                  item.typeLabel,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  _formatMoney(item.amount),
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF0F766E,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  timeText,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
