class Vehicle {
  final String name;
  final String connector;
  final String batteryCapacity;
  final String preferredCharging;
  /// Manufacturer-rated full-charge range in km. Real apps (and real trip
  /// planning) need this — battery kWh alone doesn't tell you how far a
  /// specific car goes, since efficiency (Wh/km) varies a lot by model.
  final double rangeKm;

  Vehicle({
    required this.name,
    required this.connector,
    required this.batteryCapacity,
    required this.preferredCharging,
    this.rangeKm = 480,
  });

  /// Numeric battery capacity in kWh, parsed out of e.g. "75 kWh".
  double get batteryCapacityKwh =>
      double.tryParse(batteryCapacity.replaceAll(RegExp('[^0-9.]'), '')) ?? 75;

  Map<String, dynamic> toJson() => {
        'name': name,
        'connector': connector,
        'batteryCapacity': batteryCapacity,
        'preferredCharging': preferredCharging,
        'rangeKm': rangeKm,
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        name: json['name'] ?? 'Tesla Model 3',
        connector: json['connector'] ?? 'CCS2',
        batteryCapacity: json['batteryCapacity'] ?? '75 kWh',
        preferredCharging: json['preferredCharging'] ?? 'DC Fast',
        rangeKm: (json['rangeKm'] as num?)?.toDouble() ?? 480,
      );

  static Vehicle defaultVehicle() => Vehicle(
        name: 'Tesla Model 3',
        connector: 'CCS2',
        batteryCapacity: '75 kWh',
        preferredCharging: 'DC Fast',
        rangeKm: 480,
      );
}
