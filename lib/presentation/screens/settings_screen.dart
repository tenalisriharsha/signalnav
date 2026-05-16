/// SignalNav - Settings Screen
///
/// Contains:
/// - Passenger mode toggle
/// - Privacy settings (GDPR/CCPA export/delete)
/// - About / legal
/// - Logout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../providers/app_providers.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengerMode = ref.watch(passengerModeProvider);
    final safety = ref.watch(safetyValidatorProvider);
    final firebase = ref.watch(firebaseServiceProvider);
    final user = firebase.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Mode Section
          _buildSectionHeader(context, 'Driving Mode'),
          SwitchListTile(
            title: const Text(
              'Passenger Mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Unlocks all UI controls regardless of speed. '
              'Must be explicitly enabled.',
              style: TextStyle(color: Colors.white54),
            ),
            value: passengerMode,
            onChanged: (v) {
              ref.read(passengerModeProvider.notifier).state = v;
              safety.setPassengerMode(v);
            },
            activeColor: Colors.green,
          ),
          const Divider(color: Colors.white24),

          // Privacy Section
          _buildSectionHeader(context, 'Privacy & Data'),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text(
              'Export My Data',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Download all your data (GDPR/CCPA)',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete My Account & Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Permanently remove your account and anonymize reports',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          const Divider(color: Colors.white24),

          // Legal Section
          _buildSectionHeader(context, 'Legal'),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.white),
            title: const Text(
              'Terms of Service',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _showLegalDocument(context, 'Terms of Service',
                'assets/terms_of_service.md'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.white),
            title: const Text(
              'Privacy Policy',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _showLegalDocument(
                context, 'Privacy Policy', 'assets/privacy_policy.md'),
          ),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.white),
            title: const Text(
              'Safety Notice',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _showLegalDocument(
                context, 'Safety Notice', 'assets/safety_notice.md'),
          ),
          const Divider(color: Colors.white24),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: Text(
                'Signed in as: ${user.isAnonymous ? 'Anonymous' : user.email ?? user.uid.substring(0, 8)}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _signOut(context, ref),
          ),
          const Divider(color: Colors.white24),

          // About
          _buildSectionHeader(context, 'About'),
          ListTile(
            title: Text(
              kAppDisplayName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Version 0.1.0\n$kDisclaimerExperimental',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Colors.grey,
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Preparing data export...'),
          ],
        ),
      ),
    );

    try {
      final data = await ref.read(firebaseServiceProvider).exportUserData();
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'Data Export',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Text(
                data.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This will permanently delete your account and anonymize all your '
          'historical signal reports. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(firebaseServiceProvider).deleteAccount();
                if (context.mounted) {
                  // Reset onboarding to force re-auth
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_complete', false);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deletion failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLegalDocument(
    BuildContext context,
    String title,
    String assetPath,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: FutureBuilder(
          future: DefaultAssetBundle.of(context).loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return SingleChildScrollView(
                child: Text(
                  snapshot.data!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(firebaseServiceProvider).signOut();
      if (context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      logError(LogCategory.lifecycle, 'Sign out failed: $e');
    }
  }
}
