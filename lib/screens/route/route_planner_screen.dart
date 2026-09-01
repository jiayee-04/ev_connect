import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../services/app_state.dart';
import '../../services/mock_data.dart';
import '../../services/location_service.dart';
import '../../services/geocoding_service.dart';
import '../station/station_detail_screen.dart';
import 'location_picker_screen.dart';

/// Real-world route planning
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _fromController = TextEditingController(text: 'My Location');
  final _toController = TextEditingController();

  LatLng? _fromPoint; // null = resolve from GPS at plan-time
  LatLng? _toPoint; // null = resolve by geocoding the typed text

  double _currentCharge = 100; // Assume a full charge by default.
  Vehicle? _vehicle;
  _PlanResult? _result;
  bool _planning = false;
  String? _error;


  static const double _reserve = 0.15;
  static const double _roadDistanceFactor = 1.3;

  static const Map<String, double> _commonRoutes = {
    'Kuala Lumpur → Penang': 350,
    'Kuala Lumpur → Ipoh': 205,
    'Kuala Lumpur → Melaka': 148,
    'Kuala Lumpur → Johor Bahru': 350,
    'Kuala Lumpur → Genting Highlands': 55,
    'Kuala Lumpur → Kuantan': 260,
  };

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    final v = await AppState.instance.getVehicle();
    if (mounted) setState(() => _vehicle = v);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _pickCommonRoute(String label) {
    final parts = label.split(' → ');
    setState(() {
      _fromController.text = parts.first;
      _fromPoint = null;
      _toController.text = parts.last;
      _toPoint = null;
      _result = null;
    });
  }

  Future<void> _pickOnMap({required bool isFrom}) async {
    final current = isFrom ? _fromPoint : _toPoint;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: isFrom ? 'Pick Starting Point' : 'Pick Destination',
          initial: current,
        ),
      ),
    );
    if (picked == null) return;
    final label = await GeocodingService.instance.reverse(picked);
    if (!mounted) return;
    setState(() {
      if (isFrom) {
        _fromPoint = picked;
        _fromController.text = label;
      } else {
        _toPoint = picked;
        _toController.text = label;
      }
    });
  }

  Future<LatLng?> _resolve({
    required LatLng? picked,
    required String typed,
    required bool isFrom,
  }) async {
    if (picked != null) return picked;
    if (isFrom && typed.trim().toLowerCase() == 'my location') {
      return LocationService.instance.getCurrentLatLng();
    }
    if (typed.trim().isEmpty) return null;
    return GeocodingService.instance.search(typed);
  }

  Future<void> _plan() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;

    setState(() {
      _planning = true;
      _error = null;
      _result = null;
    });

    final from = await _resolve(picked: _fromPoint, typed: _fromController.text, isFrom: true);
    final to = await _resolve(picked: _toPoint, typed: _toController.text, isFrom: false);

    if (!mounted) return;

    if (from == null || to == null) {
      setState(() {
        _planning = false;
        _error = to == null
            ? 'Couldn\'t find "${_toController.text}". Try a more specific place name, or pick it on the map.'
            : 'Couldn\'t resolve your starting location. Try picking it on the map.';
      });
      return;
    }

    final straightLineKm =
        LocationService.instance.distanceKm(from, to);
    final distance = straightLineKm * _roadDistanceFactor;

    final kwhPerKm = vehicle.batteryCapacityKwh / vehicle.rangeKm;
    final kwhNeeded = distance * kwhPerKm;

    final reserveKm = vehicle.rangeKm * _reserve;
    final usableFullRange = vehicle.rangeKm - reserveKm;
    double usableRangeLeft = vehicle.rangeKm * (_currentCharge / 100) - reserveKm;
    double distanceLeft = distance;
    int stopsNeeded = 0;

    while (distanceLeft > usableRangeLeft) {
      distanceLeft -= usableRangeLeft;
      stopsNeeded++;
      usableRangeLeft = usableFullRange;
    }
    final arrivalUsableKm = (usableRangeLeft - distanceLeft).clamp(0, usableFullRange);
    final arrivalPct = (((arrivalUsableKm + reserveKm) / vehicle.rangeKm) * 100).clamp(0, 100);

    final suggestions = List<ChargingStation>.from(MockData.stations)
      ..sort((a, b) => b.maxPowerKw.compareTo(a.maxPowerKw));
    final stops = suggestions.take(stopsNeeded).toList();

    setState(() {
      _planning = false;
      _result = _PlanResult(
        distanceKm: distance,
        kwhNeeded: kwhNeeded,
        stopsNeeded: stopsNeeded,
        stops: stops,
        arrivalPct: arrivalPct.toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    return Scaffold(
      appBar: const AppHeader(title: 'Route Planner'),
      body: vehicle == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${vehicle.name} \u2022 ${vehicle.rangeKm.round()} km rated range \u2022 ${vehicle.batteryCapacityKwh.round()} kWh battery',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _locationField(
                  label: 'From',
                  controller: _fromController,
                  isFrom: true,
                ),
                const SizedBox(height: 14),
                _locationField(
                  label: 'To',
                  controller: _toController,
                  isFrom: false,
                  hintText: 'Type a place, or pick on the map',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonRoutes.keys
                      .map((label) => ActionChip(
                            label: Text(label, style: const TextStyle(fontSize: 11.5)),
                            onPressed: () => _pickCommonRoute(label),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 22),
                Text('Starting battery: ${_currentCharge.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text('Assumed full by default \u2014 adjust if you\'re starting lower.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                Slider(
                  value: _currentCharge,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '${_currentCharge.round()}%',
                  onChanged: (v) => setState(() => _currentCharge = v),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _planning ? null : _plan,
                  icon: _planning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.alt_route_rounded),
                  label: Text(_planning ? 'Working it out\u2026' : 'Plan Route'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 26),
                  _ResultCard(result: _result!),
                ],
              ],
            ),
    );
  }

  Widget _locationField({
    required String label,
    required TextEditingController controller,
    required bool isFrom,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(hintText: hintText),
                onChanged: (_) {
                  // Typing overrides any previously map-picked point.
                  if (isFrom) {
                    _fromPoint = null;
                  } else {
                    _toPoint = null;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickOnMap(isFrom: isFrom),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.map_rounded, color: AppColors.primaryDark, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanResult {
  final double distanceKm;
  final double kwhNeeded;
  final int stopsNeeded;
  final List<ChargingStation> stops;
  final double arrivalPct;

  _PlanResult({
    required this.distanceKm,
    required this.kwhNeeded,
    required this.stopsNeeded,
    required this.stops,
    required this.arrivalPct,
  });
}

class _ResultCard extends StatelessWidget {
  final _PlanResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final noStopNeeded = result.stopsNeeded == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: noStopNeeded ? AppColors.primaryPale : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                noStopNeeded ? Icons.check_circle_rounded : Icons.ev_station_rounded,
                color: noStopNeeded ? AppColors.primary : AppColors.busy,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  noStopNeeded
                      ? 'You can make this ~${result.distanceKm.round()} km trip without stopping \u2014 you should arrive with about ${result.arrivalPct.round()}% battery.'
                      : 'This ~${result.distanceKm.round()} km trip needs ${result.stopsNeeded} charging ${result.stopsNeeded == 1 ? 'stop' : 'stops'} to arrive safely with a reserve left.',
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(label: 'Trip distance', value: '${result.distanceKm.round()} km'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(label: 'Energy needed', value: '${result.kwhNeeded.round()} kWh'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Distance is an estimate (straight-line, adjusted for typical road routing) since no paid routing API is connected \u2014 actual driving distance may vary.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        if (result.stops.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionTitle('Suggested Charging Stops'),
          const Text(
            'Approximate \u2014 based on fastest chargers on your network, not yet matched to the exact route path.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          ...result.stops.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${s.operator} \u2022 ${s.maxPowerKw.round()} kW \u2022 ${s.speed}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.primaryPale, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
