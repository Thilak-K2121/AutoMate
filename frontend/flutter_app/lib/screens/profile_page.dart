// import 'dart:convert';
// import 'create_ride_page.dart';
// import 'map_page.dart';
// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import 'ride_history_page.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'sign_in_page.dart';
// import 'home_page.dart';
// import 'my_rides_page.dart';

// class ProfilePage extends StatefulWidget {
//   const ProfilePage({super.key});

//   @override
//   State<ProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<ProfilePage> {
//   String _userName = "Loading...";
//   String _userEmail = "Loading...";
//   bool _isLoading = true;
//   int _ridesTaken = 0;
//   int _ridesHosted = 0;
//   bool _isLoadingStats = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchProfileData();
//     _fetchProfileStats(); // NEW
//   }

//   Future<void> _fetchProfileData() async {
//     try {
//       final response = await ApiService.getRequest('/auth/me');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (mounted) {
//           setState(() {
//             _userName = data['user']['name'];
//             _userEmail = data['user']['email'];
//             _isLoading = false;
//           });
//         }
//       } else {
//         if (mounted) setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       debugPrint("Error fetching profile: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchProfileStats() async {
//     try {
//       final response = await ApiService.getRequest('/rides/stats');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (mounted) {
//           setState(() {
//             _ridesHosted = data['ridesHosted'] ?? 0;
//             _ridesTaken = data['ridesTaken'] ?? 0;
//             _isLoadingStats = false;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Error fetching stats: $e");
//       if (mounted) setState(() => _isLoadingStats = false);
//     }
//   }

//   Future<void> _handleLogout() async {
//     // Show a confirmation dialog before logging out
//     final bool? confirm = await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Logout"),
//         content: const Text("Are you sure you want to log out?"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text("Logout", style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       // Clear the JWT token from the device
//       await ApiService.clearToken();

//       // Navigate back to the Sign In page and clear the navigation stack
//       if (mounted) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const SignInPage()),
//           (route) => false,
//         );
//       }
//     }
//   }

//   void _showHelpDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text("Help & Support"),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text("   Developer: Thilak K"),
//               TextButton(
//                 onPressed: () async {
//                   final Uri emailLaunchUri = Uri(
//                     scheme: 'mailto',
//                     path: 'thilakk.cs23@bmsce.ac.in', // 👇 FIXED
//                     queryParameters: {'subject': 'AutoMate Support Request'},
//                   );

//                   try {
//                     await launchUrl(
//                       emailLaunchUri,
//                       mode: LaunchMode.externalApplication,
//                     );
//                   } catch (e) {
//                     if (context.mounted) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('No email application installed.'),
//                         ),
//                       );
//                     }
//                   }
//                 },
//                 child: const Text("thilakk.cs23@bmsce.ac.in"), // 👇 FIXED
//               ),
//               const SizedBox(height: 20),
//               const Divider(),
//               const Center(
//                 child: Text(
//                   "Made with ❤️ in Bengaluru",
//                   style: TextStyle(fontSize: 12),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Close"),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F6F9),
//       bottomNavigationBar: _bottomNavBar(),
//       body: SafeArea(
//         child: _isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF34A853)),
//               )
//             : SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 22),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     const SizedBox(height: 10),

//                     /// Header
//                     Row(
//                       children: const [
//                         Text(
//                           "Profile",
//                           style: TextStyle(
//                             fontSize: 26,
//                             fontWeight: FontWeight.w700,
//                             color: Color(0xFF1F2937),
//                           ),
//                         ),
//                         Spacer(),
//                         // Icon(
//                         //   Icons.settings_outlined,
//                         //   size: 22,
//                         //   color: Color(0xFF6B7280),
//                         // ),
//                       ],
//                     ),

//                     const SizedBox(height: 30),

//                     /// Avatar
//                     const CircleAvatar(
//                       radius: 46,
//                       backgroundColor: Color(0xFFDCE7EE),
//                       child: Icon(
//                         Icons.person,
//                         size: 50,
//                         color: Color(0xFF6B7280),
//                       ),
//                     ),

//                     const SizedBox(height: 12),

//                     /// Name
//                     Text(
//                       _userName,
//                       style: const TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                         color: Color(0xFF1F2937),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),

//                     const SizedBox(height: 4),

//                     /// Email
//                     Text(
//                       _userEmail,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Color(0xFF6B7280),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),

//                     const SizedBox(height: 28),

