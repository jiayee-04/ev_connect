import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/station.dart';
import '../payment/payment_method_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final ChargingStation station;
  final double kwh;
  final double cost;
  final int minutes;

  const SessionSummaryScreen({
    super.key,
    required this.station,
    required this.kwh,
    required this.cost,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final noEnergyUsed = kwh <= 0;
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
                child: const Icon(Icons.ev_station_rounded, color: AppColors.primary, size: 52),
              ),
              const SizedBox(height: 20),
              Text(noEnergyUsed ? 'Session Ended' : 'Charging Complete',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text(
                'Here\'s what was delivered this session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 26),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _row('Station', station.name),
                      const Divider(height: 24),
                      _row('Duration', '$minutes min'),
                      const Divider(height: 24),
                      _row('Energy delivered', '${kwh.toStringAsFixed(1)} kWh'),
                      const Divider(height: 24),
                      _row('Rate', 'RM ${station.pricePerKwh.toStringAsFixed(2)}/kWh'),
                      const Divider(height: 24),
                      _row('Amount due', 'RM ${cost.toStringAsFixed(2)}', emphasize: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (noEnergyUsed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/home', (r) => false),
                    child: const Text('Done'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment_rounded),
                    label: Text('Pay RM ${cost.toStringAsFixed(2)}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentMethodScreen(
                          station: station,
                          amount: cost,
                          kwh: kwh,
                          minutes: minutes,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: emphasize ? 18 : 14,
              color: emphasize ? AppColors.primaryDark : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
