import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_footer.dart';
import '../../services/notification_service.dart';
import '../../models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationService.instance.getAll();
    if (mounted) setState(() => _items = items);
    await NotificationService.instance.markAllRead();
  }

  (IconData, Color) _visual(NotifKind kind) {
    switch (kind) {
      case NotifKind.chargingStarted:
        return (Icons.bolt_rounded, AppColors.primary);
      case NotifKind.chargingComplete:
        return (Icons.check_circle_rounded, AppColors.primary);
      case NotifKind.payment:
        return (Icons.receipt_long_rounded, AppColors.primaryDark);
      case NotifKind.favourite:
        return (Icons.favorite_rounded, AppColors.danger);
      case NotifKind.station:
        return (Icons.ev_station_rounded, AppColors.busy);
      case NotifKind.system:
        return (Icons.info_rounded, AppColors.textMuted);
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: const AppHeader(title: 'Notifications', showBack: false),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('No notifications yet.',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final n = items[i];
                        final (icon, color) = _visual(n.kind);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: color, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark)),
                                      const SizedBox(height: 4),
                                      Text(n.message,
                                          style: const TextStyle(color: AppColors.textMuted)),
                                      const SizedBox(height: 6),
                                      Text(_timeAgo(n.time),
                                          style: const TextStyle(
                                              color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: const AppFooter(currentIndex: 3),
    );
  }
}
