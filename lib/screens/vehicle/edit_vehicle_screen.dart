import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/vehicle.dart';
import '../../services/app_state.dart';

class EditVehicleScreen extends StatefulWidget {
  /// The vehicle to edit, or null to add a brand-new one.
  final Vehicle? vehicle;
  const EditVehicleScreen({super.key, this.vehicle});

  bool get isNew => vehicle == null;

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.vehicle?.name ?? '');
  late final _batteryController = TextEditingController(
      text: widget.vehicle != null ? _extractNumber(widget.vehicle!.batteryCapacity) : '');
  late final _rangeController = TextEditingController(
      text: widget.vehicle != null ? widget.vehicle!.rangeKm.round().toString() : '480');
  late String _connector = widget.vehicle?.connector ?? _connectorOptions.first;
  late String _preferred = widget.vehicle?.preferredCharging ?? _chargingOptions.first;
  bool _saving = false;

  static const _connectorOptions = ['CCS2', 'Type 2', 'CHAdeMO'];
  static const _chargingOptions = ['DC Fast', 'AC Standard', 'Slow / Home'];

  static String _extractNumber(String capacity) {
    final match = RegExp(r'[\d.]+').firstMatch(capacity);
    return match?.group(0) ?? '';
  }

  String? _validateBattery(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter the battery capacity';
    final value = double.tryParse(v.trim());
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Must be greater than 0';
    if (value > 1000) return 'That looks too high - check the value';
    return null;
  }

  String? _validateRange(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter the rated range';
    final value = double.tryParse(v.trim());
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Must be greater than 0';
    if (value > 1500) return 'That looks too high - check the value';
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batteryController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = Vehicle(
      id: widget.vehicle?.id,
      name: _nameController.text.trim(),
      connector: _connector,
      batteryCapacity: '${_batteryController.text.trim()} kWh',
      preferredCharging: _preferred,
      rangeKm: double.tryParse(_rangeController.text.trim()) ?? 480,
    );
    await AppState.instance.saveVehicle(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: widget.isNew ? 'Add Vehicle' : 'Edit Vehicle'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LabeledField(
              label: 'Vehicle Name',
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a vehicle name' : null,
            ),
            const SizedBox(height: 18),
            _dropdownField('Connector', _connector, _connectorOptions,
                (v) => setState(() => _connector = v!)),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Battery Capacity',
              controller: _batteryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: 'kWh',
              hintText: 'e.g. 75 or 325',
              validator: _validateBattery,
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Rated Range (full charge)',
              controller: _rangeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: 'km',
              hintText: 'e.g. 480',
              validator: _validateRange,
            ),
            const SizedBox(height: 18),
            _dropdownField('Preferred Charging', _preferred, _chargingOptions,
                (v) => setState(() => _preferred = v!)),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(widget.isNew ? 'Add Vehicle' : 'Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField(
      String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryPale,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options
                  .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o,
                          style: const TextStyle(color: AppColors.textDark))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
