import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';
import 'home_screen.dart';
import '../data/user_firestore_service.dart';

class ChatPlaceholderScreen extends StatefulWidget {
  const ChatPlaceholderScreen({super.key});

  @override
  State<ChatPlaceholderScreen> createState() => _ChatPlaceholderScreenState();
}

class _ChatPlaceholderScreenState extends State<ChatPlaceholderScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Map<String, dynamic>> _localMessages = [];
  bool _isLoading = false;

  void _handleSend() async {
    if (_controller.text.trim().isEmpty) return;

    String userMsg = _controller.text.trim();

    // Always render instantly in UI, even if Firestore write fails.
    _controller.clear();
    setState(() {
      _localMessages.add({'text': userMsg, 'role': 'user'});
      _isLoading = true;
    });

    try {
      final botReply = await _apiService.sendMessage(userMsg);
      if (mounted) {
        setState(() {
          _localMessages.add({'text': botReply, 'role': 'bot'});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localMessages.add({
            'text': 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.',
            'role': 'bot',
          });
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000DC0),
        elevation: 0,
        title: Text(
          "Trợ lý ảo CCPBank",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          ),
        ),
        actions: [
          // Nút xóa lịch sử (Tùy chọn thêm cho Pro)
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _confirmDeleteHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. HIỂN THỊ LỊCH SỬ CHAT TỪ FIRESTORE
          Expanded(child: _buildChatHistory()),

          // Hiệu ứng khi AI đang suy nghĩ
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF000DC0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "AI đang kiểm tra dữ liệu hệ thống...",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // 2. Ô nhập liệu
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatHistory() {
    final uid = UserFirestoreService.instance.currentUserDocId;

    if (uid == null) {
      return _buildMessagesList(_localMessages.reversed.toList());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (_localMessages.isNotEmpty) {
            return _buildMessagesList(_localMessages.reversed.toList());
          }
          return const Center(child: Text("Đã xảy ra lỗi khi tải tin nhắn"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_localMessages.isNotEmpty) {
            return _buildMessagesList(_localMessages.reversed.toList());
          }
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF000DC0)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty && _localMessages.isNotEmpty) {
          return _buildMessagesList(_localMessages.reversed.toList());
        }

        final firestoreMessages = docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        return _buildMessagesList(firestoreMessages);
      },
    );
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> messages) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(15),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final data = messages[index];
        final isUser = data['role'] == 'user';
        return _buildChatBubble((data['text'] ?? '').toString(), isUser);
      },
    );
  }

  // Widget bong bóng chat
  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF000DC0) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // Widget thanh nhập liệu
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Hỏi tôi về dịch vụ CCPBank...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF000DC0),
            radius: 24,
            child: IconButton(
              onPressed: _handleSend,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hàm xóa lịch sử chat (Để demo cho xịn)
  void _confirmDeleteHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa lịch sử?"),
        content: const Text(
          "Bạn có chắc chắn muốn xóa toàn bộ cuộc hội thoại này?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              final String? docId =
                  UserFirestoreService.instance.currentUserDocId;
              if (docId != null) {
                final collection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
                    .collection('chat_history');
                final snapshots = await collection.get();
                for (var doc in snapshots.docs) {
                  await doc.reference.delete();
                }
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
