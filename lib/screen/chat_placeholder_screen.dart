import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import 'search_screen.dart';
import '../l10n/app_text.dart';
import '../services/user_firestore_service.dart';
import '../widget/custom_confirm_dialog.dart';

class ChatPlaceholderScreen extends StatefulWidget {
  const ChatPlaceholderScreen({
    super.key,
    this.showBackButton = true,
    this.onBackPressed,
  });

  // Kept for compatibility with existing call sites.
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  State<ChatPlaceholderScreen> createState() => _ChatPlaceholderScreenState();
}

class _ChatPlaceholderScreenState extends State<ChatPlaceholderScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  final List<Map<String, dynamic>> _localMessages = [];
  bool _isLoading = false;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  String _messageSignature(Map<String, dynamic> message) {
    final role = (message['role'] ?? '').toString();
    final text = (message['text'] ?? '').toString().trim();
    return '$role|$text';
  }

  List<Map<String, dynamic>> _mergeFirestoreWithUnsyncedLocal(
    List<Map<String, dynamic>> firestoreMessages,
  ) {
    // Keep only local messages that are not yet visible from Firestore.
    final Map<String, int> firestoreCounts = {};
    for (final message in firestoreMessages) {
      final key = _messageSignature(message);
      firestoreCounts[key] = (firestoreCounts[key] ?? 0) + 1;
    }

    final List<Map<String, dynamic>> unsyncedLocalNewestFirst = [];
    for (final local in _localMessages.reversed) {
      final key = _messageSignature(local);
      final count = firestoreCounts[key] ?? 0;
      if (count > 0) {
        firestoreCounts[key] = count - 1;
        continue;
      }
      unsyncedLocalNewestFirst.add(local);
    }

    return [...unsyncedLocalNewestFirst, ...firestoreMessages];
  }

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
            'text': _t(
              'Không th? g?i tin nh?n lúc này. Vui ḷng th? l?i.',
              'Unable to send message right now. Please try again.',
            ),
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
          _t('Tr? lư ?o CCPBank', 'CCPBank virtual assistant'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed:
              widget.onBackPressed ??
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
        ),
        actions: [
          // Nút xóa l?ch s? (Tùy ch?n thêm cho Pro)
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _confirmDeleteHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. HI?N TH? L?CH S? CHAT T? FIRESTORE
          Expanded(child: _buildChatHistory()),

          // Hi?u ?ng khi AI dang suy nghi
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
                    _t(
                      'AI dang ki?m tra d? li?u h? th?ng...',
                      'AI is checking system data...',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // 2. Ô nh?p li?u
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
          return Center(
            child: Text(
              _t(
                'Đă x?y ra l?i khi t?i tin nh?n',
                'An error occurred while loading messages',
              ),
            ),
          );
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
        final mergedMessages = _mergeFirestoreWithUnsyncedLocal(
          firestoreMessages,
        );
        return _buildMessagesList(mergedMessages);
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

  // Widget thanh nh?p li?u
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
                  hintText: _t(
                    'H?i tôi v? d?ch v? CCPBank...',
                    'Ask me about CCPBank services...',
                  ),
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

  // Hàm xóa l?ch s? chat (Đ? demo cho x?n)
  Future<void> _confirmDeleteHistory() async {
    await showCustomConfirmDialog(
      context: context,
      title: AppText.text(context, 'chat_delete_history_title'),
      message: AppText.text(context, 'chat_delete_history_confirm'),
      confirmText: AppText.text(context, 'btn_delete'),
      cancelText: AppText.text(context, 'btn_cancel'),
      confirmColor: Colors.red,
      onConfirm: () async {
        final String? docId = UserFirestoreService.instance.currentUserDocId;
        if (docId != null) {
          final collection = FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .collection('chat_history');
          final snapshots = await collection.get();
          for (final doc in snapshots.docs) {
            await doc.reference.delete();
          }
        }
      },
    );
  }
}
