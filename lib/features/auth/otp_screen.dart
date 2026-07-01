import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final OtpRoutingData routingData;
  const OtpScreen({super.key, required this.routingData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  late String _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.routingData.verificationId;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP code')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: code,
      );
      await _processSignIn(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid OTP verification code.')),
      );
    }
  }

  Future<void> _processSignIn(PhoneAuthCredential credential) async {
    await FirebaseAuth.instance.signInWithCredential(credential);

    ref.invalidate(productsProvider);
    ref.invalidate(ordersProvider);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'karigar');
    final doc = await db.collection('users').doc(uid).get();

    bool hasProfile = false;

    if (doc.exists) {
      final d = doc.data()!;
      final name = (d['fullName'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) {
        hasProfile = true;
        await ref.read(userProvider.notifier).saveLocal(UserProfile(
          fullName: d['fullName'] ?? '',
          storeName: d['storeName'] ?? '',
          phone: d['phone'] ?? '',
          role: d['role'] ?? 'Master Artisan',
          paymentSetup: d['paymentSetup'] as bool? ?? false,
          upiId: d['upiId'] as String? ?? '',
        ));
        await ref.read(onboardingProvider.notifier).complete();
      }
    }

    // Explicit structural resolution check based on parent module workflow context flags
    if (!hasProfile && widget.routingData.isRegistrationFlow) {
      final localProfileCache = ref.read(userProvider);
      if (localProfileCache.fullName.isNotEmpty) {
        // Enforces your fixed user_sync_service.dart core WordPress deployment endpoint!
        await ref.read(userProvider.notifier).save(localProfileCache);
        hasProfile = true;
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (hasProfile) {
      context.go('/home');
    } else {
      context.go('/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go(widget.routingData.isRegistrationFlow ? '/signup' : '/login'),
        ),
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
                tr('enterOtp'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${tr('otpSentTo')} ${widget.routingData.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('verifyOtp')),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}