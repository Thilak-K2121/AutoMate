import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'create_ride_page.dart';
import 'metro_ride_details_page.dart';
import 'profile_page.dart';
import 'sign_in_page.dart';

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
    FcmService.syncDeviceToken();
    FcmService.checkAndHandlePendingNotification();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // ⚡ Single-flight consolidated BFF request (1 network trip replaces 4 separate calls)
      final response = await ApiService.getRequest('/rides/dashboard');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];
        if (user != null) {
          final userId = user['id'].toString();
          if (mounted) {
            setState(() {
              _userName = (user['name']?.toString() ?? 'Rider').split(' ')[0];
              _userId = userId;
            });
          }
          if (_socket.connected) {
            _socket.emit('joinUserRoom', userId);
          }
        }

        final myRidesData = data['myRides'] ?? {};
        final hostedRides = myRidesData['hosted'] as List<dynamic>? ?? [];
        final joinedRides = myRidesData['joined'] as List<dynamic>? ?? [];

        final activeHosted = hostedRides.cast<dynamic?>().firstWhere(
              (r) =>
                  r != null &&
                  (r['status'] == 'active' || r['status'] == 'full'),
              orElse: () => null,
            );

        final activeJoined = joinedRides.cast<dynamic?>().firstWhere(
              (r) =>
                  r != null &&
                  (r['status'] == 'active' || r['status'] == 'full'),
              orElse: () => null,
            );

        final active = activeHosted ?? activeJoined;
        String? nextActiveRideId;
        String? nextActiveRideDest;
        if (active != null) {
          nextActiveRideId = active['id'].toString();
          nextActiveRideDest = active['destination'].toString();
        }

        final nextAvailableRides = data['nearbyRides'] as List<dynamic>? ?? [];
        final bool hasUnread = data['hasUnreadNotifications'] == true;

        if (mounted) {
          setState(() {
            _activeRideId = nextActiveRideId;
            _activeRideDest = nextActiveRideDest;
            _availableRides = nextAvailableRides;
            _hasUnreadNotifications = hasUnread;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401 ||
          response.statusCode == 403) {
        await ApiService.clearToken();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SignInPage()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Session expired. Please sign in again."),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // 👇 Real-time ride and notification updates
  void _setupGlobalSocket() {
    _socket = ApiService.createSocket(); // 🔐 sends JWT in the handshake

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('HomePage connected to Socket.io for live updates');

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

    // Listen for any ride changes (created, ended, left, joined, updated)
    _socket.on('newRide', (_) {
      debugPrint('Socket: newRide event -> updating dashboard');
      if (mounted) _fetchDashboardData();
    });

    _socket.on('rideUpdated', (_) {
      debugPrint('Socket: rideUpdated event -> updating dashboard');
      if (mounted) _fetchDashboardData();
    });

    _socket.on('rideEnded', (_) {
      debugPrint('Socket: rideEnded event -> updating dashboard');
      if (mounted) _fetchDashboardData();
    });

    _socket.on('rideLeft', (_) {
      debugPrint('Socket: rideLeft event -> updating dashboard');
      if (mounted) _fetchDashboardData();
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
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: AppTab.home,
        onRideCreated: () async {
          setState(() => _searchQuery = "");
          await _fetchDashboardData();
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    /// HEADER — wordmark + avatar
                    Row(
                      children: [
                        Text.rich(
                          const TextSpan(
                            children: [
                              TextSpan(
                                text: "Auto",
                                style: TextStyle(color: AppColors.primary),
                              ),
                              TextSpan(
                                text: "Mate",
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfilePage(),
                              ),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: AppShadows.card,
                            ),
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    /// GREETING
                    Row(
                      children: [
                        Icon(
                          getGreetingIcon(),
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          getGreeting(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hi, $_userName 👋",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    /// HERO — where are you heading + quick actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: AppShadows.primaryGlow,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -18,
                            top: -26,
                            child: Icon(
                              Icons.electric_rickshaw_rounded,
                              size: 110,
                              color: Colors.white.withOpacity(0.09),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Where are you heading?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Share an auto with verified BMSCE students",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _quickCard(
                                      icon: Icons.directions_subway_rounded,
                                      title: "To Metro",
                                      subtitle: "Gate 1 → Metro",
                                      color: AppColors.primary,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CreateRidePage(
                                              initialDestination:
                                                  "National College Metro Station",
                                              initialMeetingPoint:
                                                  "BMSCE Gate 1",
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          setState(() => _searchQuery = "");
                                          await _fetchDashboardData();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _quickCard(
                                      icon: Icons.school_rounded,
                                      title: "To College",
                                      subtitle: "Metro → BMSCE",
                                      color: AppColors.accent,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CreateRidePage(
                                              initialDestination:
                                                  "BMSCE Campus",
                                              initialMeetingPoint:
                                                  "National College Metro Station",
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          setState(() => _searchQuery = "");
                                          await _fetchDashboardData();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    /// SEARCH
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: "Search destinations or gates",
                          fillColor: AppColors.surface,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    /// SECTION HEADER
                    Row(
                      children: [
                        const Text(
                          "Available rides",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "${displayRides.length} live",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    /// RIDES
                    if (displayRides.isEmpty)
                      _emptyState()
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
                        final bool isMyRide =
                            creatorId.isNotEmpty && creatorId == _userId;
                        final bool isActiveJoinedRide =
                            (ride['id'].toString() == _activeRideId) &&
                                !isMyRide;

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
                              ? AppColors.female
                              : AppColors.primary,
                        );
                      }),

                    const SizedBox(height: 90),
                  ],
                ),
              ),
      ),
    );
  }

  /// Quick action tile inside the hero card (frosted white)
  Widget _quickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Friendly empty state when no rides are live
  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.electric_rickshaw_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            "No rides right now",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Be the first — start a ride and others\nheading your way can join you.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRidePage()),
              );
              if (result == true) {
                setState(() => _searchQuery = "");
                await _fetchDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text("Create a ride"),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    Color color = AppColors.textSecondary,
    Color background = AppColors.fieldFill,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
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
    required String paymentMode,
  }) {
    final lower = title.toLowerCase();
    final IconData destIcon = lower.contains('metro') || lower.contains('station')
        ? Icons.directions_subway_rounded
        : (lower.contains('college') || lower.contains('bms') || lower.contains('campus'))
            ? Icons.school_rounded
            : Icons.place_rounded;

    // Accent colour of the card: pink for women-only, blue for my ride, green otherwise
    final Color tone = isFemaleOnly
        ? AppColors.female
        : (isMyRide ? AppColors.accent : AppColors.primary);
    final Color toneSoft = isFemaleOnly
        ? AppColors.femaleSoft
        : (isMyRide ? AppColors.accentSoft : AppColors.primarySoft);

    final bool highlighted = isMyRide || isActiveJoinedRide;
    final String ctaText =
        isMyRide ? "Manage" : (isActiveJoinedRide ? "Open" : "View");

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetroRideDetailsPage(rideId: id),
          ),
        );

        if (result == true && mounted) {
          // Instantly clear active ride status from UI without waiting
          setState(() {
            if (_activeRideId == id) {
              _activeRideId = null;
              _activeRideDest = null;
            }
            _availableRides.removeWhere((r) => r['id']?.toString() == id);
          });
        }

        // Always sync full fresh state immediately
        await _fetchDashboardData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: highlighted
              ? Border.all(color: tone.withOpacity(0.55), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // Status ribbon for my ride / joined ride
            if (highlighted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: toneSoft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl - 2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMyRide ? Icons.star_rounded : Icons.check_circle_rounded,
                      size: 14,
                      color: tone,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMyRide ? "You're hosting this ride" : "You've joined this ride",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: toneSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(destIcon, color: tone, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.trip_origin_rounded,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    "From $gate",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(
                              icon: Icons.event_seat_rounded,
                              label: people,
                              color: AppColors.primaryDark,
                              background: AppColors.primarySoft,
                            ),
                            _chip(
                              icon: paymentMode.contains('UPI')
                                  ? Icons.qr_code_2_rounded
                                  : Icons.payments_rounded,
                              label: paymentMode.replaceAll(" (Cash/UPI)", ""),
                            ),
                            if (isFemaleOnly)
                              _chip(
                                icon: Icons.female_rounded,
                                label: "Women only",
                                color: AppColors.female,
                                background: AppColors.femaleSoft,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: highlighted ? tone : AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ctaText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

//   static const Color ink = AppColors.ink;
//   static const Color inkSoft = AppColors.textPrimary;
//   static const Color muted = AppColors.textSecondary;
//   static const Color mutedLight = AppColors.textMuted;

//   static const Color canvas = AppColors.background;
//   static const Color surface = Colors.white;
//   static const Color surfaceSoft = AppColors.background;
//   static const Color line = Color(0xFFE8EDF3);

//   static const Color green = AppColors.primary;
//   static const Color greenDark = AppColors.primaryDark;
//   static const Color blue = AppColors.accent;
//   static const Color blueBright = AppColors.accent;
//   static const Color pink = AppColors.female;
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
//                       borderRadius: BorderRadius.circular(12),
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
//                   color: AppColors.danger,
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
//                         fontSize: 13,
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
//                           colors: [Color(0xFF5EE58A), AppColors.primary],
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
//                           borderRadius: BorderRadius.circular(12),
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
//                         fontSize: 13,
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
//                         fontSize: 12,
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
//         borderRadius: BorderRadius.circular(20),
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
//                   fontSize: 12,
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
//               fontSize: 13,
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
//                   fontSize: 12,
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
//                   borderRadius: BorderRadius.circular(16),
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
//                             borderRadius: BorderRadius.circular(12),
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
//         borderRadius: BorderRadius.circular(12),
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
//               fontSize: 10,
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
//                   fontSize: 10,
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
//               fontSize: 11,
//               fontWeight: active ? FontWeight.w900 : FontWeight.w700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
