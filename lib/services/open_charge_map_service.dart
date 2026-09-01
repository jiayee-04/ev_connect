import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
import '../models/charging_slot.dart';
import 'mock_data.dart';
import 'location_service.dart';

/// Pulls real charging-station data from Open Charge Map (openchargemap.org)
class OpenChargeMapService {
  OpenChargeMapService._();
  static final OpenChargeMapService instance = OpenChargeMapService._();

  static const String _baseUrl = 'https://api.openchargemap.io/v3/poi';

  static const String apiKey = '8669082e-b293-4797-a264-fb8ae4398f01';

  Future<List<ChargingStation>> nearby({
    required LatLng center,
    double radiusKm = 25,
    int maxResults = 60,
  }) async {
    return _fetch(
      center: center,
      queryParams: {
        'latitude': center.latitude.toString(),
        'longitude': center.longitude.toString(),
        'distance': radiusKm.toString(),
        'distanceunit': 'KM',
        'maxresults': maxResults.toString(),
      },
    );
  }

  Future<List<ChargingStation>> allForSearch({
    LatLng? center,
    int maxResults = 500,
  }) async {
    final effectiveCenter = center ?? await LocationService.instance.getCurrentLatLng();
    return _fetch(
      center: effectiveCenter,
      queryParams: {'maxresults': maxResults.toString()},
    );
  }

  Future<List<ChargingStation>> _fetch({
    required LatLng center,
    required Map<String, String> queryParams,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'output': 'json',
      'countrycode': 'MY',
      'compact': 'false',
      'verbose': 'true',
      if (apiKey.isNotEmpty) 'key': apiKey,
      ...queryParams,
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
      // Offline, request blocked, rate-limited, etc. — never break the
      // screen, just fall back to bundled sample stations.
      return _fallback(center);
    }
  }


  List<ChargingStation> _fallback(LatLng center) {
    final withRealDistance = MockData.stations.map((s) {
      final km = LocationService.instance.distanceKm(center, LatLng(s.latitude, s.longitude));
      return s.copyWith(
        distanceKm: double.parse(km.toStringAsFixed(1)),
        slots: s.slots.isNotEmpty
            ? s.slots
            : _synthesizeSlotsFromCounts(s.freeSlots, s.totalSlots),
      );
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return withRealDistance;
  }

  List<ChargingSlot> _synthesizeSlotsFromCounts(int freeSlots, int totalSlots) {
    final free = freeSlots.clamp(0, totalSlots);
    return List.generate(totalSlots, (i) {
      return ChargingSlot(
        index: i + 1,
        state: i < free ? SlotState.available : SlotState.occupied,
      );
    });
  }

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

  String _chargerType(List<dynamic> connections, List<String> canonicalConnectors) {
    var hasAc = false;
    var hasDc = false;
    for (final raw in connections) {
      final c = raw as Map<String, dynamic>;
      final currentType = c['CurrentType'] as Map<String, dynamic>?;
      final title = (currentType?['Title'] as String?)?.toUpperCase();
      if (title == null) continue;
      if (title.contains('DC')) hasDc = true;
      if (title.contains('AC')) hasAc = true;
    }

    if (!hasAc && !hasDc) {
      hasAc = canonicalConnectors.any((c) => c == 'Type 1' || c == 'Type 2');
      hasDc = canonicalConnectors
          .any((c) => c == 'CCS2' || c == 'CHAdeMO' || c == 'GB/T' || c == 'Tesla');
    }

    if (hasAc && hasDc) return 'AC & DC';
    if (hasDc) return 'DC';
    if (hasAc) return 'AC';
    return 'Unknown';
  }

  List<ChargingSlot> _buildSlots(List<dynamic> connections, bool stationIsOperational) {
    final slots = <ChargingSlot>[];
    var index = 1;

    for (final raw in connections) {
      final c = raw as Map<String, dynamic>;
      final quantity = (c['Quantity'] as num?)?.toInt() ?? 1;
      final connStatus = c['StatusType'] as Map<String, dynamic>?;
      final operational = connStatus?['IsOperational'] as bool? ?? stationIsOperational;
      final connType = c['ConnectionType'] as Map<String, dynamic>?;
      final label = connType != null
          ? _canonicalConnector((connType['Title'] as String?) ?? 'Unknown')
          : null;

      for (var i = 0; i < (quantity < 1 ? 1 : quantity); i++) {
        slots.add(ChargingSlot(
          index: index++,
          state: operational ? SlotState.available : SlotState.offline,
          connectorType: label,
        ));
      }
    }

    return slots;
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

      final slots = _buildSlots(connections, isOperational);

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
        chargerType: _chargerType(connections, connectorNames.cast<String>()),
        source: StationSource.live,
        slots: slots.isEmpty
            ? List.generate(
                numPoints,
                (i) => ChargingSlot(
                  index: i + 1,
                  state: isOperational ? SlotState.available : SlotState.offline,
                ),
              ) // no per-connection breakdown at all — fall back to station-level status
            : slots,
      );
    } catch (_) {
      return null;
    }
  }
}
