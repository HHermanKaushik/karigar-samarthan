import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _store = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final clean = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    return clean.startsWith('+') ? clean : '+91$clean';
  }

  Future<void> _submitRegistration() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your details completely')),
      );
      return;
    }

    setState(() => _loading = true);
    final formattedPhone = _normalizePhone(_phone.text);

    ref.read(userProvider.notifier).saveLocal(UserProfile(
      fullName: _name.text.trim(),
      storeName: _store.text.trim(),
      phone: formattedPhone,
    ));

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      // If Android auto-verifies, instant sign-in
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);

          final localProfileCache = ref.read(userProvider);
          if (localProfileCache.fullName.isNotEmpty) {
            // Trigger the profile sync check
            await ref.read(userProvider.notifier).save(localProfileCache);
          }

          if (!mounted) return;
          setState(() => _loading = false);
          context.go('/payment-setup');
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Verification initialization failure.')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _loading = false);
        context.go(
          '/otp',
          extra: OtpRoutingData(
            verificationId: verificationId,
            phoneNumber: formattedPhone,
            isRegistrationFlow: true,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 80)),
              const SizedBox(height: 24),
              Text(
                tr('createAccount'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              _Field(label: tr('fullName'), controller: _name),
              _Field(label: tr('storeName'), controller: _store),
              _Field(label: tr('phoneNumber'), controller: _phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _submitRegistration,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('signUp')),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textMuted),
                      children: [
                        TextSpan(text: tr('alreadyAccount')),
                        TextSpan(
                          text: tr('logIn'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _Field({required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
          TextField(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }
}