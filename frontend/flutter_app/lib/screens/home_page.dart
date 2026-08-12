import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import 'create_ride_page.dart';
import 'my_rides_page.dart';
import 'map_page.dart';
import 'notifications_page.dart';
import 'metro_ride_details_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "Student";
  String _userId = "";
  List<dynamic> _availableRides = [];
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  String _searchQuery = ""; // NEW: Tracks the search bar input
  // 👇 NEW: Track the currently joined ride for the UI & Double-Booking check
  String? _activeRideId;
  String? _activeRideDest;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _setupGlobalSocket();
  }

  Future<void> _fetchDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      // 1. Fetch user profile
      final userResponse = await ApiService.getRequest('/auth/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);

        final userId = userData['user']['id'].toString();

        if (mounted) {
          setState(() {
            _userName = userData['user']['name'].split(' ')[0];
            _userId = userId;
          });
        }

        // Join this user's personal notification room
        if (_socket.connected) {
          _socket.emit('joinUserRoom', userId);
        }
      }

      await _refreshUnreadStatus();
      // 2. NEW: Fetch My Rides to check active ride
      final myRidesResponse = await ApiService.getRequest('/rides/my-rides');
      if (myRidesResponse.statusCode == 200) {
        final myRidesData = jsonDecode(myRidesResponse.body);
        final joinedRides = myRidesData['joined'] as List<dynamic>? ?? [];

        final active = joinedRides.cast<dynamic?>().firstWhere(
          (r) => r != null && r['status'] != 'completed',
          orElse: () => null,
        );

        setState(() {
          if (active != null) {
            _activeRideId = active['id'].toString();
            _activeRideDest = active['destination'].toString();
          } else {
            _activeRideId = null;
            _activeRideDest = null;
          }
        });
      }

      // 3. Fetch nearby rides
      final ridesResponse = await ApiService.getRequest('/rides/nearby');
      if (ridesResponse.statusCode == 200) {
        final ridesData = jsonDecode(ridesResponse.body);
        setState(() {
          _availableRides = ridesData['rides'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUnreadStatus() async {
    try {
      final response = await ApiService.getRequest('/notifications');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List<dynamic>? ?? [];

        setState(() {
          _hasUnreadNotifications = notifications.any((notification) {
            return notification['is_read'] != true;
          });
        });
      }
    } catch (e) {
      debugPrint("Error checking notification status: $e");
    }
  }

  // 👇 NEW: Listen to the backend for real-time ride updates
  void _setupGlobalSocket() {
    _socket = IO.io(
      ApiService.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('HomePage connected to Socket.io for live updates');

      // Join personal notification room once socket connection is ready
      if (_userId.isNotEmpty) {
        _socket.emit('joinUserRoom', _userId);
        debugPrint('Joined personal notification room: user_$_userId');
      }
    });

    _socket.on('newNotification', (_) {
      debugPrint('New notification received');

      if (mounted) {
        setState(() {
          _hasUnreadNotifications = true;
        });
      }
    });

    // Listen for a 'newRide' or 'rideUpdated' event from the server
    _socket.on('newRide', (_) {
      debugPrint('A new ride was created! Updating UI silently...');
      if (mounted) {
        _fetchDashboardData(); // Silently pulls the fresh list without a loading screen!
      }
    });

    _socket.onDisconnect(
      (_) => debugPrint('HomePage disconnected from Socket.io'),
    );
  }

  IconData getGreetingIcon() {
    final hour = DateTime.now().hour;

    if (hour < 12) return Icons.wb_twilight; // morning
    if (hour < 17) return Icons.light_mode; // day
    return Icons.nightlight_round; // night
  }

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayRides = _searchQuery.isEmpty
        ? _availableRides
        : _availableRides.where((ride) {
            final dest = (ride['destination'] ?? '').toString().toLowerCase();
            final search = _searchQuery.toLowerCase().trim();

            if (dest.contains(search)) return true;

            final collegeKeywords = ['college', 'bmsce', 'bms'];
            final isSearchingCollege = collegeKeywords.any(
              (kw) => kw.startsWith(search) || search.contains(kw),
            );

            if (isSearchingCollege) {
              if (collegeKeywords.any((kw) => dest.contains(kw))) return true;
            }

            final metroKeywords = ['metro', 'national college', 'station'];
            final isSearchingMetro = metroKeywords.any(
              (kw) => kw.startsWith(search) || search.contains(kw),
            );

            if (isSearchingMetro) {
              if (metroKeywords.any((kw) => dest.contains(kw))) return true;
            }

            return false;
          }).toList();
    // 👇 NEW: Pin active ride to top
    displayRides.sort((a, b) {
      final idA = a['id'].toString();
      final idB = b['id'].toString();

      if (idA == _activeRideId) return -1;
      if (idB == _activeRideId) return 1;
      return 0;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      bottomNavigationBar: _bottomNavBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34A853)),
              )
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                color: const Color(0xFF34A853),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),

                    /// HEADER
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hi, $_userName 👋",
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    getGreetingIcon(),
                                    size: 16,
                                    color: Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    getGreeting(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        /// Notifications
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationsPage(),
                              ),
                            );

                            // Refresh unread status after returning from NotificationsPage
                            await _refreshUnreadStatus();
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  size: 22,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              if (_hasUnreadNotifications)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// Profile
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfilePage(),
                              ),
                            );
                          },
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFDCE7EE),
                            child: Icon(Icons.person, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// LOGO
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "Auto",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34A853),
                            ),
                          ),
                          TextSpan(
                            text: "Mate",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2F80ED),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// QUICK ACTIONS
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateRidePage(
                                    initialDestination:
                                        "National College Metro Station",
                                    initialMeetingPoint: "BMSCE Gate 1",
                                  ),
                                ),
                              );
                              if (result == true) {
                                setState(() {
                                  _searchQuery = "";
                                });

                                await _fetchDashboardData();
                              }
                            },
                            child: _quickCard(
                              icon: Icons.directions_subway,
                              title: "Go to Metro",
                              subtitle: "Auto-fill ride",
                              color: const Color(0xFF34A853),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateRidePage(
                                    initialDestination: "BMSCE Campus",
                                    initialMeetingPoint:
                                        "National College Metro Station",
                                  ),
                                ),
                              );
                              if (result == true) {
                                setState(() {
                                  _searchQuery = "";
                                });

                                await _fetchDashboardData();
                              }
                            },
                            child: _quickCard(
                              icon: Icons.school,
                              title: "Go to College",
                              subtitle: "Auto-fill ride",
                              color: const Color(0xFF2F80ED),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    /// SEARCH
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                          hintText: "Search destinations or gates...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// HEADER
                    const Text(
                      "Available Rides",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// RIDES
                    if (displayRides.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No rides available"),
                        ),
                      )
                    else
                      ...displayRides.map<Widget>((ride) {
                        final bool isMetro = ride['destination']
                            .toString()
                            .toLowerCase()
                            .contains('metro');

                        final isFemaleOnlyRaw = ride['female_only'];

                        final bool isFemaleOnly =
                            isFemaleOnlyRaw == true ||
                            isFemaleOnlyRaw == 1 ||
                            isFemaleOnlyRaw == "1" ||
                            isFemaleOnlyRaw.toString().toLowerCase() == "true";

                        final String creatorId =
                            ride['creator_id']?.toString() ?? '';
                        final bool isMyRide = creatorId == _userId;
                        final bool isActiveJoinedRide =
                            ride['id'].toString() == _activeRideId;

                        // 👇 NEW: Extract payment mode
                        final String paymentMode =
                            ride['payment_mode'] ?? 'Any (Cash/UPI)';

                        return _rideCard(
                          id: ride['id'].toString(),
                          title: ride['destination'],
                          people: "${ride['seats_available']} seats left",
                          gate: ride['meeting_point'],
                          price: "",
                          time: "Active",
                          isMyRide: isMyRide,
                          isFemaleOnly: isFemaleOnly,
                          isActiveJoinedRide: isActiveJoinedRide,
                          paymentMode: paymentMode, // 👇 NEW
                          buttonColor: isFemaleOnly
                              ? Colors.pink
                              : const Color(0xFF34A853),
                        );
                      }),

                    const SizedBox(height: 90),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Slightly reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),

          // NEW: The Expanded widget prevents the 0.5px overflow!
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis, // Adds "..." if it's too long
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideCard({
    required String id,
    required String title,
    required String people,
    required String gate,
    required String price,
    required String time,
    required Color buttonColor,
    required bool isMyRide,
    required bool isFemaleOnly,
    required bool isActiveJoinedRide,
    required String paymentMode, // 👇 NEW
  }) {
    Color cardBackground = Colors.white;
    Color buttonFinalColor = buttonColor;
    String buttonText = "View";

    if (isActiveJoinedRide) {
      cardBackground = isFemaleOnly
          ? Colors.pink.shade50
          : const Color(0xFFE8F5E9);
      buttonFinalColor = isFemaleOnly ? Colors.pink : const Color(0xFF34A853);
      buttonText = "View Details";
    } else if (isMyRide) {
      buttonFinalColor = Colors.grey.shade400;
      buttonText = "Your Ride";
    }

    return GestureDetector(
      onTap: () async {
        // 👇 FIXED: Removed the blocker! Now anyone can view ride details freely
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetroRideDetailsPage(rideId: id),
          ),
        );

        // Always refresh when coming back
        await _fetchDashboardData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: isActiveJoinedRide
              ? Border.all(
                  color: isFemaleOnly
                      ? Colors.pink.shade300
                      : Colors.green.shade300,
                  width: 2,
                )
              : (isFemaleOnly
                    ? Border.all(color: Colors.pink.shade100, width: 1.5)
                    : null),
          boxShadow: isActiveJoinedRide
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: isFemaleOnly
                      ? Colors.pink
                      : const Color(0xFF34A853),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isActiveJoinedRide)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFemaleOnly
                          ? Colors.pink
                          : const Color(0xFF34A853),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          "Joined",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Color(0xFF34A853),
                ),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF34A853),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.group, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(people, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                const Icon(
                  Icons.location_pin,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    gate,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 👇 Push everything before button to left
                // 👇 NEW: Payment Mode Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        paymentMode.contains('UPI')
                            ? Icons.qr_code_scanner
                            : Icons.payments_outlined,
                        size: 12,
                        color: const Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paymentMode.replaceAll(" (Cash/UPI)", ""),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: buttonFinalColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ), // Adjusted for smaller screens
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(Icons.home, "Home", true),

          // NEW: Interactive Rides Button
          // REPLACE the existing Rides button with this:
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyRidesPage()),
              );
            },
            child: _navItem(Icons.history, "Rides", false),
          ),

          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateRidePage()),
              );
              if (result == true) {
                setState(() {
                  _searchQuery = "";
                });

                await _fetchDashboardData();
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF2F80ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),

          // NEW: Interactive Map Button
          // REPLACE the existing Map button with this:
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
            child: _navItem(Icons.map, "Map", false),
          ),

          // FIXED: Use push instead of pushReplacement so the back button works on the Profile page
          // NEW: Interactive Profile Button
          // FIXED: Removed 'const' and named parameters to match your method signature
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: _navItem(Icons.person_outline, "Profile", false),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    final color = active ? const Color(0xFF34A853) : const Color(0xFF6B7280);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}













// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;

// import '../services/api_service.dart';
// import 'create_ride_page.dart';
// import 'map_page.dart';
// import 'metro_ride_details_page.dart';
// import 'my_rides_page.dart';
// import 'notifications_page.dart';
// import 'profile_page.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   // ===========================================================================
//   // COLORS
//   // ===========================================================================

//   static const Color ink = Color(0xFF0B1220);
//   static const Color inkSoft = Color(0xFF334155);
//   static const Color muted = Color(0xFF64748B);
//   static const Color mutedLight = Color(0xFF94A3B8);

//   static const Color canvas = Color(0xFFF5F7FB);
//   static const Color surface = Colors.white;
//   static const Color surfaceSoft = Color(0xFFF8FAFC);
//   static const Color line = Color(0xFFE8EDF3);

//   static const Color green = Color(0xFF22C55E);
//   static const Color greenDark = Color(0xFF16A34A);
//   static const Color blue = Color(0xFF2563EB);
//   static const Color blueBright = Color(0xFF4F7CFF);
//   static const Color pink = Color(0xFFEC4899);
//   static const Color orange = Color(0xFFF97316);

//   // ===========================================================================
//   // STATE
//   // ===========================================================================

//   String _userName = 'Student';
//   String _userId = '';
//   String _searchQuery = '';

