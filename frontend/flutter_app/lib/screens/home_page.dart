import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_ride_page.dart';
import 'notifications_page.dart';
import 'metro_ride_details_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "Student";
  String _userId = "";
  List<dynamic> _availableRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // Fetch user profile for the greeting
      final userResponse = await ApiService.getRequest('/auth/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        setState(() {
          // Extract first name for a friendly greeting
          _userName = userData['user']['name'].split(' ')[0];
          _userId = userData['user']['id'].toString(); // NEW: Save the ID
        });
      }

      // Fetch active nearby rides
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      bottomNavigationBar: _bottomNavBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34A853)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      /// Header
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
                                  children: const [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "College Campus",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // REPLACE the notification Stack with this:
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsPage(),
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
                                // The Red Notification Dot
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
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      /// Logo
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

                      /// Quick Actions
                      /// Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // For now, this shows a pop-up. Later we can make it auto-fill the Create Ride page!
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Filtering Metro rides... 🚇",
                                    ),
                                  ),
                                );
                              },
                              child: _quickCard(
                                icon: Icons.directions_car,
                                title: "Go to Metro",
                                subtitle: "1.5 km away",
                                color: const Color(0xFF34A853),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Filtering College rides... 🏫",
                                    ),
                                  ),
                                );
                              },
                              child: _quickCard(
                                icon: Icons.apartment,
                                title: "Go to College",
                                subtitle: "",
                                color: const Color(0xFF2F80ED),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      /// Available Rides Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "Available Rides",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            "See All",
                            style: TextStyle(
                              color: Color(0xFF34A853),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      /// Dynamic Ride Cards
                      /// Dynamic Ride Cards
                      if (_availableRides.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              "No rides available right now.\nBe the first to create one!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._availableRides.map((ride) {
                          final bool isMetro = ride['destination']
                              .toString()
                              .toLowerCase()
                              .contains('metro');

                          // NEW: Safely check if the ride belongs to the logged-in user
                          // Your backend likely saves the creator as 'user_id'
                          final String creatorId =
                              ride['user_id']?.toString() ?? '';
                          final bool isMyRide = creatorId == _userId;

                          return _rideCard(
                            id: ride['id']
                                .toString(), // Ensure this is a String
                            title: ride['destination'],
                            people: "${ride['seats_available']} seats left",
                            gate: ride['meeting_point'],
                            price: "₹ 15 / seat",
                            time: "Active",
                            buttonColor: isMetro
                                ? const Color(0xFF34A853)
                                : const Color(0xFF2F80ED),
                            isMyRide:
                                isMyRide, // NEW: Pass the flag to the card
                          );
                        }).toList(),

                      const SizedBox(height: 90),
                    ],
                  ),
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
    required bool isMyRide, // NEW: Added parameter
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetroRideDetailsPage(rideId: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
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
                const CircleAvatar(radius: 4, backgroundColor: Colors.green),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.group, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  people,
                  style: const TextStyle(fontSize: 12),
                ), // Slightly smaller text
                const SizedBox(width: 8), // Reduced gap

                const Icon(Icons.event, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                // NEW: Expanded prevents overflow and truncates long location names!
                Expanded(
                  child: Text(
                    gate,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis, // Adds "..." if it's too long
                  ),
                ),
                const SizedBox(width: 8),

                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8), // Added gap before button
                // Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ), // Slightly tighter padding
                  decoration: BoxDecoration(
                    color: isMyRide ? Colors.grey.shade400 : buttonColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isMyRide ? "Your Ride" : "Join",
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
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("My Rides history coming soon! 🚗"),
                ),
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
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Live Map integration coming soon! 🗺️"),
                ),
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
