import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import 'station_list_screen.dart';

class FilterScreen extends StatefulWidget {
  final StationFilters initial;
  const FilterScreen({super.key, required this.initial});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Set<String> _connectors = {...widget.initial.connectors};
  late double _distance = widget.initial.maxDistanceKm;
  late bool _availableOnly = widget.initial.availableOnly;
  late Set<String> _providers = {...widget.initial.providers};

  static const _connectorOptions = ['CCS2', 'Type 2', 'CHAdeMO'];
  // Malaysia's actual major charge point operators (2026), ordered
  // roughly by network size — ChargeSini and JomCharge are currently the
  // two largest networks by point count, per industry CPO reports.
  static const _providerOptions = [
    'ChargeSini',
    'JomCharge',
    'Gentari',
    'ChargEV',
    'Shell Recharge',
    'Tesla',
    'TNB Electron',
    'Charge N Go',
  ];

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
          Slider(
            value: _distance,
            min: 0,
            max: 50,
            divisions: 50,
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _connectors.clear();
                      _providers.clear();
                      _distance = 20;
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
