/// SignalNav - Onboarding Screen
///
/// Mandatory full-screen onboarding with:
/// - Terms of Service agreement
/// - Liability waiver
/// - Illinois distracted driving law notice
/// - Permission requests (location, microphone)
/// - Privacy policy acknowledgment

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../data/services/location_service.dart';
import '../providers/app_providers.dart';
import 'map_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _tosAccepted = false;
  bool _liabilityAccepted = false;
  bool _lawNoticeAcknowledged = false;
  bool _privacyAcknowledged = false;
  bool _locationPermissionGranted = false;
  bool _microphonePermissionGranted = false;

  bool get _canProceed =>
      _tosAccepted &&
      _liabilityAccepted &&
      _lawNoticeAcknowledged &&
      _privacyAcknowledged;

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_canProceed) return;

    try {
      // Request location permissions
      final locationService = ref.read(locationServiceProvider);
      await locationService.checkPermissions();
      await locationService.requestBackgroundPermission();

      // Save onboarding completion
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } catch (e) {
      logWarning(LogCategory.lifecycle, 'Permission request failed: $e');
      // Still allow proceeding; permissions can be requested later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(),
                  _buildTermsPage(),
                  _buildSafetyPage(),
                  _buildPrivacyPage(),
                  _buildPermissionsPage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.traffic, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Welcome to $kAppDisplayName',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            kAppSubtitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white70,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade700),
            ),
            child: Text(
              kDisclaimerExperimental,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red.shade200,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms of Service',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You must accept these terms to use SignalNav.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Markdown(
                data: '''# Terms of Service

## 1. Acceptance of Terms
By using SignalNav, you agree to these Terms of Service.

## 2. Experimental Service
SignalNav is an experimental community-driven assistant. Predictions are estimates, not official traffic data.

## 3. Safety First
- Never interact with the app while driving
- Always follow traffic laws and signals
- Voice commands and passenger assistance only while vehicle is in motion

## 4. Liability
SignalNav and its creators are not liable for any traffic violations, accidents, or damages resulting from use of this app.

## 5. Changes
We may update these terms at any time. Continued use constitutes acceptance.

// TODO: Replace with lawyer-approved ToS before v1.0 release
''',
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(color: Colors.white, fontSize: 20),
                  h2: TextStyle(color: Colors.white, fontSize: 18),
                  p: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _tosAccepted,
            onChanged: (v) => setState(() => _tosAccepted = v ?? false),
            title: const Text(
              'I have read and agree to the Terms of Service',
              style: TextStyle(color: Colors.white),
            ),
            activeColor: Colors.green,
          ),
          CheckboxListTile(
            value: _liabilityAccepted,
            onChanged: (v) => setState(() => _liabilityAccepted = v ?? false),
            title: Text(
              kDisclaimerLiability,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety & Legal Notice',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.speed,
            title: 'Speed-Locked UI',
            description:
                'All manual buttons are disabled when your speed exceeds 5 mph. Only voice commands and Bluetooth triggers work while driving.',
          ),
          const SizedBox(height: 12),
          _buildSafetyCard(
            icon: Icons.record_voice_over,
            title: 'Hands-Free Only',
            description:
                'This app is designed for hands-free use only. Illinois law prohibits using hand-held electronic devices while driving.',
          ),
          const SizedBox(height: 12),
          _buildSafetyCard(
            icon: Icons.warning_amber,
            title: 'Never Speed',
            description:
                'SignalNav will NEVER suggest speeds above the posted limit. If the recommended speed exceeds the limit, you will be advised to maintain the speed limit.',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _lawNoticeAcknowledged,
            onChanged: (v) =>
                setState(() => _lawNoticeAcknowledged = v ?? false),
            title: Text(
              kDisclaimerIllinoisLaw,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Policy',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Markdown(
                data: '''# Privacy Policy

## Data Collection
- Location data is used ONLY for navigation and signal detection
- Raw GPS traces are stored for maximum 24 hours, then permanently deleted
- Signal reports contain: intersection ID, color, timestamp, and hashed device ID

## Data We NEVER Collect
- Your name, email, or phone number (unless you sign in with Google)
- Precise home/work locations
- Driving history or patterns
- Data for advertising or sale to third parties

## Your Rights
- Export your data at any time from Settings
- Delete your account and anonymize all historical reports
- Opt out of crowdsourcing while still using navigation

## Contact
Privacy questions: privacy@signalnav.example.com

// TODO: Replace with lawyer-approved privacy policy before v1.0 release
''',
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(color: Colors.white, fontSize: 20),
                  h2: TextStyle(color: Colors.white, fontSize: 18),
                  p: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _privacyAcknowledged,
            onChanged: (v) => setState(() => _privacyAcknowledged = v ?? false),
            title: const Text(
              'I have read and acknowledge the Privacy Policy',
              style: TextStyle(color: Colors.white),
            ),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Location Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'SignalNav needs your location to:\n'
            '\u2022 Provide turn-by-turn navigation\n'
            '\u2022 Detect when you stop at intersections\n'
            '\u2022 Improve signal predictions for the community\n\n'
            'We request "Always Allow" location so the app can detect '
            'intersections even when the screen is off. Your location data '
            'is never sold or shared with advertisers.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Icon(Icons.mic, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Microphone Access',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used ONLY for voice commands like "Hey Signal, red". '
            'Audio is processed on-device and never recorded or transmitted.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 80),
          Row(
            children: List.generate(5, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.green
                      : Colors.grey.shade700,
                ),
              );
            }),
          ),
          if (_currentPage < 4)
            ElevatedButton(
              onPressed: _canProceed || _currentPage < 1 ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Next'),
            )
          else
            ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Get Started'),
            ),
        ],
      ),
    );
  }
}
