import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';

class ChatPage extends StatefulWidget {
  final String rideId;

  const ChatPage({super.key, required this.rideId});

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

    // Start Socket.io immediately, in parallel with REST calls
    _connectSocket();

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
      await _fetchMessages();
    } catch (e) {
      debugPrint("Error initializing chat: $e");

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final msgResponse = await ApiService.getRequest(
        '/messages/${widget.rideId}',
      );

      if (msgResponse.statusCode == 200) {
        final msgData = jsonDecode(msgResponse.body);

        if (mounted) {
          setState(() {
            _messages = msgData['messages'];
            _isLoading = false;
          });

          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _connectSocket() {
    _socket = IO.io(
      ApiService.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    // Start connecting immediately
    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('Chat connected to Socket.io');

      // Join the ride room and wait for server confirmation
      _socket.emitWithAck(
        'joinRideRoom',
        widget.rideId.toString(),
        ack: (response) {
          debugPrint(
            'Room join confirmed — resyncing history in case anything was missed',
          );

          // Safety-net fetch:
          // catches messages sent before this socket finished joining the room.
          _fetchMessages();
        },
      );
    });

    // Listen for new messages from the backend
    _socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          // Prevent drawing the message twice if we already added it locally
          final messageExists = _messages.any((msg) => msg['id'] == data['id']);

          if (!messageExists) {
            _messages.add(data);
          }
        });

        _scrollToBottom();
      }
    });

    // 🚨 Real-Time Catch: Host Ended / Cancelled Ride
    _socket.on('rideEnded', (data) {
      debugPrint('Chat: Ride ended event received');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red),
                SizedBox(width: 8),
                Text("Ride Ended"),
              ],
            ),
            content: const Text("The host has ended/cancelled this ride. Chat is no longer active."),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137333),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Exit chat page to dashboard
                  }
                },
                child: const Text("Return to Dashboard"),
              ),
            ],
          ),
        );
      }
    });

    // 🚨 Real-Time Catch: Removed or Blocked by Host
    _socket.on('passengerRemoved', (data) {
      if (data != null && data['passengerId']?.toString() == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were removed from this ride by the host.")),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    });

    _socket.on('passengerBlocked', (data) {
      if (data != null && data['passengerId']?.toString() == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were blocked from this ride by the host.")),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    });

    _socket.onDisconnect((_) => debugPrint('Disconnected from Socket.io'));
  }

  // REPLACE the entire _sendMessage function in chat_page.dart
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // Clear UI immediately for better UX

    try {
      // 1. Send to backend via REST API
      final response = await ApiService.postRequest('/messages/send', {
        'rideId': widget.rideId,
        'message': text,
      });

      // 2. Instantly draw our own message without waiting for the socket echo!
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final newMessage =
            responseData['data']; // Your backend sends the payload in 'data'

        if (mounted) {
          setState(() {
            // Double check it wasn't miraculously added by the socket already
            final messageExists = _messages.any(
              (msg) => msg['id'] == newMessage['id'],
            );
            if (!messageExists) {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send message.")),
        );
      }
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
