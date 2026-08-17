import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../models/station.dart';
import '../../services/location_service.dart';
import '../../services/open_charge_map_service.dart';
import 'station_detail_screen.dart';

/// Real, working map of nearby chargers — OpenStreetMap tiles (free, no API
/// key) with live pins pulled from Open Charge Map, falling back to bundled
/// sample stations if the device is offline. Tapping a pin shows a mini
/// preview card the driver can tap through to full details and booking.
class StationMapView extends StatefulWidget {
  final List<ChargingStation> fallbackStations;
  const StationMapView({super.key, required this.fallbackStations});

  @override
  State<StationMapView> createState() => _StationMapViewState();
}

class _StationMapViewState extends State<StationMapView> {
  final MapController _mapController = MapController();
  List<ChargingStation> _stations = [];
  ChargingStation? _selected;
  LatLng _center = LocationService.fallback;
  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _stations = widget.fallbackStations;
    _init();
  }

  Future<void> _init() async {
    final pos = await LocationService.instance.getCurrentLatLng();
    if (!mounted) return;
    setState(() => _center = pos);
    await _loadStations(pos);
  }

  Future<void> _loadStations(LatLng center) async {
    setState(() => _loading = true);
    final result = await OpenChargeMapService.instance.nearby(center: center);
    if (!mounted) return;
    setState(() {
      _stations = result;
      _loading = false;
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.instance.getCurrentLatLng();
    if (!mounted) return;
    setState(() {
      _center = pos;
      _locating = false;
    });
    _mapController.move(pos, 14);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.evconnect.app',
              ),
              MarkerLayer(
                markers: [
                  // User location marker.
                  Marker(
                    point: _center,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  // Charging station markers, colour-coded by live status.
                  for (final s in _stations)
                    Marker(
                      point: LatLng(s.latitude, s.longitude),
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = s),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 42,
                          color: s.statusColor,
                          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),

          if (_loading)
            const Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: _Pill(child: Text('Loading nearby chargers…')),
              ),
            ),

          // Legend.
          Positioned(
            top: 14,
            left: 14,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _LegendDot(color: AppColors.success, label: 'Available'),
                  SizedBox(width: 8),
                  _LegendDot(color: AppColors.busy, label: 'Busy'),
                  SizedBox(width: 8),
                  _LegendDot(color: Color(0xFF9E9E9E), label: 'Offline'),
                ],
              ),
            ),
          ),

          // My location FAB.
          Positioned(
            right: 14,
            bottom: _selected != null ? 150 : 14,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: _locating ? null : _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // Search-this-area button.
          Positioned(
            left: 14,
            bottom: _selected != null ? 150 : 14,
            child: FloatingActionButton.extended(
              heroTag: 'searchArea',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Search this area'),
              onPressed: () => _loadStations(_mapController.camera.center),
            ),
          ),

          // Selected station mini preview card.
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _StationPreviewCard(
                station: _selected!,
                onClose: () => setState(() => _selected = null),
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StationDetailScreen(station: _selected!),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
        child: child,
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _StationPreviewCard extends StatelessWidget {
  final ChargingStation station;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _StationPreviewCard({required this.station, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = station;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryPale,
                child: Icon(s.connectorIcon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${s.operator} · ${s.statusLabel} · ${s.distanceKm} km · RM${s.pricePerKwh.toStringAsFixed(2)}/kWh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
