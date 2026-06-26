import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../core/widgets/voice_button.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/translations_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../products/add_product_flow.dart';
import '../profile/profile_screen.dart';
import '../support/faq_screen.dart';
import '../support/help_support_screen.dart';

/// Persistent application scaffold. The Home screen is always visible
/// underneath; everything else opens as a modal sheet.
class StoreShell extends ConsumerStatefulWidget {
  const StoreShell({super.key});
  @override
  ConsumerState<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends ConsumerState<StoreShell> {
  void _openOrders() => showAppModal(context, child: const OrdersScreen());
  void _openProfile() => showAppModal(context, child: const ProfileScreen());
  void _openAssistant() => showAppModal(
        context,
        child: AiAssistantScreen(
          onNavigateTo: (target) {
            switch (target) {
              case NavigateTarget.orders:
                _openOrders();
              case NavigateTarget.addProduct:
                _openAddProduct();
              case NavigateTarget.profile:
                _openProfile();
              case NavigateTarget.help:
                _openHelp();
              case NavigateTarget.faq:
                _openFaq();
            }
          },
        ),
      );
  void _openAddProduct() =>
      showAppModal(context, child: const AddProductFlow());
  void _openHelp() => showAppModal(context, child: const HelpSupportScreen());
  void _openFaq() => showAppModal(context, child: const FaqScreen());

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.when(
      data: (v) => v,
      loading: () => true,
      error: (_, __) => true,
    );

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            _OfflineBanner(
              label: tr('noInternet'),
              message: tr('noInternetMessage'),
            ),
          Expanded(
            child: HomeScreen(
              onAddProduct: _openAddProduct,
              onOrders: _openOrders,
              onProfile: _openProfile,
              onAssistant: _openAssistant,
              onHelp: _openHelp,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                iconSize: 30,
                onPressed: _openProfile,
                icon: const Icon(Icons.person_outline,
                    color: AppColors.textMuted),
              ),
              VoiceButton(size: 64, onTap: _openAssistant),
              IconButton(
                iconSize: 30,
                onPressed: _openOrders,
                icon: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String label;
  final String message;

  const _OfflineBanner({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFB71C1C),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(message,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
