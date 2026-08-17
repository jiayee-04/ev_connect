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

  ChargingSession({
    required this.stationName,
    required this.location,
    required this.date,
    required this.minutes,
    required this.kwh,
    required this.amount,
    required this.status,
    this.paymentMethod = '-',
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
      );
}