//   List<dynamic> _availableRides = [];

//   // Currently joined active ride.
//   String? _activeRideId;
//   String? _activeRideDestination;

//   bool _isLoading = true;
//   bool _hasUnreadNotifications = false;

//   late IO.Socket _socket;

//   // ===========================================================================
//   // LIFECYCLE
//   // ===========================================================================

//   @override
//   void initState() {
//     super.initState();

//     _setupSocket();
//     _loadDashboard();
//   }

//   @override
//   void dispose() {
//     _socket.disconnect();
//     _socket.dispose();
//     super.dispose();
//   }

//   // ===========================================================================
//   // DATA
//   // ===========================================================================

//   Future<void> _loadDashboard() async {
//     await Future.delayed(const Duration(milliseconds: 300));
//     try {
//       // 1. Fetch user profile
//       final userResponse = await ApiService.getRequest('/auth/me');
//       if (userResponse.statusCode == 200) {
//         final userData = jsonDecode(userResponse.body);
//         final userId = userData['user']['id'].toString();

//         if (mounted) {
//           setState(() {
//             _userName = (userData['user']['name'] ?? 'Student')
//                 .toString()
//                 .split(' ')
//                 .first;
//             _userId = userId;
//           });
//         }

//         if (_socket.connected) {
//           _socket.emit('joinUserRoom', userId);
//         }
//       }

//       // 2. Refresh notifications
//       await _checkUnreadNotifications();

//       // 3. Check the user's joined rides for an active ride.
//       final myRidesResponse = await ApiService.getRequest('/rides/my-rides');
//       if (myRidesResponse.statusCode == 200) {
//         final myRidesData = jsonDecode(myRidesResponse.body);
//         final joinedRides =
//             myRidesData['joined'] as List<dynamic>? ?? <dynamic>[];

//         dynamic active;
//         for (final ride in joinedRides) {
//           final status = (ride['status'] ?? '').toString().toLowerCase().trim();
//           if (status != 'completed') {
//             active = ride;
//             break;
//           }
//         }

//         if (mounted) {
//           setState(() {
//             if (active != null) {
//               _activeRideId = active['id']?.toString();
//               _activeRideDestination = active['destination']?.toString();
//             } else {
//               _activeRideId = null;
//               _activeRideDestination = null;
//             }
//           });
//         }
//       }

//       // 4. Fetch nearby rides
//       final ridesResponse = await ApiService.getRequest('/rides/nearby');
//       if (ridesResponse.statusCode == 200) {
//         final ridesData = jsonDecode(ridesResponse.body);
//         final rides = ridesData['rides'] as List<dynamic>? ?? <dynamic>[];

//         if (mounted) {
//           setState(() {
//             _availableRides = rides;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching dashboard data: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _loadActiveJoinedRide() async {
//     try {
//       final response =
//           await ApiService.getRequest(
//         '/rides/my-rides',
//       );

