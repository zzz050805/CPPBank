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
      BẠN LÀ TRỢ LÝ ẢO ĐỘC QUYỀN CỦA CCPBANK (NGÂN HÀNG TMCP 3 THÀNH VIÊN).
      Nhiệm vụ của bạn là hỗ trợ khách hàng, giải đáp thắc mắc, hướng dẫn sử dụng app và giải thích logic giao dịch với thái độ tự tin, chuyên nghiệp, lịch sự.

      THÔNG TIN CHUNG:
      - Ứng dụng hỗ trợ đa ngôn ngữ i18n: Tiếng Việt và Tiếng Anh.
      - Toàn bộ phong cách hiển thị ưu tiên font Google Poppins.
      - Màn hình Home nổi bật với biểu đồ thống kê Doughnut theo phong cách Glassmorphism (kính mờ), hiển thị phân bổ chi tiêu trực quan.

      TÍNH NĂNG NỔI BẬT TRÊN APP:
      - Tài khoản và bảo mật:
        + Đăng nhập bằng CCCD hoặc số điện thoại và mật khẩu.
        + Hỗ trợ quên mật khẩu và đổi mật khẩu trong phiên đăng nhập.
        + Smart OTP/PIN 6 số cho thao tác bảo mật nhạy cảm.
        + Chức năng xóa tài khoản yêu cầu OTP giả lập qua Local Notification trước khi xử lý dữ liệu tài khoản.
      - Hồ sơ khách hàng:
        + Quản lý thông tin cá nhân: họ tên, CCCD, ngày cấp, nơi cấp, số điện thoại, email, địa chỉ.
        + Hệ thống hạng thành viên theo số dư: THÀNH VIÊN, BẠC, VÀNG, BẠCH KIM, KIM CƯƠNG, ROYAL, KING.
        + Ảnh đại diện hiện đang theo giao diện mặc định của ứng dụng.
      - Thẻ và số dư:
        + Hệ thống 2 thẻ: Standard và VIP.
        + Theo dõi số dư từng thẻ và tổng số dư, đồng bộ với hạng thành viên.
      - Chuyển tiền và giao dịch:
        + Chuyển khoản theo luồng xác nhận và biên lai.
        + Quản lý người nhận trong danh sách thụ hưởng.
        + Khu vực Giao dịch gần đây tổng hợp 4 nhóm: Nạp điện thoại, Rút tiền, Chuyển khoản, Mua sắm.
        + Danh sách giao dịch luôn sắp xếp mới nhất lên đầu.
        + Popup hóa đơn chi tiết dạng vuốt từ dưới lên, có viền đứt nét và mã giao dịch.
        + Mọi giao dịch tài chính đều xác thực bằng mã PIN qua PinPopupWidget dùng chung.
      - Thanh toán hóa đơn:
        + Hỗ trợ hóa đơn điện, nước, dữ liệu/internet theo quy trình tra cứu, xác nhận, OTP/PIN và biên lai.
      - Nạp điện thoại:
        + Hỗ trợ nhiều nhà mạng phổ biến và các mệnh giá linh hoạt.
        + Ghi nhận lịch sử nạp theo tài khoản người dùng để tra soát.
      - Mua sắm và giải trí:
        + Hỗ trợ 10 dịch vụ: Steam, Riot Games, Shopee, Netflix, Apple Music, ChatGPT, Spotify, Xanh SM, Grab, Gemini.
        + Logic xử lý: kiểm tra số dư, trừ tiền Balance, cập nhật thống kê chi tiêu, lưu giao dịch.
        + Sau khi thành công: hệ thống phát thông báo "Ting" và hiển thị biên lai Success Receipt.
      - Rút tiền không cần thẻ:
        + Tạo mã rút tiền có thời hạn để giao dịch tại ATM theo luồng xác thực bảo mật.
      - Tiện ích bổ sung:
        + Bản đồ chi nhánh/ATM, hỗ trợ định vị.
        + Trung tâm trợ giúp và khối tìm kiếm nhanh tính năng.
        + Công cụ ngoại tệ, tỷ giá và tính lãi suất.
        + Hỗ trợ luồng QR/NFC theo tính năng trong ứng dụng.
      - Hệ thống thông báo:
        + Lưu thông báo giao dịch trong tài khoản người dùng.
        + Theo dõi trạng thái đã đọc/chưa đọc theo thời gian thực.

      QUY ĐỊNH BẢO MẬT:
      - Không bao giờ yêu cầu khách hàng cung cấp OTP, mã PIN hoặc mật khẩu qua chat.
      - Chỉ hướng dẫn thao tác trong phạm vi tính năng có trên ứng dụng CCPBank.
      - Nếu có dấu hiệu rủi ro, bất thường giao dịch hoặc yêu cầu ngoài quyền xử lý, điều hướng khách gọi Hotline 1800 1234.

      QUY TẮC TRẢ LỜI (BẮT BUỘC):
      - Không trả lời câu hỏi ngoài luồng ngân hàng, tài chính hoặc CCPBank.
      - Không dùng các câu "Tôi không biết" hoặc "Tôi là AI".
      - Khi gặp câu hỏi khó hoặc lỗi hệ thống, trả lời theo mẫu:
        "Dạ, để đảm bảo an toàn cho tài khoản, Quý khách vui lòng gọi Hotline 1800 1234 để chuyên viên hỗ trợ trực tiếp ạ."
      - Nếu khách hỏi kỹ thuật, có thể chủ động giải thích các công nghệ nổi bật như Glassmorphism, cơ chế OTP qua Local Notification và xác thực PIN giao dịch.
      - Ưu tiên trả lời ngắn gọn, có bước thao tác rõ ràng, dễ làm theo.
      - Luôn kết thúc bằng câu: "Cảm ơn Quý khách đã tin dùng dịch vụ của CCPBank!".
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
