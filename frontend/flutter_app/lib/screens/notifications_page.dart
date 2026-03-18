import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder data for now - we will hook this up to your backend/sockets later!
    final List<Map<String, dynamic>> notifications = [
      {
        "title": "New Passenger! 🚗",
        "message": "Sarah joined your Metro Station ride.",
        "time": "2 mins ago",
        "icon": Icons.person_add,
        "color": Colors.blue,
      },
      {
        "title": "New Message 💬",
        "message": "Alex: 'I am waiting at Gate 2!'",
        "time": "10 mins ago",
        "icon": Icons.chat_bubble_outline,
        "color": Colors.green,
      }
    ];

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
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                "You're all caught up! 📭",
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        backgroundColor: notif['color'].withOpacity(0.1),
                        child: Icon(notif['icon'], color: notif['color'], size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'],
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['message'],
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        notif['time'],
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