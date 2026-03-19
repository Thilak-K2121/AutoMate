import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'metro_ride_details_page.dart';

class MyRidesPage extends StatefulWidget {
  const MyRidesPage({Key? key}) : super(key: key);

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage> {
  List<dynamic> _hostedRides = [];
  List<dynamic> _joinedRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyRides();
  }

  Future<void> _fetchMyRides() async {
    try {
      final response = await ApiService.getRequest('/rides/my-rides');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _hostedRides = data['hosted'] ?? [];
            _joinedRides = data['joined'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching my rides: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 2 Tabs: Joined and Hosted
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2937), size: 20),
          ),
          title: const Text(
            "My Rides",
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Color(0xFF34A853),
            unselectedLabelColor: Color(0xFF6B7280),
            indicatorColor: Color(0xFF34A853),
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Joined Rides"),
              Tab(text: "Hosted by Me"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF34A853)))
            : TabBarView(
                children: [
                  _buildRideList(_joinedRides, "You haven't joined any rides yet."),
                  _buildRideList(_hostedRides, "You haven't hosted any rides yet."),
                ],
              ),
      ),
    );
  }

  Widget _buildRideList(List<dynamic> rides, String emptyMessage) {
    if (rides.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final ride = rides[index];
        final bool isCompleted = ride['status'] == 'completed';
        final String rideId = ride['id'].toString();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MetroRideDetailsPage(rideId: rideId)),
            ).then((_) => _fetchMyRides()); // Refresh when coming back!
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: isCompleted ? Border.all(color: Colors.grey.shade300) : null,
              boxShadow: [
                if (!isCompleted)
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ride['destination'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.grey.shade100 : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? "Completed" : (ride['status'] ?? 'Active').toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? Colors.grey : const Color(0xFF34A853),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text(
                      ride['meeting_point'] ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}