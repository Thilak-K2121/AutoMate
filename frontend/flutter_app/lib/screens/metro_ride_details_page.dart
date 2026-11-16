import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_bottom_nav.dart';
import 'package:flutter_app/screens/home_page.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  bool _isHost = false;
  bool _isLoading = true;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _fetchData();
  }

  @override
  void dispose() {
    _socket.emit('leaveRideRoom', widget.rideId.toString());
    _socket.dispose();
    super.dispose();
  }

  void _connectSocket() {
    _socket = IO.io(
      ApiService.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      _socket.emit('joinRideRoom', widget.rideId.toString());
    });

    // 🚨 Real-Time Catch: Host Ended / Cancelled Ride
    _socket.on('rideEnded', (data) {
      final isCancelled = data != null && data['status'] == 'cancelled';
      final dialogTitle = isCancelled ? "Ride Cancelled" : "Ride Ended";
      final dialogMsg = isCancelled
          ? "The host has cancelled this ride."
          : "The host has completed this ride.";

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                  color: isCancelled ? AppColors.danger : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(dialogTitle),
              ],
            ),
            content: Text(dialogMsg),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                },
                child: const Text("Return to Dashboard"),
              ),
            ],
          ),
        );
      }
    });

    // 🚨 Real-Time Catch: Removed or Blocked by Host
    _socket.on('passengerRemoved', (data) {
      if (data != null && data['passengerId']?.toString() == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were removed from this ride by the host.")),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      } else {
        _fetchData();
      }
    });

    _socket.on('passengerBlocked', (data) {
      if (data != null && data['passengerId']?.toString() == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were blocked from this ride by the host.")),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      } else {
        _fetchData();
      }
    });

    // Live update when passengers join or leave
    _socket.on('rideUpdated', (_) {
      if (mounted) _fetchData();
    });
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
            _isHost = (_currentUserId == data['ride']['creator_id'].toString());
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

  // 🛑 Host Cancels Ride (Sets status = 'cancelled')
  Future<void> _handleCancelRide() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger),
            SizedBox(width: 8),
            Text("Cancel Ride?"),
          ],
        ),
        content: const Text(
          "Are you sure you want to cancel this ride? All joined passengers will be notified.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep Ride", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.postRequest('/rides/cancel', {
        'rideId': widget.rideId,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ride cancelled successfully")),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final errorData = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? "Failed to cancel ride")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error cancelling ride")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🏁 Host Completes/Ends Ride (Sets status = 'completed' so it counts towards profile stats)
  Future<void> _handleEndRide() async {
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.postRequest('/rides/end', {
        'rideId': widget.rideId,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ride completed successfully! 🏁")),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final errorData = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? "Failed to complete ride"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error completing ride."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showWarningDialog(
    String title,
    String message,
    Color btnColor,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continue & Join"),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  //handling the join ride
  Future<void> _handleJoinRide() async {
    // 1. Check current ride status
    final myRidesRes = await ApiService.getRequest('/rides/my-rides');

    if (myRidesRes.statusCode == 200) {
      final data = jsonDecode(myRidesRes.body);

      final hosted = data['hosted'] as List<dynamic>? ?? [];
      final joined = data['joined'] as List<dynamic>? ?? [];

      // 👇 Check if hosting a ride
      final bool isHosting = hosted.any(
        (r) => r['status'] == 'active' || r['status'] == 'full',
      );

      // 👇 Check if passenger in another ride
      final bool isPassenger = joined.any(
        (r) =>
            (r['status'] == 'active' || r['status'] == 'full') &&
            r['id'].toString() != widget.rideId,
      );

      // 2. CONFIRMATION DIALOG: CANCEL EXISTING AND JOIN THIS RIDE
      if (isHosting) {
        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text("Cancel Hosted Ride?"),
                ],
              ),
              content: const Text(
                "You are currently hosting an active ride. Do you want to cancel your hosted ride and join this one as a passenger?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Keep Hosted Ride", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Cancel & Join Ride"),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      } else if (isPassenger) {
        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text("Switch Ride?"),
                ],
              ),
              content: const Text(
                "You are currently in an active ride. Do you want to leave your current ride and join this one?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Keep Current Ride", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Leave & Join Ride"),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }
    }

    // 3. JOIN API CALL (same as before)
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.postRequest('/rides/join', {
        "rideId": widget.rideId,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Successfully joined the ride!"),
              backgroundColor: AppColors.primary,
            ),
          );

          Navigator.pop(context, true); // go back to home
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error['message'] ?? "Failed to join"),
              backgroundColor: AppColors.danger,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Join error: $e");
      if (mounted) setState(() => _isLoading = false);
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
            child: const Text("Leave", style: TextStyle(color: AppColors.danger)),
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

  // ✅ REMOVE PASSENGER
  Future<void> _removePassenger(
    String passengerId,
    String passengerName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Passenger"),
        content: Text(
          "Are you sure you want to remove $passengerName from this ride? They will be able to rejoin if seats are available.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.postRequest(
        '/rides/${widget.rideId}/remove',
        {"passengerId": passengerId},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$passengerName removed.")));
        _fetchData(); // ✅ use your existing function
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['message'] ?? 'Failed to remove')),
        );
      }
    } catch (e) {
      debugPrint("Remove error: $e");
    }
  }

  // ✅ BLOCK PASSENGER
  Future<void> _blockPassenger(String passengerId, String passengerName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Block Passenger",
          style: TextStyle(color: AppColors.danger),
        ),
        content: Text(
          "Are you sure you want to completely block $passengerName? They will be kicked out and permanently hidden from this ride.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Block Permanently",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.postRequest(
        '/rides/${widget.rideId}/block',
        {"passengerId": passengerId},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$passengerName has been blocked.")),
        );
        _fetchData(); // ✅ use your existing function
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['message'] ?? 'Failed to block')),
        );
      }
    } catch (e) {
      debugPrint("Block error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = (_rideData?['status'] ?? 'unknown').toString();
    final bool isLive = status == 'active' || status == 'full';
    final bool isFemaleOnlyRide = _rideData?['female_only'] == true ||
        _rideData?['female_only'] == 'true' ||
        _rideData?['female_only'] == 1;
    final int seatsLeft =
        int.tryParse('${_rideData?['seats_available'] ?? 0}') ?? 0;
    final String payment =
        (_rideData?['payment_mode'] ?? 'Any').toString().replaceAll(' (Cash/UPI)', '');

    final Color statusColor = switch (status) {
      'active' => AppColors.primary,
      'full' => AppColors.warning,
      'completed' => AppColors.accent,
      'cancelled' => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Ride details"),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.none,
        onRideCreated: () async => _fetchData(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  /// ROUTE HERO
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: isFemaleOnlyRide
                          ? const LinearGradient(
                              colors: [Color(0xFFDB2777), Color(0xFF9D4EDD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -22,
                          child: Icon(
                            Icons.electric_rickshaw_rounded,
                            size: 120,
                            color: Colors.white.withOpacity(0.09),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _heroPill(
                                    icon: Icons.circle,
                                    iconSize: 8,
                                    label: status.toUpperCase(),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isFemaleOnlyRide)
                                    _heroPill(
                                      icon: Icons.female_rounded,
                                      label: "WOMEN ONLY",
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // From → To timeline
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 2,
                                        height: 34,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "PICKUP",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            letterSpacing: 0.8,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withOpacity(0.75),
                                          ),
                                        ),
                                        Text(
                                          _rideData?['meeting_point'] ?? "—",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "DESTINATION",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            letterSpacing: 0.8,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withOpacity(0.75),
                                          ),
                                        ),
                                        Text(
                                          _rideData?['destination'] ?? "—",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 21,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Quick facts
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                                child: Row(
                                  children: [
                                    _heroFact(
                                      Icons.event_seat_rounded,
                                      isLive
                                          ? "$seatsLeft seat${seatsLeft == 1 ? '' : 's'} left"
                                          : "${_participants.length} rode",
                                    ),
                                    Container(
                                      width: 1,
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    _heroFact(
                                      payment.contains('UPI')
                                          ? Icons.qr_code_2_rounded
                                          : Icons.payments_rounded,
                                      payment,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  /// MEMBERS
                  Row(
                    children: [
                      const Text(
                        "Group members",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          "${_participants.length}",
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _participants.length; i++) ...[
                          if (i > 0)
                            const Divider(indent: 72, endIndent: 16),
                          _memberRow(_participants[i], isLive),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  /// ACTIONS
                  Builder(
                    builder: (context) {
                      // Determine the user's exact relationship to this ride
                      final bool isHost =
                          _currentUserId == _rideData?['creator_id'];

                      final bool isParticipant = _participants.any(
                        (p) => p['id'].toString() == _currentUserId.toString(),
                      );

                      final bool isFull =
                          (_rideData?['seats_available'] ?? 0) <= 0;

                      final bool isCompleted =
                          _rideData?['status'] == 'completed' ||
                              _rideData?['status'] == 'cancelled';

                      void openChat() => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatPage(rideId: widget.rideId),
                            ),
                          );

                      // 1. NON-PARTICIPANT VIEW: Join button
                      if (!isCompleted && !isHost && !isParticipant) {
                        return isFull
                            ? _actionButton("Ride is full", AppColors.textMuted)
                            : PrimaryButton(
                                label: "Join this ride",
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _handleJoinRide,
                              );
                      }

                      // 2. HOST & PARTICIPANT VIEW
                      if (!isCompleted && (isHost || isParticipant)) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: openChat,
                                    child: _actionButton(
                                      "Group chat",
                                      AppColors.primary,
                                      icon: Icons.chat_bubble_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: isHost
                                      ? GestureDetector(
                                          onTap: _handleCancelRide,
                                          child: _actionButton(
                                            "Cancel ride",
                                            AppColors.danger,
                                            icon: Icons.close_rounded,
                                            outlined: true,
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => _driverPhone.isNotEmpty
                                              ? _makePhoneCall(_driverPhone)
                                              : null,
                                          child: _actionButton(
                                            "Call host",
                                            _driverPhone.isNotEmpty
                                                ? AppColors.accent
                                                : AppColors.textMuted,
                                            icon: Icons.call_rounded,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (isHost)
                              // Swipe left-to-right to complete/end the ride
                              _SwipeToCompleteSlider(
                                onComplete: _handleEndRide,
                                isLoading: _isLoading,
                              )
                            else
                              GestureDetector(
                                onTap: _handleLeaveRide,
                                child: _actionButton(
                                  "Leave ride",
                                  AppColors.danger,
                                  icon: Icons.logout_rounded,
                                  outlined: true,
                                ),
                              ),
                          ],
                        );
                      }

                      // 3. FINISHED RIDE
                      final bool cancelled = status == 'cancelled';
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cancelled
                              ? AppColors.dangerSoft
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              cancelled
                                  ? Icons.cancel_rounded
                                  : Icons.flag_circle_rounded,
                              color: statusColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cancelled
                                    ? "This ride was cancelled."
                                    : "This ride is completed. Thanks for sharing!",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    double iconSize = 14,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFact(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(dynamic p, bool isLive) {
    final String passengerId = p['id'].toString();
    final String passengerName = p['name'] ?? 'Unknown';
    final bool isThisPassengerTheHost =
        passengerId == _rideData?['creator_id'].toString();
    final bool isMe = passengerId == _currentUserId.toString();

    final parts = passengerName.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : (parts.length == 1
                ? parts.first[0]
                : parts.first[0] + parts.last[0])
            .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isThisPassengerTheHost
                  ? AppColors.accentSoft
                  : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isThisPassengerTheHost
                    ? AppColors.accent
                    : AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        passengerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Text(
                        "(you)",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isThisPassengerTheHost ? "Host" : "Passenger",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isThisPassengerTheHost
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // HOST CONTROLS — only while the ride is still live
          if (_isHost && !isThisPassengerTheHost && isLive)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              onSelected: (value) {
                if (value == 'remove') {
                  _removePassenger(passengerId, passengerName);
                } else if (value == 'block') {
                  _blockPassenger(passengerId, passengerName);
                }
              },
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_rounded,
                          color: AppColors.warning, size: 20),
                      SizedBox(width: 10),
                      Text('Remove'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded,
                          color: AppColors.danger, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Block',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  // Consistent action button (filled or outlined)
  Widget _actionButton(
    String text,
    Color color, {
    IconData? icon,
    bool outlined = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: outlined ? AppColors.surface : color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: outlined ? Border.all(color: color.withOpacity(0.5), width: 1.5) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: outlined ? color : Colors.white),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: outlined ? color : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

}

class _SwipeToCompleteSlider extends StatefulWidget {
  final Future<void> Function() onComplete;
  final bool isLoading;

  const _SwipeToCompleteSlider({
    required this.onComplete,
    required this.isLoading,
  });

  @override
  State<_SwipeToCompleteSlider> createState() => _SwipeToCompleteSliderState();
}

class _SwipeToCompleteSliderState extends State<_SwipeToCompleteSlider> {
  double _dragPosition = 0.0;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 52;

        return Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Center Text Prompt
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isLoading ? "Completing Ride..." : "Slide to End Ride",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (!widget.isLoading) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_double_arrow_right, color: Colors.white70, size: 20),
                    ],
                  ],
                ),
              ),

              // Draggable Circular Thumb Knob
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_completed || widget.isLoading) return;
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx)
                          .clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_completed || widget.isLoading) return;
                    if (_dragPosition >= maxDrag * 0.75) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _completed = true;
                      });
                      await widget.onComplete();
                      if (mounted) {
                        setState(() {
                          _dragPosition = 0.0;
                          _completed = false;
                        });
                      }
                    } else {
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