//       if (response.statusCode != 200) {
//         return;
//       }

//       final data =
//           jsonDecode(response.body);

//       final List<dynamic> joinedRides =
//           data['joined'] as List<dynamic>? ??
//               <dynamic>[];

//       dynamic activeRide;

//       for (final ride in joinedRides) {
//         final String status =
//             (ride['status'] ?? '')
//                 .toString()
//                 .toLowerCase()
//                 .trim();

//         final bool isFinished =
//             status == 'completed' ||
//             status == 'cancelled' ||
//             status == 'canceled';

//         if (!isFinished) {
//           activeRide = ride;
//           break;
//         }
//       }

//       if (!mounted) {
//         return;
//       }

//       setState(() {
//         if (activeRide != null) {
//           _activeRideId =
//               activeRide['id']?.toString();

//           _activeRideDestination =
//               activeRide['destination']
//                   ?.toString();
//         } else {
//           _activeRideId = null;
//           _activeRideDestination = null;
//         }
//       });
//     } catch (e) {
//       debugPrint(
//         'Active ride check failed: $e',
//       );
//     }
//   }

//   Future<void> _checkUnreadNotifications() async {
//     try {
//       final response =
//           await ApiService.getRequest(
//         '/notifications',
//       );

//       if (response.statusCode != 200 ||
//           !mounted) {
//         return;
//       }

//       final data =
//           jsonDecode(response.body);

//       final notifications =
//           data['notifications']
//                   as List<dynamic>? ??
//               <dynamic>[];

//       setState(() {
//         _hasUnreadNotifications =
//             notifications.any(
//           (notification) =>
//               notification['is_read'] != true,
//         );
//       });
//     } catch (e) {
//       debugPrint(
//         'Notification check failed: $e',
//       );
//     }
//   }

//   // ===========================================================================
//   // SOCKET
//   // ===========================================================================

//   void _setupSocket() {
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

//       if (_userId.isNotEmpty) {
//         _socket.emit('joinUserRoom', _userId);
//       }
//     });

//     _socket.on('newNotification', (_) {
//       if (!mounted) return;
//       setState(() {
//         _hasUnreadNotifications = true;
//       });
//     });

//     _socket.on('newRide', (_) {
//       if (!mounted) return;
//       _loadDashboard();
//     });

//     _socket.onDisconnect((_) {
//       debugPrint('HomePage disconnected from Socket.io');
//     });
//   }

//   // ===========================================================================
//   // HELPERS
//   // ===========================================================================

//   String get _greeting {
//     final int hour =
//         DateTime.now().hour;

//     if (hour < 12) {
//       return 'Good morning';
//     }

//     if (hour < 17) {
//       return 'Good afternoon';
//     }

//     return 'Good evening';
//   }

//   IconData get _greetingIcon {
//     final int hour =
//         DateTime.now().hour;

//     if (hour < 12) {
//       return Icons.wb_twilight_rounded;
//     }

//     if (hour < 17) {
//       return Icons.wb_sunny_rounded;
//     }

//     return Icons.nightlight_round;
//   }

//   List<dynamic> get _filteredRides {
//     final String search = _searchQuery.toLowerCase().trim();
//     final List<dynamic> rides = List<dynamic>.from(_availableRides);

//     if (search.isNotEmpty) {
//       rides.removeWhere((ride) {
//         final String destination =
//             (ride['destination'] ?? '').toString().toLowerCase();

//         if (destination.contains(search)) {
//           return false;
//         }

//         const collegeKeywords = ['college', 'bmsce', 'bms'];
//         final bool isSearchingCollege = collegeKeywords.any(
//           (keyword) =>
//               keyword.startsWith(search) || search.contains(keyword),
//         );

//         if (isSearchingCollege &&
//             collegeKeywords.any((keyword) => destination.contains(keyword))) {
//           return false;
//         }

//         const metroKeywords = ['metro', 'national college', 'station'];
//         final bool isSearchingMetro = metroKeywords.any(
//           (keyword) =>
//               keyword.startsWith(search) || search.contains(keyword),
//         );

//         if (isSearchingMetro &&
//             metroKeywords.any((keyword) => destination.contains(keyword))) {
//           return false;
//         }

//         return true;
//       });
//     }

//     // Keep the user's active/joined ride pinned at the top.
//     if (_activeRideId != null) {
//       rides.sort((a, b) {
//         final String idA = a['id']?.toString() ?? '';
//         final String idB = b['id']?.toString() ?? '';

//         if (idA == _activeRideId) return -1;
//         if (idB == _activeRideId) return 1;
//         return 0;
//       });
//     }

//     return rides;
//   }

//   String _paymentLabel(
//     String value,
//   ) {
//     return value
//         .replaceAll(
//           ' (Cash/UPI)',
//           '',
//         )
//         .replaceAll(
//           '(Cash/UPI)',
//           '',
//         )
//         .trim();
//   }

//   // ===========================================================================
//   // NAVIGATION
//   // ===========================================================================

//   Future<void> _createRide({
//     String? destination,
//     String? meetingPoint,
//   }) async {
//     final result =
//         await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             CreateRidePage(
//           initialDestination:
//               destination,
//           initialMeetingPoint:
//               meetingPoint,
//         ),
//       ),
//     );

