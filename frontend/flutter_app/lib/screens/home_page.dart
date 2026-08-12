// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import '../services/api_service.dart';
// import 'create_ride_page.dart';
// import 'my_rides_page.dart';
// import 'map_page.dart';
// import 'notifications_page.dart';
// import 'metro_ride_details_page.dart';
// import 'profile_page.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   String _userName = "Student";
//   String _userId = "";
//   List<dynamic> _availableRides = [];
//   bool _isLoading = true;
//   bool _hasUnreadNotifications = false;
//   String _searchQuery = ""; // NEW: Tracks the search bar input
//   // 👇 NEW: Track the currently joined ride for the UI & Double-Booking check
//   String? _activeRideId;
//   String? _activeRideDest;
//   late IO.Socket _socket;

//   @override
//   void initState() {
//     super.initState();
//     _fetchDashboardData();
//     _setupGlobalSocket();
//   }

//   Future<void> _fetchDashboardData() async {
//     await Future.delayed(const Duration(milliseconds: 300));
//     try {
//       // 1. Fetch user profile
//       final userResponse = await ApiService.getRequest('/auth/me');
//       if (userResponse.statusCode == 200) {
//         final userData = jsonDecode(userResponse.body);

//         final userId = userData['user']['id'].toString();

//         if (mounted) {
//           setState(() {
//             _userName = userData['user']['name'].split(' ')[0];
//             _userId = userId;
//           });
//         }

//         // Join this user's personal notification room
//         if (_socket.connected) {
//           _socket.emit('joinUserRoom', userId);
//         }
//       }

//       await _refreshUnreadStatus();
//       // 2. NEW: Fetch My Rides to check active ride
//       final myRidesResponse = await ApiService.getRequest('/rides/my-rides');
//       if (myRidesResponse.statusCode == 200) {
//         final myRidesData = jsonDecode(myRidesResponse.body);
//         final joinedRides = myRidesData['joined'] as List<dynamic>? ?? [];

//         final active = joinedRides.cast<dynamic?>().firstWhere(
//           (r) => r != null && r['status'] != 'completed',
//           orElse: () => null,
//         );

//         setState(() {
//           if (active != null) {
//             _activeRideId = active['id'].toString();
//             _activeRideDest = active['destination'].toString();
//           } else {
//             _activeRideId = null;
//             _activeRideDest = null;
//           }
//         });
//       }

