import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

enum _HistoryFilter { all, hosted, joined }

class _RideHistoryPageState extends State<RideHistoryPage> {
  List<dynamic> _historyRides = [];
  bool _isLoading = true;
  String _userId = '';
  _HistoryFilter _filter = _HistoryFilter.all;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  /// Reads the logged-in user's id from the JWT payload (used for the
  /// Hosted / Joined filters).
  Future<void> _loadUserId() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;
      final parts = token.split('.');
      if (parts.length != 3) return;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      _userId = payload['id']?.toString() ?? '';
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    await _loadUserId();
    try {
      final response = await ApiService.getRequest('/rides/history');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rides = data['history'] ?? [];

        // The API can return a hosted ride once per participant — de-duplicate.
        final seen = <String>{};
        final unique = rides.where((r) => seen.add(r['id'].toString())).toList();

        if (!mounted) return;
        setState(() {
          _historyRides = unique;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching ride history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${_months[dt.month - 1]} ${dt.year} · $hour:$minute $period';
    } catch (_) {
      return raw;
    }
  }

  bool _isHosted(dynamic ride) =>
      _userId.isNotEmpty && ride['creator_id']?.toString() == _userId;

  List<dynamic> get _visibleRides => switch (_filter) {
        _HistoryFilter.all => _historyRides,
        _HistoryFilter.hosted => _historyRides.where(_isHosted).toList(),
        _HistoryFilter.joined =>
          _historyRides.where((r) => !_isHosted(r)).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final rides = _visibleRides;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.none),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride history',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your completed trips',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          /// Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _filterChip('All', _HistoryFilter.all),
                const SizedBox(width: 8),
                _filterChip('Hosted', _HistoryFilter.hosted),
                const SizedBox(width: 8),
                _filterChip('Joined', _HistoryFilter.joined),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchHistory,
                    color: AppColors.primary,
                    child: rides.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [_emptyState()],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: rides.length,
                            itemBuilder: (context, index) =>
                                _rideHistoryCard(rides[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String text, _HistoryFilter value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final label = switch (_filter) {
      _HistoryFilter.all => 'No completed rides yet',
      _HistoryFilter.hosted => 'No completed rides you hosted',
      _HistoryFilter.joined => 'No completed rides you joined',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
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
              Icons.history_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Finished rides will show up here.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _rideHistoryCard(dynamic ride) {
    final bool hosted = _isHosted(ride);
    final String title = ride['destination']?.toString() ?? 'Ride';
    final String location = ride['meeting_point']?.toString() ?? '';
    final String date = _formatDate(ride['created_at']?.toString() ?? '');
    final lower = title.toLowerCase();
    final IconData icon = lower.contains('metro') || lower.contains('station')
        ? Icons.directions_subway_rounded
        : (lower.contains('bms') || lower.contains('campus') || lower.contains('college'))
            ? Icons.school_rounded
            : Icons.place_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hosted ? AppColors.accentSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: hosted ? AppColors.accent : AppColors.primary,
            ),
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
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'From $location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hosted ? AppColors.accentSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              hosted ? 'Hosted' : 'Joined',
              style: TextStyle(
                color: hosted ? AppColors.accent : AppColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
