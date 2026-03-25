import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart'; // Thư viện mới
import 'package:firebase_auth/firebase_auth.dart'; // Thư viện mới
import 'package:flutter/foundation.dart';
import '../data/user_firestore_service.dart';

class ChatApiService {
  // Giữ nguyên API Key của bro
  static const String _apiKey =
      "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";
  static const String _url = "https://api.groq.com/openai/v1/chat/completions";

  // Khởi tạo các instance của Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // HÀM PHỤ: Lưu tin nhắn vào Firestore
  Future<void> _saveMessage(String text, String role) async {
    final String? docId = UserFirestoreService.instance.currentUserDocId;
    if (docId == null) {
      debugPrint('Chat save skipped: missing current user docId');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(docId)
          .collection('chat_history')
          .add({
            'text': text,
            'role': role, // 'user' hoặc 'bot'
            'timestamp':
                FieldValue.serverTimestamp(), // Lưu thời gian để sắp xếp
          });
    } catch (e) {
      debugPrint('Lỗi lưu Firestore (chat_history): $e');
    }
  }

  Future<String> sendMessage(String message) async {
    // 1. Lưu tin nhắn của User ngay khi bấm gửi
    await _saveMessage(message, 'user');

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": """
Bạn là TRỢ LÝ ẢO CAO CẤP (AI Assistant) của Ngân hàng Thương mại 3 Thành Viên (CCPBank). 
Hãy trả lời khách hàng bằng sự tự tin, chuyên nghiệp, lịch sự và luôn ưu tiên lợi ích của khách hàng.

DƯỚI ĐÂY LÀ TOÀN BỘ KIẾN THỨC NỘI BỘ CỦA CCPBANK:
1. THÔNG TIN PHÁP LÝ & MẠNG LƯỚI:
   - Tên đầy đủ: Ngân hàng TMCP 3 Thành Viên (CCPBank).
   - Mã giao dịch: CCP.
   - Trụ sở: 123 Lê Lợi, Quận 1, TP.HCM. Chi nhánh Hà Nội: 456 Trần Hưng Đạo, Quận Hoàn Kiếm.

2. HÀNH TRÌNH TRẢI NGHIỆM TRÊN APP:
   - ĐĂNG KÝ (E-KYC): CMND/CCCD, chụp ảnh khuôn mặt trong 2 phút.
   - QUẢN LÝ THẺ: Khóa/Mở thẻ, Đổi mã PIN ngay trên App.
   - BIỂU ĐỒ CHI TIÊU: Tự động phân loại chi tiêu trực quan.
   - CHUYỂN TIỀN NHANH NAPAS 247: Qua STK hoặc số thẻ ngay lập tức.
   - THANH TOÁN QR: Hỗ trợ VNPAY, VietQR toàn quốc.

3. QUY ĐỊNH BẢO MẬT:
   - Hạn mức: 500 triệu/ngày (Smart OTP nâng lên 5 tỷ).
   - Bảo mật: Mã hóa AES-256, xác thực sinh trắc học.
   - Cảnh báo: KHÔNG bao giờ yêu cầu OTP/Mật khẩu qua điện thoại.

4. ƯU ĐÃI & LÃI SUẤT:
   - Tiết kiệm Online: Cộng thêm 0.3% lãi suất.
   - Hoàn tiền: 10% nạp điện thoại ngày vàng.
   - Vay nhanh: Lãi suất từ 7.9%/năm.

5. HƯỚNG DẪN KỸ THUẬT:
   - Quên mật khẩu: Dùng tính năng 'Quên mật khẩu' tại màn hình Login.
   - Đổi ngôn ngữ: Menu -> Cài đặt (Settings) -> Ngôn ngữ.
   - Lỗi giao dịch: Gọi Hotline 1800 1234.

QUY TẮC:
   - Kết thúc bằng: "Cảm ơn Quý khách đã tin dùng dịch vụ của CCPBank!".
   - Từ chối khéo các câu hỏi ngoài lề ngân hàng.
   - Tuyệt đối không nói "Tôi không biết".
""",
            },
            {"role": "user", "content": message},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String botReply = data['choices'][0]['message']['content'];

        // 2. Lưu câu trả lời của Bot vào Firestore
        await _saveMessage(botReply, 'bot');

        return botReply;
      } else {
        return "Server CCPBank đang bảo trì, quý khách đợi tí nhé!";
      }
    } catch (e) {
      return "Lỗi kết nối: $e";
    }
  }
}