//       // 3. Fetch nearby rides
//       final ridesResponse = await ApiService.getRequest('/rides/nearby');
//       if (ridesResponse.statusCode == 200) {
//         final ridesData = jsonDecode(ridesResponse.body);
//         setState(() {
//           _availableRides = ridesData['rides'];
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching dashboard data: $e");
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _refreshUnreadStatus() async {
//     try {
//       final response = await ApiService.getRequest('/notifications');

//       if (response.statusCode == 200 && mounted) {
//         final data = jsonDecode(response.body);
//         final notifications = data['notifications'] as List<dynamic>? ?? [];

//         setState(() {
//           _hasUnreadNotifications = notifications.any((notification) {
//             return notification['is_read'] != true;
//           });
//         });
//       }
//     } catch (e) {
//       debugPrint("Error checking notification status: $e");
//     }
//   }

//   // 👇 NEW: Listen to the backend for real-time ride updates
//   void _setupGlobalSocket() {
//     _socket = IO.io(
//       ApiService.socketUrl,
//       IO.OptionBuilder()
//           .setTransports(['websocket'])
//           .disableAutoConnect()
//           .build(),
//     );

//     _socket.connect();

//     _socket.onConnect((_) {
//       debugPrint('HomePage connected to Socket.io for live updates');

//       // Join personal notification room once socket connection is ready
//       if (_userId.isNotEmpty) {
//         _socket.emit('joinUserRoom', _userId);
//         debugPrint('Joined personal notification room: user_$_userId');
//       }
//     });

//     _socket.on('newNotification', (_) {
//       debugPrint('New notification received');

//       if (mounted) {
//         setState(() {
//           _hasUnreadNotifications = true;
//         });
//       }
//     });

//     // Listen for a 'newRide' or 'rideUpdated' event from the server
//     _socket.on('newRide', (_) {
//       debugPrint('A new ride was created! Updating UI silently...');
//       if (mounted) {
//         _fetchDashboardData(); // Silently pulls the fresh list without a loading screen!
//       }
//     });

//     _socket.onDisconnect(
//       (_) => debugPrint('HomePage disconnected from Socket.io'),
//     );
//   }

//   IconData getGreetingIcon() {
//     final hour = DateTime.now().hour;

//     if (hour < 12) return Icons.wb_twilight; // morning
//     if (hour < 17) return Icons.light_mode; // day
//     return Icons.nightlight_round; // night
//   }

//   String getGreeting() {
//     final hour = DateTime.now().hour;

//     if (hour < 12) return "Good Morning";
//     if (hour < 17) return "Good Afternoon";
//     return "Good Evening";
//   }

//   @override
//   void dispose() {
//     _socket.disconnect();
//     _socket.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final displayRides = _searchQuery.isEmpty
//         ? _availableRides
//         : _availableRides.where((ride) {
//             final dest = (ride['destination'] ?? '').toString().toLowerCase();
//             final search = _searchQuery.toLowerCase().trim();

//             if (dest.contains(search)) return true;

//             final collegeKeywords = ['college', 'bmsce', 'bms'];
//             final isSearchingCollege = collegeKeywords.any(
//               (kw) => kw.startsWith(search) || search.contains(kw),
//             );

//             if (isSearchingCollege) {
//               if (collegeKeywords.any((kw) => dest.contains(kw))) return true;
//             }

//             final metroKeywords = ['metro', 'national college', 'station'];
//             final isSearchingMetro = metroKeywords.any(
//               (kw) => kw.startsWith(search) || search.contains(kw),
//             );

//             if (isSearchingMetro) {
//               if (metroKeywords.any((kw) => dest.contains(kw))) return true;
//             }

//             return false;
//           }).toList();
//     // 👇 NEW: Pin active ride to top
//     displayRides.sort((a, b) {
//       final idA = a['id'].toString();
//       final idB = b['id'].toString();

//       if (idA == _activeRideId) return -1;
//       if (idB == _activeRideId) return 1;
//       return 0;
//     });

//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F6F9),
//       bottomNavigationBar: _bottomNavBar(),
//       body: SafeArea(
//         child: _isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF34A853)),
//               )
//             : RefreshIndicator(
//                 onRefresh: _fetchDashboardData,
//                 color: const Color(0xFF34A853),
//                 child: ListView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   children: [
//                     const SizedBox(height: 8),

//                     /// HEADER
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Hi, $_userName 👋",
//                                 style: const TextStyle(
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w700,
//                                   color: Color(0xFF1F2937),
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Row(
//                                 children: [
//                                   Icon(
//                                     getGreetingIcon(),
//                                     size: 16,
//                                     color: Color(0xFF6B7280),
//                                   ),
//                                   const SizedBox(width: 6),
//                                   Text(
//                                     getGreeting(),
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                       color: Color(0xFF6B7280),
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),

//                         /// Notifications
//                         GestureDetector(
//                           onTap: () async {
//                             await Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => const NotificationsPage(),
//                               ),
//                             );

//                             // Refresh unread status after returning from NotificationsPage
//                             await _refreshUnreadStatus();
//                           },
//                           child: Stack(
//                             children: [
//                               Container(
//                                 padding: const EdgeInsets.all(10),
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(14),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.black.withOpacity(0.05),
//                                       blurRadius: 10,
//                                       offset: const Offset(0, 4),
//                                     ),
//                                   ],
//                                 ),
//                                 child: const Icon(
//                                   Icons.notifications_none,
//                                   size: 22,
//                                   color: Color(0xFF374151),
//                                 ),
//                               ),
//                               if (_hasUnreadNotifications)
//                                 Positioned(
//                                   right: 6,
//                                   top: 6,
//                                   child: Container(
//                                     width: 8,
//                                     height: 8,
//                                     decoration: const BoxDecoration(
//                                       color: Colors.red,
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(width: 12),

//                         /// Profile
//                         GestureDetector(
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => const ProfilePage(),
//                               ),
//                             );
//                           },
//                           child: const CircleAvatar(
//                             radius: 20,
//                             backgroundColor: Color(0xFFDCE7EE),
//                             child: Icon(Icons.person, color: Color(0xFF6B7280)),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 18),

//                     /// LOGO
//                     RichText(
//                       text: const TextSpan(
//                         children: [
//                           TextSpan(
//                             text: "Auto",
//                             style: TextStyle(
//                               fontSize: 32,
//                               fontWeight: FontWeight.w800,
//                               color: Color(0xFF34A853),
//                             ),
//                           ),
//                           TextSpan(
//                             text: "Mate",
//                             style: TextStyle(
//                               fontSize: 32,
//                               fontWeight: FontWeight.w800,
//                               color: Color(0xFF2F80ED),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 18),

//                     /// QUICK ACTIONS
//                     Row(
//                       children: [
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () async {
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => const CreateRidePage(
//                                     initialDestination:
//                                         "National College Metro Station",
//                                     initialMeetingPoint: "BMSCE Gate 1",
//                                   ),
//                                 ),
//                               );
//                               if (result == true) {
//                                 setState(() {
//                                   _searchQuery = "";
//                                 });

//                                 await _fetchDashboardData();
//                               }
//                             },
//                             child: _quickCard(
//                               icon: Icons.directions_subway,
//                               title: "Go to Metro",
//                               subtitle: "Auto-fill ride",
//                               color: const Color(0xFF34A853),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () async {
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => const CreateRidePage(
//                                     initialDestination: "BMSCE Campus",
//                                     initialMeetingPoint:
//                                         "National College Metro Station",
//                                   ),
//                                 ),
//                               );
//                               if (result == true) {
//                                 setState(() {
//                                   _searchQuery = "";
//                                 });

//                                 await _fetchDashboardData();
//                               }
//                             },
//                             child: _quickCard(
//                               icon: Icons.school,
//                               title: "Go to College",
//                               subtitle: "Auto-fill ride",
//                               color: const Color(0xFF2F80ED),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 26),

//                     /// SEARCH
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.03),
//                             blurRadius: 10,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: TextField(
//                         onChanged: (value) =>
//                             setState(() => _searchQuery = value),
//                         decoration: const InputDecoration(
//                           icon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
//                           hintText: "Search destinations or gates...",
//                           border: InputBorder.none,
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 24),

//                     /// HEADER
//                     const Text(
//                       "Available Rides",
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                         color: Color(0xFF1F2937),
//                       ),
//                     ),

//                     const SizedBox(height: 14),

//                     /// RIDES
//                     if (displayRides.isEmpty)
//                       const Center(
//                         child: Padding(
//                           padding: EdgeInsets.symmetric(vertical: 20),
//                           child: Text("No rides available"),
//                         ),
//                       )
//                     else
//                       ...displayRides.map<Widget>((ride) {
//                         final bool isMetro = ride['destination']
//                             .toString()
//                             .toLowerCase()
//                             .contains('metro');

//                         final isFemaleOnlyRaw = ride['female_only'];

//                         final bool isFemaleOnly =
//                             isFemaleOnlyRaw == true ||
//                             isFemaleOnlyRaw == 1 ||
//                             isFemaleOnlyRaw == "1" ||
//                             isFemaleOnlyRaw.toString().toLowerCase() == "true";

//                         final String creatorId =
//                             ride['creator_id']?.toString() ?? '';
//                         final bool isMyRide = creatorId == _userId;
//                         final bool isActiveJoinedRide =
//                             ride['id'].toString() == _activeRideId;

//                         // 👇 NEW: Extract payment mode
//                         final String paymentMode =
//                             ride['payment_mode'] ?? 'Any (Cash/UPI)';

//                         return _rideCard(
//                           id: ride['id'].toString(),
//                           title: ride['destination'],
//                           people: "${ride['seats_available']} seats left",
//                           gate: ride['meeting_point'],
//                           price: "",
//                           time: "Active",
//                           isMyRide: isMyRide,
//                           isFemaleOnly: isFemaleOnly,
//                           isActiveJoinedRide: isActiveJoinedRide,
//                           paymentMode: paymentMode, // 👇 NEW
//                           buttonColor: isFemaleOnly
//                               ? Colors.pink
//                               : const Color(0xFF34A853),
//                         );
//                       }),

//                     const SizedBox(height: 90),
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget _quickCard({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12), // Slightly reduced padding
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: color.withOpacity(.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(icon, color: color, size: 20),
//           ),
//           const SizedBox(width: 8),

//           // NEW: The Expanded widget prevents the 0.5px overflow!
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13,
//                   ),
//                   maxLines: 1,
//                   overflow:
//                       TextOverflow.ellipsis, // Adds "..." if it's too long
//                 ),
//                 if (subtitle.isNotEmpty)
//                   Text(
//                     subtitle,
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: Color(0xFF6B7280),
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _rideCard({
//     required String id,
//     required String title,
//     required String people,
//     required String gate,
//     required String price,
//     required String time,
//     required Color buttonColor,
//     required bool isMyRide,
//     required bool isFemaleOnly,
//     required bool isActiveJoinedRide,
//     required String paymentMode, // 👇 NEW
//   }) {
//     Color cardBackground = Colors.white;
//     Color buttonFinalColor = buttonColor;
//     String buttonText = "View";

//     if (isActiveJoinedRide) {
//       cardBackground = isFemaleOnly
//           ? Colors.pink.shade50
//           : const Color(0xFFE8F5E9);
//       buttonFinalColor = isFemaleOnly ? Colors.pink : const Color(0xFF34A853);
//       buttonText = "View Details";
//     } else if (isMyRide) {
//       buttonFinalColor = Colors.grey.shade400;
//       buttonText = "Your Ride";
//     }

//     return GestureDetector(
//       onTap: () async {
//         // 👇 FIXED: Removed the blocker! Now anyone can view ride details freely
//         await Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => MetroRideDetailsPage(rideId: id),
//           ),
//         );

//         // Always refresh when coming back
//         await _fetchDashboardData();
//       },
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 14),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: cardBackground,
//           borderRadius: BorderRadius.circular(22),
//           border: isActiveJoinedRide
//               ? Border.all(
//                   color: isFemaleOnly
//                       ? Colors.pink.shade300
//                       : Colors.green.shade300,
//                   width: 2,
//                 )
//               : (isFemaleOnly
//                     ? Border.all(color: Colors.pink.shade100, width: 1.5)
//                     : null),
//           boxShadow: isActiveJoinedRide
//               ? []
//               : [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.04),
//                     blurRadius: 10,
//                     offset: const Offset(0, 6),
//                   ),
//                 ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 4,
//                   backgroundColor: isFemaleOnly
//                       ? Colors.pink
//                       : const Color(0xFF34A853),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     title,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 16,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),

//                 if (isActiveJoinedRide)
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isFemaleOnly
//                           ? Colors.pink
//                           : const Color(0xFF34A853),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Row(
//                       children: [
//                         Icon(Icons.check, color: Colors.white, size: 12),
//                         SizedBox(width: 4),
//                         Text(
//                           "Joined",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//               ],
//             ),

//             const SizedBox(height: 6),

//             Row(
//               children: [
//                 const Icon(
//                   Icons.access_time,
//                   size: 14,
//                   color: Color(0xFF34A853),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   time,
//                   style: const TextStyle(
//                     color: Color(0xFF34A853),
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 10),

//             Row(
//               children: [
//                 const Icon(Icons.group, size: 16, color: Color(0xFF6B7280)),
//                 const SizedBox(width: 4),
//                 Text(people, style: const TextStyle(fontSize: 12)),
//                 const SizedBox(width: 8),
//                 const Icon(
//                   Icons.location_pin,
//                   size: 16,
//                   color: Color(0xFF6B7280),
//                 ),
//                 const SizedBox(width: 4),
//                 Flexible(
//                   child: Text(
//                     gate,
//                     style: const TextStyle(fontSize: 12),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 // 👇 Push everything before button to left
//                 // 👇 NEW: Payment Mode Badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 6,
//                     vertical: 3,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: BorderRadius.circular(6),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         paymentMode.contains('UPI')
//                             ? Icons.qr_code_scanner
//                             : Icons.payments_outlined,
//                         size: 12,
//                         color: const Color(0xFF4B5563),
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         paymentMode.replaceAll(" (Cash/UPI)", ""),
//                         style: const TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFF4B5563),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(width: 8),
//                 const Spacer(),

//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: buttonFinalColor,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     buttonText,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _bottomNavBar() {
//     return Container(
//       height: 80,
//       padding: const EdgeInsets.symmetric(
//         horizontal: 20,
//       ), // Adjusted for smaller screens
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.05),
//             blurRadius: 10,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           _navItem(Icons.home, "Home", true),

//           // NEW: Interactive Rides Button
//           // REPLACE the existing Rides button with this:
//           GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const MyRidesPage()),
//               );
//             },
//             child: _navItem(Icons.history, "Rides", false),
//           ),

//           GestureDetector(
//             onTap: () async {
//               final result = await Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const CreateRidePage()),
//               );
//               if (result == true) {
//                 setState(() {
//                   _searchQuery = "";
//                 });

//                 await _fetchDashboardData();
//               }
//             },
//             child: Container(
//               width: 56,
//               height: 56,
//               decoration: const BoxDecoration(
//                 color: Color(0xFF2F80ED),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.add, color: Colors.white),
//             ),
//           ),

//           // NEW: Interactive Map Button
//           // REPLACE the existing Map button with this:
//           GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const MapPage()),
//               );
//             },
//             child: _navItem(Icons.map, "Map", false),
//           ),

//           // FIXED: Use push instead of pushReplacement so the back button works on the Profile page
//           // NEW: Interactive Profile Button
//           // FIXED: Removed 'const' and named parameters to match your method signature
//           GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const ProfilePage()),
//               );
//             },
//             child: _navItem(Icons.person_outline, "Profile", false),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _navItem(IconData icon, String label, bool active) {
//     final color = active ? const Color(0xFF34A853) : const Color(0xFF6B7280);

//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: color, size: 22),
//         const SizedBox(height: 4),
//         Text(label, style: TextStyle(fontSize: 12, color: color)),
//       ],
//     );
//   }
// }
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../services/api_service.dart';
import 'create_ride_page.dart';
import 'map_page.dart';
import 'metro_ride_details_page.dart';
import 'my_rides_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ===========================================================================
  // DESIGN SYSTEM
  // ===========================================================================

  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color mutedLight = Color(0xFF94A3B8);

  static const Color canvas = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color line = Color(0xFFE8EDF3);

  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBright = Color(0xFF4F7CFF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color pink = Color(0xFFEC4899);
  static const Color orange = Color(0xFFF97316);

  // ===========================================================================
  // STATE
  // ===========================================================================

  String _userName = 'Student';
  String _userId = '';
  String _searchQuery = '';

  List<dynamic> _availableRides = [];

  bool _isLoading = true;
  bool _hasUnreadNotifications = false;

  late IO.Socket _socket;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _setupSocket();
    _loadDashboard();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _loadDashboard() async {
    try {
      await Future.delayed(const Duration(milliseconds: 220));

      final userResponse = await ApiService.getRequest('/auth/me');

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final user = userData['user'];

        final userId = user['id'].toString();
        final fullName = (user['name'] ?? 'Student').toString();

        if (mounted) {
          setState(() {
            _userId = userId;
            _userName = fullName.split(' ').first;
          });
        }

        if (_socket.connected) {
          _socket.emit('joinUserRoom', userId);
        }
      }

      await _checkUnreadNotifications();

      final ridesResponse =
          await ApiService.getRequest('/rides/nearby');

      if (ridesResponse.statusCode == 200) {
        final ridesData = jsonDecode(ridesResponse.body);
        final rides =
            ridesData['rides'] as List<dynamic>? ?? <dynamic>[];

        if (mounted) {
          setState(() {
            _availableRides = rides;
          });
        }
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final response =
          await ApiService.getRequest('/notifications');

      if (response.statusCode != 200 || !mounted) {
        return;
      }

      final data = jsonDecode(response.body);
      final notifications =
          data['notifications'] as List<dynamic>? ?? <dynamic>[];

      setState(() {
        _hasUnreadNotifications = notifications.any(
          (notification) => notification['is_read'] != true,
        );
      });
    } catch (e) {
      debugPrint('Notification check failed: $e');
    }
  }

  // ===========================================================================
  // SOCKET
  // ===========================================================================

  void _setupSocket() {
    _socket = IO.io(
      ApiService.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('AutoMate socket connected');

      if (_userId.isNotEmpty) {
        _socket.emit('joinUserRoom', _userId);
      }
    });

    _socket.on('newNotification', (_) {
      if (!mounted) return;

      setState(() {
        _hasUnreadNotifications = true;
      });
    });

    _socket.on('newRide', (_) {
      if (!mounted) return;
      _loadDashboard();
    });

    _socket.on('rideUpdated', (_) {
      if (!mounted) return;
      _loadDashboard();
    });

    _socket.onDisconnect((_) {
      debugPrint('AutoMate socket disconnected');
    });
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData get _greetingIcon {
    final hour = DateTime.now().hour;

    if (hour < 12) return Icons.wb_twilight_rounded;
    if (hour < 17) return Icons.wb_sunny_rounded;
    return Icons.nightlight_round;
  }

  List<dynamic> get _filteredRides {
    final query = _searchQuery.trim().toLowerCase();
    final rides = List<dynamic>.from(_availableRides);

    if (query.isEmpty) {
      return rides;
    }

    return rides.where((ride) {
      final destination =
          (ride['destination'] ?? '').toString().toLowerCase();

      final meetingPoint =
          (ride['meeting_point'] ?? '').toString().toLowerCase();

      final payment =
          (ride['payment_mode'] ?? '').toString().toLowerCase();

      return destination.contains(query) ||
          meetingPoint.contains(query) ||
          payment.contains(query);
    }).toList();
  }

  String _paymentLabel(String value) {
    return value
        .replaceAll(' (Cash/UPI)', '')
        .replaceAll('(Cash/UPI)', '')
        .trim();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  Future<void> _createRide({
    String? destination,
    String? meetingPoint,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRidePage(
          initialDestination: destination,
          initialMeetingPoint: meetingPoint,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openRide(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetroRideDetailsPage(
          rideId: id,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );

    if (mounted) {
      await _checkUnreadNotifications();
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfilePage(),
      ),
    );
  }

  void _openRides() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyRidesPage(),
      ),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPage(),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? _buildLoadingScreen()
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadDashboard,
                    color: greenDark,
                    displacement: 22,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildTopBar(),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            22,
                            20,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildHero(),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            26,
                            20,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildQuickActionsSection(),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildSearch(),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            27,
                            20,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildRidesHeader(),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            14,
                            20,
                            140,
                          ),
                          sliver: _filteredRides.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _buildEmptyState(),
                                )
                              : SliverList.builder(
                                  itemCount: _filteredRides.length,
                                  itemBuilder: (context, index) =>
                                      _buildRideCard(
                                    _filteredRides[index],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: _buildBottomBar(),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.07),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(23),
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: greenDark,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Getting things ready',
            style: TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Finding nearby rides for you',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: green.withOpacity(.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _greetingIcon,
                      size: 15,
                      color: greenDark,
                    ),
                  ),

                  const SizedBox(width: 9),

                  Text(
                    _greeting,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Hey, $_userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),

        _buildIconButton(
          icon: Icons.notifications_none_rounded,
          badge: _hasUnreadNotifications,
          onTap: _openNotifications,
        ),

        const SizedBox(width: 9),

        GestureDetector(
          onTap: _openProfile,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF8EF),
                  Color(0xFFDCEBFF),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.055),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 21,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: line,
              ),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.045),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 21,
              color: ink,
            ),
          ),

          if (badge)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D6D),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: canvas,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HERO
  // ===========================================================================

  Widget _buildHero() {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 188,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E1B2A),
            Color(0xFF132E42),
            Color(0xFF0F3E35),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1A27).withOpacity(.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -10,
            child: _heroGlow(
              size: 150,
              color: green.withOpacity(.16),
            ),
          ),

          Positioned(
            bottom: -55,
            left: 95,
            child: _heroGlow(
              size: 130,
              color: blue.withOpacity(.12),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              18,
              18,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(.10),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFA7F3D0),
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'SMART RIDE SHARING',
                              style: TextStyle(
                                color: Color(0xFFE8FFF4),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .55,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Move smarter.\nRide together.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),

                      const SizedBox(height: 9),

                      Text(
                        'Find classmates, split the ride,\nand get where you need to be.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.66),
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                _buildHeroVisual(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroGlow({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHeroVisual() {
    return SizedBox(
      width: 95,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 3,
            right: 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: green.withOpacity(.28),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: 29,
            left: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: blue.withOpacity(.38),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: 8,
            right: 3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5EE58A),
                  Color(0xFF22C55E),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(.26),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 33,
            ),
          ),

          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(.08),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    color: Color(0xFFA7F3D0),
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'LET\'S GO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Quick actions',
              style: TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -.35,
              ),
            ),
            Spacer(),
            Text(
              'One tap away',
              style: TextStyle(
                color: mutedLight,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        const Text(
          'Start a common route in seconds',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.subway_rounded,
                title: 'Go to Metro',
                subtitle: 'Create instantly',
                accent: green,
                onTap: () {
                  _createRide(
                    destination:
                        'National College Metro Station',
                    meetingPoint: 'BMSCE Gate 1',
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _quickAction(
                icon: Icons.school_rounded,
                title: 'Go to College',
                subtitle: 'Create instantly',
                accent: blue,
                onTap: () {
                  _createRide(
                    destination: 'BMSCE Campus',
                    meetingPoint:
                        'National College Metro Station',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: line,
            ),
            boxShadow: [
              BoxShadow(
                color: ink.withOpacity(.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(.18),
                      accent.withOpacity(.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 22,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_outward_rounded,
                color: accent,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch() {
    final hasText = _searchQuery.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasText
              ? green.withOpacity(.42)
              : line,
          width: hasText ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ink.withOpacity(.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText:
              'Search destination, pickup or payment...',
          hintStyle: const TextStyle(
            color: mutedLight,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: green.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: greenDark,
              size: 19,
            ),
          ),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: muted,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(
                    right: 12,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius:
                            BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: greenDark,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // RIDES HEADER
  // ===========================================================================

  Widget _buildRidesHeader() {
    final count = _filteredRides.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nearby rides',
                style: TextStyle(
                  color: ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Pick a route that fits your plan',
                style: TextStyle(
                  color: muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count ${count == 1 ? 'ride' : 'rides'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    final searching = _searchQuery.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(
        24,
        34,
        24,
        30,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: line,
        ),
        boxShadow: [
          BoxShadow(
            color: ink.withOpacity(.025),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  green.withOpacity(.14),
                  blue.withOpacity(.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.route_outlined,
              size: 32,
              color: searching ? blue : greenDark,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            searching
                ? 'Nothing matched your search'
                : 'No nearby rides yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            searching
                ? 'Try another destination or pickup point.'
                : 'Create a ride and let others join your route.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (!searching) ...[
            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: () => _createRide(),
              icon: const Icon(
                Icons.add_rounded,
                size: 17,
              ),
              label: const Text(
                'Create a ride',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // RIDE CARD
  // ===========================================================================

  Widget _buildRideCard(dynamic ride) {
    final String id =
        ride['id']?.toString() ?? '';

    final String destination =
        (ride['destination'] ??
                'Unknown destination')
            .toString();

    final String meetingPoint =
        (ride['meeting_point'] ??
                'Meeting point unavailable')
            .toString();

    final String creatorId =
        ride['creator_id']?.toString() ?? '';

    final bool isMyRide =
        creatorId.isNotEmpty &&
        creatorId == _userId;

    final dynamic femaleRaw =
        ride['female_only'];

    final bool isFemaleOnly =
        femaleRaw == true ||
        femaleRaw == 1 ||
        femaleRaw == '1' ||
        femaleRaw
            .toString()
            .toLowerCase() ==
            'true';

    final String paymentMode =
        (ride['payment_mode'] ??
                'Any (Cash/UPI)')
            .toString();

    final String seats =
        (ride['seats_available'] ??
                '0')
            .toString();

    final bool isMetro =
        destination
            .toLowerCase()
            .contains('metro');

    final Color accent =
        isFemaleOnly ? pink : green;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(26),
          onTap: () => _openRide(id),
          child: Ink(
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(26),
              border: Border.all(
                color: isFemaleOnly
                    ? const Color(0xFFF8D7E7)
                    : line,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      ink.withOpacity(.035),
                  blurRadius: 22,
                  offset:
                      const Offset(0, 9),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                15,
                15,
                15,
                13,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            begin:
                                Alignment.topLeft,
                            end:
                                Alignment.bottomRight,
                            colors: [
                              accent.withOpacity(
                                .17,
                              ),
                              accent.withOpacity(
                                .055,
                              ),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: Icon(
                          isMetro
                              ? Icons
                                  .subway_rounded
                              : Icons
                                  .directions_car_filled_rounded,
                          color: accent,
                          size: 23,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              destination,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color: ink,
                                fontSize: 15,
                                height: 1.18,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                letterSpacing:
                                    -.22,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .location_on_outlined,
                                  size: 13,
                                  color: muted,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    meetingPoint,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          muted,
                                      fontSize:
                                          10.5,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      _rideTypeChip(
                        label: isFemaleOnly
                            ? 'Women only'
                            : 'Open',
                        color: accent,
                        icon: isFemaleOnly
                            ? Icons
                                .female_rounded
                            : Icons
                                .people_alt_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: surfaceSoft,
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFF0F3F7,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _detailBox(
                            icon: Icons
                                .groups_rounded,
                            title: 'Seats',
                            value:
                                '$seats left',
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: _detailBox(
                            icon: paymentMode
                                    .toLowerCase()
                                    .contains(
                                      'upi',
                                    )
                                ? Icons
                                    .qr_code_rounded
                                : Icons
                                    .payments_outlined,
                            title: 'Payment',
                            value:
                                _paymentLabel(
                              paymentMode,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: _detailBox(
                            icon: Icons
                                .bolt_rounded,
                            title: 'Status',
                            value: 'Active',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 13,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration:
                                  BoxDecoration(
                                color: accent,
                                shape:
                                    BoxShape
                                        .circle,
                              ),
                            ),

                            const SizedBox(
                              width: 7,
                            ),

                            Flexible(
                              child: Text(
                                isMyRide
                                    ? 'Created by you'
                                    : 'Tap to view ride',
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: ink,
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Text(
                              'View ride',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 9.5,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              color:
                                  Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rideTypeChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: color,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.3,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: muted,
          size: 14,
        ),

        const SizedBox(
          width: 7,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      mutedLight,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                value,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: ink,
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION
  // ===========================================================================

  Widget _buildBottomBar() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(.97),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                ink.withOpacity(.12),
            blurRadius: 32,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _navItem(
              icon:
                  Icons.home_rounded,
              label: 'Home',
              active: true,
              onTap: () {},
            ),
          ),

          Expanded(
            child: _navItem(
              icon:
                  Icons.history_rounded,
              label: 'Rides',
              onTap: _openRides,
            ),
          ),

          SizedBox(
            width: 76,
            child: Center(
              child: GestureDetector(
                onTap:
                    () => _createRide(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end: Alignment
                          .bottomRight,
                      colors: [
                        blueBright,
                        blue,
                      ],
                    ),
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: blue
                            .withOpacity(
                          .30,
                        ),
                        blurRadius: 18,
                        offset:
                            const Offset(
                          0,
                          8,
                        ),
                      ),
                    ],
                  ),
                  child:
                      const Icon(
                    Icons
                        .add_rounded,
                    color:
                        Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _navItem(
              icon:
                  Icons.map_outlined,
              label: 'Map',
              onTap: _openMap,
            ),
          ),

          Expanded(
            child: _navItem(
              icon:
                  Icons.person_outline_rounded,
              label: 'Profile',
              onTap:
                  _openProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final Color color =
        active ? greenDark : mutedLight;

    return GestureDetector(
      onTap: onTap,
      behavior:
          HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            width: 38,
            height: 30,
            decoration:
                BoxDecoration(
              color: active
                  ? green.withOpacity(
                      .11,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size:
                  active ? 21 : 20,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.8,
              fontWeight: active
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}