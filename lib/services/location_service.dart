import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Wraps device GPS access. Every real charging-station app needs this to
/// centre the map, sort stations by distance, and know when the driver has
/// actually arrived at a station (for auto-starting a session).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Kuala Lumpur city centre — used whenever GPS is unavailable/denied so
  /// the map always has something sensible to show instead of failing.
  static const LatLng fallback = LatLng(3.1390, 101.6869);

  Future<LatLng> getCurrentLatLng() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return fallback;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallback;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // GPS timeout, permission plugin not wired on this platform yet, etc.
      // Never let a location failure block the map from rendering.
      return fallback;
    }
  }

  double distanceKm(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Kilometer, a, b);
  }
}
