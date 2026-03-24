import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_text.dart';

class ExchangeRateScreen extends StatefulWidget {
  const ExchangeRateScreen({super.key});

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  int _selectedIndex = 1;

  String _t(String vi, String en) => AppText.tr(context, vi, en);
  String _country(Map<String, dynamic> item) {
    final bool isEn = Localizations.localeOf(context).languageCode == 'en';
    return isEn ? item['countryEn'] as String : item['country'] as String;
  }

  final List<Map<String, dynamic>> exchangeRates = [
    {
      "country": "Mỹ",
      "countryEn": "United States",
      "code": "USD",
      "buy": "25.120",
      "sell": "25.435",
      "flag": "🇺🇸",
    },
    {
      "country": "Anh",
      "countryEn": "United Kingdom",
      "code": "GBP",
      "buy": "31.800",
      "sell": "33.150",
      "flag": "🇬🇧",
    },
    {
      "country": "Pháp",
      "countryEn": "France",
      "code": "EUR",
      "buy": "26.850",
      "sell": "28.100",
      "flag": "🇫🇷",
    },
    {
      "country": "Đức",
      "countryEn": "Germany",
      "code": "EUR",
      "buy": "26.850",
      "sell": "28.100",
      "flag": "🇩🇪",
    },
    {
      "country": "Ý",
      "countryEn": "Italy",
      "code": "EUR",
      "buy": "26.850",
      "sell": "28.100",
      "flag": "🇮🇹",
    },
    {
      "country": "Thụy Sĩ",
      "countryEn": "Switzerland",
      "code": "CHF",
      "buy": "27.900",
      "sell": "28.850",
      "flag": "🇨🇭",
    },
    {
      "country": "Nhật Bản",
      "countryEn": "Japan",
      "code": "JPY",
      "buy": "164.200",
      "sell": "173.500",
      "flag": "🇯🇵",
    },
    {
      "country": "Singapore",
      "countryEn": "Singapore",
      "code": "SGD",
      "buy": "18.650",
      "sell": "19.380",
      "flag": "🇸🇬",
    },
    {
      "country": "Canada",
      "countryEn": "Canada",
      "code": "CAD",
      "buy": "18.120",
      "sell": "18.950",
      "flag": "🇨🇦",
    },
    {
      "country": "Úc",
      "countryEn": "Australia",
      "code": "AUD",
      "buy": "16.480",
      "sell": "17.150",
      "flag": "🇦🇺",
    },
    {
      "country": "Thái Lan",
      "countryEn": "Thailand",
      "code": "THB",
      "buy": "685.400",
      "sell": "722.000",
      "flag": "🇹🇭",
    },
    {
      "country": "Ấn Độ",
      "countryEn": "India",
      "code": "INR",
      "buy": "295.000",
      "sell": "315.000",
      "flag": "🇮🇳",
    },
    {
      "country": "Nga",
      "countryEn": "Russia",
      "code": "RUB",
      "buy": "265.120",
      "sell": "290.450",
      "flag": "🇷🇺",
    },
    {
      "country": "Trung Quốc",
      "countryEn": "China",
      "code": "NDT",
      "buy": "3.420",
      "sell": "3.580",
      "flag": "🇨🇳",
    },
    {
      "country": "Hàn Quốc",
      "countryEn": "South Korea",
      "code": "KRW",
      "buy": "18.250",
      "sell": "19.800",
      "flag": "🇰🇷",
    },
    {
      "country": "Argentina",
      "countryEn": "Argentina",
      "code": "ARS",
      "buy": "28.500",
      "sell": "32.000",
      "flag": "🇦🇷",
    },
    {
      "country": "Uruguay",
      "countryEn": "Uruguay",
      "code": "UYU",
      "buy": "620.000",
      "sell": "660.000",
      "flag": "🇺🇾",
    },
    {
      "country": "Bồ Đào Nha",
      "countryEn": "Portugal",
      "code": "EUR",
      "buy": "26.850",
      "sell": "28.100",
      "flag": "🇵🇹",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Cố định nền trắng
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor:
            Colors.transparent, // KHÓA MÀU: Không cho đổi màu khi cuộn
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t("Tỷ giá hối đoái", "Exchange rates"),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- HEADER ĐƯỢC KHÓA (STAY FIXED) ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Tăng flex lên 5 để không bị mất chữ đơn vị tiền tệ
                        Expanded(
                          flex: 5,
                          child: Text(
                            _t("Quốc gia", "Country"),
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _t("Mua vào", "Buy"),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _t("Bán ra", "Sell"),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                  ],
                ),
              ),

              // --- DANH SÁCH CUỘN ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 85,
                  ),
                  itemCount: exchangeRates.length + 1,
                  itemBuilder: (context, index) {
                    if (index == exchangeRates.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Text(
                          _t(
                            "*Tỷ giá có thể thay đổi theo từng thời điểm giao dịch thực tế.*",
                            "*Rates may change by real transaction time.*",
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    final item = exchangeRates[index];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              // CỘT QUỐC GIA: Tăng không gian và bỏ Ellipsis
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    Text(
                                      item['flag'],
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "${_country(item)}(${item['code']})",
                                        style: GoogleFonts.poppins(
                                          fontSize:
                                              13.5, // Giảm nhẹ size để chắc chắn hiện đủ
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF343434),
                                        ),
                                        softWrap: false, // Không cho xuống dòng
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // CỘT MUA VÀO
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item['buy'],
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // CỘT BÁN RA
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item['sell'],
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF000DC0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // THANH BOTTOM NAV
          _buildPillBottomNav(),
        ],
      ),
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
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _pillNavItem(Icons.home, _t("Trang chính", "Home"), 0),
            _pillNavItem(Icons.search, _t("Tìm kiếm", "Search"), 1),
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
        if (index == 0)
          Navigator.of(context).popUntil((route) => route.isFirst);
        else if (index == 1)
          Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFF000DC0),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 22,
            ),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
