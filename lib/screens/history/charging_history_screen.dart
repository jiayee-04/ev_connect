import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../services/app_state.dart';
import '../../models/charging_session.dart';
import '../payment/booking_confirm_screen.dart';

class ChargingHistoryScreen extends StatefulWidget {
  const ChargingHistoryScreen({super.key});

  @override
  State<ChargingHistoryScreen> createState() => _ChargingHistoryScreenState();
}

class _ChargingHistoryScreenState extends State<ChargingHistoryScreen> {
  List<ChargingSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await AppState.instance.getHistory();
    if (mounted) setState(() => _sessions = sessions);
  }

  void _rebook(BuildContext context, ChargingSession session) {
    final station = session.station;
    if (station == null) {
      // Sessions saved before station snapshots were added to history
      // won't have one on hand - nothing to rebook against.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Station details for this session are no longer available.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingConfirmScreen(station: station)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    if (sessions == null) {
      return const Scaffold(
        appBar: AppHeader(title: 'Charging History'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final monthTotal = sessions
        .where((s) => s.status == SessionStatus.completed)
        .fold<double>(0, (sum, s) => sum + s.kwh);
    final spentTotal = sessions
        .where((s) => s.status == SessionStatus.completed)
        .fold<double>(0, (sum, s) => sum + s.amount);

    return Scaffold(
      appBar: const AppHeader(title: 'Charging History'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'This month',
                    value: '${monthTotal.toStringAsFixed(1)} kWh',
                    background: AppColors.primaryPale,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total spent',
                    value: 'RM ${spentTotal.toStringAsFixed(2)}',
                    background: const Color(0xFFFFF3E0),
                    valueColor: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: Text('No charging sessions yet.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            ...sessions.map((s) => _SessionTile(
                  session: s,
                  onRebook: () => _rebook(context, s),
                )),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.background,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.primary)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChargingSession session;
  final VoidCallback onRebook;
  const _SessionTile({required this.session, required this.onRebook});

  Color get _statusColor {
    switch (session.status) {
      case SessionStatus.completed:
        return AppColors.primary;
      case SessionStatus.cancelled:
        return AppColors.danger;
      case SessionStatus.inProgress:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (session.status) {
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
      case SessionStatus.inProgress:
        return 'In Progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM, h:mm a').format(session.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(session.stationName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              session.status == SessionStatus.cancelled
                  ? '$dateLabel \u2022 session not started'
                  : '$dateLabel \u2022 ${session.minutes} min \u2022 ${session.kwh} kWh',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (session.status == SessionStatus.completed) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RM ${session.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark)),
                  TextButton.icon(
                    onPressed: onRebook,
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Rebook'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
