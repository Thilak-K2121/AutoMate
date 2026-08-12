// import 'dart:convert';
// import 'create_ride_page.dart';
// import 'map_page.dart';
// import 'profile_page.dart';
// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import 'metro_ride_details_page.dart';

// class MyRidesPage extends StatefulWidget {
//   const MyRidesPage({super.key});

//   @override
//   State<MyRidesPage> createState() => _MyRidesPageState();
// }

// class _MyRidesPageState extends State<MyRidesPage> {
//   List<dynamic> _hostedRides = [];
//   List<dynamic> _joinedRides = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchMyRides();
//   }

//   Future<void> _fetchMyRides() async {
//     try {
//       final response = await ApiService.getRequest('/rides/my-rides');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (mounted) {
//           setState(() {
//             _hostedRides = data['hosted'] ?? [];
//             _joinedRides = data['joined'] ?? [];
//             _isLoading = false;
//           });
//         }
//       } else {
//         if (mounted) setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       debugPrint("Error fetching my rides: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2, // 2 Tabs: Joined and Hosted
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF3F6F9),
//         bottomNavigationBar: _bottomNavBar(),
//         appBar: AppBar(
//           backgroundColor: Colors.white,
//           elevation: 0,
//           leading: GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: const Icon(
//               Icons.arrow_back_ios,
//               color: Color(0xFF1F2937),
//               size: 20,
//             ),
//           ),
//           title: const Text(
//             "My Rides",
//             style: TextStyle(
//               color: Color(0xFF1F2937),
//               fontSize: 22,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           centerTitle: true,
//           bottom: const TabBar(
//             labelColor: Color(0xFF34A853),
//             unselectedLabelColor: Color(0xFF6B7280),
//             indicatorColor: Color(0xFF34A853),
//             indicatorWeight: 3,
//             tabs: [
//               Tab(text: "Joined Rides"),
//               Tab(text: "Hosted by Me"),
//             ],
//           ),
//         ),
//         body: _isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF34A853)),
//               )
//             : TabBarView(
//                 children: [
//                   _buildRideList(
//                     _joinedRides,
//                     "You haven't joined any rides yet.",
//                   ),
//                   _buildRideList(
//                     _hostedRides,
//                     "You haven't hosted any rides yet.",
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }

//   Widget _buildRideList(List<dynamic> rides, String emptyMessage) {
//     return RefreshIndicator(
//       onRefresh: _fetchMyRides,
//       color: const Color(0xFF34A853),
//       child: rides.isEmpty
//           ? ListView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               children: [
//                 SizedBox(height: MediaQuery.of(context).size.height * 0.3),
//                 Center(
//                   child: Text(
//                     emptyMessage,
//                     style: const TextStyle(
//                       color: Color(0xFF6B7280),
//                       fontSize: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             )
//           : ListView.builder(
//               physics: const AlwaysScrollableScrollPhysics(),
//               padding: const EdgeInsets.all(20),
//               itemCount: rides.length,
//               itemBuilder: (context, index) {
//                 final ride = rides[index];
//                 final bool isCompleted = ride['status'] == 'completed';
//                 final String rideId = ride['id'].toString();

//                 return GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) =>
//                             MetroRideDetailsPage(rideId: rideId),
//                       ),
//                     ).then((_) => _fetchMyRides());
//                   },
//                   child: Container(
//                     margin: const EdgeInsets.only(bottom: 14),
//                     padding: const EdgeInsets.all(18),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(22),
//                       border: isCompleted
//                           ? Border.all(color: Colors.grey.shade300)
//                           : null,
//                       boxShadow: [
//                         if (!isCompleted)
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.04),
//                             blurRadius: 10,
//                             offset: const Offset(0, 6),
//                           ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               ride['destination'] ?? 'Unknown',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 16,
//                                 color: isCompleted ? Colors.grey : Colors.black,
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: isCompleted
//                                     ? Colors.grey.shade100
//                                     : const Color(0xFFE8F5E9),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 isCompleted
//                                     ? "Completed"
//                                     : (ride['status'] ?? 'Active')
//                                           .toString()
//                                           .toUpperCase(),
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w700,
//                                   color: isCompleted
//                                       ? Colors.grey
//                                       : const Color(0xFF34A853),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 10),
//                         Row(
//                           children: [
//                             const Icon(
//                               Icons.event,
//                               size: 16,
//                               color: Color(0xFF6B7280),
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               ride['meeting_point'] ?? '',
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 color: Color(0xFF6B7280),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }

