import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_footer.dart';
import '../../services/mock_data.dart';
import '../../services/location_service.dart';
import '../../services/open_charge_map_service.dart';
import '../../models/station.dart';
import 'station_detail_screen.dart';
import 'filter_screen.dart';
import 'search_screen.dart';
import 'station_map_view.dart';

class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  // Kept in one place because it has to match the radius actually passed to
  // OpenChargeMapService.nearby() below — otherwise the filter screen's
  // distance slider can offer a range with zero fetched stations in it.
  static const double kNearbyRadiusKm = 25;

  bool _showMap = false;
  StationFilters _filters = StationFilters.initial(kNearbyRadiusKm);

  // Real nearby stations from GPS + Open Charge Map, the same live source
  // the Map tab uses — the List used to just filter the 5-7 bundled mock
  // stations regardless of where you actually were, which made no sense.
  List<ChargingStation> _stations = MockData.stations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  Future<void> _loadNearby() async {
    setState(() => _loading = true);
    final pos = await LocationService.instance.getCurrentLatLng();
    final result = await OpenChargeMapService.instance
        .nearby(center: pos, radiusKm: kNearbyRadiusKm, maxResults: 30);
    if (!mounted) return;
    setState(() {
      _stations = result;
      _loading = false;
    });
  }

  List<ChargingStation> get _filtered {
    return _stations.where((s) {
      if (s.distanceKm > _filters.maxDistanceKm) return false;
      if (_filters.availableOnly && s.status != StationStatus.available) {
        return false;
      }
      if (_filters.connectors.isNotEmpty &&
          !s.connectors.any((c) => _filters.connectors.contains(c))) {
        return false;
      }
      if (_filters.providers.isNotEmpty &&
          !_filters.providers.any(
              (p) => p.toLowerCase() == s.operator.toLowerCase())) {
        return false;
      }
      if (_filters.speeds.isNotEmpty && !_filters.speeds.contains(s.speed)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filtered;

    return Scaffold(
      appBar: AppHeader(
        title: 'Charging Station',
        showBack: false,
        trailing: IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StationSearchScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ToggleButton(
                    label: 'Map',
                    selected: _showMap,
                    onTap: () => setState(() => _showMap = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleButton(
                    label: 'List',
                    selected: !_showMap,
                    onTap: () => setState(() => _showMap = false),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.primaryPale,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      final result = await Navigator.of(context).push<StationFilters>(
                        MaterialPageRoute(
                          builder: (_) => FilterScreen(
                            initial: _filters,
                            maxRadiusKm: kNearbyRadiusKm,
                            allStations: _stations,
                            availableProviders:
                                _stations.map((s) => s.operator).toSet().toList(),
                            availableConnectors: _stations
                                .expand((s) => s.connectors)
                                .toSet()
                                .toList(),
                          ),
                        ),
                      );
                      if (result != null) setState(() => _filters = result);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.tune_rounded, color: AppColors.primaryDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _showMap
                  ? StationMapView(fallbackStations: stations)
                  : _buildList(stations),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(currentIndex: 1),
    );
  }

  Widget _buildList(List<ChargingStation> stations) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNearby,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('No stations match your filters.',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    }
    // Nearest 10 real, distance-sorted stations — matches what the driver
    // asked for instead of an arbitrary bundled list.
    final nearest = stations.take(10).toList();
    return RefreshIndicator(
      onRefresh: _loadNearby,
      child: ListView.separated(
        itemCount: nearest.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${nearest.length} nearest stations \u2022 sorted by distance from you',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            );
          }
          final s = nearest[i - 1];
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryPale,
                child: const Icon(Icons.bolt_rounded, color: AppColors.primary),
              ),
              title: Text(s.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.textDark)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '\u2605 ${s.rating}  \u2022  ${s.statusLabel}  \u2022  ${s.distanceKm} km',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
              trailing: Text(s.speed,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
              ),
            ),
          );
        },
      ),
    );
  }

}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.primaryPale,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple value object carrying the current filter selections between
/// the station list and filter screen.
class StationFilters {
  final Set<String> connectors;
  final double maxDistanceKm;
  final bool availableOnly;
  final Set<String> providers;
  final Set<String> speeds;

  StationFilters({
    required this.connectors,
    required this.maxDistanceKm,
    required this.availableOnly,
    required this.providers,
    this.speeds = const {},
  });

  // Defaults to the full fetched radius so "no filter applied" really means
  // no filter applied, instead of silently hiding stations between the old
  // hardcoded 20km default and the 25km radius that's actually fetched.
  factory StationFilters.initial(double defaultRadiusKm) => StationFilters(
        connectors: {},
        maxDistanceKm: defaultRadiusKm,
        availableOnly: false,
        providers: {},
        speeds: {},
      );

  StationFilters copyWith({
    Set<String>? connectors,
    double? maxDistanceKm,
    bool? availableOnly,
    Set<String>? providers,
    Set<String>? speeds,
  }) {
    return StationFilters(
      connectors: connectors ?? this.connectors,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      availableOnly: availableOnly ?? this.availableOnly,
      providers: providers ?? this.providers,
      speeds: speeds ?? this.speeds,
    );
  }
}
