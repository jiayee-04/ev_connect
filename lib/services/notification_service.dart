import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

/// Notification history, synced across the user's devices via Firestore.
///
/// Stored as `users/{uid}/notifications/{id}` — a subcollection, not an
/// array field on the shared app_state document. Notification history is
/// an unbounded, ever-growing event log (every charging start/stop,
/// payment, etc. adds one), which doesn't fit the same shape as small
/// fixed state like "the active vehicle": an array field would eventually
/// hit Firestore's 1MB document-size limit, and every single new
/// notification would have to rewrite the entire history just to append
/// one entry.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Legacy local key — read only during the one-time migration below, for
  // installs that had notifications saved before this moved to Firestore.
  static const _legacyStoreKey = 'ev_connect_notifications';

  static const int _maxFetch = 200;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  int _nextOsId = 1000;
  bool _initialized = false;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('NotificationService requires a signed-in Firebase user');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('notifications');

  // A single marker document, separate from the notifications themselves,
  // records whether the one-time legacy migration has already run for
  // this user — an empty notifications collection alone can't tell "never
  // migrated" apart from "migrated, and there was nothing to bring over".
  DocumentReference<Map<String, dynamic>> get _migrationMarker => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('notifications_meta')
      .doc('migration');

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
    await _collection.doc(item.id).set(item.toJson());
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

  /// Runs once per user: copies any notifications saved locally under the
  /// old SharedPreferences-only version of this class up into Firestore,
  /// so upgrading doesn't wipe someone's notification history.
  Future<void> _migrateLegacyIfNeeded() async {
    final marker = await _migrationMarker.get();
    if (marker.exists) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_legacyStoreKey) ?? [];
    if (raw.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final s in raw) {
        try {
          final item = AppNotification.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
          batch.set(_collection.doc(item.id), item.toJson());
        } catch (_) {
          // Skip a corrupted legacy entry rather than failing the whole migration.
        }
      }
      await batch.commit();
    }
    await _migrationMarker.set({'migratedAt': DateTime.now().toIso8601String()});
  }

  Future<List<AppNotification>> getAll() async {
    await _migrateLegacyIfNeeded();

    final snap = await _collection
        .orderBy('time', descending: true)
        .limit(_maxFetch)
        .get();

    if (snap.docs.isEmpty) {
      final welcome = AppNotification(
        id: 'welcome',
        kind: NotifKind.system,
        title: 'Welcome to EV Connect',
        message: 'Start a charging session to see live updates here.',
        time: DateTime.now(),
      );
      await _collection.doc(welcome.id).set(welcome.toJson());
      return [welcome];
    }

    return snap.docs.map((d) => AppNotification.fromJson(d.data())).toList();
  }

  Future<void> markAllRead() async {
    final snap = await _collection.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
