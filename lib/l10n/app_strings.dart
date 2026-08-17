import '../services/locale_controller.dart';

/// Small hand-rolled translation lookup (not full ARB/gen-l10n codegen,
/// which needs the Flutter toolchain to run) covering the app's highest
/// traffic surfaces: bottom navigation, main screen headers, Settings,
/// and Home's quick actions. See IMPROVEMENTS.md for what's covered vs.
/// what would need a follow-up pass to translate the rest of the app.
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'nav_home': 'Home',
      'nav_stations': 'Stations',
      'nav_vehicle': 'Vehicle',
      'nav_alerts': 'Alerts',
      'nav_profile': 'Profile',
      'home_title': 'My vehicle',
      'quick_charging_station': 'Charging\nStation',
      'quick_favourites': 'Favourites',
      'quick_charging_history': 'Charging\nHistory',
      'quick_my_route': 'My\nRoute',
      'nearby_stations': 'Nearby Stations',
      'see_all': 'See all',
      'settings_title': 'Settings',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'notifications': 'Notifications',
      'about': 'About',
      'language_changed': 'Language changed to English',
      'dark_mode_on': 'Dark mode turned on',
      'dark_mode_off': 'Dark mode turned off',
    },
    'ms': {
      'nav_home': 'Utama',
      'nav_stations': 'Stesen',
      'nav_vehicle': 'Kenderaan',
      'nav_alerts': 'Makluman',
      'nav_profile': 'Profil',
      'home_title': 'Kenderaan saya',
      'quick_charging_station': 'Stesen\nCas',
      'quick_favourites': 'Kegemaran',
      'quick_charging_history': 'Sejarah\nCas',
      'quick_my_route': 'Laluan\nSaya',
      'nearby_stations': 'Stesen Berhampiran',
      'see_all': 'Lihat semua',
      'settings_title': 'Tetapan',
      'dark_mode': 'Mod Gelap',
      'language': 'Bahasa',
      'notifications': 'Pemberitahuan',
      'about': 'Tentang',
      'language_changed': 'Bahasa ditukar kepada Bahasa Malaysia',
      'dark_mode_on': 'Mod gelap dihidupkan',
      'dark_mode_off': 'Mod gelap dimatikan',
    },
    'zh': {
      'nav_home': '首页',
      'nav_stations': '充电站',
      'nav_vehicle': '车辆',
      'nav_alerts': '通知',
      'nav_profile': '我的',
      'home_title': '我的车辆',
      'quick_charging_station': '充电站',
      'quick_favourites': '收藏',
      'quick_charging_history': '充电记录',
      'quick_my_route': '路线规划',
      'nearby_stations': '附近充电站',
      'see_all': '查看全部',
      'settings_title': '设置',
      'dark_mode': '深色模式',
      'language': '语言',
      'notifications': '通知',
      'about': '关于',
      'language_changed': '语言已切换为中文',
      'dark_mode_on': '深色模式已开启',
      'dark_mode_off': '深色模式已关闭',
    },
  };

  /// Looks up [key] in the current locale (from [LocaleController]),
  /// falling back to English, then to the raw key if truly missing.
  static String t(String key) {
    final code = LocaleController.instance.value.languageCode;
    return _values[code]?[key] ?? _values['en']?[key] ?? key;
  }

  static const languageNames = {
    'en': 'English',
    'ms': 'Bahasa Malaysia',
    'zh': '中文',
  };
}
