import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_router.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/voice_button.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/service_providers.dart';

enum _Step { phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _loading = false;
  bool _sttReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    final stt = ref.read(speechToTextProvider);
    final ok = await stt.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (ok && mounted) setState(() => _sttReady = true);
  }

  Future<void> _toggleVoicePhone() async {
    final stt = ref.read(speechToTextProvider);

    if (_listening) {
      await stt.stop();
      setState(() => _listening = false);
      return;
    }

    if (!_sttReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(trProvider)('micUnavailable'))));
      return;
    }

    setState(() => _listening = true);
    stt.listen(
      onResult: (r) {
        if (r.finalResult) {
          setState(() {
            _phone.text = r.recognizedWords.replaceAll(RegExp(r'[^0-9]'), '');
            _listening = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final clean = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    return clean.startsWith('+') ? clean : '+91$clean';
  }

  Future<void> _submitLogin() async {
    final phone = _normalizePhone(_phone.text);
    if (phone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _loading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      // Android auto-verify path - sign in directly.
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);

          final uid = FirebaseAuth.instance.currentUser!.uid;
          final db = FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'karigar');
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

          if (!mounted) return;
          setState(() => _loading = false);
          if (hasProfile) {
            context.go('/home');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(ref.read(trProvider)('phoneNotRegistered'))),
            );
            context.go('/signup');
          }
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Verification failed.')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _loading = false);
        context.go(
          '/otp',
          extra: OtpRoutingData(
            verificationId: verificationId,
            phoneNumber: phone,
            isRegistrationFlow: false,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 80)),
              const SizedBox(height: 24),
              Text(
                tr('loginTitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
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
                  VoiceButton(
                      size: 56,
                      listening: _listening,
                      onTap: _toggleVoicePhone),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submitLogin,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr('sendOtp')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
