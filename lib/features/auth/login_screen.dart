import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/voice_button.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';

enum _Step { phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  _Step _step = _Step.phone;
  bool _loading = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final clean = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    return clean.startsWith('+') ? clean : '+91$clean';
  }

  Future<void> _sendOtp() async {
    final phone = _normalizePhone(_phone.text);
    // Expect at least a 10-digit local number after +91
    if (phone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _loading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified on Android — sign in immediately
        await _signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ??
                  'Verification failed. Check your number and try again.')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _step = _Step.otp;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final code = _otp.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid OTP. Please try again.')),
      );
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    // Step 1: Firebase Auth — only FirebaseAuthException can be thrown here.
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Sign-in failed.')),
      );
      return;
    }

    if (!mounted) return;

    // Reload per-user providers with the authenticated UID.
    ref.invalidate(productsProvider);
    ref.invalidate(ordersProvider);

    // Step 2: Check Firestore for an existing profile.
    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool hasProfile = false;
    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      );
      final doc = await db.collection('users').doc(uid).get();
      if (!mounted) return;

      final name = (doc.data()?['fullName'] as String?)?.trim() ?? '';
      if (doc.exists && name.isNotEmpty) {
        hasProfile = true;
        final d = doc.data()!;
        await ref.read(userProvider.notifier).saveLocal(UserProfile(
              fullName: d['fullName'] ?? '',
              storeName: d['storeName'] ?? '',
              phone: d['phone'] ?? '',
              role: d['role'] ?? 'Master Artisan',
              paymentSetup: d['paymentSetup'] as bool? ?? false,
            ));
        await ref.read(onboardingProvider.notifier).complete();
      }
    } on FirebaseException catch (e) {
      // Firestore threw — most likely rules not deployed yet.
      // Show the real error so it can be diagnosed; do NOT silently redirect
      // the user to /signup (that would erase their existing account).
      if (!mounted) return;
      setState(() => _loading = false);
      final hint = e.code == 'permission-denied'
          ? 'Firestore rules may not be deployed yet. Run: firebase deploy --only firestore:rules'
          : e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your account: $hint'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    context.go(hasProfile ? '/home' : '/signup');
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);

    return Scaffold(
      appBar: AppBar(
        leading: _step == _Step.otp
            ? BackButton(onPressed: () {
                setState(() {
                  _step = _Step.phone;
                  _otp.clear();
                  _loading = false;
                });
              })
            : BackButton(onPressed: () => context.go('/')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 80)),
              const SizedBox(height: 24),
              Text(
                _step == _Step.phone ? tr('loginTitle') : tr('enterOtp'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_step == _Step.otp) ...[
                const SizedBox(height: 8),
                Text(
                  '${tr('otpSentTo')} +91 ${_phone.text.trim()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 32),
              if (_step == _Step.phone) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: tr('phoneNumber'),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: '+91 ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    VoiceButton(size: 56, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(tr('sendOtp')),
                ),
              ] else ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: '· · · · · ·',
                    counterText: '',
                    hintStyle: TextStyle(letterSpacing: 8, fontSize: 22),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(tr('verifyOtp')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: Text(tr('resendOtp')),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(tr('dataSecure'),
                      style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
