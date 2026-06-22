import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and phone')),
      );
      return;
    }
    ref.read(userProvider.notifier).save(UserProfile(
          fullName: _name.text.trim(),
          storeName: _store.text.trim(),
          phone: _phone.text.trim(),
        ));
    context.go('/payment-setup');
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 28),
              _Field(label: tr('fullName'), controller: _name),
              _Field(label: tr('storeName'), controller: _store),
              _Field(
                label: tr('phoneNumber'),
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: _submit, child: Text(tr('signUp'))),
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
  const _Field(
      {required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
          TextField(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }
}
