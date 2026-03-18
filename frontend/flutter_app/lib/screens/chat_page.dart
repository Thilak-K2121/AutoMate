import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';

class ChatPage extends StatefulWidget {
  final String rideId;

  const ChatPage({Key? key, required this.rideId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  String _currentUserId = "";
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // 1. Get the current user ID so we know which messages are "ours"
      final userResponse = await ApiService.getRequest('/auth/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        _currentUserId = userData['user']['id'];
      }

      // 2. Fetch Chat History
      final msgResponse = await ApiService.getRequest(
        '/messages/${widget.rideId}',
      );
      if (msgResponse.statusCode == 200) {
        final msgData = jsonDecode(msgResponse.body);
        setState(() {
          _messages = msgData['messages'];
          _isLoading = false;
        });
        _scrollToBottom();
      }

      // 3. Connect to Socket.io
      _connectSocket();
    } catch (e) {
      debugPrint("Error initializing chat: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _connectSocket() {
    // Note: Use your IP or 10.0.2.2 for Android Emulator
    _socket = IO.io(
      'http://10.0.2.2:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('Connected to Socket.io');
      // Join the specific ride room
      _socket.emit('joinRideRoom', widget.rideId);
    });

    // Listen for new messages from the backend
    _socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          _messages.add(data);
        });
        _scrollToBottom();
      }
    });

    _socket.onDisconnect((_) => debugPrint('Disconnected from Socket.io'));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // Clear UI immediately for better UX

    try {
      // Send to backend via REST API (which will then broadcast via Socket.io)
      await ApiService.postRequest('/messages/send', {
        'rideId': widget.rideId,
        'message': text,
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void _scrollToBottom() {
    // Wait a tiny bit for the UI to build the new message before scrolling
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    // Clean up socket connections
    _socket.emit('leaveRideRoom', widget.rideId);
    _socket.disconnect();
    _socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            /// Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFDCE7EE),
                    child: Icon(
                      Icons.directions_car,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Ride Chat",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            /// Messages Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF34A853),
                      ),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        "No messages yet. Say hi!",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == _currentUserId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
            ),

            /// Input area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34A853),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to draw the chat bubbles based on who sent it
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE9F7EF),
              child: Text(
                (msg['sender_name'] ?? "?")[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF34A853),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF34A853) : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
                bottomLeft: !isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    msg['sender_name'] ?? "User",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (!isMe) const SizedBox(height: 4),
                Text(
                  msg['message'] ?? "",
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