//     if (result == true &&
//         mounted) {
//       await _loadDashboard();
//     }
//   }

//   Future<void> _openRide(
//     String id,
//   ) async {
//     await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             MetroRideDetailsPage(
//           rideId: id,
//         ),
//       ),
//     );

//     if (mounted) {
//       await _loadDashboard();
//     }
//   }

//   Future<void> _openNotifications() async {
//     await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             const NotificationsPage(),
//       ),
//     );

//     if (mounted) {
//       await _checkUnreadNotifications();
//     }
//   }

//   void _openProfile() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             const ProfilePage(),
//       ),
//     );
//   }

//   void _openRides() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             const MyRidesPage(),
//       ),
//     );
//   }

//   void _openMap() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             const MapPage(),
//       ),
//     );
//   }

//   // ===========================================================================
//   // BUILD
//   // ===========================================================================



//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: canvas,
//       body: SafeArea(
//         bottom: false,
//         child: _isLoading
//             ? _buildLoadingScreen()
//             : Stack(
//                 children: [
//                   RefreshIndicator(
//                     onRefresh: _loadDashboard,
//                     color: greenDark,
//                     backgroundColor: surface,
//                     displacement: 22,
//                     child: CustomScrollView(
//                       physics: const BouncingScrollPhysics(
//                         parent: AlwaysScrollableScrollPhysics(),
//                       ),
//                       slivers: [
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
//                           sliver: SliverToBoxAdapter(child: _buildPremiumHeader()),
//                         ),
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
//                           sliver: SliverToBoxAdapter(child: _buildPremiumHero()),
//                         ),
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
//                           sliver: SliverToBoxAdapter(child: _buildQuickActionsSection()),
//                         ),
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
//                           sliver: SliverToBoxAdapter(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Padding(
//                                   padding: EdgeInsets.only(left: 2, bottom: 10),
//                                   child: Text(
//                                     'Find a ride',
//                                     style: TextStyle(
//                                       color: ink,
//                                       fontSize: 15,
//                                       fontWeight: FontWeight.w900,
//                                     ),
//                                   ),
//                                 ),
//                                 _buildSearch(),
//                               ],
//                             ),
//                           ),
//                         ),
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
//                           sliver: SliverToBoxAdapter(child: _buildRidesHeader()),
//                         ),
//                         SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(20, 14, 20, 126),
//                           sliver: _filteredRides.isEmpty
//                               ? SliverToBoxAdapter(child: _buildEmptyState())
//                               : SliverList.builder(
//                                   itemCount: _filteredRides.length,
//                                   itemBuilder: (context, index) =>
//                                       _buildRideCard(_filteredRides[index]),
//                                 ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Positioned(
//                     left: 18,
//                     right: 18,
//                     bottom: 12,
//                     child: _buildBottomBar(),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }

