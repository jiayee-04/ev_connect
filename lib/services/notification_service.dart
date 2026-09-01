import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _storeKey = 'ev_connect_notifications';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  int _nextOsId = 1000;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> notify({
    required NotifKind kind,
    required String title,
    required String message,
  }) async {
    final item = AppNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      title: title,
      message: message,
      time: DateTime.now(),
    );
    await _save(item);
    await _showOsNotification(title, message);
  }

  Future<void> _showOsNotification(String title, String message) async {
    if (!_initialized) return; // Never block the caller if init failed/was skipped.
    try {
      const androidDetails = AndroidNotificationDetails(
        'ev_connect_events',
        'EV Connect Updates',
        channelDescription: 'Charging session, payment and station updates',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(_nextOsId++, title, message, details);
    } catch (_) {
    }
  }

  Future<void> _save(AppNotification item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    await prefs.setStringList(_storeKey, raw);
  }

  Future<List<AppNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    final list = raw
        .map((s) => AppNotification.fromJson(Map<String, dynamic>.from(jsonDecode(s))))
        .toList();
    if (list.isEmpty) {
      final welcome = AppNotification(
        id: 'welcome',
        kind: NotifKind.system,
        title: 'Welcome to EV Connect',
        message: 'Start a charging session to see live updates here.',
        time: DateTime.now(),
      );
      await _save(welcome);
      return [welcome];
    }
    return list..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    final updated = raw.map((s) {
      final item = AppNotification.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
      return jsonEncode(item.copyWith(read: true).toJson());
    }).toList();
    await prefs.setStringList(_storeKey, updated);
  }
}
