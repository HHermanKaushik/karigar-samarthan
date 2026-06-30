import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/network_error_view.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/service_providers.dart';
import '../../utils/upi_utils.dart';

class PaymentSetupScreen extends ConsumerStatefulWidget {
  const PaymentSetupScreen({super.key});
  @override
  ConsumerState<PaymentSetupScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentSetupScreen> {
  final _upiId = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing UPI ID if the user is revisiting this screen.
    final existing = ref.read(userProvider).upiId;
    if (existing.isNotEmpty) _upiId.text = existing;
  }

  @override
  void dispose() {
    _upiId.dispose();
    super.dispose();
  }

  Future<void> _save({required bool skipped}) async {
    final upiId = _upiId.text.trim();

    if (!skipped && upiId.isNotEmpty && !isValidUpiId(upiId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Please enter a valid UPI ID (e.g. yourname@oksbi or 9876543210@ybl)'),
      ));
      return;
    }

    setState(() => _saving = true);

    final user = ref.read(userProvider);
    final updated = user.copyWith(
      paymentSetup: !skipped,
      upiId: skipped ? user.upiId : upiId,
    );

    await ref.read(userProvider.notifier).saveLocal(updated);

    final online = await hasNetworkConnection();
    var syncedOk = false;

    if (online) {
      syncedOk =
          await ref.read(userSyncServiceProvider).syncUserProfile(updated);
    }

    await ref.read(onboardingProvider.notifier).complete();

    if (!mounted) return;

    setState(() => _saving = false);

    if (!online || !syncedOk) {
      showNetworkErrorSnackBar(
        context,
        message: online
            ? "We couldn't reach the server. Your details are saved on this device and will sync automatically later."
            : "You're offline. Your details are saved on this device and will sync once you're back online.",
      );
    }

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(leading: BackButton(onPressed: () => context.go('/signup'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 72)),
              const SizedBox(height: 20),
              Text(
                'Set up UPI payments',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Customers will pay you directly — money goes straight to your UPI account. Karigar Samarthan never holds your funds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              _LabelField(
                label: 'Your UPI ID',
                hint: 'e.g. yourname@oksbi  or  9876543210@ybl',
                controller: _upiId,
                keyboardType: TextInputType.emailAddress,
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your UPI ID is safe. It will only be shown to customers who have already purchased your product so they can complete payment.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(skipped: false),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user),
                label: const Text('Save & Continue'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _saving ? null : () => _save(skipped: true),
                child: const Text('Do this later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _LabelField(
      {required this.label,
      required this.controller,
      this.hint,
      this.keyboardType});

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
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
