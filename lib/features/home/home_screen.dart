import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../models/app_language.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/product_translation_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/service_providers.dart';
import '../products/edit_product_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onOrders;
  final VoidCallback onProfile;
  final VoidCallback onAssistant;
  final VoidCallback onHelp;

  const HomeScreen({
    super.key,
    required this.onAddProduct,
    required this.onOrders,
    required this.onProfile,
    required this.onAssistant,
    required this.onHelp,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Sync with WooCommerce after the first frame so the local Firestore
    // snapshot renders immediately, then stale/deleted products are removed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncProducts());
  }

  Future<void> _syncProducts() async {
    final woo = ref.read(wooServiceProvider);
    final activeIds = await woo.fetchActiveProductIds();
    if (!mounted) return;
    await ref.read(productsProvider.notifier).refresh(activeIds);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final products = ref.watch(productsProvider);
    final tr = ref.watch(trProvider);
    final lang = ref.watch(languageProvider);

    final List<List<Product>> columns = [];
    for (int i = 0; i < products.length; i += 2) {
      columns.add(products.sublist(
          i, i + 2 > products.length ? products.length : i + 2));
    }

    return SafeArea(
      child: RefreshIndicator(
        key: const Key('home_refresh_indicator'),
        onRefresh: _syncProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TOP BAR
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('home_ask_ai_button'),
                      onPressed: widget.onAssistant,
                      icon: const Icon(Icons.smart_toy_outlined,
                          color: AppColors.primary),
                      label: Text(tr('askAiAssistant'),
                          style: const TextStyle(color: AppColors.primary)),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: tr('helpAndSupport'),
                    child: IconButton(
                      key: const Key('home_help_button'),
                      onPressed: widget.onHelp,
                      icon: const Icon(Icons.help_outline,
                          color: AppColors.primary),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: tr('viewEditAccount'),
                    child: InkWell(
                      key: const Key('home_profile_button'),
                      onTap: widget.onProfile,
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              /// TITLE
              Text(
                tr('myStore'),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 4),

              /// GREETING
              Text(
                '${tr('welcomeBack')}, ${user.fullName.isEmpty ? "Seller" : user.fullName.split(' ').first}',
                style: const TextStyle(color: AppColors.textMuted),
              ),

              const SizedBox(height: 18),

              /// PRODUCTS
              if (products.isEmpty)
                Container(
                  key: const Key('home_empty_state'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 64, color: AppColors.primary),
                      const SizedBox(height: 14),
                      Text(
                        tr('noProductsYet'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('tapToAddFirst'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 420,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: columns.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final col = columns[index];
                      return SizedBox(
                        width: 180,
                        child: Column(
                          children: col.map((p) {
                            return Expanded(
                              child: Container(
                                key: ValueKey('home_product_tile_${p.id}'),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _ProductTile(
                                  product: p,
                                  qtyLabel: tr('qty'),
                                  lang: lang,
                                  onTap: () => showAppModal(context,
                                      child: EditProductScreen(product: p)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              _AddCard(
                  key: const Key('home_add_product_card'),
                  label: tr('addNewProduct'),
                  onTap: widget.onAddProduct),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  final String qtyLabel;
  final AppLanguage lang;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.qtyLabel,
    required this.lang,
    required this.onTap,
  });

  Widget _networkOrPlaceholder(Product p) {
    if (p.wooImageUrl != null) {
      return Image.network(
        p.wooImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, size: 42, color: AppColors.primary),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image_outlined, size: 42, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: product.imagePaths.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(product.imagePaths.first),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _networkOrPlaceholder(product),
                          ),
                        )
                      : _networkOrPlaceholder(product),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                watchTranslatedProductField(
                  ref,
                  product: product,
                  field: ProductFieldText(
                    english: product.title,
                    local: product.localTitle,
                    field: 'title',
                  ),
                  currentLanguageCode: lang.code,
                  currentSarvamCode: lang.sarvamCode,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text('₹ ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('$qtyLabel: ${product.quantity}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCard({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.white, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
