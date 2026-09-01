import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle.dart';
import '../models/charging_session.dart';
import '../models/station.dart';
import 'mock_data.dart';

/// Holds small bits of app state that need to survive app restarts and
/// sync across devices: the user's vehicle profile, favourite stations,
/// and charging history from sessions actually completed in the app.
///
/// Backed by Cloud Firestore, one document per signed-in user at
/// users/{uid}/app_state/data — a subcollection, not fields directly on
/// users/{uid}, so this never collides with whatever profile fields your
/// auth/signup flow already writes there (email, display name, etc).
///
/// The first time a signed-in user has no doc here yet, this migrates
/// whatever was already saved locally (from the previous SharedPreferences
/// version of this class) up into Firestore, once, so existing installs
/// don't lose data when this ships. After that migration runs, local
/// storage for these keys is no longer read.
class AppState {
  AppState._();
  static final AppState instance = AppState._();

  // Legacy local keys — read only during the one-time migration below.
  static const _legacyVehiclesKey = 'ev_connect_vehicles';
  static const _legacyActiveVehicleIdKey = 'ev_connect_active_vehicle_id';
  static const _legacyLegacyVehicleKey = 'ev_connect_vehicle';
  static const _legacyFavouritesKey = 'ev_connect_favourites';
  static const _legacyHistoryKey = 'ev_connect_history';

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('AppState requires a signed-in Firebase user');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('app_state')
      .doc('data');

  Future<Map<String, dynamic>> _readDoc() async {
    final snap = await _doc.get();
    if (snap.exists && snap.data() != null) return snap.data()!;
    return await _migrateFromLocalOrSeed();
  }

  /// Runs once per user: pulls any existing local SharedPreferences data
  /// into Firestore so nothing is lost when a returning user first opens
  /// the app on this update. If there's nothing local either, seeds fresh
  /// defaults (same seeding the old local-only version did).
  Future<Map<String, dynamic>> _migrateFromLocalOrSeed() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Vehicles ---
    List<Map<String, dynamic>> vehicles = [];
    final rawVehicles = prefs.getStringList(_legacyVehiclesKey);
    if (rawVehicles != null && rawVehicles.isNotEmpty) {
      vehicles = rawVehicles
          .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
          .toList();
    } else {
      final legacyRaw = prefs.getString(_legacyLegacyVehicleKey);
      final migrated = legacyRaw != null
          ? Vehicle.fromJson(Map<String, dynamic>.from(jsonDecode(legacyRaw)))
          : Vehicle.defaultVehicle();
      vehicles = [migrated.toJson()];
    }
    final activeVehicleId =
        prefs.getString(_legacyActiveVehicleIdKey) ?? vehicles.first['id'] as String;

    // --- Favourites ---
    Map<String, dynamic> favourites;
    final rawFavourites = prefs.getStringList(_legacyFavouritesKey);
    if (rawFavourites != null) {
      favourites = {};
      for (final entry in rawFavourites) {
        final station = ChargingStation.fromJson(
            Map<String, dynamic>.from(jsonDecode(entry)));
        favourites[station.id] = station.toJson();
      }
    } else {
      favourites = {
        for (final s in MockData.stations.take(3)) s.id: s.toJson(),
      };
    }

    // --- History ---
    final rawHistory = prefs.getStringList(_legacyHistoryKey) ?? [];
    final history = rawHistory
        .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
        .toList();

    final data = <String, dynamic>{
      'vehicles': vehicles,
      'activeVehicleId': activeVehicleId,
      'favourites': favourites,
      'history': history,
    };
    await _doc.set(data);
    return data;
  }

  Future<void> _updateDoc(Map<String, dynamic> patch) =>
      _doc.set(patch, SetOptions(merge: true));

  // ---------------- Vehicles ----------------

  /// All vehicles the user has saved, oldest-added first.
  Future<List<Vehicle>> getVehicles() async {
    final data = await _readDoc();
    final raw = (data['vehicles'] as List<dynamic>? ?? []);
    if (raw.isEmpty) {
      final fallback = Vehicle.defaultVehicle();
      await _updateDoc({
        'vehicles': [fallback.toJson()],
        'activeVehicleId': fallback.id,
      });
      return [fallback];
    }
    return raw
        .map((v) => Vehicle.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<String> _getActiveVehicleId(List<Vehicle> vehicles) async {
    final data = await _readDoc();
    final id = data['activeVehicleId'] as String?;
    if (id != null && vehicles.any((v) => v.id == id)) return id;
    final fallback = vehicles.first.id;
    await _updateDoc({'activeVehicleId': fallback});
    return fallback;
  }

  /// The vehicle used everywhere only "the" vehicle matters — route
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
    await _updateDoc({'activeVehicleId': id});
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
    await _updateDoc({'vehicles': vehicles.map((v) => v.toJson()).toList()});
  }

  /// Removes a vehicle. Refuses to delete the last remaining vehicle —
  /// the app always needs at least one active vehicle to function. If
  /// the deleted vehicle was the active one, falls back to whichever
  /// vehicle is now first.
  Future<void> deleteVehicle(String id) async {
    final vehicles = await getVehicles();
    if (vehicles.length <= 1) return;
    vehicles.removeWhere((v) => v.id == id);
    final data = await _readDoc();
    final patch = <String, dynamic>{
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
    };
    if (data['activeVehicleId'] == id) {
      patch['activeVehicleId'] = vehicles.first.id;
    }
    await _updateDoc(patch);
  }

  // ---------------- Favourites ----------------

  /// Favourites are stored as full station snapshots keyed by id, not
  /// just a list of ids — a live station fetched from Open Charge Map
  /// isn't kept anywhere else once you leave the map/list screen, so
  /// storing only the id would make it impossible to ever show that
  /// station again on the Favourites screen.
  Future<Map<String, ChargingStation>> _readFavourites() async {
    final data = await _readDoc();
    final raw = Map<String, dynamic>.from(data['favourites'] as Map? ?? {});
    final map = <String, ChargingStation>{};
    for (final entry in raw.entries) {
      try {
        map[entry.key] = ChargingStation.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
      } catch (_) {
        // Skip any corrupted entry rather than losing the rest.
      }
    }
    return map;
  }

  Future<void> _writeFavourites(Map<String, ChargingStation> map) async {
    await _updateDoc({
      'favourites': {for (final e in map.entries) e.key: e.value.toJson()},
    });
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

  // ---------------- History ----------------

  /// Sessions actually completed in this app, persisted across restarts
  /// and sorted newest-first. Only real sessions the user has actually
  /// paid for through the app — no seeded/sample entries mixed in.
  Future<List<ChargingSession>> getHistory() async {
    final data = await _readDoc();
    final raw = (data['history'] as List<dynamic>? ?? []);
    final sessions = raw
        .map((s) => ChargingSession.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  Future<void> addHistoryEntry(ChargingSession session) async {
    final data = await _readDoc();
    final raw = List<Map<String, dynamic>>.from(
      (data['history'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map)),
    );
    raw.insert(0, session.toJson());
    await _updateDoc({'history': raw});
  }
}