//                     /// Stats Row
//                     _isLoadingStats
//                         ? const Center(
//                             child: CircularProgressIndicator(
//                               color: Color(0xFF34A853),
//                             ),
//                           )
//                         : Row(
//                             children: [
//                               Expanded(
//                                 child: _StatCard(
//                                   title: _ridesTaken.toString(),
//                                   subtitle: "Rides Taken",
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: _StatCard(
//                                   title: _ridesHosted.toString(),
//                                   subtitle: "Rides Hosted",
//                                 ),
//                               ),
//                             ],
//                           ),

//                     const SizedBox(height: 26),

//                     /// Menu Options
//                     _menuTile(
//                       icon: Icons.history,
//                       title: "Ride History",
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             // Change this from RideHistoryPage() to MyRidesPage()
//                             builder: (context) => const MyRidesPage(),
//                           ),
//                         );
//                       },
//                     ),
//                     _menuTile(
//                       icon: Icons.help_outline,
//                       title: "Help & Support",
//                       onTap: () => _showHelpDialog(context),
//                     ),
//                     _menuTile(
//                       icon: Icons.logout,
//                       title: "Logout",
//                       red: true,
//                       onTap: _handleLogout,
//                     ),

//                     const SizedBox(height: 100), // space for bottom nav
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget _menuTile({
//     required IconData icon,
//     required String title,
//     bool red = false,
//     VoidCallback? onTap, // Added onTap functionality
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.04),
//               blurRadius: 10,
//               offset: const Offset(0, 6),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: red ? Colors.red : const Color(0xFF34A853)),
//             const SizedBox(width: 12),
//             Text(
//               title,
//               style: TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//                 color: red ? Colors.red : const Color(0xFF1F2937),
//               ),
//             ),
//             const Spacer(),
//             const Icon(
//               Icons.arrow_forward_ios,
//               size: 16,
//               color: Color(0xFF9CA3AF),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _bottomNavBar() {
//     return Container(
//       height: 80,
//       padding: const EdgeInsets.symmetric(horizontal: 30),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.05),
//             blurRadius: 10,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // HOME: Pops all the way back to the root (Home Page)
//           GestureDetector(
//             onTap: () {
//               Navigator.popUntil(context, (route) => route.isFirst);
//             },
//             child: _NavItem(
//               icon: Icons.home,
//               label: "Home",
//               active: false,
//             ), // Removed const
//           ),

//           // RIDES: Replaces current tab
//           GestureDetector(
//             onTap: () {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => const MyRidesPage()),
//               );
//             },
//             child: _NavItem(
//               icon: Icons.history,
//               label: "Rides",
//               active: false,
//             ), // Removed const
//           ),

//           // ADD RIDE
//           GestureDetector(
//             onTap: () async {
//               final result = await Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const CreateRidePage()),
//               );
//               if (result == true) _fetchProfileStats();
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

//           // MAP: Replaces current tab
//           GestureDetector(
//             onTap: () {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => const MapPage()),
//               );
//             },
//             child: _NavItem(
//               icon: Icons.map,
//               label: "Map",
//               active: false,
//             ), // Removed const
//           ),

//           // PROFILE: Already here
//           _NavItem(
//             icon: Icons.person,
//             label: "Profile",
//             active: true,
//           ), // Removed const
//         ],
//       ),
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   final String title;
//   final String subtitle;

//   const _StatCard({required this.title, required this.subtitle});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.04),
//             blurRadius: 10,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF1F2937),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             subtitle,
//             style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _NavItem extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final bool active;

//   const _NavItem({
//     required this.icon,
//     required this.label,
//     this.active = false,
//   });

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
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'create_ride_page.dart';
import 'map_page.dart';
import 'my_rides_page.dart';
import 'sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ===========================================================================
  // DESIGN SYSTEM
  // ===========================================================================

  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color mutedLight = Color(0xFF94A3B8);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color divider = Color(0xFFE7ECF2);

  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFF4F7CFF);
  static const Color pink = Color(0xFFEC4899);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF59E0B);

  // ===========================================================================
  // STATE
  // ===========================================================================

  String _userName = 'Loading...';
  String _userEmail = 'Loading...';

  bool _isLoading = true;
  bool _isLoadingStats = true;

  int _ridesTaken = 0;
  int _ridesHosted = 0;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _fetchProfileData();
    _fetchProfileStats();
  }

  // ===========================================================================
  // PROFILE DATA
  // ===========================================================================

  Future<void> _fetchProfileData() async {
    try {
      final response = await ApiService.getRequest('/auth/me');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _userName = data['user']['name']?.toString() ?? 'Student';

            _userEmail = data['user']['email']?.toString() ?? '';

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
      debugPrint('Error fetching profile: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');

      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _handleLogout() async {
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: red.withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: red, size: 28),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Log out of AutoMate?',
                  style: TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'You will need to sign in again to access your rides and profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: divider),
                          foregroundColor: ink,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, true);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Log out',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await ApiService.clearToken();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
      }
    }
  }

  // ===========================================================================
  // HELP
  // ===========================================================================

  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: blue.withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: blue,
                    size: 29,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Help & Support',
                  style: TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Need help with AutoMate? Get in touch with the developer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: green.withOpacity(.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: greenDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Developer',
                              style: TextStyle(
                                color: mutedLight,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Thilak K',
                              style: TextStyle(
                                color: ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'thilakk.cs23@bmsce.ac.in',
                      queryParameters: {'subject': 'AutoMate Support Request'},
                    );

                    try {
                      await launchUrl(
                        emailLaunchUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            content: const Text(
                              'No email application installed.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: blue.withOpacity(.06),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: blue.withOpacity(.12)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.mail_outline_rounded, color: blue, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'thilakk.cs23@bmsce.ac.in',
                            style: TextStyle(
                              color: blue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          color: blue,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Made with ❤️ in Bengaluru',
                  style: TextStyle(
                    color: mutedLight,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: const BorderSide(color: divider),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? _buildLoading()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeader()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildProfileCard()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildStats()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                    sliver: SliverToBoxAdapter(child: _buildMenu()),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.07),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
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
            'Loading profile',
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Getting your AutoMate details',
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
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your profile',
                style: TextStyle(
                  color: ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage your account and ride activity',
                style: TextStyle(
                  color: muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: divider),
            boxShadow: [
              BoxShadow(
                color: ink.withOpacity(.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: greenDark,
            size: 19,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PROFILE CARD
  // ===========================================================================

  Widget _buildProfileCard() {
    final initials = _buildInitials(_userName);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1B2A), Color(0xFF143C37)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ink.withOpacity(.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -35,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: green.withOpacity(.11),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -40,
            left: 100,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: blue.withOpacity(.07),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6FE69A), Color(0xFF16A34A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: green.withOpacity(.25),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.person_pin_circle_rounded,
                          color: Color(0xFFA7F3D0),
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'AUTOMATE MEMBER',
                          style: TextStyle(
                            color: Color(0xFFE8FFF4),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .65,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.62),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildInitials(String name) {
    final cleaned = name.trim();

    if (cleaned.isEmpty) {
      return 'A';
    }

    final parts = cleaned.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ===========================================================================
  // STATS
  // ===========================================================================

  Widget _buildStats() {
    if (_isLoadingStats) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: divider),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: greenDark,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _statCard(
            number: _ridesTaken.toString(),
            label: 'Rides taken',
            icon: Icons.directions_car_filled_rounded,
            color: blue,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _statCard(
            number: _ridesHosted.toString(),
            label: 'Rides hosted',
            icon: Icons.groups_rounded,
            color: greenDark,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String number,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: divider),
        boxShadow: [
          BoxShadow(
            color: ink.withOpacity(.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),

          const SizedBox(height: 12),

          Text(
            number,
            style: const TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MENU
  // ===========================================================================

  Widget _buildMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -.35,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Useful shortcuts and support',
          style: TextStyle(
            color: muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 13),

        _menuTile(
          icon: Icons.history_rounded,
          title: 'Ride History',
          subtitle: 'View rides you have taken or hosted',
          color: blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRidesPage()),
            );
          },
        ),

        _menuTile(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'Get help or contact the developer',
          color: greenDark,
          onTap: () => _showHelpDialog(context),
        ),

        _menuTile(
          icon: Icons.logout_rounded,
          title: 'Logout',
          subtitle: 'Sign out from this device',
          color: red,
          isLogout: true,
          onTap: _handleLogout,
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: isLogout ? red.withOpacity(.10) : divider,
              ),
              boxShadow: [
                BoxShadow(
                  color: ink.withOpacity(.025),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isLogout ? red : ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: isLogout ? red.withOpacity(.65) : mutedLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM NAV
  // ===========================================================================

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: ink.withOpacity(.11),
                blurRadius: 30,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _navItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: false,
                  onTap: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),

              Expanded(
                child: _navItem(
                  icon: Icons.history_rounded,
                  label: 'Rides',
                  active: false,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyRidesPage()),
                    );
                  },
                ),
              ),

              SizedBox(
                width: 76,
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateRidePage(),
                        ),
                      );

                      if (result == true) {
                        _fetchProfileStats();
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [blueLight, blue],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: blue.withOpacity(.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _navItem(
                  icon: Icons.map_outlined,
                  label: 'Map',
                  active: false,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MapPage()),
                    );
                  },
                ),
              ),

              Expanded(
                child: _navItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  active: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? greenDark : mutedLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 30,
            decoration: BoxDecoration(
              color: active ? green.withOpacity(.11) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: active ? 21 : 20),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.8,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
