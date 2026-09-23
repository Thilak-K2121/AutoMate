import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'home_page.dart';

class ChatPage extends StatefulWidget {
  final String rideId;

  const ChatPage({super.key, required this.rideId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  String _currentUserId = "";
  String _currentUserName = "";
  late IO.Socket _socket;

  // 💬 Real-Time Typing State (Isolated with ValueNotifier to avoid keyboard rebuild suppression)
  final ValueNotifier<Map<String, String>> _typingUsersNotifier =
      ValueNotifier<Map<String, String>>({});
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;

  @override
  void initState() {
    super.initState();
    FcmService.currentActiveChatRideId = widget.rideId;
    _connectSocket();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // 1. Get the current user ID and Name
      final userResponse = await ApiService.getRequest('/auth/me');

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        _currentUserId = userData['user']['id'].toString();
        _currentUserName = (userData['user']['name'] ?? 'Rider').toString().split(' ')[0];
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
            _messages = List<Map<String, dynamic>>.from(
              (msgData['messages'] as List).map((m) {
                final map = Map<String, dynamic>.from(m);
                map['is_read'] = true;
                map['is_delivered'] = true;
                return map;
              }),
            );
            _isLoading = false;
          });

          // Inform room that active user has read messages
          _socket.emit('markMessagesRead', {
            'rideId': widget.rideId,
            'userId': _currentUserId,
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

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('Chat connected to Socket.io');

      // Join the ride room and wait for server confirmation
      _socket.emitWithAck(
        'joinRideRoom',
        widget.rideId.toString(),
        ack: (response) {
          debugPrint('Room join confirmed — resyncing history');
          _fetchMessages();
        },
      );
    });

    // Listen for new messages
    _socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          final msgMap = Map<String, dynamic>.from(data);
          final isFromMe = msgMap['sender_id']?.toString() == _currentUserId;

          final existingIndex = _messages.indexWhere((msg) => msg['id'] == msgMap['id']);
          if (existingIndex == -1) {
            msgMap['is_delivered'] = true;
            msgMap['is_read'] = false;
            _messages.add(msgMap);
          }

          if (!isFromMe) {
            // Read receipt: notify room that we are currently viewing this message
            _socket.emit('markMessagesRead', {
              'rideId': widget.rideId,
              'userId': _currentUserId,
            });
          }
        });
        // If sender was typing, remove them from typing notifier
        if (data['sender_id'] != null) {
          final senderId = data['sender_id'].toString();
          if (_typingUsersNotifier.value.containsKey(senderId)) {
            final updated = Map<String, String>.from(_typingUsersNotifier.value);
            updated.remove(senderId);
            _typingUsersNotifier.value = updated;
          }
        }
        _scrollToBottom();
      }
    });

    // 👁️ Listen for Read Receipts (Double Blue Ticks)
    _socket.on('messagesRead', (data) {
      if (mounted && data != null && data['rideId']?.toString() == widget.rideId) {
        setState(() {
          for (var msg in _messages) {
            if (msg is Map<String, dynamic> && msg['sender_id']?.toString() == _currentUserId) {
              msg['is_read'] = true;
              msg['is_delivered'] = true;
            }
          }
        });
      }
    });

    // 💬 Listen for Typing Events (updates notifier only — does NOT rebuild the entire page or suppress keyboard)
    _socket.on('userTyping', (data) {
      if (data != null && data['userId']?.toString() != _currentUserId) {
        final uid = data['userId']?.toString() ?? '';
        final name = data['userName']?.toString() ?? 'Someone';
        if (uid.isNotEmpty) {
          final current = _typingUsersNotifier.value;
          if (current[uid] != name) {
            final updated = Map<String, String>.from(current);
            updated[uid] = name;
            _typingUsersNotifier.value = updated;
          }
        }
      }
    });

    _socket.on('userStoppedTyping', (data) {
      if (data != null) {
        final uid = data['userId']?.toString() ?? '';
        if (uid.isNotEmpty && _typingUsersNotifier.value.containsKey(uid)) {
          final updated = Map<String, String>.from(_typingUsersNotifier.value);
          updated.remove(uid);
          _typingUsersNotifier.value = updated;
        }
      }
    });

    // 🚨 Real-Time Catch: Host Ended / Cancelled Ride
    _socket.on('rideEnded', (data) {
      debugPrint('Chat: Ride ended event received');
      final isCancelled = data != null && data['status'] == 'cancelled';
      final dialogTitle = isCancelled ? "Ride Cancelled" : "Ride Ended";
      final dialogMsg = isCancelled
          ? "The host has cancelled this ride. Chat is no longer active."
          : "The host has completed this ride. Chat is no longer active.";

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                  color: isCancelled ? Colors.red : const Color(0xFF34A853),
                ),
                const SizedBox(width: 8),
                Text(dialogTitle),
              ],
            ),
            content: Text(dialogMsg),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137333),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
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
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    _socket.on('passengerBlocked', (data) {
      if (data != null && data['passengerId']?.toString() == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were blocked from this ride by the host.")),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    _socket.onDisconnect((_) => debugPrint('Disconnected from Socket.io'));
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty) {
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        _socket.emit('typing', {
          'rideId': widget.rideId,
          'userId': _currentUserId,
          'userName': _currentUserName,
        });
      }

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        _isCurrentlyTyping = false;
        _socket.emit('stopTyping', {
          'rideId': widget.rideId,
          'userId': _currentUserId,
        });
      });
    } else if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _typingTimer?.cancel();
      _socket.emit('stopTyping', {
        'rideId': widget.rideId,
        'userId': _currentUserId,
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // Stop typing indicator immediately on send
    _isCurrentlyTyping = false;
    _typingTimer?.cancel();
    _socket.emit('stopTyping', {
      'rideId': widget.rideId,
      'userId': _currentUserId,
    });

    try {
      final response = await ApiService.postRequest('/messages/send', {
        'rideId': widget.rideId,
        'message': text,
      });

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final newMessage = Map<String, dynamic>.from(responseData['data']);
        newMessage['is_delivered'] = true;
        newMessage['is_read'] = false;

        if (mounted) {
          setState(() {
            final existingIndex = _messages.indexWhere(
              (msg) => msg['id'] == newMessage['id'],
            );
            if (existingIndex == -1) {
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
    if (FcmService.currentActiveChatRideId == widget.rideId) {
      FcmService.currentActiveChatRideId = null;
    }
    _typingTimer?.cancel();
    _socket.emit('stopTyping', {
      'rideId': widget.rideId,
      'userId': _currentUserId,
    });
    _socket.emit('leaveRideRoom', widget.rideId.toString());
    _socket.disconnect();
    _socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingUsersNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            /// Messages List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF34A853),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No messages yet.\nCoordinate pickup details here!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_id'] != null &&
                                msg['sender_id'].toString() == _currentUserId;

                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
            ),

            /// 💬 Animated Typing Indicator Bubble (Isolated via ValueListenableBuilder)
            ValueListenableBuilder<Map<String, String>>(
              valueListenable: _typingUsersNotifier,
              builder: (context, typingUsers, _) {
                if (typingUsers.isEmpty) return const SizedBox.shrink();

                return Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${typingUsers.values.join(', ')} is typing",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const _TypingDotsAnimation(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            /// Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          maxHeight: 120,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _messageController,
                          onChanged: _onTextChanged,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
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
                        Icons.send_rounded,
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

  String _formatTime(dynamic rawTimestamp) {
    if (rawTimestamp == null) return "";
    try {
      final dt = DateTime.parse(rawTimestamp.toString()).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $period";
    } catch (_) {
      return "";
    }
  }

  /// Helper widget to draw chat bubbles with Double Ticks & Double Blue Ticks
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final bool isRead = msg['is_read'] == true;
    final bool isDelivered = msg['is_delivered'] == true;
    final timeStr = _formatTime(msg['timestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF137333) : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
                bottomLeft: !isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    msg['sender_name'] ?? "User",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF137333),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (!isMe) const SizedBox(height: 2),
                Text(
                  msg['message'] ?? "",
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isMe ? Colors.white : const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        (isRead || isDelivered)
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 15,
                        color: isRead
                            ? const Color(0xFF67E8F9) // 🔵 Double Blue Tick (Cyan/Sky Blue)!
                            : Colors.white.withOpacity(0.7), // ⚪ Double White/Gray Tick
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 💬 Bouncing 3-dot typing animation widget
class _TypingDotsAnimation extends StatefulWidget {
  const _TypingDotsAnimation();

  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final val = (_controller.value - delay) % 1.0;
            final double bounce = val < 0.5
                ? 4.0 * val * (0.5 - val)
                : 0.0;

            return Transform.translate(
              offset: Offset(0, -bounce * 6),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF34A853),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
