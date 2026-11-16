import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

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

  // Payment selection
  String _selectedPayment = 'Any (Cash/UPI)';

  final List<String> _paymentOptions = [
    'Any (Cash/UPI)',
    'UPI Only',
    'Cash Only',
  ];

  // Current user gender
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

  Future<void> _fetchUserData() async {
    try {
      final response =
          await ApiService.getRequest('/auth/me');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final gender =
            data['user']['gender']
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                '';

        if (mounted) {
          setState(() {
            _isCurrentUserFemale =
                gender == 'female';
          });
        }
      }
    } catch (e) {
      debugPrint(
        "Error fetching gender: $e",
      );
    }
  }

  Future<void> _handleCreateRide() async {
    final destination =
        _destinationController.text.trim();

    final meetingPoint =
        _meetingPointController.text.trim();

    if (destination.isEmpty ||
        meetingPoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill in destination and meeting point",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 🚫 Double-booking check: verify user has no active hosted or joined rides
      final myRidesRes = await ApiService.getRequest('/rides/my-rides');
      if (myRidesRes.statusCode == 200) {
        final data = jsonDecode(myRidesRes.body);
        final hosted = data['hosted'] as List<dynamic>? ?? [];
        final joined = data['joined'] as List<dynamic>? ?? [];

        final hasActiveHosted = hosted.any(
          (r) => r['status'] == 'active' || r['status'] == 'full',
        );
        final hasActiveJoined = joined.any(
          (r) => r['status'] == 'active' || r['status'] == 'full',
        );

        if (hasActiveHosted || hasActiveJoined) {
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text("Cancel Existing Ride?"),
                  ],
                ),
                content: Text(
                  hasActiveHosted
                      ? "You are currently hosting an active ride. Do you want to cancel your existing ride and create this new one?"
                      : "You are currently booked in an active ride. Do you want to cancel/leave your existing ride and create this new one?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Keep Current Ride", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Cancel & Create New"),
                  ),
                ],
              ),
            );
            if (proceed != true) return;
            setState(() {
              _isLoading = true;
            });
          }
        }
      }

      final response =
          await ApiService.postRequest(
        '/rides/create',
        {
          'destination': destination,
          'meeting_point': meetingPoint,
          'seats_total': _seats,
          'female_only': _isFemaleOnly,
          'paymentMode': _selectedPayment,
        },
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Ride created successfully!",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );

          Navigator.pop(
            context,
            true,
          );
        }
      } else {
        final errorData =
            jsonDecode(response.body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ??
                    "Failed to create ride",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Network error. Could not connect to backend.",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _meetingPointController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI state & helpers
  // ---------------------------------------------------------------------------

  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  /// Which field a "popular place" chip fills (last focused; pickup by default)
  bool _targetIsDestination = false;

  static const List<(String, IconData)> _popularPlaces = [
    ('BMSCE Gate 1', Icons.school_rounded),
    ('BMSCE Gate 2', Icons.school_rounded),
    ('National College Metro Station', Icons.directions_subway_rounded),
    ('BMSCE Campus', Icons.apartment_rounded),
  ];

  void _applyPlace(String place) {
    setState(() {
      if (_targetIsDestination) {
        _destinationController.text = place;
        _destinationFocus.unfocus();
      } else {
        _meetingPointController.text = place;
        // Move on to the destination next
        _targetIsDestination = true;
        if (_destinationController.text.trim().isEmpty) {
          _destinationFocus.requestFocus();
        } else {
          _pickupFocus.unfocus();
        }
      }
    });
  }

  void _swapRoute() {
    setState(() {
      final from = _meetingPointController.text;
      _meetingPointController.text = _destinationController.text;
      _destinationController.text = from;
    });
  }

  Widget _routeField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isDestination,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: () => setState(() => _targetIsDestination = isDestination),
          onChanged: (_) => setState(() {}),
          textInputAction:
              isDestination ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (!isDestination) {
              setState(() => _targetIsDestination = true);
              _destinationFocus.requestFocus();
            }
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) => Material(
        color: onTap == null ? AppColors.fieldFill : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: onTap == null ? AppColors.fieldFill : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 19,
              color: onTap == null ? AppColors.textMuted : AppColors.ink,
            ),
          ),
        ),
      );

  Widget _optionRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String from = _meetingPointController.text.trim();
    final String to = _destinationController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,

      /// Sticky primary action
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: PrimaryButton(
            label: "Post ride",
            icon: Icons.arrow_forward_rounded,
            loading: _isLoading,
            onPressed: _handleCreateRide,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            /// Pinned top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Create ride",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    /// ROUTE CARD — From → To with timeline + swap
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Timeline
                          Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 46,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary.withOpacity(0.5),
                                      AppColors.accent.withOpacity(0.5),
                                    ],
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // Fields
                          Expanded(
                            child: Column(
                              children: [
                                _routeField(
                                  label: "FROM",
                                  hint: "Pickup point",
                                  controller: _meetingPointController,
                                  focusNode: _pickupFocus,
                                  isDestination: false,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _routeField(
                                  label: "TO",
                                  hint: "Where to?",
                                  controller: _destinationController,
                                  focusNode: _destinationFocus,
                                  isDestination: true,
                                ),
                              ],
                            ),
                          ),
                          // Swap
                          IconButton(
                            tooltip: "Swap",
                            onPressed: _swapRoute,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.fieldFill,
                            ),
                            icon: const Icon(
                              Icons.swap_vert_rounded,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// POPULAR PLACES
                    Row(
                      children: [
                        const Text(
                          "Popular places",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _targetIsDestination
                              ? "· tap to set destination"
                              : "· tap to set pickup",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none, // let chips scroll into the page gutter
                        itemCount: _popularPlaces.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final (place, icon) = _popularPlaces[i];
                          final bool used = place == from || place == to;
                          return GestureDetector(
                            onTap: () => _applyPlace(place),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: used
                                    ? AppColors.primarySoft
                                    : AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: used
                                      ? AppColors.primary.withOpacity(0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    used ? Icons.check_rounded : icon,
                                    size: 15,
                                    color: used
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    place,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: used
                                          ? AppColors.primaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    /// TRIP DETAILS — seats, payment, women-only in one card
                    const Text(
                      "Trip details",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _optionRow(
                            icon: Icons.groups_rounded,
                            iconColor: AppColors.accent,
                            iconBg: AppColors.accentSoft,
                            title: "Group size",
                            subtitle: "Including you",
                            trailing: Row(
                              children: [
                                _stepButton(
                                  Icons.remove_rounded,
                                  _seats > 1
                                      ? () => setState(() => _seats--)
                                      : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    "$_seats",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                _stepButton(
                                  Icons.add_rounded,
                                  _seats < 4
                                      ? () => setState(() => _seats++)
                                      : null,
                                ),
                              ],
                            ),
                          ),

                          // Fare split hint
                          Padding(
                            padding: const EdgeInsets.only(left: 52, top: 8),
                            child: Row(
                              children: [
                                ...List.generate(
                                  4,
                                  (i) => Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: i < _seats
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _seats == 1
                                      ? "Riding solo"
                                      : "Fare splits $_seats ways",
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),

                          // Payment
                          const Text(
                            "Accepted payment",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.fieldFill,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: _paymentOptions.map((mode) {
                                final selected = mode == _selectedPayment;
                                final label = mode == 'Any (Cash/UPI)'
                                    ? 'Any'
                                    : mode.replaceAll(' Only', '');
                                final icon = mode.startsWith('UPI')
                                    ? Icons.qr_code_2_rounded
                                    : mode.startsWith('Cash')
                                        ? Icons.payments_rounded
                                        : Icons.all_inclusive_rounded;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedPayment = mode,
                                    ),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.surface
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm + 2,
                                        ),
                                        boxShadow:
                                            selected ? AppShadows.card : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 16,
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: selected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: selected
                                                  ? AppColors.ink
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          /// Women-only (offered to female users only)
                          if (_isCurrentUserFemale) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1),
                            ),
                            _optionRow(
                              icon: Icons.female_rounded,
                              iconColor: AppColors.female,
                              iconBg: AppColors.femaleSoft,
                              title: "Women-only ride",
                              subtitle: "Only female students can join",
                              trailing: Switch(
                                value: _isFemaleOnly,
                                activeTrackColor: AppColors.female,
                                onChanged: (value) =>
                                    setState(() => _isFemaleOnly = value),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// Reassurance note
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Only verified BMSCE students can see and join your ride.",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
