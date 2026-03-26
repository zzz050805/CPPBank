import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_text.dart';

class InterestTable extends StatelessWidget {
  const InterestTable({
    super.key,
    required this.rateByTerm,
    required this.selectedTerm,
    required this.onTermTap,
  });

  final Map<int, double> rateByTerm;
  final int selectedTerm;
  final ValueChanged<int> onTermTap;

  String _t(BuildContext context, String vi, String en) {
    return AppText.tr(context, vi, en);
  }

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<int, double>> items = rateByTerm.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(context, 'Bảng lãi suất tiết kiệm', 'Savings interest table'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2230),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((entry) {
            final bool isSelected = entry.key == selectedTerm;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTermTap(entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF000DC0).withValues(alpha: 0.08)
                      : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF000DC0).withValues(alpha: 0.35)
                        : const Color(0xFFE4E7F1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${entry.key} ${_t(context, 'tháng', 'months')}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF2D3242),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.value.toStringAsFixed(2)}%/${_t(context, 'năm', 'year')}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF000DC0),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
