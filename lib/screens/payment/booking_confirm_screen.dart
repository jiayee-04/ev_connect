import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../services/app_state.dart';
import '../../services/charging_session_manager.dart';
import '../session/charging_session_screen.dart';
import '../session/connector_detect_screen.dart';

class BookingConfirmScreen extends StatefulWidget {
  final ChargingStation station;
  const BookingConfirmScreen({super.key, required this.station});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  double _startPct = 30;
  double _targetPct = 80;
  Vehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    final v = await AppState.instance.getVehicle();
    if (mounted) setState(() => _vehicle = v);
  }

  void _startCharging() {
    final vehicle = _vehicle;
    if (vehicle == null) return;

    if (ChargingSessionManager.instance.isActive) {
      final activeStation = ChargingSessionManager.instance.station?.name ?? 'another station';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Charging already in progress'),
          content: Text(
              'You already have an active session at $activeStation. Stop and pay for that session before starting a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ChargingSessionScreen()),
                );
              },
              child: const Text('Go to Active Session'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConnectorDetectScreen(
          station: widget.station,
          batteryCapacityKwh: vehicle.batteryCapacityKwh,
          startBatteryPct: _startPct,
          targetBatteryPct: _targetPct,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final vehicle = _vehicle;
    return Scaffold(
      appBar: const AppHeader(title: 'Start Charging'),
      body: vehicle == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(s.address, style: const TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 10),
                          Text(
                              'RM ${s.pricePerKwh.toStringAsFixed(2)} / kWh \u2022 ${s.speed} charging \u2022 up to ${s.maxPowerKw.round()} kW',
                              style: const TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Current battery: ${_startPct.round()}%',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Roughly where your battery is right now',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Slider(
                    value: _startPct,
                    min: 5,
                    max: 95,
                    divisions: 18,
                    label: '${_startPct.round()}%',
                    onChanged: (v) => setState(() {
                      _startPct = v;
                      if (_targetPct <= _startPct) _targetPct = (_startPct + 10).clamp(10, 100);
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text('Charge to: ${_targetPct.round()}%',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('You can always stop earlier \u2014 you only pay for what you use',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Slider(
                    value: _targetPct,
                    min: (_startPct + 5).clamp(10, 100),
                    max: 100,
                    divisions: 18,
                    label: '${_targetPct.round()}%',
                    onChanged: (v) => setState(() => _targetPct = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payment happens after you stop, based on the actual energy delivered \u2014 not an upfront estimate.',
                            style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Start Charging'),
                    onPressed: _startCharging,
                  ),
                ],
              ),
            ),
    );
  }
}
