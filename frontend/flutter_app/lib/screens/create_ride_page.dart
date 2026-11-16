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
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _suggestions(TextEditingController controller, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((o) {
          final selected = controller.text.trim() == o;
          return GestureDetector(
            onTap: () => setState(() => controller.text = o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                o,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );

  Widget _stepButton(IconData icon, VoidCallback? onTap) => Material(
        color: onTap == null ? AppColors.fieldFill : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null ? AppColors.textMuted : AppColors.primaryDark,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppColors.ink),
            ),
          ),
        ],
      ),

      /// Sticky primary action
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: PrimaryButton(
            label: "Create ride",
            icon: Icons.arrow_forward_rounded,
            loading: _isLoading,
            onPressed: _handleCreateRide,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Where are you going?",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Post your trip — students heading the same way can join and split the fare.",
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 22),

            /// ROUTE
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _destinationController,
                    label: "Destination",
                    hint: "e.g. National College Metro Station",
                    icon: Icons.flag_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  _suggestions(_destinationController, const [
                    "National College Metro Station",
                    "BMSCE Campus",
                  ]),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: _meetingPointController,
                    label: "Meeting point",
                    hint: "e.g. BMSCE Gate 1",
                    icon: Icons.location_on_rounded,
                    textInputAction: TextInputAction.done,
                  ),
                  _suggestions(_meetingPointController, const [
                    "BMSCE Gate 1",
                    "BMSCE Gate 2",
                    "National College Metro Station",
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// SEATS
            _card(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: AppColors.accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total seats",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Including you",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _stepButton(
                    Icons.remove_rounded,
                    _seats > 1 ? () => setState(() => _seats--) : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      "$_seats",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _stepButton(
                    Icons.add_rounded,
                    _seats < 4 ? () => setState(() => _seats++) : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// PAYMENT
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("Accepted payment"),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: _paymentOptions.map((mode) {
                        final selected = mode == _selectedPayment;
                        final label = mode == 'Any (Cash/UPI)' ? 'Any' : mode.replaceAll(' Only', '');
                        final icon = mode.startsWith('UPI')
                            ? Icons.qr_code_2_rounded
                            : mode.startsWith('Cash')
                                ? Icons.payments_rounded
                                : Icons.all_inclusive_rounded;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPayment = mode),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                                boxShadow: selected ? AppShadows.card : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icon,
                                    size: 16,
                                    color: selected ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      color: selected ? AppColors.ink : AppColors.textSecondary,
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
                ],
              ),
            ),

            /// WOMEN ONLY (only offered to female users)
            if (_isCurrentUserFemale) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: _isFemaleOnly ? AppColors.femaleSoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: _isFemaleOnly
                        ? AppColors.female.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.femaleSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.female_rounded,
                        color: AppColors.female,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Women-only ride",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Only female students can see and join.",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isFemaleOnly,
                      activeTrackColor: AppColors.female,
                      onChanged: (value) => setState(() => _isFemaleOnly = value),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
