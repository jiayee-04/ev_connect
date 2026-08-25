import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../services/mock_data.dart';
import '../../models/station.dart';
import 'station_detail_screen.dart';

class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({super.key});

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  final _controller = TextEditingController();
  List<String> _recent = ['JomCharge Sunway Pyramid', 'Shell Recharge Rawang'];
  static const _popular = ['Tesla Supercharger', 'Gentari Pavilion', 'Petronas EV Charger'];
  List<ChargingStation> _results = [];

  void _search(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _results = [];
        return;
      }
      _results = MockData.stations
          .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!_recent.contains(query)) {
        _recent = [query, ..._recent].take(5).toList();
      }
    });
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
              onChanged: _search,
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
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Searches', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => setState(() => _recent = []),
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
      },
    );
  }
}
