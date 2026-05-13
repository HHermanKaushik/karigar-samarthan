import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_provider.dart';

enum _PayMethod { upi, bank }

class PaymentSetupScreen extends ConsumerStatefulWidget {
  const PaymentSetupScreen({super.key});
  @override
  ConsumerState<PaymentSetupScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentSetupScreen> {
  _PayMethod _method = _PayMethod.upi;
  final _id = TextEditingController();
  final _holder = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _holder.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save({required bool skipped}) async {
    final user = ref.read(userProvider);
    await ref.read(userProvider.notifier).save(user.copyWith(paymentSetup: !skipped));
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/signup'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 72)),
              const SizedBox(height: 20),
              Text(
                'How do you want to be paid?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MethodCard(
                      label: 'UPI',
                      icon: Icons.qr_code_2,
                      active: _method == _PayMethod.upi,
                      onTap: () => setState(() => _method = _PayMethod.upi),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MethodCard(
                      label: 'Bank',
                      icon: Icons.account_balance,
                      active: _method == _PayMethod.bank,
                      onTap: () => setState(() => _method = _PayMethod.bank),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _LabelField(
                  label: _method == _PayMethod.upi ? 'UPI ID' : 'Account Number',
                  controller: _id),
              _LabelField(label: 'Account Holder Name', controller: _holder),
              _LabelField(
                  label: 'Phone Number Linked',
                  controller: _phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _save(skipped: false),
                icon: const Icon(Icons.verified_user),
                label: const Text('Verify & Save'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _save(skipped: true),
                child: const Text('Do this later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _MethodCard(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 36),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _LabelField(
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
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextField(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }
}
