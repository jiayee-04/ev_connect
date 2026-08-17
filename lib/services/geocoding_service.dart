import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turns typed place names into coordinates (and back) using OpenStreetMap
/// Nominatim — free, no API key, same data source family as the map tiles
/// and Open Charge Map already used elsewhere in the app. This is what
/// lets the Route Planner accept a typed "Penang" or "IOI City Mall"
/// instead of requiring the driver to always drop a pin manually.
///
/// Nominatim's usage policy asks for a real User-Agent and no more than
/// ~1 request/second — fine for how this screen calls it (once per typed
/// field, on demand, not on every keystroke).
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _searchUrl = 'https://nominatim.openstreetmap.org/search';
  static const _reverseUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const _headers = {'User-Agent': 'EVConnectApp/1.0 (student project)'};

  /// Resolve a typed place name to coordinates, biased towards Malaysia.
  /// Returns null if nothing could be matched.
  Future<LatLng?> search(String query) async {
    if (query.trim().isEmpty) return null;
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': query.trim(),
      'format': 'json',
      'limit': '1',
      'countrycodes': 'my',
    });
    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final first = data.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lon = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  /// Turn coordinates into a readable label (e.g. after picking a point
  /// on the map), so the text field shows something meaningful instead
  /// of raw numbers. Falls back to a lat/lng string if reverse lookup
  /// fails — never blocks the flow.
  Future<String> reverse(LatLng point) async {
    final uri = Uri.parse(_reverseUrl).replace(queryParameters: {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'json',
    });
    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _fallbackLabel(point);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final display = data['display_name'] as String?;
      if (display == null || display.isEmpty) return _fallbackLabel(point);
      // Trim to the first couple of segments so it's not a huge string.
      final parts = display.split(',');
      return parts.take(2).join(',').trim();
    } catch (_) {
      return _fallbackLabel(point);
    }
  }

  String _fallbackLabel(LatLng point) =>
      'Pinned location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
}
