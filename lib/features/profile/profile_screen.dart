import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/network_error_view.dart';
import '../../models/app_language.dart';
import '../../providers/language_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/service_providers.dart';
import '../../utils/upi_utils.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final lang = ref.watch(languageProvider);
    final tr = ref.watch(trProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('myAccount'),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person,
                      size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(user.role,
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('details'),
            style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          _Row(label: tr('name'), value: user.fullName),
          _Row(label: tr('store'), value: user.storeName),
          _Row(label: tr('phone'), value: user.phone),
          _Row(label: tr('language'), value: lang.englishName),
          _Row(
            label: tr('paymentSetup'),
            value: user.paymentSetup
                ? tr('paymentActive')
                : tr('paymentNotSet'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 130,
                  child: Text('UPI ID',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text(
                    user.upiId.isNotEmpty ? user.upiId : 'No UPI ID added',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: user.upiId.isEmpty
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _editUpiId(context, user),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 32)),
                  child: Text(user.upiId.isNotEmpty ? 'Edit' : 'Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _changeLanguage(context, ref, tr),
            icon: const Icon(Icons.translate),
            label: Text(tr('changeLanguage')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              // Sign out the phone-auth user, then re-auth anonymously for
              // Storage/Firestore writes before the next phone login.
              await FirebaseAuth.instance.signOut();
              try {
                await FirebaseAuth.instance.signInAnonymously();
              } catch (_) {}
              // Clear per-user cached data so the next user starts fresh.
              ref.invalidate(productsProvider);
              ref.invalidate(ordersProvider);
              await ref.read(userProvider.notifier).clear();
              await ref.read(onboardingProvider.notifier).reset();
              if (context.mounted) {
                Navigator.of(context).pop();
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(tr('logOut')),
          ),
        ],
      ),
    );
  }

  void _editUpiId(BuildContext context, UserProfile user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UpiEditSheet(user: user),
    );
  }

  void _changeLanguage(
      BuildContext context, WidgetRef ref, String Function(String) tr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final selected = ref.read(languageProvider);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppLanguage.values.map((l) {
                final isActive = l == selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PopupLanguageCard(
                    lang: l,
                    active: isActive,
                    onTap: () {
                      ref.read(languageProvider.notifier).setLanguage(l);
                      Navigator.of(ctx).pop();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _PopupLanguageCard extends StatelessWidget {
  final AppLanguage lang;
  final bool active;
  final VoidCallback onTap;

  const _PopupLanguageCard({
    required this.lang,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: active ? 0.25 : 0.9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    lang.nativeName.characters.first,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.text),
                    ),
                    Text(
                      lang.englishName,
                      style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? Colors.white70
                              : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                active ? Icons.check_circle : Icons.radio_button_unchecked,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _UpiEditSheet extends ConsumerStatefulWidget {
  final UserProfile user;
  const _UpiEditSheet({required this.user});

  @override
  ConsumerState<_UpiEditSheet> createState() => _UpiEditSheetState();
}

class _UpiEditSheetState extends ConsumerState<_UpiEditSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.upiId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String upiId) async {
    if (upiId.isNotEmpty && !isValidUpiId(upiId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Please enter a valid UPI ID (e.g. yourname@oksbi or 9876543210@ybl)'),
      ));
      return;
    }
    setState(() => _saving = true);
    final updated = widget.user.copyWith(
      paymentSetup: upiId.isNotEmpty,
      upiId: upiId,
    );
    await ref.read(userProvider.notifier).saveLocal(updated);

    // Sync new UPI ID to all existing WooCommerce products in the background.
    // WooCommerce meta_data PUT uses merge semantics — only _ks_upi_id changes.
    final wooIds = ref
        .read(productsProvider)
        .where((p) => p.wooId != null)
        .map((p) => p.wooId!)
        .toList();
    if (wooIds.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      unawaited(
        ref.read(wooServiceProvider).syncUpiId(
          wooIds: wooIds,
          upiId: upiId,
          karigarUid: uid,
        ),
      );
    }

    final online = await hasNetworkConnection();
    if (online) {
      final ok =
          await ref.read(userSyncServiceProvider).syncUserProfile(updated);
      if (!ok && mounted) {
        showNetworkErrorSnackBar(context,
            message: "Saved on device. Will sync when back online.");
      }
    } else if (mounted) {
      showNetworkErrorSnackBar(context,
          message: "You're offline. Saved on device — will sync later.");
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Payment Details',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Buyers pay you directly — money goes straight to your UPI account.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'e.g. yourname@oksbi  or  9876543210@ybl',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : () => _save(_controller.text.trim()),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
          if (widget.user.upiId.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => _save(''),
              child: const Text('Remove UPI ID',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
