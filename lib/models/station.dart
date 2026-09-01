import 'package:flutter/material.dart';
import 'charging_slot.dart';

enum StationStatus { available, busy, offline }

/// Where a station record came from.
enum StationSource { live, community, mock }

class ChargingStation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final StationStatus status;
  final List<String> connectors;
  final String speed; // Fast / Standard / Slow
  final double maxPowerKw;
  final double pricePerKwh; // RM
  final int freeSlots;
  final int totalSlots;
  final String operator; // e.g. ChargEV, Gentari, Shell Recharge
  final String chargerType; // 'AC', 'DC', 'AC & DC', or 'Unknown'
  final bool isOpen24Hours;
  final List<String> amenities;
  final StationSource source;
  final DateTime? lastVerified;
  final List<ChargingSlot> slots;

  const ChargingStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.rating,
    this.reviewCount = 0,
    required this.status,
    required this.connectors,
    required this.speed,
    this.maxPowerKw = 0,
    required this.pricePerKwh,
    required this.freeSlots,
    required this.totalSlots,
    this.operator = 'Independent',
    this.chargerType = 'Unknown',
    this.isOpen24Hours = true,
    this.amenities = const [],
    this.source = StationSource.mock,
    this.lastVerified,
    this.slots = const [],
  });

  String get statusLabel {
    switch (status) {
      case StationStatus.available:
        return 'Available';
      case StationStatus.busy:
        return 'Busy';
      case StationStatus.offline:
        return 'Offline';
    }
  }

  Color get statusColor {
    switch (status) {
      case StationStatus.available:
        return const Color(0xFF2E7D32);
      case StationStatus.busy:
        return const Color(0xFFEF6C00);
      case StationStatus.offline:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Rough charge-time estimate shown before booking
  String estimateTimeFor(double kwhNeeded) {
    if (maxPowerKw <= 0) return '—';
    final hours = kwhNeeded / maxPowerKw;
    final minutes = (hours * 60).round();
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  double estimateCostFor(double kwhNeeded) => kwhNeeded * pricePerKwh;

  IconData get connectorIcon {
    if (connectors.any((c) => c.contains('CCS'))) return Icons.ev_station_rounded;
    if (connectors.any((c) => c.contains('CHAdeMO'))) return Icons.bolt_rounded;
    return Icons.power_rounded;
  }

  String get sourceLabel {
    switch (source) {
      case StationSource.live:
        return 'Live network data';
      case StationSource.community:
        return 'Community verified';
      case StationSource.mock:
        return 'Sample data';
    }
  }

  ChargingStation copyWith({double? distanceKm, List<ChargingSlot>? slots}) {
    return ChargingStation(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating,
      reviewCount: reviewCount,
      status: status,
      connectors: connectors,
      speed: speed,
      maxPowerKw: maxPowerKw,
      pricePerKwh: pricePerKwh,
      freeSlots: freeSlots,
      totalSlots: totalSlots,
      operator: operator,
      chargerType: chargerType,
      isOpen24Hours: isOpen24Hours,
      amenities: amenities,
      source: source,
      lastVerified: lastVerified,
      slots: slots ?? this.slots,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
        'rating': rating,
        'reviewCount': reviewCount,
        'status': status.name,
        'connectors': connectors,
        'speed': speed,
        'maxPowerKw': maxPowerKw,
        'pricePerKwh': pricePerKwh,
        'freeSlots': freeSlots,
        'totalSlots': totalSlots,
        'operator': operator,
        'chargerType': chargerType,
        'isOpen24Hours': isOpen24Hours,
        'amenities': amenities,
        'source': source.name,
        'lastVerified': lastVerified?.toIso8601String(),
        'slots': slots
            .map((s) => {
                  'index': s.index,
                  'state': s.state.name,
                  'connectorType': s.connectorType,
                })
            .toList(),
      };

  factory ChargingStation.fromJson(Map<String, dynamic> json) => ChargingStation(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        rating: (json['rating'] as num).toDouble(),
        reviewCount: json['reviewCount'] as int? ?? 0,
        status: StationStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => StationStatus.available,
        ),
        connectors: List<String>.from(json['connectors'] as List? ?? []),
        speed: json['speed'] as String? ?? 'Standard',
        maxPowerKw: (json['maxPowerKw'] as num?)?.toDouble() ?? 0,
        pricePerKwh: (json['pricePerKwh'] as num).toDouble(),
        freeSlots: json['freeSlots'] as int? ?? 0,
        totalSlots: json['totalSlots'] as int? ?? 0,
        operator: json['operator'] as String? ?? 'Independent',
        chargerType: json['chargerType'] as String? ?? 'Unknown',
        isOpen24Hours: json['isOpen24Hours'] as bool? ?? true,
        amenities: List<String>.from(json['amenities'] as List? ?? []),
        source: StationSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => StationSource.mock,
        ),
        lastVerified: json['lastVerified'] != null
            ? DateTime.tryParse(json['lastVerified'] as String)
            : null,
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) {
              final m = s as Map<String, dynamic>;
              return ChargingSlot(
                index: m['index'] as int,
                state: SlotState.values.firstWhere(
                  (v) => v.name == m['state'],
                  orElse: () => SlotState.offline,
                ),
                connectorType: m['connectorType'] as String?,
              );
            })
            .toList(),
      );
}
