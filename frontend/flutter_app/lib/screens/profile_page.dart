import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'ride_history_page.dart';
import 'sign_in_page.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  bool _isLoading = true;
  int _ridesTaken = 0;
  int _ridesHosted = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _fetchProfileStats(); // NEW
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await ApiService.getRequest('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _userName = data['user']['name'];
            _userEmail = data['user']['email'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfileStats() async {
    try {
      final response = await ApiService.getRequest('/rides/stats');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _ridesHosted = data['ridesHosted'] ?? 0;
            _ridesTaken = data['ridesTaken'] ?? 0;
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _handleLogout() async {
    // Show a confirmation dialog before logging out
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear the JWT token from the device
      await ApiService.clearToken();

      // Navigate back to the Sign In page and clear the navigation stack
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) => false,
        );
      }
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
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    /// Header
                    Row(
                      children: const [
                        Text(
                          "Profile",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Spacer(),
                        // Icon(
                        //   Icons.settings_outlined,
                        //   size: 22,
                        //   color: Color(0xFF6B7280),
                        // ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// Avatar
                    const CircleAvatar(
                      radius: 46,
                      backgroundColor: Color(0xFFDCE7EE),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFF6B7280),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// Name
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    /// Email
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    /// Stats Row
                    _isLoadingStats
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF34A853),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: _ridesTaken.toString(),
                                  subtitle: "Rides Taken",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: _ridesHosted.toString(),
                                  subtitle: "Rides Hosted",
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 26),

                    /// Menu Options
                    _menuTile(
                      icon: Icons.history,
                      title: "Ride History",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RideHistoryPage(),
                          ),
                        );
                      },
                    ),
                    _menuTile(icon: Icons.star_border, title: "Saved Rides"),
                    _menuTile(
                      icon: Icons.help_outline,
                      title: "Help & Support",
                    ),
                    _menuTile(
                      icon: Icons.logout,
                      title: "Logout",
                      red: true,
                      onTap: _handleLogout,
                    ),

                    const SizedBox(height: 100), // space for bottom nav
                  ],
                ),
              ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    bool red = false,
    VoidCallback? onTap, // Added onTap functionality
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: red ? Colors.red : const Color(0xFF34A853)),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: red ? Colors.red : const Color(0xFF1F2937),
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
      ),
    );
  }

  Widget _bottomNavBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 30),
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
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            },
            child: const _NavItem(icon: Icons.home, label: "Home"),
          ),
          const _NavItem(icon: Icons.directions_car, label: "Rides"),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF2F80ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const _NavItem(icon: Icons.map, label: "Map"),
          const _NavItem(icon: Icons.person, label: "Profile", active: true),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StatCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
