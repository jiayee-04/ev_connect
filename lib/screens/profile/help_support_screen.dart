import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Help and Support'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            RoundedActionButton(
              label: 'Hotline: 1-300-88-3823',
              icon: Icons.call_rounded,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            RoundedActionButton(
              label: 'Email Us',
              icon: Icons.email_rounded,
              onTap: () {},
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Frequently asked questions',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 10),
            _faqTile('How do I find a charging station?',
                'Go to the Charging Station tab, then use Map or List view and apply filters for connector type, distance or provider.'),
            _faqTile('How does payment work?',
                'After booking a slot you can pay with TnG eWallet or a credit/debit card. All payments in this app are simulated for demo purposes.'),
            _faqTile('Can I cancel a booking?',
                'Yes, cancelled sessions show up in your Charging History with a Cancelled status.'),
          ],
        ),
      ),
    );
  }

  Widget _faqTile(String q, String a) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedAlignment: Alignment.centerLeft,
      children: [
        Text(a, style: const TextStyle(color: AppColors.textMuted)),
      ],
    );
  }
}
