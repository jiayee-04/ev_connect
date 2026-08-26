import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common_widgets.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.instance.currentUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      appBar: const AppHeader(title: 'Profile', showBack: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProfileAvatar(photoPath: user?.photoPath, radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, ${user?.fullName ?? '...'}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '',
                          style: const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            RoundedActionButton(
              label: 'Edit Profile',
              icon: Icons.edit_rounded,
              onTap: () async {
                if (user == null) return;
                final updated = await Navigator.of(context).push<AppUser>(
                  MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
                );
                if (updated != null) setState(() => _user = updated);
              },
            ),
            const SizedBox(height: 14),
            RoundedActionButton(
              label: 'Settings',
              icon: Icons.settings_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 14),
            RoundedActionButton(
              label: 'Help and Support',
              icon: Icons.help_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
            ),
            const SizedBox(height: 14),
            RoundedActionButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              background: const Color(0xFFFFEBEE),
              foreground: AppColors.danger,
              onTap: _logout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(currentIndex: 4),
    );
  }
}