//   Widget _bottomNavBar() {
//     return Container(
//       height: 80,
//       padding: const EdgeInsets.symmetric(horizontal: 28),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.05),
//             blurRadius: 10,
//             offset: const Offset(0, -3),
//           )
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           GestureDetector(
//             onTap: () {
//               Navigator.popUntil(context, (route) => route.isFirst);
//             },
//             child: _NavItem(icon: Icons.home, label: "Home", active: false),
//           ),
//           _NavItem(icon: Icons.history, label: "Rides", active: true),
//           GestureDetector(
//             onTap: () async {
//               final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRidePage()));
//               if (result == true) _fetchMyRides();
//             },
//             child: Container(
//               width: 56,
//               height: 56,
//               decoration: const BoxDecoration(
//                 color: Color(0xFF2F80ED),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.add, color: Colors.white),
//             ),
//           ),
//           GestureDetector(
//             onTap: () {
//               Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MapPage()));
//             },
//             child: _NavItem(icon: Icons.map, label: "Map", active: false),
//           ),
//           GestureDetector(
//             onTap: () {
//               Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
//             },
//             child: _NavItem(icon: Icons.person_outline, label: "Profile", active: false),
//           ),
//         ],
//       ),
//     );
//   }
// } // <-- This closes _MyRidesPageState

// // 👇 Restoring the deleted _NavItem class
// class _NavItem extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final bool active;

//   const _NavItem({super.key, required this.icon, required this.label, this.active = false});

//   @override
//   Widget build(BuildContext context) {
//     final color = active ? const Color(0xFF34A853) : const Color(0xFF6B7280);
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, size: 22, color: color),
//         const SizedBox(height: 4),
//         Text(label, style: TextStyle(fontSize: 12, color: color)),
//       ],
//     );
//   }
// }
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'create_ride_page.dart';
import 'metro_ride_details_page.dart';

class MyRidesPage extends StatefulWidget {
  const MyRidesPage({super.key});

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState
    extends State<MyRidesPage>
    with SingleTickerProviderStateMixin {
  // ===========================================================================
  // DESIGN SYSTEM
  // ===========================================================================

  static const Color ink = Color(0xFF0B1220);
  static const Color muted = Color(0xFF64748B);
  static const Color mutedLight = Color(0xFF94A3B8);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color divider = Color(0xFFE7ECF2);

  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color pink = Color(0xFFEC4899);
  static const Color red = Color(0xFFEF4444);
  static const Color greyStatus = Color(0xFF94A3B8);

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<dynamic> _hostedRides = <dynamic>[];
  List<dynamic> _joinedRides = <dynamic>[];

  bool _isLoading = true;

  late TabController _tabController;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _fetchMyRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _fetchMyRides() async {
    try {
      final response =
          await ApiService.getRequest('/rides/my-rides');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _hostedRides =
                data['hosted'] as List<dynamic>? ?? <dynamic>[];

            _joinedRides =
                data['joined'] as List<dynamic>? ?? <dynamic>[];

            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching my rides: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  Future<void> _openRide(dynamic ride) async {
    final String rideId =
        ride['id']?.toString() ?? '';

    if (rideId.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetroRideDetailsPage(
          rideId: rideId,
        ),
      ),
    );

    if (mounted) {
      await _fetchMyRides();
    }
  }

  Future<void> _createRide() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateRidePage(),
      ),
    );

