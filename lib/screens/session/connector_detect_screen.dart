import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/station.dart';
import '../../services/charging_session_manager.dart';
import 'charging_session_screen.dart';

/// Shown right after the user taps "Start Charging" and before the live
/// session screen begins - simulates plugging the connector into the
/// vehicle and detecting it. There's no real hardware to talk to here,
/// so this always "succeeds" after a short delay purely for pacing and
/// feel. If a real connector-detect call (BLE/OCPP/etc.) is added later,
/// swap the body of [_run] for that instead of the fixed delays below.
class ConnectorDetectScreen extends StatefulWidget {
  final ChargingStation station;
  final double batteryCapacityKwh;
  final double startBatteryPct;
  final double targetBatteryPct;

  const ConnectorDetectScreen({
    super.key,
    required this.station,
    required this.batteryCapacityKwh,
    required this.startBatteryPct,
    required this.targetBatteryPct,
  });

  @override
  State<ConnectorDetectScreen> createState() => _ConnectorDetectScreenState();
}

class _ConnectorDetectScreenState extends State<ConnectorDetectScreen> {
  // Tune these to speed up/slow down the simulated detection. Kept well
  // above 0ms on purpose - an instant flash wouldn't read as "detecting"
  // to the user even though nothing real is being checked.
  static const _connectingDuration = Duration(milliseconds: 1600);
  static const _connectedHoldDuration = Duration(milliseconds: 900);

  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(_connectingDuration);
    if (!mounted) return;
    setState(() => _connected = true);

    await Future.delayed(_connectedHoldDuration);
    if (!mounted) return;

    ChargingSessionManager.instance.start(
      station: widget.station,
      batteryCapacityKwh: widget.batteryCapacityKwh,
      startBatteryPct: widget.startBatteryPct,
      targetBatteryPct: widget.targetBatteryPct,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChargingSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _connected
                      ? Container(
                          key: const ValueKey('done'),
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8BE28B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 56),
                        )
                      : SizedBox(
                          key: const ValueKey('connecting'),
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: const [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                              Icon(Icons.ev_station_rounded,
                                  color: Colors.white, size: 40),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                Text(
                  _connected ? 'Connector detected' : 'Connecting to your vehicle...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _connected
                      ? 'Starting your charging session'
                      : 'Plug in the connector at ${widget.station.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
