import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/create_ride_page.dart';
import '../screens/map_page.dart';
import '../screens/my_rides_page.dart';
import '../screens/profile_page.dart';
import '../theme/app_theme.dart';

enum AppTab { home, rides, map, profile, none }

/// Single bottom navigation bar used by every main screen, so the look and the
/// navigation behaviour are identical everywhere.
///
/// - Home     → returns to the root (dashboard) route
/// - Rides / Map / Profile → opened from Home with push; between tabs with
///   pushReplacement so the back stack never grows endlessly
/// - Centre ➕ → Create Ride; [onRideCreated] runs when a ride was created
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    this.onRideCreated,
  });

  final AppTab current;
  final Future<void> Function()? onRideCreated;

  void _open(BuildContext context, AppTab tab) {
    if (tab == current) return;
    HapticFeedback.selectionClick();

    if (tab == AppTab.home) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final Widget page = switch (tab) {
      AppTab.rides => const MyRidesPage(),
      AppTab.map => const MapPage(),
      AppTab.profile => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };
    final route = MaterialPageRoute(builder: (_) => page);

    if (current == AppTab.home || current == AppTab.none) {
      Navigator.of(context).push(route);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }

  Future<void> _createRide(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateRidePage()),
    );
    if (result == true && onRideCreated != null) {
      await onRideCreated!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                active: current == AppTab.home,
                onTap: () => _open(context, AppTab.home),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Rides',
                active: current == AppTab.rides,
                onTap: () => _open(context, AppTab.rides),
              ),
              SizedBox(
                width: 72,
                child: Center(
                  child: _CreateButton(onTap: () => _createRide(context)),
                ),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
                active: current == AppTab.map,
                onTap: () => _open(context, AppTab.map),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                active: current == AppTab.profile,
                onTap: () => _open(context, AppTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        splashColor: AppColors.primary.withOpacity(0.10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(active ? activeIcon : icon, color: color, size: 23),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? AppColors.ink : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
