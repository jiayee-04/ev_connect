import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../services/theme_controller.dart';
import '../../services/locale_controller.dart';
import '../../l10n/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  Future<void> _toggleDarkMode(bool value) async {
    await ThemeController.instance.setDark(value);
    if (!mounted) return;
    setState(() {}); // re-read ThemeController.instance.isDark for the switch
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? AppStrings.t('dark_mode_on')
            : AppStrings.t('dark_mode_off')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeLanguage(String code) async {
    await LocaleController.instance.setLocale(code);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.t('language_changed')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = LocaleController.instance.value.languageCode;
    return Scaffold(
      appBar: AppHeader(title: AppStrings.t('settings_title')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _settingsTile(
            icon: Icons.dark_mode_rounded,
            title: AppStrings.t('dark_mode'),
            trailing: Switch(
              value: ThemeController.instance.isDark,
              activeColor: AppColors.primary,
              onChanged: _toggleDarkMode,
            ),
          ),
          const SizedBox(height: 12),
          _settingsTile(
            icon: Icons.notifications_rounded,
            title: AppStrings.t('notifications'),
            trailing: Switch(
              value: _notifications,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ),
          const SizedBox(height: 12),
          _settingsTile(
            icon: Icons.language_rounded,
            title: AppStrings.t('language'),
            trailing: DropdownButton<String>(
              value: currentCode,
              underline: const SizedBox(),
              items: AppStrings.languageNames.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          style: const TextStyle(color: AppColors.textDark))))
                  .toList(),
              onChanged: (v) {
                if (v != null) _changeLanguage(v);
              },
            ),
          ),
          const SizedBox(height: 12),
          _settingsTile(
            icon: Icons.info_outline_rounded,
            title: AppStrings.t('about'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDark),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'EV Connect',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Powering Every Journey.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.primaryPale,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textDark)),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
