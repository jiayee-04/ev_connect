import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common_widgets.dart';
import '../../models/vehicle.dart';
import '../../services/app_state.dart';
import 'edit_vehicle_screen.dart';
import 'vehicles_list_screen.dart';
import '../history/charging_history_screen.dart';

class MyVehicleScreen extends StatefulWidget {
  const MyVehicleScreen({super.key});

  @override
  State<MyVehicleScreen> createState() => _MyVehicleScreenState();
}

class _MyVehicleScreenState extends State<MyVehicleScreen> {
  Vehicle? _vehicle;
  int _vehicleCount = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await AppState.instance.getVehicle();
    final all = await AppState.instance.getVehicles();
    if (mounted) {
      setState(() {
        _vehicle = v;
        _vehicleCount = all.length;
      });
    }
  }

  Future<void> _openVehicleList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VehiclesListScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    return Scaffold(
      appBar: const AppHeader(title: 'My Vehicle', showBack: false),
      body: vehicle == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openVehicleList,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryPale,
                              border: Border.all(color: AppColors.mint, width: 6),
                            ),
                            child: const Icon(Icons.electric_car_rounded,
                                size: 62, color: AppColors.primary),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(vehicle.name, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(width: 4),
                              const Icon(Icons.unfold_more_rounded,
                                  size: 20, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${vehicle.connector} \u2022 ${vehicle.batteryCapacity} \u2022 ${vehicle.rangeKm.round()} km range',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted)),
                          if (_vehicleCount > 1) ...[
                            const SizedBox(height: 6),
                            Text('$_vehicleCount vehicles saved \u2022 tap to switch',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ] else ...[
                            const SizedBox(height: 6),
                            const Text('Tap to manage or add a vehicle',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  RoundedActionButton(
                    label: 'Edit Vehicle',
                    icon: Icons.edit_rounded,
                    onTap: () async {
                      final updated = await Navigator.of(context).push<Vehicle>(
                        MaterialPageRoute(
                          builder: (_) => EditVehicleScreen(vehicle: vehicle),
                        ),
                      );
                      if (updated != null) setState(() => _vehicle = updated);
                    },
                  ),
                  const SizedBox(height: 14),
                  RoundedActionButton(
                    label: 'Plan a Route',
                    icon: Icons.alt_route_rounded,
                    onTap: () => Navigator.of(context).pushNamed('/route'),
                  ),
                  const SizedBox(height: 14),
                  RoundedActionButton(
                    label: 'Charging History',
                    icon: Icons.history_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChargingHistoryScreen()),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const AppFooter(currentIndex: 2),
    );
  }
}