    if (result == true && mounted) {
      await _fetchMyRides();
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingScreen()
            : Column(
                children: [
                  _buildHeader(),
                  _buildTabs(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRideList(
                          rides: _joinedRides,
                          emptyTitle: 'No joined rides yet',
                          emptySubtitle:
                              'When you join a ride, it will appear here.',
                          emptyIcon:
                              Icons.group_add_rounded,
                          accent: blue,
                          buttonLabel: 'Back to Home',
                          onButtonTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        _buildRideList(
                          rides: _hostedRides,
                          emptyTitle: 'No hosted rides yet',
                          emptySubtitle:
                              'Create your first ride and invite others to join.',
                          emptyIcon:
                              Icons.add_road_rounded,
                          accent: greenDark,
                          buttonLabel: 'Create a ride',
                          onButtonTap: _createRide,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.07),
                  blurRadius: 30,
                  offset:
                      const Offset(0, 12),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: greenDark,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Loading your rides',
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Fetching your latest activity',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: divider,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        ink.withOpacity(.035),
                    blurRadius: 14,
                    offset:
                        const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: ink,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'My rides',
                  style: TextStyle(
                    color: ink,
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track rides you joined and hosted',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: divider,
              ),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: greenDark,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TABS
  // ===========================================================================

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: surfaceSoft,
          borderRadius:
              BorderRadius.circular(17),
          border: Border.all(
            color: divider,
          ),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: surface,
            borderRadius:
                BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color:
                    ink.withOpacity(.07),
                blurRadius: 10,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize:
              TabBarIndicatorSize.tab,
          labelColor: ink,
          unselectedLabelColor:
              mutedLight,
          labelStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight:
                FontWeight.w800,
          ),
          unselectedLabelStyle:
              const TextStyle(
            fontSize: 10.5,
            fontWeight:
                FontWeight.w600,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.group_rounded,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Joined (${_joinedRides.length})',
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_road_rounded,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hosted (${_hostedRides.length})',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // RIDE LIST
  // ===========================================================================

  Widget _buildRideList({
    required List<dynamic> rides,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required Color accent,
    required String buttonLabel,
    required VoidCallback onButtonTap,
  }) {
    return RefreshIndicator(
      onRefresh: _fetchMyRides,
      color: greenDark,
      displacement: 20,
      child: rides.isEmpty
          ? ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                32,
                20,
                40,
              ),
              children: [
                _buildEmptyState(
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                  icon: emptyIcon,
                  accent: accent,
                  buttonLabel: buttonLabel,
                  onButtonTap: onButtonTap,
                ),
              ],
            )
          : ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                40,
              ),
              itemCount: rides.length,
              itemBuilder:
                  (context, index) {
                return _buildRideCard(
                  rides[index],
                );
              },
            ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String buttonLabel,
    required VoidCallback onButtonTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        38,
        24,
        30,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: divider,
        ),
        boxShadow: [
          BoxShadow(
            color:
                ink.withOpacity(.025),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  accent.withOpacity(.15),
                  accent.withOpacity(.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accent,
              size: 31,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 11.5,
              height: 1.5,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onButtonTap,
            icon: Icon(
              buttonLabel == 'Back to Home'
                  ? Icons.home_rounded
                  : Icons.add_rounded,
              size: 17,
            ),
            label: Text(
              buttonLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            style:
                ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: ink,
              foregroundColor:
                  Colors.white,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 17,
                vertical: 13,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RIDE CARD
  // ===========================================================================

  Widget _buildRideCard(dynamic ride) {
    final String destination =
        (ride['destination'] ??
                'Unknown destination')
            .toString();

    final String meetingPoint =
        (ride['meeting_point'] ?? '')
            .toString();

    final String rawStatus =
        (ride['status'] ?? 'Active')
            .toString()
            .trim();

    final String normalizedStatus =
        rawStatus.toLowerCase();

    final bool isCompleted =
        normalizedStatus == 'completed';

    final bool isCancelled =
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled';

    final bool isActive =
        !isCompleted && !isCancelled;

    final dynamic femaleValue =
        ride['female_only'];

    final bool isFemaleOnly =
        femaleValue == true ||
        femaleValue == 1 ||
        femaleValue == '1' ||
        femaleValue
                ?.toString()
                .toLowerCase() ==
            'true';

    final bool isMetro =
        destination
            .toLowerCase()
            .contains('metro');

    // -------------------------------------------------------------------------
    // STATUS COLORS
    // -------------------------------------------------------------------------

    final Color accent;

    if (isCancelled) {
      accent = red;
    } else if (isCompleted) {
      accent = greyStatus;
    } else if (isFemaleOnly) {
      accent = pink;
    } else {
      accent = greenDark;
    }

    final Color cardBorder;

    if (isCancelled) {
      cardBorder = const Color(0xFFFECACA);
    } else if (isFemaleOnly && isActive) {
      cardBorder = const Color(0xFFF7D6E6);
    } else {
      cardBorder = divider;
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 13,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(25),
          onTap: () => _openRide(ride),
          child: Ink(
            padding:
                const EdgeInsets.all(15),
            decoration:
                BoxDecoration(
              color: surface,
              borderRadius:
                  BorderRadius.circular(25),
              border: Border.all(
                color: cardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      ink.withOpacity(.035),
                  blurRadius: 21,
                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // -------------------------------------------------------------
                // HEADER
                // -------------------------------------------------------------

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment
                                  .topLeft,
                          end:
                              Alignment
                                  .bottomRight,
                          colors: [
                            accent
                                .withOpacity(
                              .16,
                            ),
                            accent
                                .withOpacity(
                              .05,
                            ),
                          ],
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child: Icon(
                        isMetro
                            ? Icons
                                .subway_rounded
                            : Icons
                                .directions_car_filled_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            destination,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  isCancelled
                                      ? const Color(
                                          0xFF64748B,
                                        )
                                      : isCompleted
                                          ? muted
                                          : ink,
                              fontSize: 14.5,
                              height: 1.18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  -.25,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          if (meetingPoint
                              .isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  isCancelled
                                      ? Icons
                                          .location_off_outlined
                                      : Icons
                                          .location_on_outlined,
                                  color: muted,
                                  size: 13,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    meetingPoint,
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          muted,
                                      fontSize:
                                          10.5,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    _statusChip(
                      status:
                          normalizedStatus,
                      accent: accent,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 14,
                ),

                // -------------------------------------------------------------
                // META
                // -------------------------------------------------------------

                Container(
                  padding:
                      const EdgeInsets.all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        surfaceSoft,
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                    border: Border.all(
                      color: divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            _rideMeta(
                          icon: Icons
                              .location_on_rounded,
                          title:
                              'Meeting point',
                          value:
                              meetingPoint
                                  .isEmpty
                                  ? 'Not available'
                                  : meetingPoint,
                          color:
                              blue,
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            _rideMeta(
                          icon:
                              isCancelled
                                  ? Icons
                                      .cancel_outlined
                                  : isCompleted
                                      ? Icons
                                          .check_circle_outline_rounded
                                      : Icons
                                          .bolt_rounded,
                          title:
                              'Status',
                          value:
                              _statusLabel(
                            normalizedStatus,
                          ),
                          color:
                              accent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),

                // -------------------------------------------------------------
                // FOOTER
                // -------------------------------------------------------------

                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration:
                                BoxDecoration(
                              color:
                                  accent,
                              shape:
                                  BoxShape
                                      .circle,
                            ),
                          ),
                          const SizedBox(
                            width: 7,
                          ),
                          Flexible(
                            child: Text(
                              isCancelled
                                  ? 'This ride was cancelled'
                                  : isCompleted
                                      ? 'Ride completed'
                                      : 'Tap to view details',
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color: muted,
                                fontSize: 9.5,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isActive)
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: ink,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child:
                            const Row(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            Text(
                              'View ride',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    9.5,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              color:
                                  Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),

                    if (isCompleted)
                      _smallStatusAction(
                        icon:
                            Icons.check_rounded,
                        label: 'Done',
                        color:
                            greyStatus,
                      ),

                    if (isCancelled)
                      _smallStatusAction(
                        icon:
                            Icons.close_rounded,
                        label: 'Cancelled',
                        color: red,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STATUS CHIP
  // ===========================================================================

  Widget _statusChip({
    required String status,
    required Color accent,
  }) {
    final String label;

    if (status == 'cancelled' ||
        status == 'canceled') {
      label = 'CANCELLED';
    } else if (status == 'completed') {
      label = 'DONE';
    } else if (status.isEmpty) {
      label = 'ACTIVE';
    } else {
      label = status.toUpperCase();
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            accent.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(
              color: accent,
              shape:
                  BoxShape.circle,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
                TextStyle(
              color: accent,
              fontSize: 8,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS LABEL
  // ===========================================================================

  String _statusLabel(String status) {
    if (status == 'cancelled' ||
        status == 'canceled') {
      return 'Cancelled';
    }

    if (status == 'completed') {
      return 'Completed';
    }

    if (status.isEmpty) {
      return 'Active';
    }

    return _capitalizeStatus(status);
  }

  String _capitalizeStatus(String value) {
    if (value.isEmpty) {
      return '';
    }

    return value[0].toUpperCase() +
        value.substring(1);
  }

  // ===========================================================================
  // SMALL STATUS ACTION
  // ===========================================================================

  Widget _smallStatusAction({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(.07),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
                TextStyle(
              color: color,
              fontSize: 9,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RIDE META
  // ===========================================================================

  Widget _rideMeta({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration:
              BoxDecoration(
            color:
                color.withOpacity(.10),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 15,
          ),
        ),

        const SizedBox(
          width: 7,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: mutedLight,
                  fontSize: 7.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                value,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: ink,
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}