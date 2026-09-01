import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SlotState { available, occupied, offline }

class ChargingSlot {
  final int index; // 1-based, for display ("Slot 1", "Slot 2"...)
  final SlotState state;
  final String? connectorType; // e.g. "CCS2" — null if unknown

  const ChargingSlot({
    required this.index,
    required this.state,
    this.connectorType,
  });

  String get label {
    switch (state) {
      case SlotState.available:
        return 'Available';
      case SlotState.occupied:
        return 'In use';
      case SlotState.offline:
        return 'Offline';
    }
  }

  Color get color {
    switch (state) {
      case SlotState.available:
        return AppColors.success;
      case SlotState.occupied:
        return AppColors.warning;
      case SlotState.offline:
        return AppColors.textMuted;
    }
  }

  IconData get icon {
    switch (state) {
      case SlotState.available:
        return Icons.bolt_rounded;
      case SlotState.occupied:
        return Icons.ev_station_rounded;
      case SlotState.offline:
        return Icons.power_off_rounded;
    }
  }
}
