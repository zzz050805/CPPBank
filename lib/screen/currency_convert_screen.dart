import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 

// --- FORMATTER GIỮ NGUYÊN ---
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String stripped = newValue.text.replaceAll('.', '');
    double? num = double.tryParse(stripped);
    if (num == null) return oldValue;
    final formatter = NumberFormat('#,###', 'vi_VN');
    String formatted = formatter.format(num).replaceAll(',', '.');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CurrencyConvertScreen extends StatefulWidget {
  const CurrencyConvertScreen({super.key});
  @override
  State<CurrencyConvertScreen> createState() => _CurrencyConvertScreenState();
}

class _CurrencyConvertScreenState extends State<CurrencyConvertScreen> {
  int _selectedIndex = 1;

  final List<Map<String, String>> currencies = [
    {"code": "VND", "name": "Việt Nam đồng"},
    {"code": "USD", "name": "Đô la"},
    {"code": "GBP", "name": "Bảng"},
    {"code": "CNY", "name": "Nhân dân tệ"},
    {"code": "EUR", "name": "Euro"},
    {"code": "JPY", "name": "Yên Nhật"},
    {"code": "KRW", "name": "Won Hàn Quốc"},
  ];

  final Map<String, double> mockRates = {
    "VND": 1, "USD": 25400, "GBP": 32200, "CNY": 3500, "EUR": 27500, "JPY": 170, "KRW": 19,
  };

  String fromCurrency = "VND";
  String toCurrency = "USD";
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  void _handleConvert() {
    if (_fromController.text.isEmpty) {
      _toController.clear();
      return;
    }
    double? amount = double.tryParse(_fromController.text.replaceAll(".", ""));
    if (amount == null) return;
    double inVND = amount * (mockRates[fromCurrency] ?? 1);
    double result = inVND / (mockRates[toCurrency] ?? 1);
    final formatter = NumberFormat('#,###.##', 'vi_VN');
    setState(() {
      _toController.text = formatter.format(result).replaceAll(',', '.');
    });
  }

  void _handleSwap() {
    setState(() {
      String tempCode = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = tempCode;
      _handleConvert();
    });
  }

  void _showCurrencyPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Chọn đơn vị tiền tệ", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final c = currencies[index];
                  bool isSelected = isFrom ? fromCurrency == c['code'] : toCurrency == c['code'];
                  return ListTile(
                    title: Text("${c['code']} (${c['name']})", 
                      style: GoogleFonts.poppins(
                        color: isSelected ? const Color(0xFF000DC0) : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF000DC0)) : null,
                    onTap: () {
                      setState(() {
                        if (isFrom) fromCurrency = c['code']!;
                        else toCurrency = c['code']!;
                      });
                      Navigator.pop(context);
                      _handleConvert();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double rateValue = mockRates[fromCurrency]! / mockRates[toCurrency]!;
    String rateLabel = "1 $fromCurrency = ${NumberFormat('#,###.##', 'vi_VN').format(rateValue).replaceAll(',', '.')} $toCurrency";

    return Scaffold(
      backgroundColor: Colors.white,
      // KHÔNG DÙNG appBar: AppBar() để tránh bị lệch thanh Nav
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // --- CUSTOM HEADER GIẢM CHIỀU CAO (THAY THẾ APPBAR) ---
                const SizedBox(height: 50),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      "Quy đổi tiền tệ",
                      style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                
                // --- NỘI DUNG CHÍNH ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.asset('assets/search/quydoitiente.png', height: 160, fit: BoxFit.contain),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      _buildInputBox("Từ", _fromController, fromCurrency, () => _showCurrencyPicker(true)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(rateLabel, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF000DC0), fontWeight: FontWeight.w500)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: IconButton(onPressed: _handleSwap, icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF000DC0), size: 32)),
                      ),
                      _buildInputBox("Thành", _toController, toCurrency, () => _showCurrencyPicker(false), isReadOnly: true),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _handleConvert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F4FB),
                            foregroundColor: const Color(0xFF000DC0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text("Quy đổi", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "*Tỷ giá có thể thay đổi theo từng thời điểm giao dịch thực tế.*",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 120), // Khoảng trống cho Nav
              ],
            ),
          ),
          
          // THANH NAV - BÂY GIỜ SẼ KHỚP 100% VÌ STACK PHỦ TOÀN MÀN HÌNH
          _buildPillBottomNav(),
        ],
      ),
    );
  }

  Widget _buildInputBox(String label, TextEditingController controller, String code, VoidCallback onPick, {bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: isReadOnly,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(hintText: "Giá", contentPadding: EdgeInsets.symmetric(horizontal: 15), border: InputBorder.none),
                  onChanged: (val) => _handleConvert(),
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: Row(children: [Text(code, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), const Icon(Icons.unfold_more, size: 18, color: Colors.grey)]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillBottomNav() {
    return Positioned(
      bottom: 20, 
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _pillNavItem(Icons.home, "Trang chính", 0),
            _pillNavItem(Icons.search, "Tìm kiếm", 1),
            _pillNavItem(Icons.chat_bubble_outline, "", 2),
            _pillNavItem(Icons.settings_outlined, "", 3),
          ],
        ),
      ),
    );
  }

  Widget _pillNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) Navigator.of(context).popUntil((route) => route.isFirst);
        else if (index == 1) Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected ? BoxDecoration(color: const Color(0xFF000DC0), borderRadius: BorderRadius.circular(20)) : null,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 22),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}