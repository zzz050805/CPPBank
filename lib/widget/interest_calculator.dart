import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InterestCalculator extends StatelessWidget {
  const InterestCalculator({
    super.key,
    required this.amountController,
    required this.amountInputFormatters,
    required this.term,
    required this.currentRate,
    required this.estimatedInterest,
    required this.onAmountChanged,
    required this.onTermChanged,
  });

  final TextEditingController amountController;
  final List<TextInputFormatter> amountInputFormatters;
  final int term;
  final double currentRate;
  final double estimatedInterest;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<int> onTermChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bộ tính toán lãi suất',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2230),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: amountInputFormatters,
            onChanged: onAmountChanged,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Số tiền gửi (VND)',
              labelStyle: GoogleFonts.poppins(
                color: const Color(0xFF6E7485),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Kỳ hạn: $term tháng',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5162),
                ),
              ),
              const Spacer(),
              Text(
                '${currentRate.toStringAsFixed(2)}%/năm',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF000DC0),
                ),
              ),
            ],
          ),
          Slider(
            value: term.toDouble(),
            min: 1,
            max: 36,
            divisions: 35,
            activeColor: const Color(0xFF000DC0),
            inactiveColor: const Color(0xFFD9DDF0),
            label: '$term',
            onChanged: (value) => onTermChanged(value.round()),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF000DC0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiền lãi dự kiến',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(estimatedInterest),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final NumberFormat formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(value.round())} VND';
  }
}
