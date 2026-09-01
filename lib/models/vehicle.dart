class Vehicle {
  final String id;
  final String name;
  final String connector;
  final String batteryCapacity;
  final String preferredCharging;
  /// Manufacturer-rated full-charge range in km. Real apps (and real trip
  /// planning) need this — battery kWh alone doesn't tell you how far a
  /// specific car goes, since efficiency (Wh/km) varies a lot by model.
  final double rangeKm;

  /// [id] identifies this vehicle across saves/loads so it can be
  /// updated or deleted from a multi-vehicle list. Auto-generated when
  /// not supplied (e.g. when creating a brand-new vehicle in the UI).
  Vehicle({
    String? id,
    required this.name,
    required this.connector,
    required this.batteryCapacity,
    required this.preferredCharging,
    this.rangeKm = 480,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Numeric battery capacity in kWh, parsed out of e.g. "75 kWh".
  double get batteryCapacityKwh =>
      double.tryParse(batteryCapacity.replaceAll(RegExp('[^0-9.]'), '')) ?? 75;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connector': connector,
        'batteryCapacity': batteryCapacity,
        'preferredCharging': preferredCharging,
        'rangeKm': rangeKm,
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String?,
        name: json['name'] ?? 'Tesla Model 3',
        connector: json['connector'] ?? 'CCS2',
        batteryCapacity: json['batteryCapacity'] ?? '75 kWh',
        preferredCharging: json['preferredCharging'] ?? 'DC Fast',
        rangeKm: (json['rangeKm'] as num?)?.toDouble() ?? 480,
      );

  static Vehicle defaultVehicle() => Vehicle(
        id: 'default',
        name: 'Tesla Model 3',
        connector: 'CCS2',
        batteryCapacity: '75 kWh',
        preferredCharging: 'DC Fast',
        rangeKm: 480,
      );
}
