import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../models/station.dart';
import 'station_list_screen.dart';

class FilterScreen extends StatefulWidget {
  final StationFilters initial;
  final double maxRadiusKm;
  final List<ChargingStation> allStations;
  final List<String> availableProviders;
  final List<String> availableConnectors;
  const FilterScreen({
    super.key,
    required this.initial,
    required this.maxRadiusKm,
    required this.allStations,
    required this.availableProviders,
    required this.availableConnectors,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Defensive null-aware spreads (`...?`) everywhere here: if `widget.initial`
  // is ever a StationFilters built by stale/old code (e.g. mid-session hot
  // reload before a field like `speeds` existed, or a future JSON/prefs
  // loader that omits a key), these fall back to an empty set instead of
  // throwing "type 'Null' is not a subtype of type 'Set<String>'".
  late Set<String> _connectors = {...?widget.initial.connectors};
  late double _distance = widget.initial.maxDistanceKm;
  late bool _availableOnly = widget.initial.availableOnly;
  late Set<String> _providers = {...?widget.initial.providers};
  late Set<String> _speeds = {...?widget.initial.speeds};

  List<String> get _providerOptions =>
      (widget.availableProviders.toSet().toList()..sort());

  // Built from whatever connector types actually turned up nearby, instead
  // of a fixed 3-option list — so Type 1 / Tesla / GB/T chargers (all real
  // OCM connector types) are filterable when they exist, and options don't
  // show for connector types that aren't near you anyway.
  List<String> get _connectorOptions =>
      (widget.availableConnectors.toSet().toList()..sort());

  static const _speedOptions = ['Fast', 'Standard', 'Slow'];

  int get _matchCount {
    return widget.allStations.where((s) {
      if (s.distanceKm > _distance) return false;
      if (_availableOnly && s.status != StationStatus.available) return false;
      if (_connectors.isNotEmpty && !s.connectors.any(_connectors.contains)) {
        return false;
      }
      if (_providers.isNotEmpty &&
          !_providers.any((p) => p.toLowerCase() == s.operator.toLowerCase())) {
        return false;
      }
      if (_speeds.isNotEmpty && !_speeds.contains(s.speed)) return false;
      return true;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Filters'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Connector type', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose 1 or more', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          ..._connectorOptions.map((c) => CheckboxListTile(
                value: _connectors.contains(c),
                title: Text(c),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _connectors.add(c);
                    } else {
                      _connectors.remove(c);
                    }
                  });
                },
              )),
          const SizedBox(height: 12),
          Text('Distance', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Nearby search only covers ${widget.maxRadiusKm.round()} km, so the slider stops there.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Slider(
            value: _distance.clamp(0.0, widget.maxRadiusKm).toDouble(),
            min: 0,
            max: widget.maxRadiusKm,
            divisions: widget.maxRadiusKm.round(),
            activeColor: AppColors.primary,
            label: '${_distance.round()} km',
            onChanged: (v) => setState(() => _distance = v),
          ),
          Center(
            child: Text('${_distance.round()} KM',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(height: 12),
          Text('Availability', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose 1', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          RadioListTile<bool>(
            value: false,
            groupValue: _availableOnly,
            title: const Text('All Stations'),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _availableOnly = v!),
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: _availableOnly,
            title: const Text('Available Now'),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _availableOnly = v!),
          ),
          const SizedBox(height: 12),
          Text('Provider', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose 1 or more', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (_providerOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No providers found among nearby stations yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ..._providerOptions.map((p) => CheckboxListTile(
                  value: _providers.contains(p),
                  title: Text(p),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _providers.add(p);
                      } else {
                        _providers.remove(p);
                      }
                    });
                  },
                )),
          const SizedBox(height: 12),
          Text('Charging speed', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose 1 or more', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ..._speedOptions.map((sp) => CheckboxListTile(
                value: _speeds.contains(sp),
                title: Text(sp),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _speeds.add(sp);
                    } else {
                      _speeds.remove(sp);
                    }
                  });
                },
              )),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '$_matchCount station${_matchCount == 1 ? '' : 's'} match these filters',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _connectors.clear();
                      _providers.clear();
                      _speeds.clear();
                      _distance = widget.maxRadiusKm;
                      _availableOnly = false;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      StationFilters(
                        connectors: _connectors,
                        maxDistanceKm: _distance,
                        availableOnly: _availableOnly,
                        providers: _providers,
                        speeds: _speeds,
                      ),
                    );
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
