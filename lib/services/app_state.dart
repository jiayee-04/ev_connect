import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle.dart';
import '../models/charging_session.dart';
import '../models/station.dart';
import 'mock_data.dart';

/// Holds small bits of app state that need to survive app restarts:
/// the user's vehicle profile, favourite stations, and charging
/// history from sessions actually completed in the app.
class AppState {
  AppState._();
  static final AppState instance = AppState._();

  static const _vehicleKey = 'ev_connect_vehicle';
  static const _favouritesKey = 'ev_connect_favourites';
  static const _historyKey = 'ev_connect_history';

  Future<Vehicle> getVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehicleKey);
    if (raw == null) return Vehicle.defaultVehicle();
    return Vehicle.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehicleKey, jsonEncode(vehicle.toJson()));
  }

  /// Favourites are stored as full station snapshots keyed by id, not
  /// just a list of ids — a live station fetched from Open Charge Map
  /// isn't kept anywhere else once you leave the map/list screen, so
  /// storing only the id would make it impossible to ever show that
  /// station again on the Favourites screen. Seeded with a few sample
  /// stations on first run so Favourites isn't empty out of the box.
  Future<Map<String, ChargingStation>> _readFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favouritesKey);
    if (raw == null) {
      final seeded = {
        for (final s in MockData.stations.take(3)) s.id: s,
      };
      await _writeFavourites(seeded);
      return seeded;
    }
    final map = <String, ChargingStation>{};
    for (final entry in raw) {
      try {
        final station = ChargingStation.fromJson(
            Map<String, dynamic>.from(jsonDecode(entry)));
        map[station.id] = station;
      } catch (_) {
        // Skip any corrupted entry rather than losing the rest.
      }
    }
    return map;
  }

  Future<void> _writeFavourites(Map<String, ChargingStation> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favouritesKey,
      map.values.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<Set<String>> getFavouriteIds() async {
    final map = await _readFavourites();
    return map.keys.toSet();
  }

  /// Full favourited station objects, for the Favourites screen to
  /// actually render — includes live-fetched stations, not just the
  /// bundled sample set.
  Future<List<ChargingStation>> getFavouriteStations() async {
    final map = await _readFavourites();
    return map.values.toList();
  }

  /// Returns the new favourited state (true = now a favourite) so the
  /// caller can update its UI without a second read.
  Future<bool> toggleFavourite(ChargingStation station) async {
    final map = await _readFavourites();
    final nowFavourite = !map.containsKey(station.id);
    if (nowFavourite) {
      map[station.id] = station;
    } else {
      map.remove(station.id);
    }
    await _writeFavourites(map);
    return nowFavourite;
  }

  Future<void> removeFavourite(String stationId) async {
    final map = await _readFavourites();
    map.remove(stationId);
    await _writeFavourites(map);
  }

  /// Sessions actually completed in this app, persisted across restarts
  /// and sorted newest-first. Only real sessions the user has actually
  /// paid for through the app - no seeded/sample entries mixed in.
  Future<List<ChargingSession>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final real = raw
        .map((s) => ChargingSession.fromJson(
            Map<String, dynamic>.from(jsonDecode(s))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return real;
  }

  Future<void> addHistoryEntry(ChargingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    raw.insert(0, jsonEncode(session.toJson()));
    await prefs.setStringList(_historyKey, raw);
  }
}
