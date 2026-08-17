enum NotifKind { chargingStarted, chargingComplete, payment, favourite, station, system }

class AppNotification {
  final String id;
  final NotifKind kind;
  final String title;
  final String message;
  final DateTime time;
  final bool read;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.time,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        message: message,
        time: time,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'message': message,
        'time': time.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        kind: NotifKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => NotifKind.system,
        ),
        title: json['title'] as String,
        message: json['message'] as String,
        time: DateTime.parse(json['time'] as String),
        read: json['read'] as bool? ?? false,
      );
}
