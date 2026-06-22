import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_language.dart';
import '../../providers/language_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';

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
