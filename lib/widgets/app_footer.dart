import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom navigation used across every main screen:
/// Home, Charging Station, My Vehicle, Notifications, Profile.
class AppFooter extends StatelessWidget {
  final int currentIndex;

  const AppFooter({super.key, required this.currentIndex});

  static const _routes = [
    '/home',
    '/stations',
    '/vehicle',
    '/notifications',
    '/profile',
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      _routes[index],
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) => _onTap(context, i),
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.mint,
      selectedItemColor: AppColors.primaryDark,
      unselectedItemColor: const Color(0xFF4E6B4F),
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.ev_station_rounded), label: 'Stations'),
        BottomNavigationBarItem(icon: Icon(Icons.directions_car_rounded), label: 'Vehicle'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Notifications'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}
