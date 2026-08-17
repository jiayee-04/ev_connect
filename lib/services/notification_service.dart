import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

/// Fires real notifications for real events - no hardcoded example list.
/// Every call to [notify] does two things:
///  1. Saves the notification to persisted storage, read by the
///     Notifications screen (so it's there even if the OS notification
///     was dismissed or the app was in the foreground when it fired).
///  2. Shows an actual system-tray notification via
///     flutter_local_notifications - a real OS notification, not a
///     simulated in-app-only banner.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _storeKey = 'ev_connect_notifications';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  int _nextOsId = 1000;
  bool _initialized = false;

  /// Call once, before runApp(). Sets up the notification channel and
  /// (on Android 13+) requests the runtime notification permission -
  /// without this, Android silently drops notifications on newer OS
  /// versions.
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
      // OS notification permission not granted / platform not set up yet
      // (e.g. Android manifest not configured after `flutter create .`).
      // The in-app notification was already saved above regardless, so
      // nothing is lost - it'll show correctly on the Notifications screen.
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
      // First run: seed a single real welcome notification so the screen
      // isn't confusingly blank before the driver has done anything yet.
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
