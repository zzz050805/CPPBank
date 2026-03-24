import 'package:flutter/material.dart';

class ConfirmTopUpScreen extends StatelessWidget {
  final String selectedAmount;
  final String selectedProvider;
  final String selectedPhoneNumber;

  const ConfirmTopUpScreen({
    super.key,
    required this.selectedAmount,
    required this.selectedProvider,
    required this.selectedPhoneNumber,
  });

  String get _amountDisplay {
    if (selectedAmount == 'Số khác') {
      return selectedAmount;
    }
    return '$selectedAmount VND';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A1A9E); // Màu xanh đậm chủ đạo

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nạp tiền điện thoại',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Header hiển thị số tiền
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25),
            color: primaryColor,
            child: Column(
              children: [
                Text(
                  _amountDisplay,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  selectedAmount == 'Số khác'
                      ? "Vui lòng nhập số tiền mong muốn"
                      : "Số tiền bạn đã chọn",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mục Trích từ
                  const Text(
                    "Trích từ",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black, fontSize: 14),
                            children: [
                              TextSpan(text: "STK: "),
                              TextSpan(
                                text: "123 568 567 456",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "PHUNG THANH D",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mục Thông tin chi tiết
                  const Text(
                    "Thông tin chi tiết",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow("Loại dịch vụ", "Nạp ĐTDD", isBlue: true),
                        const Divider(height: 1),
                        _buildInfoRow(
                          "Nhà cung cấp",
                          selectedProvider,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          "Số điện thoại",
                          selectedPhoneNumber,
                          isBlue: true,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          "Mệnh giá (VND)",
                          _amountDisplay,
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Nút Xác nhận
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Xử lý xác nhận giao dịch
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0000CD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        "Xác nhận",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để vẽ từng dòng thông tin
  Widget _buildInfoRow(String label, String value, {bool isBlue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBlue ? Colors.blue.shade900 : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
