import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF667085);
  static const Color lightMuted = Color(0xFF98A2B3);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color borderColor = Color(0xFFE4E7EC);

  static const Color green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: ink,
                size: 20,
              ),
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Live Tracking',
                style: TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTENT
  // ===========================================================================

  Widget _buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          28,
          20,
          28,
          40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // -------------------------------------------------------------------
            // ICON
            // -------------------------------------------------------------------

            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6EE),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD5ECDD),
                ),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: green,
                size: 40,
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------------------------------------------------
            // TITLE
            // -------------------------------------------------------------------

            const Text(
              'Live tracking is coming soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),

            const SizedBox(height: 10),

            // -------------------------------------------------------------------
            // DESCRIPTION
            // -------------------------------------------------------------------

            const Text(
              'We are working on live ride tracking so you can see your ride location and follow the route in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------------------------------------------------
            // INFORMATION CARD
            // -------------------------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Column(
                children: [
                  _featureRow(
                    icon: Icons.gps_fixed_rounded,
                    title: 'Real-time location',
                    subtitle:
                        'See where your ride is on the map.',
                  ),

                  const SizedBox(height: 14),

                  _featureRow(
                    icon: Icons.route_outlined,
                    title: 'Live route updates',
                    subtitle:
                        'Follow the ride as it moves.',
                  ),

                  const SizedBox(height: 14),

                  _featureRow(
                    icon: Icons.access_time_rounded,
                    title: 'Better ETA',
                    subtitle:
                        'Get a clearer idea of when your ride will arrive.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // -------------------------------------------------------------------
            // STATUS
            // -------------------------------------------------------------------

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: lightMuted,
                    size: 15,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Feature under development',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // -------------------------------------------------------------------
            // BACK BUTTON
            // -------------------------------------------------------------------

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(
                    color: borderColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FEATURE ROW
  // ===========================================================================

  Widget _featureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8F6),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: green,
            size: 18,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: const TextStyle(
                  color: muted,
                  fontSize: 9.5,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}