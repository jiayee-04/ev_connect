import '../services/locale_controller.dart';


class AppStrings {
  AppStrings._();

  static const Map<String, String> _values = {
    'nav_home': 'Home',
    'nav_stations': 'Stations',
    'nav_vehicle': 'Vehicle',
    'nav_alerts': 'Alerts',
    'nav_profile': 'Profile',
    'home_title': 'Home',
    'quick_charging_station': 'Charging\nStation',
    'quick_favourites': 'Favourites',
    'quick_charging_history': 'Charging\nHistory',
    'quick_my_route': 'My\nRoute',
    'nearby_stations': 'Nearby Stations',
    'see_all': 'See all',
    'settings_title': 'Settings',
    'dark_mode': 'Dark Mode',
    'notifications': 'Notifications',
    'about': 'About',
    'dark_mode_on': 'Dark mode turned on',
    'dark_mode_off': 'Dark mode turned off',
  };

  static String t(String key) => _values[key] ?? key;
}
