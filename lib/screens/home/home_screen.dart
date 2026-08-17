import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common_widgets.dart';
import '../../services/mock_data.dart';
import '../../services/charging_session_manager.dart';
import '../../l10n/app_strings.dart';
import '../station/station_detail_screen.dart';
import '../route/route_planner_screen.dart';
import '../session/charging_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _adController = PageController();
  int _adIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-slide the ad carousel every 4 seconds - this is the "advertisement
    // space" that replaces the static banner, used to generate ad income.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _adIndex = (_adIndex + 1) % MockData.ads.length;
      _adController.animateToPage(
        _adIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearby = MockData.stations.take(3).toList();

    return Scaffold(
      appBar: AppHeader(
        title: AppStrings.t('home_title'),
        showBack: false,
        trailing: IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pushNamed('/notifications'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- Active charging session (running in the background) ----
          AnimatedBuilder(
            animation: ChargingSessionManager.instance,
            builder: (context, _) {
              final manager = ChargingSessionManager.instance;
              if (!manager.isActive || manager.station == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChargingSessionScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: manager.batteryPct / 100,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                                Text('${manager.batteryPct.round()}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Charging \u2022 ${manager.station!.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${manager.kwhDelivered.toStringAsFixed(1)} kWh \u2022 RM ${manager.costSoFar.toStringAsFixed(2)} so far',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ---- Advertisement carousel (monetisation slot) ----
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _adController,
              itemCount: MockData.ads.length,
              onPageChanged: (i) => _adIndex = i,
              itemBuilder: (context, i) {
                final ad = MockData.ads[i];
                return _AdCard(title: ad['title']!, subtitle: ad['subtitle']!);
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(MockData.ads.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _adIndex
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.25),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Quick actions ----
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.ev_station_rounded,
                  label: AppStrings.t('quick_charging_station'),
                  onTap: () => Navigator.of(context).pushNamed('/stations'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.favorite_rounded,
                  label: AppStrings.t('quick_favourites'),
                  onTap: () => Navigator.of(context).pushNamed('/favourites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.history_rounded,
                  label: AppStrings.t('quick_charging_history'),
                  onTap: () => Navigator.of(context).pushNamed('/history'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.alt_route_rounded,
                  label: AppStrings.t('quick_my_route'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoutePlannerScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          SectionTitle(
            AppStrings.t('nearby_stations'),
            trailing: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/stations'),
              child: Text(AppStrings.t('see_all')),
            ),
          ),
          ...nearby.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryPale,
                    child: const Icon(Icons.bolt_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(s.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  subtitle: Text(
                      '${s.statusLabel} \u2022 ${s.distanceKm} km \u2022 ${s.speed}',
                      style: const TextStyle(color: AppColors.textMuted)),
                  trailing: Text(
                    s.statusLabel,
                    style: TextStyle(
                        color: s.statusColor, fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => StationDetailScreen(station: s)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppFooter(currentIndex: 0),
    );
  }
}

class _AdCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AdCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 42),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryPale,
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
