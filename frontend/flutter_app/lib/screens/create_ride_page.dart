import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateRidePage extends StatefulWidget {
  final String? initialDestination;
  final String? initialMeetingPoint;

  const CreateRidePage({
    super.key,
    this.initialDestination,
    this.initialMeetingPoint,
  });

  @override
  State<CreateRidePage> createState() => _CreateRidePageState();
}

class _CreateRidePageState extends State<CreateRidePage> {
  late TextEditingController _destinationController;
  late TextEditingController _meetingPointController;

  int _seats = 3;
  bool _isLoading = false;
  bool _isFemaleOnly = false;

  // 👇 NEW: Payment selection
  String _selectedPayment = 'Any (Cash/UPI)';
  final List<String> _paymentOptions = [
    'Any (Cash/UPI)',
    'UPI Only',
    'Cash Only',
  ];

  // NEW
  bool _isCurrentUserFemale = false;

  @override
  void initState() {
    super.initState();

    _destinationController = TextEditingController(
      text: widget.initialDestination ?? "",
    );
    _meetingPointController = TextEditingController(
      text: widget.initialMeetingPoint ?? "",
    );

    _fetchUserData();
  }

  // NEW
  Future<void> _fetchUserData() async {
    try {
      final response = await ApiService.getRequest('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final gender =
            data['user']['gender']?.toString().toLowerCase().trim() ?? '';

        if (mounted) {
          setState(() {
            _isCurrentUserFemale = (gender == 'female');
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching gender: $e");
    }
  }

  Future<void> _handleCreateRide() async {
    final destination = _destinationController.text.trim();
    final meetingPoint = _meetingPointController.text.trim();

    if (destination.isEmpty || meetingPoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in destination and meeting point"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.postRequest('/rides/create', {
        'destination': destination,
        'meeting_point': meetingPoint,
        'seats_total': _seats,
        'female_only': _isFemaleOnly,
        'paymentMode': _selectedPayment, // 👇 NEW
      });

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ride created successfully!")),
          );
          Navigator.pop(context, true);
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? "Failed to create ride"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error. Could not connect to backend."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _meetingPointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/bg_waves.png",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios, size: 20),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.05),
                                blurRadius: 6,
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
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "Create Ride",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    "assets/images/auto_icon.png",
                    width: 140,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Destination",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _inputTile(
                          icon: Icons.flag,
                          hintText: "E.g. Metro Station",
                          controller: _destinationController,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Meeting Point",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _inputTile(
                          icon: Icons.location_on,
                          hintText: "E.g. Main Gate",
                          controller: _meetingPointController,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Total Seats Needed",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
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
                              const Icon(
                                Icons.person_add_alt_1,
                                color: Color(0xFF34A853),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "$_seats Seat${_seats > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (_seats > 1) {
                                          setState(() => _seats--);
                                        }
                                      },
                                      icon: const Icon(Icons.remove, size: 18),
                                    ),
                                    Text("$_seats"),
                                    IconButton(
                                      onPressed: () {
                                        if (_seats < 4) {
                                          setState(() => _seats++);
                                        }
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Accepted Payment",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
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
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedPayment,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF6B7280),
                              ),
                              items: _paymentOptions.map((String mode) {
                                return DropdownMenuItem<String>(
                                  value: mode,
                                  child: Row(
                                    children: [
                                      Icon(
                                        mode.contains('UPI')
                                            ? Icons.qr_code_scanner
                                            : Icons.money,
                                        color: const Color(0xFF34A853),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        mode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedPayment = newValue!;
                                });
                              },
                            ),
                          ),
                        ),
                        // UPDATED female-only toggle
                        if (_isCurrentUserFemale) ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.pink.shade200),
                            ),
                            child: SwitchListTile(
                              activeThumbColor: Colors.pink,
                              title: const Text(
                                "Female-Only Ride",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.pink,
                                ),
                              ),
                              subtitle: const Text(
                                "Restrict this ride to female passengers only.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.pinkAccent,
                                ),
                              ),
                              value: _isFemaleOnly,
                              onChanged: (bool value) {
                                setState(() {
                                  _isFemaleOnly = value;
                                });
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 30),

                        GestureDetector(
                          onTap: _isLoading ? null : _handleCreateRide,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34C759), Color(0xFF28A745)],
                              ),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Create Ride",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputTile({
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          Icon(icon, color: const Color(0xFF34A853)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  color: Colors.black38,
                ),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
