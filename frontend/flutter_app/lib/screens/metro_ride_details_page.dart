import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_app/screens/create_ride_page.dart';
import 'package:flutter_app/screens/home_page.dart';
import 'package:flutter_app/screens/map_page.dart';
import 'package:flutter_app/screens/my_rides_page.dart';
import 'package:flutter_app/screens/profile_page.dart';
import '../services/api_service.dart';
import 'chat_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MetroRideDetailsPage extends StatefulWidget {
  final String rideId;

  const MetroRideDetailsPage({super.key, required this.rideId});

  @override
  State<MetroRideDetailsPage> createState() => _MetroRideDetailsPageState();
}

class _MetroRideDetailsPageState extends State<MetroRideDetailsPage> {
  Map<String, dynamic>? _rideData;
  List<dynamic> _participants = [];
  String _driverPhone = "";
  String _currentUserId = ""; // NEW: Track who is looking at the app
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // NEW: Combined fetch to get the user ID first, then the ride details
  Future<void> _fetchData() async {
    try {
      // 1. Get current user ID
      final userRes = await ApiService.getRequest('/auth/me');
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        _currentUserId = userData['user']['id'];
      }

      // 2. Get Ride Details
      final response = await ApiService.getRequest('/rides/${widget.rideId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _rideData = data['ride'];
            _driverPhone = data['ride']['creator_phone'] ?? "";
            _participants = data['participants'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load ride details')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network error')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $launchUri');
    }
  }

