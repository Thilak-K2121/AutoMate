import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MetroRideDetailsPage extends StatefulWidget {
  final String rideId;

  const MetroRideDetailsPage({Key? key, required this.rideId})
    : super(key: key);

  @override
  State<MetroRideDetailsPage> createState() => _MetroRideDetailsPageState();
}

class _MetroRideDetailsPageState extends State<MetroRideDetailsPage> {
  Map<String, dynamic>? _rideData;
  List<dynamic> _participants = [];
  String _driverPhone = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideDetails();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $launchUri');
    }
  }

  Future<void> _fetchRideDetails() async {
    try {
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

  @override
  Widget build(BuildContext context) {
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
                            final isHost = p['id'] == _rideData?['creator_id'];

                            return _memberTile(
                              name: p['name'],
                              role: isHost ? "Host" : "Member",
                              seat: "1 seat",
                              host: isHost,
                              avatar: "assets/images/avatar1.png",
                            );
                          }).toList(),

                          const SizedBox(height: 30),

                          /// Buttons
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChatPage(rideId: widget.rideId),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34A853),
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Chat",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (_driverPhone.isNotEmpty) {
                                      await _makePhoneCall(_driverPhone);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "No phone number provided 📵",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _driverPhone.isNotEmpty
                                          ? const Color(0xFF34A853)
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Call",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _memberTile({
    required String name,
    required String role,
    required String seat,
    required bool host,
    required String avatar,
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _NavItem(icon: Icons.home, label: "Home", active: true),
          _NavItem(icon: Icons.directions_car, label: "Rides"),
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFF2F80ED),
            child: Icon(Icons.add, color: Colors.white),
          ),
          _NavItem(icon: Icons.map, label: "Map"),
          _NavItem(icon: Icons.person_outline, label: "Profile"),
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
