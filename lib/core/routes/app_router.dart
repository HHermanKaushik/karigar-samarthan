import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/payment_setup_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/onboarding/language_screen.dart';
import '../../features/store/store_shell.dart';
import '../../providers/onboarding_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboardingComplete = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atOnboarding = loc == '/' ||
          loc == '/signup' ||
          loc == '/payment-setup' ||
          loc == '/login';
      if (onboardingComplete && atOnboarding && loc != '/login') {
        return '/home';
      }
      if (!onboardingComplete && loc == '/home') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/payment-setup',
          builder: (_, __) => const PaymentSetupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const StoreShell()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
