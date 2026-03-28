import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/user_firestore_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import tủ bảo mật

class ChatApiService {
  // 1. LOẠI BỎ MÃ KEY CỨNG - THAY BẰNG GETTER ĐỂ LẤY TỪ FILE .ENV
  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _url = "https://api.groq.com/openai/v1/chat/completions";
  static const List<String> _candidateModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'gemma2-9b-it',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
            'role': role,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Lỗi lưu Firestore (chat_history): $e');
    }
  }

  Future<http.Response> _postChatRequest(String message, String model) {
    // 2. SỬ DỤNG _apiKey ĐÃ ĐƯỢC BẢO MẬT
    return http
        .post(
          Uri.parse(_url),
          headers: {
            "Authorization": "Bearer $_apiKey", // Lấy từ file .env ra dùng nè
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": model,
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
        )
        .timeout(const Duration(seconds: 25));
  }

  String _extractApiErrorMessage(http.Response response) {
    try {
      final body = utf8.decode(response.bodyBytes);
      final dynamic data = jsonDecode(body);
      final String msg = (data['error']?['message'] ?? '').toString().trim();
      if (msg.isNotEmpty) {
        return msg;
      }
      return body;
    } catch (_) {
      return response.body;
    }
  }

  bool _isModelUnavailable(int statusCode, String errorMessage) {
    if (statusCode != 400 && statusCode != 404) return false;
    final lower = errorMessage.toLowerCase();
    return lower.contains('model') &&
        (lower.contains('not found') ||
            lower.contains('decommissioned') ||
            lower.contains('does not exist') ||
            lower.contains('invalid'));
  }

  Future<String> sendMessage(String message) async {
    await _saveMessage(message, 'user');

    // KIỂM TRA KEY TRƯỚC KHI GỌI
    if (_apiKey.isEmpty) {
      return "Lỗi cấu hình: Không tìm thấy khóa API trong hệ thống. Vui lòng kiểm tra file .env!";
    }

    try {
      String? lastModelError;

      for (final model in _candidateModels) {
        final response = await _postChatRequest(message, model);

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final String botReply =
              (data['choices']?[0]?['message']?['content'] ?? '').toString();

          if (botReply.trim().isEmpty) {
            return "Hiện tại hệ thống phản hồi chậm, Quý khách vui lòng thử lại sau ít phút.";
          }

          await _saveMessage(botReply, 'bot');
          return botReply;
        }

        final errorMessage = _extractApiErrorMessage(response);

        if (response.statusCode == 401 || response.statusCode == 403) {
          return "Khóa API của trợ lý AI đã bị vô hiệu hóa hoặc sai. Vui lòng cập nhật mã Key mới trong file .env!";
        }

        if (response.statusCode == 429) {
          return "Trợ lý AI đang quá tải yêu cầu. Quý khách vui lòng thử lại sau khoảng 1 phút.";
        }

        if (_isModelUnavailable(response.statusCode, errorMessage)) {
          lastModelError = errorMessage;
          continue;
        }

        return "Trợ lý AI đang gián đoạn: $errorMessage";
      }

      return "Model AI hiện tại không khả dụng. Chi tiết: ${lastModelError ?? 'không xác định'}.";
    } on TimeoutException {
      return "Kết nối tới trợ lý AI đang quá thời gian chờ, Quý khách thử lại giúp CCPBank nhé.";
    } catch (e) {
      return "Lỗi kết nối: $e";
    }
  }
}
