import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../services/location_service.dart';

class PickedLocation {
  final LatLng point;
  final String label;
  const PickedLocation({required this.point, required this.label});
}

/// Lets the driver drop a pin on a real map
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initial;

  const LocationPickerScreen({super.key, required this.title, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  late LatLng _picked = widget.initial ?? LocationService.fallback;
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.instance.getCurrentLatLng();
    if (!mounted) return;
    setState(() {
      _picked = pos;
      _locating = false;
    });
    _mapController.move(pos, 14);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: widget.title),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 13,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.evconnect.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 42,
                    height: 42,
                    child: const Icon(Icons.location_on_rounded,
                        size: 42, color: AppColors.primary),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: const Text(
                'Tap anywhere on the map to drop a pin',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 90,
            child: FloatingActionButton.small(
              heroTag: 'pickerMyLocation',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm This Location'),
              onPressed: () => Navigator.of(context).pop(_picked),
            ),
          ),
        ],
      ),
    );
  }
}
