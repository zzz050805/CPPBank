import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../data/user_firestore_service.dart';
import '../effect/gentle_page_route.dart';
import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';
import 'delete_account_otp_screen.dart';
import 'smart_otp_screen.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String get _notUpdated => _t('Chưa cập nhật', 'Not updated');

  String _displayValue(dynamic value) {
    if (value == null) return _notUpdated;
    final String text = value.toString().trim();
    return text.isEmpty ? _notUpdated : text;
  }

  bool _isMissing(String value) => value == _notUpdated;

  String _displayMembershipTier(dynamic rawTier) {
    final String text = rawTier?.toString().trim() ?? '';
    if (text.isEmpty) return _notUpdated;

    final String normalized = text.toLowerCase();
    if (normalized.contains('prive') ||
        normalized.contains('privé') ||
        normalized.contains('vip')) {
      return 'PRIVÉ';
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return _t('KIM CƯƠNG', 'DIAMOND');
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return _t('BẠCH KIM', 'PLATINUM');
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return _t('VÀNG', 'GOLD');
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return _t('BẠC', 'SILVER');
    }
    if (normalized.contains('thành viên') || normalized.contains('member')) {
      return _t('THÀNH VIÊN', 'MEMBER');
    }
    return text.toUpperCase();
  }

  String _localizedRankName(String rawName) {
    final String normalized = rawName.trim().toLowerCase();
    if (normalized.isEmpty) return rawName;

    if (normalized.contains('king')) {
      return _t('HẠNG KING', 'KING');
    }
    if (normalized.contains('royal')) {
      return _t('HẠNG ROYAL', 'ROYAL');
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return _t('HẠNG KIM CƯƠNG', 'DIAMOND');
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return _t('HẠNG BẠCH KIM', 'PLATINUM');
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return _t('HẠNG VÀNG', 'GOLD');
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return _t('HẠNG BẠC', 'SILVER');
    }
    if (normalized.contains('thành viên') || normalized.contains('member')) {
      return _t('THÀNH VIÊN', 'MEMBER');
    }
    return rawName.toUpperCase();
  }

  _MembershipRankData _membershipStyle(String tierLabel) {
    final String normalized = tierLabel.toLowerCase();

    if (normalized.contains('king')) {
      return const _MembershipRankData(
        name: 'KING',
        gradient: [Color(0xFF6B4A00), Color(0xFFD4AF37)],
        icon: Icons.workspace_premium_outlined,
      );
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return _MembershipRankData(
        name: tierLabel,
        gradient: const [
          Color.fromARGB(255, 103, 156, 255),
          Color.fromARGB(255, 83, 198, 255),
        ],
        icon: Icons.workspace_premium_outlined,
      );
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return _MembershipRankData(
        name: tierLabel,
        gradient: const [Color.fromARGB(255, 88, 239, 134), Color(0xFF45C8FF)],
        icon: Icons.diamond_outlined,
      );
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return _MembershipRankData(
        name: tierLabel,
        gradient: const [Color(0xFFB38719), Color(0xFFF6D365)],
        icon: Icons.emoji_events_outlined,
      );
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return _MembershipRankData(
        name: tierLabel,
        gradient: const [Color(0xFF8D97AA), Color(0xFFC9D0DE)],
        icon: Icons.military_tech_outlined,
      );
    }
    if (normalized.contains('THÀNH VIÊN') || normalized.contains('member')) {
      return const _MembershipRankData(
        name: 'THÀNH VIÊN',
        gradient: [Color(0xFF101010), Color(0xFF313131)],
        icon: Icons.diamond_outlined,
      );
    }

    return _MembershipRankData(
      name: tierLabel,
      gradient: const [Color(0xFF7A7A82), Color(0xFFACACB6)],
      icon: Icons.person_outline,
    );
  }

  _MembershipRankData _getMembershipRankByBalance(double totalBalance) {
    if (totalBalance > 10000000000) {
      return const _MembershipRankData(
        name: 'HẠNG KING',
        gradient: [Color(0xFF0C0818), Color.fromARGB(255, 214, 222, 46)],
        icon: Icons.all_inclusive,
      );
    }
    if (totalBalance > 2000000000) {
      return const _MembershipRankData(
        name: 'HẠNG ROYAL',
        gradient: [Color(0xFF880D2F), Color.fromARGB(255, 206, 206, 83)],
        icon: Icons.local_fire_department_outlined,
      );
    }
    if (totalBalance > 500000000) {
      return const _MembershipRankData(
        name: 'HẠNG KIM CƯƠNG',
        gradient: [
          Color.fromARGB(255, 100, 151, 247),
          Color.fromARGB(255, 83, 198, 255),
        ],
        icon: Icons.workspace_premium_outlined,
      );
    }
    if (totalBalance > 100000000) {
      return const _MembershipRankData(
        name: 'HẠNG BẠCH KIM',
        gradient: [Color.fromARGB(255, 88, 239, 134), Color(0xFF45C8FF)],
        icon: Icons.diamond_outlined,
      );
    }
    if (totalBalance > 50000000) {
      return const _MembershipRankData(
        name: 'HẠNG VÀNG',
        gradient: [Color(0xFFB38719), Color(0xFFF6D365)],
        icon: Icons.emoji_events_outlined,
      );
    }
    if (totalBalance > 5000000) {
      return const _MembershipRankData(
        name: 'HẠNG BẠC',
        gradient: [Color(0xFF8D97AA), Color(0xFFC9D0DE)],
        icon: Icons.military_tech_outlined,
      );
    }
    return const _MembershipRankData(
      name: 'THÀNH VIÊN',
      gradient: [Color(0xFF7A7A82), Color(0xFFACACB6)],
      icon: Icons.person_outline,
    );
  }

  IconData _resolveRankIcon(String rankName) {
    final String normalized = rankName.toLowerCase();
    if (normalized.contains('king')) {
      return Icons.all_inclusive;
    }
    if (normalized.contains('royal')) {
      return Icons.local_fire_department_outlined;
    }
    if (normalized.contains('kim cương') || normalized.contains('diamond')) {
      return Icons.workspace_premium_outlined;
    }
    if (normalized.contains('bạch kim') || normalized.contains('platinum')) {
      return Icons.diamond_outlined;
    }
    if (normalized.contains('vàng') || normalized.contains('gold')) {
      return Icons.emoji_events_outlined;
    }
    if (normalized.contains('bạc') || normalized.contains('silver')) {
      return Icons.military_tech_outlined;
    }
    if (normalized.contains('thành viên') || normalized.contains('member')) {
      return Icons.workspace_premium_outlined;
    }
    return Icons.person_outline;
  }

  Color _formatRankColor(String colorCode) {
    String hex = colorCode.trim().replaceAll('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((e) => '$e$e').join();
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null) return const Color(0xFF8D8D95);
    return Color(value);
  }

  double _readBalance(dynamic rawBalance) {
    if (rawBalance is num) return rawBalance.toDouble();
    if (rawBalance is String) {
      final String trimmed = rawBalance.trim();
      if (trimmed.isEmpty) return 0;

      final double? direct = double.tryParse(trimmed);
      if (direct != null) return direct;

      final String digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(digitsOnly) ?? 0;
    }
    return 0;
  }

  _MembershipRankData _resolveRankFromData({
    required Map<String, dynamic> userData,
    required double totalBalance,
  }) {
    final String manualRank = (userData['manualRank'] ?? '').toString().trim();
    final String manualRankColor = (userData['manualRankColor'] ?? '')
        .toString()
        .trim();

    if (manualRank.isNotEmpty) {
      final Color baseColor = manualRankColor.isEmpty
          ? const Color(0xFF8D8D95)
          : _formatRankColor(manualRankColor);
      final HSLColor hsl = HSLColor.fromColor(baseColor);
      return _MembershipRankData(
        name: manualRank.toUpperCase(),
        gradient: [
          hsl
              .withLightness((hsl.lightness - 0.12).clamp(0, 1).toDouble())
              .toColor(),
          hsl
              .withLightness((hsl.lightness + 0.12).clamp(0, 1).toDouble())
              .toColor(),
        ],
        icon: _resolveRankIcon(manualRank),
      );
    }

    final String tierLabel = _displayMembershipTier(userData['membershipTier']);
    if (!_isMissing(tierLabel)) {
      return _membershipStyle(tierLabel);
    }

    return _getMembershipRankByBalance(totalBalance);
  }

  Widget _buildMembershipBadge(_MembershipRankData rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rank.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rank.icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            _localizedRankName(rank.name),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _transitionController,
            curve: Curves.easeOutCubic,
          ),
        );
    _transitionController.forward();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _openEdit({
    required String uid,
    required String fieldKey,
    required String fieldLabel,
    required String currentValue,
  }) async {
    await Navigator.push(
      context,
      GentlePageRoute<void>(
        page: SmartOTPScreen(
          uid: uid,
          fieldKey: fieldKey,
          fieldLabel: fieldLabel,
          currentValue: _isMissing(currentValue) ? '' : currentValue,
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFCFCFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t('Xóa tài khoản', 'Delete account'),
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'Bạn có chắc chắn muốn xóa tài khoản này không? Mọi dữ liệu giao dịch và số dư sẽ bị xóa vĩnh viễn và không thể khôi phục.',
                    'Are you sure you want to delete this account? All transaction data and balances will be permanently removed and cannot be restored.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF364152),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          _t('Hủy', 'Cancel'),
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(
                          _t('Có, Xóa', 'Yes, Delete'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
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

    if (confirmed != true || !mounted) {
      return;
    }

    await Navigator.push(
      context,
      GentlePageRoute<void>(page: const DeleteAccountOtpScreen()),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    String? uid,
    String? fieldKey,
    String? fieldLabel,
    bool editable = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9CA3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: _isMissing(value)
                        ? const Color(0xFFB3BACB)
                        : const Color(0xFF121826),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (editable && uid != null && fieldKey != null && fieldLabel != null)
            IconButton(
              splashRadius: 19,
              onPressed: () {
                _openEdit(
                  uid: uid,
                  fieldKey: fieldKey,
                  fieldLabel: fieldLabel,
                  currentValue: value,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFFD4AF37),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHomeStyleAvatar() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0xFF000DC0),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: const Icon(Icons.person, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: SizedBox(
        width: 220,
        child: Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.2),
          highlightColor: Colors.grey.withValues(alpha: 0.08),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = UserFirestoreService.instance.currentUserDocId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: CCPAppBar(
        title: _t('Thông tin cá nhân', 'Personal Information'),
        backgroundColor: const Color(0xFFF5F7FF),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: uid == null || uid.isEmpty
                ? Center(
                    child: Text(
                      _t(
                        'Không tìm thấy tài khoản người dùng.',
                        'Cannot find user account.',
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoading();
                      }

                      final Map<String, dynamic>? data = snapshot.data?.data();
                      if (data == null) {
                        return Center(
                          child: Text(
                            _t('Không có dữ liệu hồ sơ.', 'No profile data.'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }

                      final String fullName = _displayValue(
                        data['fullName'] ?? data['fullname'],
                      ).toUpperCase();
                      final String idNumber = _displayValue(
                        data['idNumber'] ?? data['cccd'],
                      );
                      final String idDate = _displayValue(
                        data['idDate'] ?? data['issueDate'],
                      );
                      final String idPlace = _displayValue(data['idPlace']);
                      final String phoneNumber = _displayValue(
                        data['phoneNumber'],
                      );
                      final String address = _displayValue(data['address']);

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('cards')
                            .snapshots(includeMetadataChanges: true),
                        builder: (context, cardsSnapshot) {
                          double standardBalance = 0;
                          double vipBalance = 0;
                          bool hasCardData = false;

                          for (final QueryDocumentSnapshot<Map<String, dynamic>>
                              doc
                              in cardsSnapshot.data?.docs ??
                                  <
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                  >[]) {
                            final String cardId = doc.id.toLowerCase();
                            final double balance = _readBalance(
                              doc.data()['balance'],
                            );
                            if (cardId == 'standard') {
                              standardBalance = balance;
                              hasCardData = true;
                            } else if (cardId == 'vip') {
                              vipBalance = balance;
                              hasCardData = true;
                            }
                          }

                          final dynamic rawNormal =
                              data['balance_normal'] ??
                              data['standardBalance'] ??
                              data['balanceNormal'];
                          final dynamic rawVip =
                              data['balance_vip'] ??
                              data['vipBalance'] ??
                              data['balanceVip'];
                          final bool hasVipCard = data['hasVipCard'] == true;
                          final bool isStandardLocked =
                              data['is_standard_locked'] == true;
                          final bool isVipLocked =
                              data['is_vip_locked'] == true;
                          final bool hasSplitBalance =
                              rawNormal != null || rawVip != null;
                          final double fallbackTotal = hasSplitBalance
                              ? (isStandardLocked
                                        ? 0
                                        : _readBalance(rawNormal)) +
                                    ((hasVipCard && !isVipLocked)
                                        ? _readBalance(rawVip)
                                        : 0)
                              : _readBalance(
                                  data['availableBalance'] ??
                                      data['totalBalance'] ??
                                      data['balance'],
                                );

                          final double totalBalance = hasCardData
                              ? (isStandardLocked ? 0 : standardBalance) +
                                    ((hasVipCard && !isVipLocked)
                                        ? vipBalance
                                        : 0)
                              : fallbackTotal;

                          final _MembershipRankData rank = _resolveRankFromData(
                            userData: data,
                            totalBalance: totalBalance,
                          );

                          final String tierLabel = _displayMembershipTier(
                            data['membershipTier'],
                          );
                          final String tierValue = _isMissing(tierLabel)
                              ? _localizedRankName(rank.name)
                              : tierLabel;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                _buildHomeStyleAvatar(),
                                const SizedBox(height: 8),
                                Text(
                                  fullName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A237E),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildMembershipBadge(rank),
                                const SizedBox(height: 18),
                                _buildCard(
                                  child: Column(
                                    children: [
                                      _buildInfoTile(
                                        label: _t('Số giấy tờ', 'ID number'),
                                        value: idNumber,
                                      ),
                                      _buildInfoTile(
                                        label: _t('Ngày cấp', 'Issue date'),
                                        value: idDate,
                                      ),
                                      _buildInfoTile(
                                        label: _t('Nơi cấp', 'Issue place'),
                                        value: idPlace,
                                      ),
                                      _buildInfoTile(
                                        label: _t(
                                          'Hạng thành viên',
                                          'Membership tier',
                                        ),
                                        value: tierValue,
                                        isLast: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      _t(
                                        'Thông tin liên lạc',
                                        'Contact information',
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildCard(
                                  child: Column(
                                    children: [
                                      _buildInfoTile(
                                        label: _t(
                                          'Số điện thoại',
                                          'Phone number',
                                        ),
                                        value: phoneNumber,
                                        uid: uid,
                                        fieldKey: 'phoneNumber',
                                        fieldLabel: _t(
                                          'Số điện thoại',
                                          'Phone number',
                                        ),
                                        editable: true,
                                      ),
                                      _buildInfoTile(
                                        label: _t('Địa chỉ', 'Address'),
                                        value: address,
                                        uid: uid,
                                        fieldKey: 'address',
                                        fieldLabel: _t('Địa chỉ', 'Address'),
                                        editable: true,
                                        isLast: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextButton.icon(
                                  onPressed: _showDeleteAccountDialog,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    _t('Xóa tài khoản', 'Delete account'),
                                    style: GoogleFonts.poppins(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _MembershipRankData {
  const _MembershipRankData({
    required this.name,
    required this.gradient,
    required this.icon,
  });

  final String name;
  final List<Color> gradient;
  final IconData icon;
}
