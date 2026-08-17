import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/station.dart';
import '../../services/auth_service.dart';
import 'payment_success_screen.dart';

class TngPaymentScreen extends StatefulWidget {
  final ChargingStation station;
  final double amount;
  final double kwh;
  final int minutes;

  const TngPaymentScreen({
    super.key,
    required this.station,
    required this.amount,
    required this.kwh,
    required this.minutes,
  });

  @override
  State<TngPaymentScreen> createState() => _TngPaymentScreenState();
}

class _TngPaymentScreenState extends State<TngPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _processing = false;

  static final _phoneRegex = RegExp(r'^0\d{1,2}-?\d{7,8}$');

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    final user = await AuthService.instance.currentUser();
    if (user != null && mounted) {
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    // Simulated eWallet debit - no real TnG account is contacted.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          station: widget.station,
          amount: widget.amount,
          kwh: widget.kwh,
          minutes: widget.minutes,
          method: 'TnG eWallet',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'TnG eWallet'),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003DA5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Touch \u2018n Go eWallet',
                                style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Fast, secure, no fees',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 20),
                LabeledField(
                  label: 'Registered Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  hintText: '011-25978281',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    if (!_phoneRegex.hasMatch(v.trim())) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _processing ? null : _pay,
                  child: Text('Pay RM ${widget.amount.toStringAsFixed(2)}'),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'This is a simulated payment. No real eWallet is charged.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Confirming with TnG eWallet...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
