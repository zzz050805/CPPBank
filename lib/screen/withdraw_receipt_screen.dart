import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'branch_map_screen.dart';

class WithdrawReceiptScreen extends StatefulWidget {
  const WithdrawReceiptScreen({
    super.key,
    required this.amount,
    required this.withdrawCode,
    required this.createdAt,
    required this.expiresAt,
  });

  final int amount;
  final String withdrawCode;
  final DateTime createdAt;
  final DateTime expiresAt;

  @override
  State<WithdrawReceiptScreen> createState() => _WithdrawReceiptScreenState();
}

class _WithdrawReceiptScreenState extends State<WithdrawReceiptScreen> {
  static const Color primaryBlue = Color(0xFF000DC0);
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncRemaining() {
    final Duration delta = widget.expiresAt.difference(DateTime.now());
    final Duration safeDelta = delta.isNegative ? Duration.zero : delta;

    if (!mounted) {
      return;
    }

    setState(() {
      _remaining = safeDelta;
    });

    if (safeDelta == Duration.zero) {
      _timer?.cancel();
    }
  }

  String _formatAmount(int value) {
    return NumberFormat('#,###', 'vi_VN').format(value).replaceAll(',', '.');
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('HH:mm:ss dd/MM/yyyy').format(value);
  }

  String _formatRemain(Duration value) {
    final int totalSeconds = value.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _openNearestAtmMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BranchMapScreen(autoSelectNearest: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FE),
        foregroundColor: const Color(0xFF1F2845),
        title: Text(
          'Biên lai rút tiền',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF000DC0),
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tạo mã rút tiền thành công',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2845),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã có hiệu lực trong vòng 15 phút',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF66708C),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3E8F7)),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.payments_outlined,
                      label: 'Số tiền',
                      value: '${_formatAmount(widget.amount)}đ',
                      isImportant: true,
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      icon: Icons.pin_outlined,
                      label: 'Mã rút tiền',
                      value: widget.withdrawCode,
                      isImportant: true,
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Thời gian tạo',
                      value: _formatDateTime(widget.createdAt),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      icon: Icons.timer_outlined,
                      label: 'Còn lại',
                      value: _remaining == Duration.zero
                          ? 'Đã hết hạn'
                          : _formatRemain(_remaining),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD3DEFF)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vui lòng tới cây ATM gần nhất để thực hiện rút tiền.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF415187),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openNearestAtmMap,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    'Tìm ATM gần nhất',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B61FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000DC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Về trang chủ',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isImportant = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C7593)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isImportant ? 13 : 12,
              color: const Color(0xFF6B7390),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isImportant ? 16 : 13,
            color: const Color(0xFF1D2644),
            fontWeight: isImportant ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
