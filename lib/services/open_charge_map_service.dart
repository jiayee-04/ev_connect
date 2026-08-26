import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
import 'mock_data.dart';
import 'location_service.dart';

/// Pulls real charging-station data from Open Charge Map (openchargemap.org)
/// — a free, open, community-maintained database covering real chargers
/// worldwide, including Malaysia (ChargEV, Gentari, Shell Recharge, JomCharge
/// and Tesla destination chargers are all in it).
///
/// No paid billing account is required. Get a free client key at
/// https://openchargemap.org/site/developerinfo and put it below to raise
/// your rate limit — the API also works at a low rate limit with no key at
/// all, which is enough for development and demos.
class OpenChargeMapService {
  OpenChargeMapService._();
  static final OpenChargeMapService instance = OpenChargeMapService._();

  static const String _baseUrl = 'https://api.openchargemap.io/v3/poi';

  /// Put your free Open Charge Map client key here before shipping to
  /// production. Leave blank to use the shared low-rate-limit access.
  static const String apiKey = '8669082e-b293-4797-a264-fb8ae4398f01';

  Future<List<ChargingStation>> nearby({
    required LatLng center,
    double radiusKm = 25,
    int maxResults = 60,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'output': 'json',
      'countrycode': 'MY',
      'latitude': center.latitude.toString(),
      'longitude': center.longitude.toString(),
      'distance': radiusKm.toString(),
      'distanceunit': 'KM',
      'maxresults': maxResults.toString(),
      'compact': 'false',
      'verbose': 'true',
      if (apiKey.isNotEmpty) 'key': apiKey,
    });

    try {
      final res = await http
          .get(uri, headers: const {'User-Agent': 'EVConnectApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        return _fallback(center);
      }

      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return _fallback(center);

      final stations = data.map((raw) => _fromOcmJson(raw, center)).whereType<ChargingStation>().toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return stations.isEmpty ? _fallback(center) : stations;
    } catch (_) {
      // Offline, request blocked, rate-limited, etc. — never break the map,
      // just fall back to bundled sample stations.
      return _fallback(center);
    }
  }

  /// Bundled sample stations, but with real distance-from-you recalculated
  /// (not the stale hardcoded values baked into mock_data.dart) so the
  /// list/sort is still honest even when the live API is unreachable.
  List<ChargingStation> _fallback(LatLng center) {
    final withRealDistance = MockData.stations.map((s) {
      final km = LocationService.instance.distanceKm(center, LatLng(s.latitude, s.longitude));
      return s.copyWith(distanceKm: double.parse(km.toStringAsFixed(1)));
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return withRealDistance;
  }

  /// OCM's connector titles are free-text and inconsistent across records
  /// (e.g. "CCS (Type 2)", "Type 2 (Socket Only)", "Type 2 (Tethered
  /// Connector)"). The app's filter screen only knows a small set of
  /// canonical labels, so raw titles need to be bucketed into those before
  /// they're stored - otherwise exact-match filtering (e.g. "CCS2") never
  /// finds anything.
  String _canonicalConnector(String rawTitle) {
    final t = rawTitle.toLowerCase();
    // Check CCS/Combo before the generic "type 2" check below, since OCM's
    // CCS title also contains the substring "type 2" (e.g. "CCS (Type 2)").
    if (t.contains('ccs') || t.contains('combo')) return 'CCS2';
    if (t.contains('chademo')) return 'CHAdeMO';
    if (t.contains('type 2') || t.contains('mennekes')) return 'Type 2';
    if (t.contains('type 1') || t.contains('j1772')) return 'Type 1';
    if (t.contains('tesla')) return 'Tesla';
    if (t.contains('gb/t') || t.contains('gbt')) return 'GB/T';
    return rawTitle;
  }

  /// OCM's operator titles are whatever the community entered - legal
  /// entity names, inconsistent casing, sometimes blank. Map known
  /// Malaysian CPOs onto the clean brand names the filter screen offers,
  /// and fall back to the raw (trimmed) title so it's still visible even
  /// when it isn't one of the known ones.
  String _canonicalOperator(String? rawTitle) {
    final t = rawTitle?.trim() ?? '';
    if (t.isEmpty) return 'Independent';
    final lower = t.toLowerCase();
    const known = {
      'chargesini': 'ChargeSini',
      'jomcharge': 'JomCharge',
      'gentari': 'Gentari',
      'chargev': 'ChargEV',
      'charge ev': 'ChargEV',
      'shell': 'Shell Recharge',
      'tesla': 'Tesla',
      'tnb': 'TNB Electron',
      'charge n go': 'Charge N Go',
      'chargengo': 'Charge N Go',
    };
    for (final entry in known.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return t;
  }

  ChargingStation? _fromOcmJson(dynamic raw, LatLng center) {
    try {
      final map = raw as Map<String, dynamic>;
      final addressInfo = map['AddressInfo'] as Map<String, dynamic>?;
      if (addressInfo == null) return null;

      final lat = (addressInfo['Latitude'] as num?)?.toDouble();
      final lng = (addressInfo['Longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final connections = (map['Connections'] as List<dynamic>? ?? []);
      final connectorNames = connections
          .map((c) => (c as Map<String, dynamic>)['ConnectionType'] as Map<String, dynamic>?)
          .where((c) => c != null)
          .map((c) => _canonicalConnector((c!['Title'] as String?) ?? 'Unknown'))
          .toSet()
          .toList();

      final maxPower = connections
          .map((c) => ((c as Map<String, dynamic>)['PowerKW'] as num?)?.toDouble() ?? 0)
          .fold<double>(0, (a, b) => b > a ? b : a);

      final numPoints = (map['NumberOfPoints'] as num?)?.toInt() ?? connections.length;
      final operatorInfo = map['OperatorInfo'] as Map<String, dynamic>?;
      final statusType = map['StatusType'] as Map<String, dynamic>?;
      final isOperational = statusType?['IsOperational'] as bool? ?? true;

      final distance = LocationService.instance.distanceKm(
        center,
        LatLng(lat, lng),
      );

      return ChargingStation(
        id: 'ocm_${map['ID']}',
        name: (addressInfo['Title'] as String?)?.trim().isNotEmpty == true
            ? addressInfo['Title'] as String
            : 'EV Charging Station',
        address: [
          addressInfo['AddressLine1'],
          addressInfo['Town'],
          addressInfo['StateOrProvince'],
        ].where((e) => e != null && (e as String).isNotEmpty).join(', '),
        latitude: lat,
        longitude: lng,
        distanceKm: double.parse(distance.toStringAsFixed(1)),
        rating: 4.0,
        status: isOperational ? StationStatus.available : StationStatus.offline,
        connectors: connectorNames.isEmpty ? ['Type 2'] : connectorNames.cast<String>(),
        speed: maxPower >= 50 ? 'Fast' : (maxPower >= 22 ? 'Standard' : 'Slow'),
        maxPowerKw: maxPower,
        pricePerKwh: 1.10,
        freeSlots: numPoints,
        totalSlots: numPoints,
        operator: _canonicalOperator(operatorInfo?['Title'] as String?),
        source: StationSource.live,
      );
    } catch (_) {
      return null;
    }
  }
}
