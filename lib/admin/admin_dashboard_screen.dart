import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_text.dart';

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

  static const List<({IconData icon, String vi, String en})> _tabConfig =
      <({IconData icon, String vi, String en})>[
        (icon: Icons.dashboard_rounded, vi: 'Dashboard', en: 'Dashboard'),
        (icon: Icons.people_alt_rounded, vi: 'Người dùng', en: 'Users'),
        (icon: Icons.price_change_rounded, vi: 'Dịch vụ', en: 'Services'),
        (icon: Icons.photo_library_rounded, vi: 'Banner', en: 'Banners'),
      ];

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

  Future<int> _fetchTodayTransactionsCount() async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final Timestamp startTs = Timestamp.fromDate(start);

    final List<String> collections = <String>[
      'pay_bill',
      'bill_payment',
      'phone_recharge',
      'recent_transfers',
      'withdraw',
      'Shopping',
    ];

    int total = 0;
    for (final String name in collections) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
            .collectionGroup(name)
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .get();
        total += snap.docs.length;
      } catch (_) {
        // Ignore missing-index / permission errors per group and continue.
      }
    }

    return total;
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

                return FutureBuilder<int>(
                  future: _fetchTodayTransactionsCount(),
                  builder:
                      (BuildContext context, AsyncSnapshot<int> txSnapshot) {
                        final int txToday = txSnapshot.data ?? 0;

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
                                  ),
                                  _metricCard(
                                    title: _t(
                                      'Tổng số dư hệ thống',
                                      'System total balance',
                                    ),
                                    value: _formatVndDouble(totalBalance),
                                    icon: Icons.account_balance_wallet_rounded,
                                  ),
                                  _metricCard(
                                    title: _t(
                                      'Giao dịch hôm nay',
                                      'Transactions today',
                                    ),
                                    value: '$txToday',
                                    icon: Icons.receipt_long_rounded,
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
  }) {
    return Container(
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
