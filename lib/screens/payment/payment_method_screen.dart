import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../models/station.dart';
import 'card_payment_screen.dart';
import 'tng_payment_screen.dart';

enum PaymentMethod { tng, card }

class PaymentMethodScreen extends StatefulWidget {
  final ChargingStation station;
  final double amount;
  final double kwh;
  final int minutes;

  const PaymentMethodScreen({
    super.key,
    required this.station,
    required this.amount,
    required this.kwh,
    required this.minutes,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethod _selected = PaymentMethod.tng;

  void _continue() {
    if (_selected == PaymentMethod.tng) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TngPaymentScreen(
            station: widget.station,
            amount: widget.amount,
            kwh: widget.kwh,
            minutes: widget.minutes,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardPaymentScreen(
            station: widget.station,
            amount: widget.amount,
            kwh: widget.kwh,
            minutes: widget.minutes,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Payment Method'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount to pay', style: TextStyle(color: AppColors.textMuted)),
                  Text('RM ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primaryDark)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Select a payment method', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _methodTile(
              method: PaymentMethod.tng,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Touch \u2018n Go eWallet',
              subtitle: 'Pay instantly using your TnG eWallet balance',
            ),
            const SizedBox(height: 12),
            _methodTile(
              method: PaymentMethod.card,
              icon: Icons.credit_card_rounded,
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard and other major cards',
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _continue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selected == method;
    return Material(
      color: selected ? AppColors.primaryPale : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selected = method),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                child: Icon(icon, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Radio<PaymentMethod>(
                value: method,
                groupValue: _selected,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _selected = v!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
