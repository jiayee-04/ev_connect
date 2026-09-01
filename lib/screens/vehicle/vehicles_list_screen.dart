import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../models/vehicle.dart';
import '../../services/app_state.dart';
import 'edit_vehicle_screen.dart';

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  List<Vehicle>? _vehicles;
  String? _activeId;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles = await AppState.instance.getVehicles();
    final active = await AppState.instance.getVehicle();
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _activeId = active.id;
    });
  }

  Future<void> _setActive(Vehicle v) async {
    if (v.id == _activeId) return;
    await AppState.instance.setActiveVehicle(v.id);
    _changed = true;
    setState(() => _activeId = v.id);
  }

  Future<void> _addOrEdit([Vehicle? vehicle]) async {
    final result = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => EditVehicleScreen(vehicle: vehicle)),
    );
    if (result != null) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _delete(Vehicle v) async {
    final vehicles = _vehicles;
    if (vehicles == null) return;
    if (vehicles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one saved vehicle.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('This removes "${v.name}" from your saved vehicles.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppState.instance.deleteVehicle(v.id);
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: const AppHeader(title: 'My Vehicles'),
        body: vehicles == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ...vehicles.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VehicleCard(
                          vehicle: v,
                          isActive: v.id == _activeId,
                          onTap: () => _setActive(v),
                          onEdit: () => _addOrEdit(v),
                          onDelete: () => _delete(v),
                        ),
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addOrEdit(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Vehicle'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehicle,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primaryPale : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.mint.withOpacity(0.3),
                child: const Icon(Icons.electric_car_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(vehicle.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Active',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.connector} \u2022 ${vehicle.batteryCapacity} \u2022 ${vehicle.rangeKm.round()} km range',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
