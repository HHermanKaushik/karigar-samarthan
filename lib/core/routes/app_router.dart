import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/payment_setup_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/otp_screen.dart'; // Target reference
import '../../features/onboarding/language_screen.dart';
import '../../features/store/store_shell.dart';
import '../../providers/onboarding_provider.dart';

// Clear metadata container to bridge context between screens safely
class OtpRoutingData {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  final bool isRegistrationFlow;

  const OtpRoutingData({
    required this.verificationId,
    required this.phoneNumber,
    required this.isRegistrationFlow,
    this.resendToken,
  });
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboardingComplete = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atOnboarding = loc == '/' ||
          loc == '/signup' ||
          loc == '/payment-setup' ||
          loc == '/login' ||
          loc == '/otp';
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
      GoRoute(path: '/payment-setup', builder: (_, __) => const PaymentSetupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp',
        builder: (context, state) {
          final args = state.extra as OtpRoutingData;
          return OtpScreen(routingData: args);
        },
      ),
      GoRoute(path: '/home', builder: (_, __) => const StoreShell()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});