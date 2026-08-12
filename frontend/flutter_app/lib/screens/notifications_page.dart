// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../services/api_service.dart';

// class NotificationsPage extends StatefulWidget {
//   const NotificationsPage({super.key});

//   @override
//   State<NotificationsPage> createState() => _NotificationsPageState();
// }

// class _NotificationsPageState extends State<NotificationsPage> {
//   List<dynamic> _notifications = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchNotifications();
//   }

//   Future<void> _fetchNotifications() async {
//     try {
//       final response = await ApiService.getRequest('/notifications');

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (mounted) {
//           setState(() {
//             _notifications = data['notifications'] ?? [];
//             _isLoading = false;
//           });
//         }

//         // Mark all fetched notifications as read
//         await ApiService.putRequest('/notifications/read', {});
//       } else {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     } catch (e) {
//       debugPrint("Error fetching notifications: $e");

//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   // Helper to map string icon names from your database to actual Flutter icons
//   IconData _getIcon(String? iconType) {
//     switch (iconType) {
//       case 'person_add':
//         return Icons.person_add;
//       case 'chat_bubble':
//         return Icons.chat_bubble_outline;
//       case 'directions_car':
//         return Icons.directions_car;
//       default:
//         return Icons.notifications_active;
//     }
//   }

//   // Helper to make database timestamps look pretty (e.g. "10:30 AM")
//   String _formatTime(String? timestamp) {
//     if (timestamp == null) return "Just now";
//     try {
//       final DateTime dt = DateTime.parse(timestamp).toLocal();
//       String hour = dt.hour > 12
//           ? '${dt.hour - 12}'
//           : '${dt.hour == 0 ? 12 : dt.hour}';
//       String minute = dt.minute.toString().padLeft(2, '0');
//       String ampm = dt.hour >= 12 ? 'PM' : 'AM';
//       return "$hour:$minute $ampm";
//     } catch (e) {
//       return "Recently";
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F6F9),
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: GestureDetector(
//           onTap: () => Navigator.pop(context),
//           child: const Icon(
//             Icons.arrow_back_ios,
//             color: Color(0xFF1F2937),
//             size: 20,
//           ),
//         ),
//         title: const Text(
//           "Notifications",
//           style: TextStyle(
//             color: Color(0xFF1F2937),
//             fontSize: 22,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(color: Color(0xFF34A853)),
//             )
//           : _notifications.isEmpty
//           ? const Center(
//               child: Text(
//                 "You're all caught up! 📭",
//                 style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(20),
//               itemCount: _notifications.length,
//               itemBuilder: (context, index) {
//                 final notif = _notifications[index];
//                 final isRead = notif['is_read'] == true;

//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 14),
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: isRead
//                         ? Colors.white
//                         : const Color(0xFFF0FDF4), // Light green if unread
//                     borderRadius: BorderRadius.circular(16),
//                     border: isRead
//                         ? null
//                         : Border.all(
//                             color: const Color(0xFF34A853).withOpacity(0.3),
//                           ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.04),
//                         blurRadius: 10,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         backgroundColor: const Color(
//                           0xFF34A853,
//                         ).withOpacity(0.1),
//                         child: Icon(
//                           _getIcon(notif['icon_type']),
//                           color: const Color(0xFF34A853),
//                           size: 20,
//                         ),
//                       ),
//                       const SizedBox(width: 14),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               notif['title'] ?? "Alert",
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 15,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               notif['message'] ?? "",
//                               style: const TextStyle(
//                                 color: Color(0xFF6B7280),
//                                 fontSize: 13,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Text(
//                         _formatTime(notif['created_at']),
//                         style: const TextStyle(
//                           color: Color(0xFF9CA3AF),
//                           fontSize: 11,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState
    extends State<NotificationsPage> {
  // ===========================================================================
  // DESIGN SYSTEM
  // ===========================================================================

  static const Color ink =
      Color(0xFF0B1220);

  static const Color muted =
      Color(0xFF64748B);

  static const Color mutedLight =
      Color(0xFF94A3B8);

  static const Color background =
      Color(0xFFF5F7FB);

  static const Color surface =
      Colors.white;

  static const Color surfaceSoft =
      Color(0xFFF8FAFC);

  static const Color divider =
      Color(0xFFE7ECF2);

  static const Color green =
      Color(0xFF22C55E);

  static const Color greenDark =
      Color(0xFF16A34A);

  static const Color blue =
      Color(0xFF2563EB);

  static const Color orange =
      Color(0xFFF59E0B);

  static const Color pink =
      Color(0xFFEC4899);

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<dynamic> _notifications =
      <dynamic>[];

  bool _isLoading = true;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _fetchNotifications();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _fetchNotifications() async {
    try {
      final response =
          await ApiService.getRequest(
        '/notifications',
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _notifications =
                data['notifications']
                        as List<dynamic>? ??
                    <dynamic>[];

            _isLoading = false;
          });
        }

        // Mark fetched notifications as read.
        await ApiService.putRequest(
          '/notifications/read',
          {},
        );
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Error fetching notifications: $e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // ICON HELPER
  // ===========================================================================

  IconData _getIcon(
    String? iconType,
  ) {
    switch (iconType) {
      case 'person_add':
        return Icons.person_add_rounded;

      case 'chat_bubble':
        return Icons.chat_bubble_outline_rounded;

      case 'directions_car':
        return Icons.directions_car_filled_rounded;

      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getIconColor(
    String? iconType,
  ) {
    switch (iconType) {
      case 'person_add':
        return blue;

      case 'chat_bubble':
        return pink;

      case 'directions_car':
        return greenDark;

      default:
        return orange;
    }
  }

  // ===========================================================================
  // TIME FORMATTER
  // ===========================================================================

  String _formatTime(
    String? timestamp,
  ) {
    if (timestamp == null ||
        timestamp.isEmpty) {
      return 'Just now';
    }

    try {
      final DateTime dateTime =
          DateTime.parse(
        timestamp,
      ).toLocal();

      final int hour24 =
          dateTime.hour;

      final int hour12 =
          hour24 == 0
              ? 12
              : hour24 > 12
                  ? hour24 - 12
                  : hour24;

      final String minute =
          dateTime.minute
              .toString()
              .padLeft(2, '0');

      final String period =
          hour24 >= 12
              ? 'PM'
              : 'AM';

      return '$hour12:$minute $period';
    } catch (e) {
      return 'Recently';
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _notifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                border: Border.all(
                  color: divider,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        ink.withOpacity(.04),
                    blurRadius: 14,
                    offset:
                        const Offset(
                      0,
                      6,
                    ),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: ink,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: ink,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay updated about your rides',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border: Border.all(
                color: divider,
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: ink,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      ink.withOpacity(.07),
                  blurRadius: 28,
                  offset:
                      const Offset(
                    0,
                    12,
                  ),
                ),
              ],
            ),
            child: const Padding(
              padding:
                  EdgeInsets.all(21),
              child:
                  CircularProgressIndicator(
                strokeWidth: 2.7,
                color: greenDark,
              ),
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'Loading notifications',
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Checking for recent updates',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
        ),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.fromLTRB(
            24,
            34,
            24,
            30,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
                BorderRadius.circular(
              25,
            ),
            border: Border.all(
              color: divider,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    ink.withOpacity(.025),
                blurRadius: 20,
                offset:
                    const Offset(
                  0,
                  8,
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      green.withOpacity(.14),
                      blue.withOpacity(.07),
                    ],
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .notifications_none_rounded,
                  color: greenDark,
                  size: 32,
                ),
              ),

              const SizedBox(height: 17),

              const Text(
                'You\'re all caught up',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'New ride updates and activity will appear here.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11.5,
                  height: 1.5,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // NOTIFICATION LIST
  // ===========================================================================

  Widget _buildNotificationList() {
    return RefreshIndicator(
      onRefresh:
          _fetchNotifications,
      color: greenDark,
      displacement: 20,
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          20,
          5,
          20,
          30,
        ),
        itemCount:
            _notifications.length,
        itemBuilder:
            (context, index) {
          final dynamic notification =
              _notifications[index];

          return _buildNotificationCard(
            notification,
          );
        },
      ),
    );
  }

  // ===========================================================================
  // NOTIFICATION CARD
  // ===========================================================================

  Widget _buildNotificationCard(
    dynamic notification,
  ) {
    final bool isRead =
        notification['is_read'] == true;

    final String? iconType =
        notification['icon_type']
            ?.toString();

    final Color iconColor =
        _getIconColor(iconType);

    final String title =
        notification['title']
                ?.toString() ??
            'Alert';

    final String message =
        notification['message']
                ?.toString() ??
            '';

    final String time =
        _formatTime(
      notification['created_at']
          ?.toString(),
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 11,
      ),
      decoration: BoxDecoration(
        color: isRead
            ? surface
            : const Color(0xFFF0FDF4),
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        border: Border.all(
          color: isRead
              ? divider
              : green.withOpacity(.22),
        ),
        boxShadow: [
          BoxShadow(
            color:
                ink.withOpacity(.025),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _notificationIcon(
              icon:
                  _getIcon(iconType),
              color: iconColor,
              unread:
                  !isRead,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color: ink,
                            fontSize: 12.5,
                            height: 1.2,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Text(
                        time,
                        style:
                            const TextStyle(
                          color:
                              mutedLight,
                          fontSize: 8.5,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ],
                  ),

                  if (message.isNotEmpty) ...[
                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      message,
                      maxLines: 3,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color: muted,
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                    ),
                  ],

                  if (!isRead) ...[
                    const SizedBox(
                      height: 9,
                    ),

                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration:
                              const BoxDecoration(
                            color: greenDark,
                            shape:
                                BoxShape
                                    .circle,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        const Text(
                          'New notification',
                          style:
                              TextStyle(
                            color:
                                greenDark,
                            fontSize: 8,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NOTIFICATION ICON
  // ===========================================================================

  Widget _notificationIcon({
    required IconData icon,
    required Color color,
    required bool unread,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color:
                color.withOpacity(.10),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),

        if (unread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(
                color: greenDark,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}