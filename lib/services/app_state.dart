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

  static const _vehiclesKey = 'ev_connect_vehicles';
  static const _activeVehicleIdKey = 'ev_connect_active_vehicle_id';
  // Old single-vehicle storage key, kept only so _getVehicles() can
  // migrate anyone's existing saved vehicle into the new multi-vehicle
  // list the first time they open the app after this update.
  static const _legacyVehicleKey = 'ev_connect_vehicle';
  static const _favouritesKey = 'ev_connect_favourites';
  static const _historyKey = 'ev_connect_history';

  /// All vehicles the user has saved, oldest-added first. Migrates the
  /// old single-vehicle format on first read, or seeds a default vehicle
  /// if there's nothing saved at all yet.
  Future<List<Vehicle>> getVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_vehiclesKey);
    if (raw != null) {
      final vehicles = raw
          .map((s) =>
              Vehicle.fromJson(Map<String, dynamic>.from(jsonDecode(s))))
          .toList();
      if (vehicles.isNotEmpty) return vehicles;
    }
    final legacyRaw = prefs.getString(_legacyVehicleKey);
    final migrated = legacyRaw != null
        ? Vehicle.fromJson(Map<String, dynamic>.from(jsonDecode(legacyRaw)))
        : Vehicle.defaultVehicle();
    await _writeVehicles([migrated]);
    await prefs.setString(_activeVehicleIdKey, migrated.id);
    return [migrated];
  }

  Future<void> _writeVehicles(List<Vehicle> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _vehiclesKey,
      vehicles.map((v) => jsonEncode(v.toJson())).toList(),
    );
  }

  Future<String> _getActiveVehicleId(List<Vehicle> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_activeVehicleIdKey);
    if (id != null && vehicles.any((v) => v.id == id)) return id;
    // Active id missing or points at a vehicle that no longer exists
    // (e.g. it was deleted) - fall back to the first vehicle.
    final fallback = vehicles.first.id;
    await prefs.setString(_activeVehicleIdKey, fallback);
    return fallback;
  }

  /// The vehicle used everywhere only "the" vehicle matters - route
  /// planning, connector matching, etc. This is the currently *active*
  /// vehicle out of possibly several saved ones.
  Future<Vehicle> getVehicle() async {
    final vehicles = await getVehicles();
    final activeId = await _getActiveVehicleId(vehicles);
    return vehicles.firstWhere((v) => v.id == activeId,
        orElse: () => vehicles.first);
  }

  /// Makes [id] the active vehicle. No-op if [id] doesn't match a saved
  /// vehicle.
  Future<void> setActiveVehicle(String id) async {
    final vehicles = await getVehicles();
    if (!vehicles.any((v) => v.id == id)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeVehicleIdKey, id);
  }

  /// Inserts [vehicle] if its id isn't already saved, otherwise updates
  /// the existing entry in place. Used for both "Edit Vehicle" (existing
  /// id) and "Add Vehicle" (new id) so callers don't need to know which
  /// case they're in.
  Future<void> saveVehicle(Vehicle vehicle) async {
    final vehicles = await getVehicles();
    final idx = vehicles.indexWhere((v) => v.id == vehicle.id);
    if (idx == -1) {
      vehicles.add(vehicle);
    } else {
      vehicles[idx] = vehicle;
    }
    await _writeVehicles(vehicles);
  }

  /// Removes a vehicle. Refuses to delete the last remaining vehicle -
  /// the app always needs at least one active vehicle to function. If
  /// the deleted vehicle was the active one, falls back to whichever
  /// vehicle is now first.
  Future<void> deleteVehicle(String id) async {
    final vehicles = await getVehicles();
    if (vehicles.length <= 1) return;
    vehicles.removeWhere((v) => v.id == id);
    await _writeVehicles(vehicles);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_activeVehicleIdKey) == id) {
      await prefs.setString(_activeVehicleIdKey, vehicles.first.id);
    }
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
