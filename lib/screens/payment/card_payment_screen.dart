import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/station.dart';
import 'payment_success_screen.dart';

/// Formats raw digits as "1234 5678 9012 3456" while typing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Formats raw digits as "MM/YY" while typing.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    String formatted = limited;
    if (limited.length >= 3) {
      formatted = '${limited.substring(0, 2)}/${limited.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CardPaymentScreen extends StatefulWidget {
  final ChargingStation station;
  final double amount;
  final double kwh;
  final int minutes;

  const CardPaymentScreen({
    super.key,
    required this.station,
    required this.amount,
    required this.kwh,
    required this.minutes,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameController, _numberController, _expiryController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Cardholder name is required';
    if (!RegExp(r"^[a-zA-Z\s\.'-]{2,}$").hasMatch(v.trim())) {
      return 'Enter a valid name';
    }
    return null;
  }

  String? _validateNumber(String? v) {
    final digits = (v ?? '').replaceAll(' ', '');
    if (digits.isEmpty) return 'Card number is required';
    if (digits.length != 16) return 'Card number must be 16 digits';
    return null;
  }

  bool _passesLuhn(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  String? _validateExpiry(String? v) {
    if (v == null || !RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) {
      return 'Use MM/YY format';
    }
    final month = int.parse(v.substring(0, 2));
    final year = int.parse('20${v.substring(3, 5)}');
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    final expiry = DateTime(year, month + 1); // end of expiry month
    if (expiry.isBefore(now)) return 'Card has expired';
    return null;
  }

  String? _validateCvv(String? v) {
    if (v == null || !RegExp(r'^\d{3}$').hasMatch(v)) {
      return 'CVV must be 3 digits';
    }
    return null;
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    // Simulated payment processing - no real card network is contacted.
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
          method: 'Credit / Debit Card',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Card Payment'),
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
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sim_card_rounded, color: Colors.white70, size: 30),
                      const SizedBox(height: 24),
                      Text(
                        _numberController.text.isEmpty
                            ? '\u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022'
                            : _numberController.text,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, letterSpacing: 2),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _nameController.text.isEmpty
                                ? 'CARD HOLDER'
                                : _nameController.text.toUpperCase(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LabeledField(
                  label: 'Cardholder Name',
                  controller: _nameController,
                  validator: _validateName,
                  hintText: 'e.g. Ahmad Bin Ali',
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Card Number',
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  validator: _validateNumber,
                  inputFormatters: [_CardNumberFormatter()],
                  hintText: '1234 5678 9012 3456',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Expiry Date',
                        controller: _expiryController,
                        keyboardType: TextInputType.number,
                        validator: _validateExpiry,
                        inputFormatters: [_ExpiryFormatter()],
                        hintText: 'MM/YY',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: LabeledField(
                        label: 'CVV',
                        controller: _cvvController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: _validateCvv,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        hintText: '123',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _processing ? null : _pay,
                  child: Text('Pay RM ${widget.amount.toStringAsFixed(2)}'),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'This is a simulated payment. No real card is charged.',
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
                        Text('Processing payment...'),
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
