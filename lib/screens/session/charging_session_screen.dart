import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/charging_session_manager.dart';
import 'session_summary_screen.dart';

/// Live charging session — watches [ChargingSessionManager], the shared,
/// screen-independent ticker. Leaving this screen (via the minimize
/// button or the device back gesture) does NOT stop charging - the
/// manager keeps running, and Home shows a live "Charging in progress"
/// banner the driver can tap to come back here at any time.
class ChargingSessionScreen extends StatefulWidget {
  const ChargingSessionScreen({super.key});

  @override
  State<ChargingSessionScreen> createState() => _ChargingSessionScreenState();
}

class _ChargingSessionScreenState extends State<ChargingSessionScreen> {
  final _manager = ChargingSessionManager.instance;

  void _minimize() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  Future<void> _confirmStop() async {
    if (_manager.targetReached) {
      _goToSummary();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop charging?'),
        content: Text(
          'You\'re at ${_manager.batteryPct.round()}%. Stopping now ends the session \u2014 you\'ll pay for ${_manager.kwhDelivered.toStringAsFixed(1)} kWh (RM ${_manager.costSoFar.toStringAsFixed(2)}) used so far.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep charging')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (confirmed == true) _goToSummary();
  }

  void _goToSummary() {
    final result = _manager.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          station: result.station,
          kwh: result.kwh,
          cost: result.cost,
          minutes: result.minutes,
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final station = _manager.station;
        if (station == null || !_manager.isActive) {
          // Nothing active (e.g. deep-linked here with no session) -
          // just bounce back rather than showing a broken screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(
            backgroundColor: AppColors.primaryDark,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final finished = _manager.targetReached;
        return Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 30),
                        tooltip: 'Run in background',
                        onPressed: _minimize,
                      ),
                      Expanded(
                        child: Text(
                          station.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Text(
                    'Tap the arrow to keep browsing the app \u2014 charging keeps going.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: _manager.batteryPct / 100,
                            strokeWidth: 14,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                              finished ? const Color(0xFF8BE28B) : Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_manager.batteryPct.round()}%',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                            Text(
                              finished
                                  ? 'Target reached'
                                  : '${_manager.currentPowerKw.round()} kW \u2022 charging',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: 'Time', value: _formatElapsed(_manager.elapsed)),
                      _Stat(label: 'Energy', value: '${_manager.kwhDelivered.toStringAsFixed(1)} kWh'),
                      _Stat(label: 'Cost so far', value: 'RM ${_manager.costSoFar.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!finished)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Charging tapers after 80% to protect battery health \u2014 the last stretch is slower by design.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: finished ? Colors.white : const Color(0xFFD84315),
                        foregroundColor: finished ? AppColors.primaryDark : Colors.white,
                      ),
                      onPressed: _confirmStop,
                      child: Text(finished ? 'Review & Pay' : 'Stop Charging'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