  // NEW: The End Ride Logic
  // REPLACE this entire function in metro_ride_details_page.dart
  Future<void> _handleEndRide() async {
    // 1. Show a confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("End Ride"),
        content: const Text("Are you sure you want to end this ride?"),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false), // Fixed to onPressed
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Fixed to onPressed
            child: const Text("End Ride", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.postRequest('/rides/end', {
        'rideId': widget.rideId,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ride ended successfully! 🏁")),
          );
          Navigator.pop(context, true); // Pop back to home page
        }
      } else {
        final errorData = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? "Failed to end ride"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error ending ride. Is backend running?"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //handling the join ride
  // --- ADD THESE TWO FUNCTIONS ---
  Future<void> _handleJoinRide() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.postRequest('/rides/join', {
        'rideId': widget.rideId,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Successfully joined the ride! 🎉")),
          );
          _fetchData(); // Refresh the page to show the user in the participants list!
        }
      } else {
        final errorData = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? "Failed to join")),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error joining ride.")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLeaveRide() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Ride"),
        content: const Text(
          "Are you sure you want to leave? Your seat will be given to someone else.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.postRequest('/rides/leave', {
        'rideId': widget.rideId,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You have left the ride.")),
          );
          _fetchData(); // Refresh to update seats and remove user
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Check if the current user is the host
    final bool isHost = _currentUserId == _rideData?['creator_id'];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      bottomNavigationBar: _bottomNavBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34A853)),
              )
            : Column(
                children: [
                  const SizedBox(height: 8),

                  /// Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios, size: 20),
                        ),
                        const Spacer(),
                        Text(
                          _rideData?['destination'] ?? "Ride Details",
                          style: const TextStyle(
                            fontSize: 22,
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

                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Meeting point + status
                          /// Meeting point + status
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: _cardDecoration(),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF34A853),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Meeting Point",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _rideData?['meeting_point'] ?? "Loading...",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const Divider(height: 26),

                                /// STATUS ROW
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Status:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9F7EF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        (_rideData?['status'] ?? "Unknown")
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF34A853),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                /// 🔥 NEW: FEMALE ONLY BADGE
                                if (_rideData?['female_only'] == true ||
                                    _rideData?['female_only'] == 'true' ||
                                    _rideData?['female_only'] == 1) ...[
                                  const Divider(height: 26),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.security,
                                        color: Colors.pink,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "Security:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.pink.shade50,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: Colors.pink.shade200,
                                          ),
                                        ),
                                        child: const Text(
                                          "FEMALE ONLY",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.pink,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          /// Members
                          const Text(
                            "Group Members",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),

                          const SizedBox(height: 12),

                          ..._participants.map((p) {
                            final bool isThisUserHost =
                                p['id'] == _rideData?['creator_id'];

                            return _memberTile(
                              name: p['name'],
                              role: isThisUserHost ? "Host" : "Member",
                              seat: "1 seat",
                              host: isThisUserHost,
                            );
                          }),

                          const SizedBox(height: 30),

                          /// Buttons Area
                          /// Buttons Area
                          Builder(
                            builder: (context) {
                              // Determine the user's exact relationship to this ride
                              final bool isHost =
                                  _currentUserId == _rideData?['creator_id'];
                              final bool isParticipant = _participants.any(
                                (p) => p['id'] == _currentUserId,
                              );
                              final bool isFull =
                                  (_rideData?['seats_available'] ?? 0) <= 0;

                              // 1. NON-PARTICIPANT VIEW: Only show the "Join" button (Full width)
                              if (!isHost && !isParticipant) {
                                return GestureDetector(
                                  onTap: isFull ? null : _handleJoinRide,
                                  child: _actionButton(
                                    isFull ? "Ride Full" : "Join Ride",
                                    isFull
                                        ? Colors.grey
                                        : const Color(0xFF34A853),
                                  ),
                                );
                              }

                              // 2. HOST & PARTICIPANT VIEW: Show the unlocked control panel
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      // LEFT BUTTON: Chat (Always visible for members)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatPage(
                                                rideId: widget.rideId,
                                              ),
                                            ),
                                          ),
                                          child: _actionButton(
                                            "Chat",
                                            const Color(0xFF34A853),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // RIGHT BUTTON: End Ride (Host) OR Call Host (Participant)
                                      Expanded(
                                        child: isHost
                                            ? GestureDetector(
                                                onTap: _handleEndRide,
                                                child: _actionButton(
                                                  "End Ride",
                                                  Colors.red.shade500,
                                                ),
                                              )
                                            : GestureDetector(
                                                // Must be a participant here
                                                onTap: () =>
                                                    _driverPhone.isNotEmpty
                                                    ? _makePhoneCall(
                                                        _driverPhone,
                                                      )
                                                    : null,
                                                child: _actionButton(
                                                  "Call Host",
                                                  _driverPhone.isNotEmpty
                                                      ? const Color(0xFF2F80ED)
                                                      : Colors.grey,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),

                                  // 3. BOTTOM BUTTON (Leave Ride - only for participants who aren't the host)
                                  if (isParticipant && !isHost) ...[
                                    const SizedBox(height: 14),
                                    GestureDetector(
                                      onTap: _handleLeaveRide,
                                      child: Container(
                                        width: double.infinity,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.red.shade400,
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Leave Ride",
                                            style: TextStyle(
                                              color: Colors.red.shade500,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.04),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Helper for drawing the colorful buttons
  Widget _actionButton(String text, Color color) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _memberTile({
    required String name,
    required String role,
    required String seat,
    required bool host,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFDCE7EE),
            child: Icon(Icons.person, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (host)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        "HOST",
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF34A853),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(role, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
          const Spacer(),
          Text(seat),
        ],
      ),
    );
  }

 Widget _bottomNavBar() {
  return Container(
    height: 80,
    padding: const EdgeInsets.symmetric(horizontal: 20),
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
        // HOME
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
          child: _NavItem(icon: Icons.home, label: "Home", active: false),
        ),

        // RIDES
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyRidesPage()),
            );
          },
          child: _NavItem(icon: Icons.history, label: "Rides"),
        ),

        // ADD RIDE
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateRidePage(),
              ),
            );
            if (result == true) _fetchData();
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

        // MAP
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapPage()),
            );
          },
          child: _NavItem(icon: Icons.map, label: "Map"),
        ),

        // PROFILE
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: _NavItem(icon: Icons.person_outline, label: "Profile"),
        ),
      ],
    ),
  );
}
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF34A853) : const Color(0xFF6B7280);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
