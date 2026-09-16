import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';
import '../onboarding/onboarding_screen.dart';
import 'dashboard_screen.dart';

/// Routes an authenticated user to onboarding until it is complete,
/// then to the dashboard (US-001/002).
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your profile.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (p) {
        if (p == null || !p.onboardingComplete || p.languages.isEmpty) {
          return const OnboardingScreen();
        }
        return DashboardScreen(profile: p);
      },
    );
  }
}
