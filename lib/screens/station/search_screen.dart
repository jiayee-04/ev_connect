import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../services/open_charge_map_service.dart';
import '../../models/station.dart';
import 'station_detail_screen.dart';

class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({super.key});

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  static const _recentSearchesKey = 'recent_station_searches';
  static const _maxRecent = 5;

  final _controller = TextEditingController();

  List<String> _recent = [];
  bool _loadingRecent = true;

  static const _popular = ['Tesla Supercharger', 'Gentari Pavilion', 'Petronas EV Charger'];

  List<ChargingStation> _allStations = [];
  bool _loadingStations = true;
  bool _stationsFailed = false;

  List<ChargingStation> _results = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadStations();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentSearchesKey);
    if (!mounted) return;
    setState(() {
      _recent = raw ?? [];
      _loadingRecent = false;
    });
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recent);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> _loadStations() async {
    try {
      final stations = await OpenChargeMapService.instance.allForSearch();
      if (!mounted) return;
      setState(() {
        _allStations = stations;
        _loadingStations = false;
      });
      if (_controller.text.trim().isNotEmpty) {
        _search(_controller.text);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStations = false;
        _stationsFailed = true;
      });
    }
  }

  void _search(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _results = [];
        return;
      }
      final q = query.trim().toLowerCase();
      _results = _allStations
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.operator.toLowerCase().contains(q) ||
              s.address.toLowerCase().contains(q))
          .toList();
      if (!_recent.contains(query)) {
        _recent = [query, ..._recent].take(_maxRecent).toList();
        _saveRecent();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Search'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) {
                _search(v);
                setState(() {}); // refresh so suggestions/results toggle correctly
              },
              decoration: const InputDecoration(
                hintText: 'Search charging station',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _controller.text.isEmpty
                  ? _buildSuggestions()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loadingStations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stationsFailed && _allStations.isEmpty) {
      return Center(
        child: Text(
          'Could not load stations. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No matching stations.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = _results[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.bolt_rounded, color: AppColors.primary),
            title: Text(s.name,
                style: const TextStyle(color: AppColors.textDark)),
            subtitle: Text('${s.distanceKm} km \u2022 ${s.statusLabel}',
                style: const TextStyle(color: AppColors.textMuted)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    if (_loadingRecent) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Searches', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: _clearRecent,
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _recent
                .map((r) => _chip(r, Icons.bolt_rounded))
                .toList(),
          ),
          const SizedBox(height: 20),
        ] else ...[
          Text(
            'No recent searches yet — search for a station to see it here.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
        ],
        Text('Popular Searches', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _popular.map((p) => _chip(p, Icons.star_rounded)).toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.warning),
      label: Text(label, style: const TextStyle(color: AppColors.textDark)),
      backgroundColor: AppColors.primaryPale,
      onPressed: () {
        _controller.text = label;
        _search(label);
        setState(() {});
      },
    );
  }
}