//   Widget _buildLoadingScreen() {
//     return Container(
//       color: canvas,
//       alignment: Alignment.center,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 78,
//             height: 78,
//             decoration: BoxDecoration(
//               color: ink,
//               borderRadius: BorderRadius.circular(24),
//               boxShadow: [
//                 BoxShadow(
//                   color: ink.withOpacity(.14),
//                   blurRadius: 30,
//                   offset: const Offset(0, 14),
//                 ),
//               ],
//             ),
//             child: const Icon(
//               Icons.directions_car_filled_rounded,
//               color: Colors.white,
//               size: 32,
//             ),
//           ),
//           const SizedBox(height: 18),
//           const Text(
//             'Getting things ready',
//             style: TextStyle(
//               color: ink,
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           const SizedBox(height: 6),
//           const Text(
//             'Finding nearby rides for you',
//             style: TextStyle(
//               color: muted,
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 18),
//           const SizedBox(
//             width: 28,
//             height: 28,
//             child: CircularProgressIndicator(
//               strokeWidth: 2.4,
//               color: greenDark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPremiumHeader() {
//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Container(
//                     width: 30,
//                     height: 30,
//                     decoration: BoxDecoration(
//                       color: green.withOpacity(.11),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Icon(
//                       _greetingIcon,
//                       color: greenDark,
//                       size: 16,
//                     ),
//                   ),
//                   const SizedBox(width: 9),
//                   Text(
//                     _greeting,
//                     style: const TextStyle(
//                       color: inkSoft,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Hey, $_userName',
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: ink,
//                   fontSize: 25,
//                   height: 1,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -0.7,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         _buildIconButton(
//           icon: Icons.notifications_none_rounded,
//           badge: _hasUnreadNotifications,
//           onTap: _openNotifications,
//         ),
//         const SizedBox(width: 10),
//         GestureDetector(
//           onTap: _openProfile,
//           child: Container(
//             width: 46,
//             height: 46,
//             decoration: BoxDecoration(
//               color: surface,
//               shape: BoxShape.circle,
//               border: Border.all(color: line),
//               boxShadow: [
//                 BoxShadow(
//                   color: ink.withOpacity(.06),
//                   blurRadius: 18,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: const Icon(
//               Icons.person_outline_rounded,
//               color: ink,
//               size: 21,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildIconButton({
//     required IconData icon,
//     required VoidCallback onTap,
//     bool badge = false,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Container(
//             width: 46,
//             height: 46,
//             decoration: BoxDecoration(
//               color: surface,
//               shape: BoxShape.circle,
//               border: Border.all(color: line),
//               boxShadow: [
//                 BoxShadow(
//                   color: ink.withOpacity(.05),
//                   blurRadius: 18,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: Icon(icon, color: ink, size: 21),
//           ),
//           if (badge)
//             Positioned(
//               top: 0,
//               right: 0,
//               child: Container(
//                 width: 11,
//                 height: 11,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFF4D6D),
//                   shape: BoxShape.circle,
//                   border: Border.all(color: canvas, width: 2),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPremiumHero() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
//       decoration: BoxDecoration(
//         color: ink,
//         borderRadius: BorderRadius.circular(30),
//         boxShadow: [
//           BoxShadow(
//             color: ink.withOpacity(.16),
//             blurRadius: 30,
//             offset: const Offset(0, 16),
//           ),
//         ],
//       ),
//       child: Stack(
//         children: [
//           Positioned(
//             top: -48,
//             right: -24,
//             child: Container(
//               width: 150,
//               height: 150,
//               decoration: BoxDecoration(
//                 color: green.withOpacity(.13),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: -55,
//             left: 78,
//             child: Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 color: blue.withOpacity(.10),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 9,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(.08),
//                         borderRadius: BorderRadius.circular(999),
//                         border: Border.all(
//                           color: Colors.white.withOpacity(.08),
//                         ),
//                       ),
//                       child: const Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.auto_awesome_rounded,
//                             color: Color(0xFFA7F3D0),
//                             size: 12,
//                           ),
//                           SizedBox(width: 5),
//                           Text(
//                             'SMART RIDE SHARING',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 8,
//                               fontWeight: FontWeight.w900,
//                               letterSpacing: .55,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     const Text(
//                       'Move smarter.\nRide together.',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 30,
//                         height: 1.02,
//                         fontWeight: FontWeight.w900,
//                         letterSpacing: -1.25,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       'Find classmates, split the ride,\nand get where you need to be.',
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(.76),
//                         fontSize: 12.5,
//                         height: 1.45,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Container(
//                 width: 94,
//                 height: 134,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(.055),
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(
//                     color: Colors.white.withOpacity(.07),
//                   ),
//                 ),
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     Positioned(
//                       top: 14,
//                       right: 14,
//                       child: Container(
//                         width: 9,
//                         height: 9,
//                         decoration: BoxDecoration(
//                           color: green.withOpacity(.55),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       top: 29,
//                       left: 13,
//                       child: Container(
//                         width: 7,
//                         height: 7,
//                         decoration: BoxDecoration(
//                           color: blue.withOpacity(.65),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     ),
//                     Container(
//                       width: 68,
//                       height: 68,
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                           colors: [Color(0xFF5EE58A), Color(0xFF22C55E)],
//                         ),
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: green.withOpacity(.24),
//                             blurRadius: 24,
//                             offset: const Offset(0, 10),
//                           ),
//                         ],
//                       ),
//                       child: const Icon(
//                         Icons.directions_car_filled_rounded,
//                         color: Colors.white,
//                         size: 30,
//                       ),
//                     ),
//                     Positioned(
//                       bottom: 10,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 6,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(.09),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: const Text(
//                           'LET\'S GO',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 7.5,
//                             fontWeight: FontWeight.w900,
//                             letterSpacing: .55,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildQuickActionsSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Text(
//               'Quick actions',
//               style: TextStyle(
//                 color: ink,
//                 fontSize: 19,
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: -.4,
//               ),
//             ),
//             Spacer(),
//             Text(
//               'Fast routes',
//               style: TextStyle(
//                 color: muted,
//                 fontSize: 11,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           'Start a common route in seconds',
//           style: TextStyle(
//             color: inkSoft,
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         const SizedBox(height: 14),
//         Row(
//           children: [
//             Expanded(
//               child: _quickAction(
//                 icon: Icons.subway_rounded,
//                 title: 'Go to Metro',
//                 subtitle: 'Create instantly',
//                 accent: green,
//                 onTap: () => _createRide(
//                   destination: 'National College Metro Station',
//                   meetingPoint: 'BMSCE Gate 1',
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _quickAction(
//                 icon: Icons.school_rounded,
//                 title: 'Go to College',
//                 subtitle: 'Create instantly',
//                 accent: blue,
//                 onTap: () => _createRide(
//                   destination: 'BMSCE Campus',
//                   meetingPoint: 'National College Metro Station',
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _quickAction({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color accent,
//     required VoidCallback onTap,
//   }) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(20),
//         child: Ink(
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: surface,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: line),
//             boxShadow: [
//               BoxShadow(
//                 color: ink.withOpacity(.035),
//                 blurRadius: 18,
//                 offset: const Offset(0, 8),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 45,
//                 height: 45,
//                 decoration: BoxDecoration(
//                   color: accent.withOpacity(.10),
//                   borderRadius: BorderRadius.circular(15),
//                 ),
//                 child: Icon(icon, color: accent, size: 21),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: ink,
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: inkSoft,
//                         fontSize: 11.5,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Icon(Icons.arrow_outward_rounded, color: accent, size: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearch() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: line),
//         boxShadow: [
//           BoxShadow(
//             color: ink.withOpacity(.035),
//             blurRadius: 18,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: TextField(
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//         decoration: const InputDecoration(
//           icon: Icon(Icons.search_rounded, color: greenDark, size: 21),
//           hintText: 'Search destinations or gates...',
//           hintStyle: TextStyle(
//             color: muted,
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//           ),
//           border: InputBorder.none,
//         ),
//       ),
//     );
//   }

//   Widget _buildRidesHeader() {
//     final int count = _filteredRides.length;
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         const Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Nearby rides',
//                 style: TextStyle(
//                   color: ink,
//                   fontSize: 20,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -.5,
//                 ),
//               ),
//               SizedBox(height: 4),
//               Text(
//                 'Choose a route that fits your plan',
//                 style: TextStyle(
//                   color: inkSoft,
//                   fontSize: 11.5,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//           decoration: BoxDecoration(
//             color: ink,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Text(
//             '$count ${count == 1 ? 'ride' : 'rides'}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 9,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildEmptyState() {
//     final bool searching = _searchQuery.trim().isNotEmpty;
//     return Container(
//       padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(26),
//         border: Border.all(color: line),
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 70,
//             height: 70,
//             decoration: BoxDecoration(
//               color: green.withOpacity(.09),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               searching ? Icons.search_off_rounded : Icons.route_outlined,
//               size: 30,
//               color: searching ? blue : greenDark,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             searching ? 'Nothing matched your search' : 'No nearby rides yet',
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: ink,
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           const SizedBox(height: 7),
//           Text(
//             searching
//                 ? 'Try another destination or pickup point.'
//                 : 'Create a ride and let others join your route.',
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: muted,
//               fontSize: 12.5,
//               height: 1.55,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           if (!searching) ...[
//             const SizedBox(height: 18),
//             ElevatedButton.icon(
//               onPressed: () => _createRide(),
//               icon: const Icon(Icons.add_rounded, size: 17),
//               label: const Text(
//                 'Create a ride',
//                 style: TextStyle(
//                   fontSize: 11.5,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 elevation: 0,
//                 backgroundColor: ink,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 13,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildRideCard(dynamic ride) {
//     final String id = ride['id']?.toString() ?? '';
//     final String destination =
//         (ride['destination'] ?? 'Unknown destination').toString();
//     final String meetingPoint =
//         (ride['meeting_point'] ?? 'Meeting point unavailable').toString();
//     final String creatorId = ride['creator_id']?.toString() ?? '';
//     final bool isMyRide = creatorId.isNotEmpty && creatorId == _userId;
//     final dynamic femaleRaw = ride['female_only'];
//     final bool isFemaleOnly = femaleRaw == true ||
//         femaleRaw == 1 ||
//         femaleRaw == '1' ||
//         femaleRaw.toString().toLowerCase() == 'true';
//     final String paymentMode =
//         (ride['payment_mode'] ?? 'Any (Cash/UPI)').toString();
//     final String seats = (ride['seats_available'] ?? '0').toString();
//     final bool isMetro = destination.toLowerCase().contains('metro');
//     final bool isActiveJoinedRide =
//         _activeRideId != null && id == _activeRideId;
//     final Color accent = isFemaleOnly ? pink : green;
//     final Color cardBackground = isActiveJoinedRide
//         ? (isFemaleOnly
//             ? const Color(0xFFFFF0F7)
//             : const Color(0xFFEFFAF2))
//         : surface;
//     final Color cardBorderColor = isActiveJoinedRide
//         ? (isFemaleOnly
//             ? const Color(0xFFF3A9C9)
//             : const Color(0xFF86C995))
//         : (isFemaleOnly ? const Color(0xFFF8D7E7) : line);
//     final String actionLabel = isActiveJoinedRide
//         ? 'View details'
//         : isMyRide
//             ? 'Your ride'
//             : 'View ride';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 13),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () => _openRide(id),
//           borderRadius: BorderRadius.circular(24),
//           child: Ink(
//             decoration: BoxDecoration(
//               color: cardBackground,
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(
//                 color: cardBorderColor,
//                 width: isActiveJoinedRide ? 1.6 : 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: ink.withOpacity(isActiveJoinedRide ? .02 : .04),
//                   blurRadius: 24,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
//               child: Column(
//                 children: [
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         width: 50,
//                         height: 50,
//                         decoration: BoxDecoration(
//                           color: accent.withOpacity(.10),
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Icon(
//                           isMetro
//                               ? Icons.subway_rounded
//                               : Icons.directions_car_filled_rounded,
//                           color: accent,
//                           size: 23,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               destination,
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                 color: ink,
//                                 fontSize: 15.5,
//                                 height: 1.18,
//                                 fontWeight: FontWeight.w900,
//                                 letterSpacing: -.2,
//                               ),
//                             ),
//                             const SizedBox(height: 7),
//                             Row(
//                               children: [
//                                 const Icon(
//                                   Icons.location_on_outlined,
//                                   size: 13,
//                                   color: muted,
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Expanded(
//                                   child: Text(
//                                     meetingPoint,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                     style: const TextStyle(
//                                       color: inkSoft,
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       if (isActiveJoinedRide)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 5,
//                           ),
//                           decoration: BoxDecoration(
//                             color: accent,
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: const Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.check_rounded,
//                                 color: Colors.white,
//                                 size: 11,
//                               ),
//                               SizedBox(width: 3),
//                               Text(
//                                 'Joined',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 8,
//                                   fontWeight: FontWeight.w900,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 13),
//                   Row(
//                     children: [
//                       _rideTypeChip(
//                         label: isFemaleOnly ? 'Women only' : 'Open',
//                         color: accent,
//                         icon: isFemaleOnly
//                             ? Icons.female_rounded
//                             : Icons.people_alt_outlined,
//                       ),
//                       const Spacer(),
//                       if (isMyRide)
//                         const Text(
//                           'Created by you',
//                           style: TextStyle(
//                             color: inkSoft,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         )
//                       else if (!isActiveJoinedRide)
//                         const Text(
//                           'Tap to view ride',
//                           style: TextStyle(
//                             color: inkSoft,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: surfaceSoft,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: line.withOpacity(.8)),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: _detailBox(
//                             icon: Icons.groups_rounded,
//                             title: 'Seats',
//                             value: '$seats left',
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _detailBox(
//                             icon: paymentMode.toLowerCase().contains('upi')
//                                 ? Icons.qr_code_rounded
//                                 : Icons.payments_outlined,
//                             title: 'Payment',
//                             value: _paymentLabel(paymentMode),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _detailBox(
//                             icon: isActiveJoinedRide
//                                 ? Icons.check_circle_outline_rounded
//                                 : Icons.bolt_rounded,
//                             title: 'Status',
//                             value: isActiveJoinedRide ? 'Joined' : 'Active',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Container(
//                         width: 7,
//                         height: 7,
//                         decoration: BoxDecoration(
//                           color: accent,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 7),
//                       Expanded(
//                         child: Text(
//                           isActiveJoinedRide
//                               ? 'You joined this ride'
//                               : isMyRide
//                                   ? 'Ready for others to join'
//                                   : 'Tap to see the full ride',
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: inkSoft,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 11,
//                           vertical: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           color: isActiveJoinedRide ? accent : ink,
//                           borderRadius: BorderRadius.circular(11),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               actionLabel,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                             const SizedBox(width: 5),
//                             const Icon(
//                               Icons.arrow_forward_rounded,
//                               color: Colors.white,
//                               size: 12,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _rideTypeChip({
//     required String label,
//     required Color color,
//     required IconData icon,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(.08),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 11, color: color),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: TextStyle(
//               color: color,
//               fontSize: 9.2,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _detailBox({
//     required IconData icon,
//     required String title,
//     required String value,
//   }) {
//     return Row(
//       children: [
//         Icon(icon, color: muted, size: 14),
//         const SizedBox(width: 6),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: muted,
//                   fontSize: 9.2,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 value,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: ink,
//                   fontSize: 10.2,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildBottomBar() {
//     return Container(
//       height: 72,
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(24),
//         border: Border.all(color: line),
//         boxShadow: [
//           BoxShadow(
//             color: ink.withOpacity(.12),
//             blurRadius: 32,
//             offset: const Offset(0, 12),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: _navItem(
//               icon: Icons.home_rounded,
//               label: 'Home',
//               active: true,
//               onTap: () {},
//             ),
//           ),
//           Expanded(
//             child: _navItem(
//               icon: Icons.history_rounded,
//               label: 'Rides',
//               onTap: _openRides,
//             ),
//           ),
//           SizedBox(
//             width: 72,
//             child: Center(
//               child: GestureDetector(
//                 onTap: () => _createRide(),
//                 child: Container(
//                   width: 54,
//                   height: 54,
//                   decoration: BoxDecoration(
//                     color: ink,
//                     shape: BoxShape.circle,
//                     boxShadow: [
//                       BoxShadow(
//                         color: ink.withOpacity(.22),
//                         blurRadius: 18,
//                         offset: const Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: const Icon(
//                     Icons.add_rounded,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: _navItem(
//               icon: Icons.map_outlined,
//               label: 'Map',
//               onTap: _openMap,
//             ),
//           ),
//           Expanded(
//             child: _navItem(
//               icon: Icons.person_outline_rounded,
//               label: 'Profile',
//               onTap: _openProfile,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _navItem({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     bool active = false,
//   }) {
//     final Color color = active ? greenDark : mutedLight;
//     return GestureDetector(
//       onTap: onTap,
//       behavior: HitTestBehavior.opaque,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 180),
//             width: 36,
//             height: 30,
//             decoration: BoxDecoration(
//               color: active ? green.withOpacity(.10) : Colors.transparent,
//               borderRadius: BorderRadius.circular(11),
//             ),
//             child: Icon(
//               icon,
//               color: color,
//               size: active ? 21 : 20,
//             ),
//           ),
//           const SizedBox(height: 3),
//           Text(
//             label,
//             style: TextStyle(
//               color: color,
//               fontSize: 10.5,
//               fontWeight: active ? FontWeight.w900 : FontWeight.w700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
