import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await ApiService.getRequest('/notifications');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data['notifications'] ?? [];
            _isLoading = false;
          });
        }
        // Optional: Call a route to mark them as read here!
        // await ApiService.putRequest('/notifications/read', {});
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to map string icon names from your database to actual Flutter icons
  IconData _getIcon(String? iconType) {
    switch (iconType) {
      case 'person_add':
        return Icons.person_add;
      case 'chat_bubble':
        return Icons.chat_bubble_outline;
      case 'directions_car':
        return Icons.directions_car;
      default:
        return Icons.notifications_active;
    }
  }

  // Helper to make database timestamps look pretty (e.g. "10:30 AM")
  String _formatTime(String? timestamp) {
    if (timestamp == null) return "Just now";
    try {
      final DateTime dt = DateTime.parse(timestamp).toLocal();
      String hour = dt.hour > 12 ? '${dt.hour - 12}' : '${dt.hour == 0 ? 12 : dt.hour}';
      String minute = dt.minute.toString().padLeft(2, '0');
      String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $ampm";
    } catch (e) {
      return "Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2937), size: 20),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF34A853)))
          : _notifications.isEmpty
              ? const Center(
                  child: Text(
                    "You're all caught up! 📭",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['is_read'] == true;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white : const Color(0xFFF0FDF4), // Light green if unread
                        borderRadius: BorderRadius.circular(16),
                        border: isRead ? null : Border.all(color: const Color(0xFF34A853).withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF34A853).withOpacity(0.1),
                            child: Icon(
                              _getIcon(notif['icon_type']), 
                              color: const Color(0xFF34A853), 
                              size: 20
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif['title'] ?? "Alert",
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['message'] ?? "",
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(notif['created_at']),
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}