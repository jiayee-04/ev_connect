import 'station.dart';

enum SessionStatus { completed, cancelled, inProgress }

class ChargingSession {
  final String stationName;
  final String location;
  final DateTime date;
  final int minutes;
  final double kwh;
  final double amount;
  final SessionStatus status;
  final String paymentMethod;
  // Full station snapshot at the time of charging, so History can offer
  // a real "Rebook" action later without needing a fresh lookup - same
  // pattern Favourites uses for stations that came from a live feed.
  // Nullable so older sessions saved before this field existed (or any
  // session that genuinely has no station on hand) still deserialize fine.
  final ChargingStation? station;

  ChargingSession({
    required this.stationName,
    required this.location,
    required this.date,
    required this.minutes,
    required this.kwh,
    required this.amount,
    required this.status,
    this.paymentMethod = '-',
    this.station,
  });

  Map<String, dynamic> toJson() => {
        'stationName': stationName,
        'location': location,
        'date': date.toIso8601String(),
        'minutes': minutes,
        'kwh': kwh,
        'amount': amount,
        'status': status.name,
        'paymentMethod': paymentMethod,
        'station': station?.toJson(),
      };

  factory ChargingSession.fromJson(Map<String, dynamic> json) => ChargingSession(
        stationName: json['stationName'] as String,
        location: json['location'] as String,
        date: DateTime.parse(json['date'] as String),
        minutes: json['minutes'] as int,
        kwh: (json['kwh'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        status: SessionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SessionStatus.completed,
        ),
        paymentMethod: json['paymentMethod'] as String? ?? '-',
        station: json['station'] != null
            ? ChargingStation.fromJson(
                Map<String, dynamic>.from(json['station'] as Map))
            : null,
      );
}
