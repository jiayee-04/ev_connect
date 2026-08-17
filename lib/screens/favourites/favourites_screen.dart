import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../services/app_state.dart';
import '../../models/station.dart';
import '../station/station_detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<ChargingStation>? _favourites;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await AppState.instance.getFavouriteStations();
    if (mounted) setState(() => _favourites = favs);
  }

  Future<void> _remove(ChargingStation s) async {
    await AppState.instance.removeFavourite(s.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = _favourites;
    final favourites = (all ?? [])
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: const AppHeader(title: 'Favourites'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search Favourite',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: all == null
                  ? const Center(child: CircularProgressIndicator())
                  : favourites.isEmpty
                      ? const Center(
                          child: Text('No favourite stations yet.',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: favourites.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final s = favourites[i];
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  title: Text(s.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '\u2605 ${s.rating} \u2022 ${s.statusLabel} \u2022 ${s.distanceKm} km'),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          children: s.connectors.map((c) => Tag(c)).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.favorite_rounded,
                                        color: AppColors.danger),
                                    onPressed: () => _remove(s),
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => StationDetailScreen(station: s)),
                                    );
                                    // The detail screen may have toggled this
                                    // station's favourite state — refresh so
                                    // an un-favourite there is reflected here.
                                    _load();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
