import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../core/widgets/voice_button.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../products/add_product_flow.dart';
import '../profile/profile_screen.dart';

/// Persistent application scaffold. The Home screen is always visible
/// underneath; everything else opens as a modal sheet.
class StoreShell extends ConsumerStatefulWidget {
  const StoreShell({super.key});
  @override
  ConsumerState<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends ConsumerState<StoreShell> {
  void _openOrders() =>
      showAppModal(context, child: const OrdersScreen());
  void _openProfile() =>
      showAppModal(context, child: const ProfileScreen());
  void _openAssistant() =>
      showAppModal(context, child: const AiAssistantScreen());
  void _openAddProduct() =>
      showAppModal(context, child: const AddProductFlow());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeScreen(onAddProduct: _openAddProduct, onOrders: _openOrders),
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
