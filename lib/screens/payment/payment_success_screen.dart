import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/station.dart';
import '../../models/charging_session.dart';
import '../../models/app_notification.dart';
import '../../services/app_state.dart';
import '../../services/notification_service.dart';
import '../../services/charging_session_manager.dart';

/// The real final step of the flow: payment for the ACTUAL amount used,
/// confirmed after charging - not an upfront estimate. This is where the
/// session is written to Charging History (once it's actually paid for,
/// which matches how a real receipt works) and where the "Payment
/// Successful" notification fires for real.
class PaymentSuccessScreen extends StatefulWidget {
  final ChargingStation station;
  final double amount;
  final double kwh;
  final int minutes;
  final String method;

  const PaymentSuccessScreen({
    super.key,
    required this.station,
    required this.amount,
    required this.kwh,
    required this.minutes,
    required this.method,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _saved = false;

  String get _reference {
    final rand = Random(widget.station.id.hashCode + widget.amount.round());
    return 'EVC${100000 + rand.nextInt(899999)}';
  }

  @override
  void initState() {
    super.initState();
    _finalize();
  }

  Future<void> _finalize() async {
    if (_saved) return;
    _saved = true;

    final session = ChargingSession(
      stationName: widget.station.name,
      location: widget.station.address,
      date: DateTime.now(),
      minutes: widget.minutes,
      kwh: widget.kwh,
      amount: widget.amount,
      status: SessionStatus.completed,
      paymentMethod: widget.method,
    );
    await AppState.instance.addHistoryEntry(session);

    await NotificationService.instance.notify(
      kind: NotifKind.payment,
      title: 'Payment Successful',
      message:
          'RM ${widget.amount.toStringAsFixed(2)} charged via ${widget.method} for ${widget.station.name}.',
    );

    // The session's numbers have now been paid for and recorded -
    // clear the shared manager so the next "start charging" begins clean.
    ChargingSessionManager.instance.reset();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 60),
              ),
              const SizedBox(height: 20),
              Text('Payment Successful',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text('Thanks for charging with EV Connect.',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 26),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _row('Station', widget.station.name),
                      const Divider(height: 24),
                      _row('Duration', '${widget.minutes} min'),
                      const Divider(height: 24),
                      _row('Energy delivered', '${widget.kwh.toStringAsFixed(1)} kWh'),
                      const Divider(height: 24),
                      _row('Payment method', widget.method),
                      const Divider(height: 24),
                      _row('Date', DateFormat('d MMM yyyy, h:mm a').format(now)),
                      const Divider(height: 24),
                      _row('Reference no.', _reference),
                      const Divider(height: 24),
                      _row('Amount paid', 'RM ${widget.amount.toStringAsFixed(2)}', emphasize: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Reset to Home first, then push History on top of it -
                  // otherwise History becomes the only route on the stack
                  // and its back button has nothing left to pop to.
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false);
                  Navigator.of(context).pushNamed('/history');
                },
                child: const Text('View Charging History'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: emphasize ? 18 : 14,
              color: emphasize ? AppColors.primaryDark : AppColors.textDark,
            )),
      ],
    );
  }
}
