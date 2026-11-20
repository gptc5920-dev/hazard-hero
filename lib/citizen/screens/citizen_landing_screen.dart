import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../widgets/language_button.dart';

class CitizenLandingScreen extends ConsumerWidget {
  const CitizenLandingScreen({super.key});

  static const _brand = Color(0xffdd2d4a);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -90,
              top: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  color: Color(0xfffce8ec),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 48 : 22,
                12,
                wide ? 48 : 22,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _brand,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.health_and_safety_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'HAZARD HERO',
                              style: TextStyle(
                                color: _brand,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: wide ? 76 : 46),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _WelcomeCopy(strings: strings)),
                            const SizedBox(width: 64),
                            Expanded(child: _SafetyPanel(strings: strings)),
                          ],
                        )
                      else ...[
                        _WelcomeCopy(strings: strings),
                        const SizedBox(height: 34),
                        _SafetyPanel(strings: strings),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: wide ? 40 : 14,
              child: const CitizenLanguageButton(iconOnly: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.strings});

  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xfffce8ec),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          strings.text('landingEyebrow'),
          style: const TextStyle(
            color: Color(0xffb51f39),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .45,
          ),
        ),
      ),
      const SizedBox(height: 22),
      Text(
        strings.text('landingTitle'),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: const Color(0xff35141d),
          fontWeight: FontWeight.w900,
          height: 1.06,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        strings.text('landingDescription'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xff6f4a54),
          height: 1.55,
        ),
      ),
      const SizedBox(height: 30),
      FilledButton.icon(
        onPressed: () => context.go('/'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, 54),
          backgroundColor: const Color(0xffdd2d4a),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(
          strings.text('startExploring'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(
            Icons.no_accounts_outlined,
            size: 17,
            color: Color(0xff8d6670),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              strings.text('noLoginRequired'),
              style: const TextStyle(
                color: Color(0xff8d6670),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({required this.strings});

  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xffdd2d4a),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x29a71935),
          blurRadius: 32,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _FeatureTile(
            icon: Icons.cloud_done_outlined,
            title: strings.text('verifiedInformation'),
            description: strings.text('verifiedInformationDescription'),
          ),
          const Divider(height: 28),
          _FeatureTile(
            icon: Icons.wifi_off_rounded,
            title: strings.text('offlineReady'),
            description: strings.text('offlineReadyDescription'),
          ),
          const Divider(height: 28),
          _FeatureTile(
            icon: Icons.location_on_outlined,
            title: strings.text('emergencyAccess'),
            description: strings.text('emergencyAccessDescription'),
          ),
        ],
      ),
    ),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xfffce8ec),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xffdd2d4a)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff35141d),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xff76515b),
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
