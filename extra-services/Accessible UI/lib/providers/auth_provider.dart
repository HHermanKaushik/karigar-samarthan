import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// True only when signed in with a real phone number (not anonymous).
final isPhoneAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return user != null && !user.isAnonymous;
});
