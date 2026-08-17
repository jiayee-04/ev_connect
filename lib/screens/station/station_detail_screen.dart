import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/station.dart';
import '../../services/app_state.dart';
import '../payment/booking_confirm_screen.dart';

class StationDetailScreen extends StatefulWidget {
  final ChargingStation station;
  const StationDetailScreen({super.key, required this.station});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _loadFavourite();
  }

  Future<void> _loadFavourite() async {
    final favs = await AppState.instance.getFavouriteIds();
    if (mounted) setState(() => _isFavourite = favs.contains(widget.station.id));
  }

  Future<void> _toggleFavourite() async {
    final nowFavourite = await AppState.instance.toggleFavourite(widget.station);
    if (!mounted) return;
    setState(() => _isFavourite = nowFavourite);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowFavourite
            ? 'Added ${widget.station.name} to Favourites'
            : 'Removed ${widget.station.name} from Favourites'),
        action: nowFavourite
            ? SnackBarAction(
                label: 'View',
                onPressed: () => Navigator.of(context).pushNamed('/favourites'),
              )
            : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    return Scaffold(
      appBar: AppHeader(
        title: s.name,
        trailing: IconButton(
          icon: Icon(
            _isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _isFavourite ? AppColors.danger : Colors.white,
          ),
          onPressed: _toggleFavourite,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(Icons.ev_station_rounded, size: 64, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.warning),
              const SizedBox(width: 4),
              Text('${s.rating}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('\u2022 ${s.distanceKm} km away',
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.address, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                s.source == StationSource.live
                    ? Icons.wifi_tethering_rounded
                    : Icons.verified_user_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                s.lastVerified != null
                    ? '${s.sourceLabel} · updated ${_timeAgo(s.lastVerified!)}'
                    : s.sourceLabel,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: s.connectors.map((c) => Tag(c)).toList()),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow('Operator', s.operator),
                  const Divider(),
                  _infoRow('Status', s.statusLabel, valueColor: s.statusColor),
                  const Divider(),
                  _infoRow('Charging speed', '${s.speed} · up to ${s.maxPowerKw.toStringAsFixed(0)} kW'),
                  const Divider(),
                  _infoRow('Available slots', '${s.freeSlots} / ${s.totalSlots}'),
                  const Divider(),
                  _infoRow('Price', 'RM ${s.pricePerKwh.toStringAsFixed(2)} / kWh'),
                  const Divider(),
                  _infoRow('Hours', s.isOpen24Hours ? 'Open 24 hours' : 'Business hours'),
                  if (s.amenities.isNotEmpty) ...[
                    const Divider(),
                    _infoRow('Amenities', s.amenities.join(', ')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Real apps let the driver estimate cost/time before committing —
          // small but genuinely useful "will this fit my stop" calculator.
          Card(
            color: AppColors.primaryPale,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Charge to 80% (≈ 40 kWh)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text(
                    'Est. ${s.estimateTimeFor(40)} · RM ${s.estimateCostFor(40).toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: s.status == StationStatus.offline
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingConfirmScreen(station: s),
                      ),
                    );
                  },
            icon: const Icon(Icons.bolt_rounded),
            label: Text(s.status == StationStatus.offline
                ? 'Station Offline'
                : 'Start Charging'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openExternalNavigation(s),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Navigate'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalNavigation(ChargingStation s) async {
    // Hands off to the user's installed maps app for real turn-by-turn —
    // exactly what PlugShare / ChargEV / Gentari do rather than building
    // their own driving directions.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${s.latitude},${s.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textDark)),
        ],
      ),
    );
  }
}
