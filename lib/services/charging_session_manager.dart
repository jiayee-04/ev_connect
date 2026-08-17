import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/station.dart';
import '../models/app_notification.dart';
import 'notification_service.dart';

/// Runs the live charging simulation independent of any screen's widget
/// tree - this is what makes "leave the charging screen and keep
/// charging in the background" actually work. Any screen can watch it
/// with `AnimatedBuilder(animation: ChargingSessionManager.instance, ...)`
/// since it's a ChangeNotifier (a Listenable), and it keeps ticking
/// regardless of which screen is currently on top.
///
/// Real-world model: post-paid, the way charging actually works. You
/// start charging, it tracks live energy/cost as it goes, and payment
/// only happens after you stop - not before.
class ChargingSessionManager extends ChangeNotifier {
  ChargingSessionManager._();
  static final ChargingSessionManager instance = ChargingSessionManager._();

  Timer? _ticker;
  ChargingStation? station;
  double batteryCapacityKwh = 75;
  double batteryPct = 30;
  double targetBatteryPct = 80;
  double kwhDelivered = 0;
  Duration elapsed = Duration.zero;
  bool isActive = false;
  bool targetReached = false;

  // 1 simulated minute per real second - a session completes in a
  // demo-friendly amount of time instead of literally taking 40+ minutes.
  static const _tickEvery = Duration(seconds: 1);
  static const _simulatedMinutesPerTick = 1;

  double get costSoFar => station == null ? 0 : kwhDelivered * station!.pricePerKwh;

  void start({
    required ChargingStation station,
    required double batteryCapacityKwh,
    double startBatteryPct = 32,
    double targetBatteryPct = 80,
  }) {
    _ticker?.cancel();
    this.station = station;
    this.batteryCapacityKwh = batteryCapacityKwh;
    this.batteryPct = startBatteryPct;
    this.targetBatteryPct = targetBatteryPct;
    kwhDelivered = 0;
    elapsed = Duration.zero;
    isActive = true;
    targetReached = false;
    notifyListeners();

    NotificationService.instance.notify(
      kind: NotifKind.chargingStarted,
      title: 'Charging Started',
      message: 'Your session at ${station.name} has begun.',
    );

    _ticker = Timer.periodic(_tickEvery, (_) => _tick());
  }

  /// Real DC fast chargers deliver near-max power up to ~80%, then taper
  /// sharply to protect the battery.
  double _currentPowerKw() {
    final maxPower = station?.maxPowerKw ?? 0;
    final power = maxPower > 0 ? maxPower : 22;
    if (batteryPct < 80) return power.toDouble();
    if (batteryPct < 90) return power * 0.5;
    return power * 0.22;
  }

  double get currentPowerKw => _currentPowerKw();

  void _tick() {
    if (!isActive) return;
    final powerKw = _currentPowerKw();
    final kwhThisTick = powerKw * (_simulatedMinutesPerTick / 60);
    kwhDelivered += kwhThisTick;
    batteryPct = (batteryPct + (kwhThisTick / batteryCapacityKwh) * 100).clamp(0, 100);
    elapsed += const Duration(minutes: _simulatedMinutesPerTick);

    if (batteryPct >= targetBatteryPct && !targetReached) {
      targetReached = true;
      _ticker?.cancel();
      NotificationService.instance.notify(
        kind: NotifKind.chargingComplete,
        title: 'Target Charge Reached',
        message:
            '${station?.name ?? 'Your station'} \u2014 ${kwhDelivered.toStringAsFixed(1)} kWh delivered. Stop the session to pay.',
      );
    }
    notifyListeners();
  }

  /// Stops the session (if still running) and returns the final result.
  /// Does NOT clear the session's data - screens navigated to right after
  /// stopping (like the payment flow) still need to read the final
  /// numbers, so [reset] is called explicitly once payment is done.
  ({ChargingStation station, double kwh, double cost, int minutes}) stop() {
    _ticker?.cancel();
    final wasActive = isActive;
    isActive = false;
    notifyListeners();

    if (wasActive) {
      NotificationService.instance.notify(
        kind: NotifKind.chargingComplete,
        title: 'Charging Stopped',
        message:
            '${station?.name ?? 'Your station'} \u2014 ${kwhDelivered.toStringAsFixed(1)} kWh, RM ${costSoFar.toStringAsFixed(2)}.',
      );
    }

    return (
      station: station!,
      kwh: double.parse(kwhDelivered.toStringAsFixed(1)),
      cost: double.parse(costSoFar.toStringAsFixed(2)),
      minutes: elapsed.inMinutes,
    );
  }

  void reset() {
    _ticker?.cancel();
    station = null;
    isActive = false;
    kwhDelivered = 0;
    elapsed = Duration.zero;
    targetReached = false;
    notifyListeners();
  }
}
