import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'services/locale_controller.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/station/station_list_screen.dart';
import 'screens/favourites/favourites_screen.dart';
import 'screens/history/charging_history_screen.dart';
import 'screens/vehicle/my_vehicle_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/route/route_planner_screen.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart';

void main() async { 
WidgetsFlutterBinding.ensureInitialized(); 
await Firebase.initializeApp( 
options: DefaultFirebaseOptions.currentPlatform, 
);
// Sets up the notification channel and requests the runtime permission
// (Android 13+ / iOS) up front, so real system notifications can fire
// the first time a charging session starts.
NotificationService.instance.init();
// Load the driver's saved dark-mode / language choice before the first
// frame, so the app opens already in the right mode instead of
// flashing light-mode/English first.
await ThemeController.instance.load();
await LocaleController.instance.load();
runApp(const EvConnectApp());
}
class EvConnectApp extends StatelessWidget {
  const EvConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleController.instance,
          builder: (context, locale, __) {
            return MaterialApp(
              title: 'EV Connect',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              locale: locale,
              supportedLocales: LocaleController.supported,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              initialRoute: '/splash',
              routes: {
                '/splash': (_) => const SplashScreen(),
                '/login': (_) => const LoginScreen(),
                '/signup': (_) => const SignupScreen(),
                '/forgot': (_) => const ForgotPasswordScreen(),
                '/home': (_) => const HomeScreen(),
                '/stations': (_) => const StationListScreen(),
                '/favourites': (_) => const FavouritesScreen(),
                '/history': (_) => const ChargingHistoryScreen(),
                '/vehicle': (_) => const MyVehicleScreen(),
                '/notifications': (_) => const NotificationsScreen(),
                '/profile': (_) => const ProfileScreen(),
                '/route': (_) => const RoutePlannerScreen(),
              },
            );
          },
        );
      },
    );
  }
}
