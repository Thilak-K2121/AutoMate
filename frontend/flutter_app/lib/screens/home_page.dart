import 'dart:convert';
import 'package:flutter/material.dart';
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
  String _searchQuery = ""; // NEW: Tracks the search bar input
  // 👇 NEW: Track the currently joined ride for the UI & Double-Booking check
  String? _activeRideId;
  String? _activeRideDest;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      // 1. Fetch user profile
      final userResponse = await ApiService.getRequest('/auth/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        setState(() {
          _userName = userData['user']['name'].split(' ')[0];
          _userId = userData['user']['id'].toString();
        });
      }

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
            : ListView(
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
                                fontWeight: FontWeight.w700,
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
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
                            if (result == true) _fetchDashboardData();
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
                            if (result == true) _fetchDashboardData();
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
                      fontWeight: FontWeight.w700,
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
                      // ✅ ADD DEBUG HERE
                      print("is_female_only value: ${ride['is_female_only']}");
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
                          ride['user_id']?.toString() ?? '';
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
                        buttonColor: isMetro
                            ? const Color(0xFF34A853)
                            : const Color(0xFF2F80ED),
                      );
                    }),

                  const SizedBox(height: 90),
                ],
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
    String buttonText = "Join";

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
        // 🚫 Double booking protection
        if (_activeRideId != null && _activeRideId != id && !isMyRide) {
          final bool? shouldSwap = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Switch Rides?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                "You are already in a ride to $_activeRideDest.\n\nJoining this ride will automatically leave your current one.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFemaleOnly
                        ? Colors.pink
                        : const Color(0xFF34A853),
                    foregroundColor: isFemaleOnly
                        ? Colors
                              .white // Female-only ride → white text
                        : Colors.black, // Normal ride → black text
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Join New Ride"),
                ),
              ],
            ),
          );

          if (shouldSwap != true) return;

          // 👇 DIRECTLY JOIN NEW RIDE (NO JUST NAVIGATION)
          await ApiService.postRequest('/rides/join', {"rideId": id});

          // 👇 REFRESH UI IMMEDIATELY
          await _fetchDashboardData();
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetroRideDetailsPage(rideId: id),
          ),
        );

        // 👇 ALWAYS refresh (not only when result == true)
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
              if (result == true) _fetchDashboardData();
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
