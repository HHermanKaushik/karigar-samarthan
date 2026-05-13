import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../providers/user_provider.dart';
import '../products/edit_product_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onOrders;

  const HomeScreen({
    super.key,
    required this.onAddProduct,
    required this.onOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final products = ref.watch(productsProvider);

    final List<List<Product>> columns = [];

    for (int i = 0; i < products.length; i += 2) {
      columns.add(
        products.sublist(
          i,
          i + 2 > products.length ? products.length : i + 2,
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TOP BAR
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.smart_toy_outlined,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Ask AI Assistant',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.help_outline,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            /// TITLE
            Text(
              'My Store',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 4),

            /// GREETING
            Text(
              'Welcome back, ${user.fullName.isEmpty ? "Seller" : user.fullName.split(' ').first}',
              style: const TextStyle(color: AppColors.textMuted),
            ),

            const SizedBox(height: 18),

            /// PRODUCTS SECTION
            if (products.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No products added yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tap below to add your first product',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
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
                              margin: const EdgeInsets.only(bottom: 12),
                              child: _ProductTile(
                                product: p,
                                onTap: () => showAppModal(
                                  context,
                                  child: EditProductScreen(product: p),
                                ),
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

            /// ADD PRODUCT BUTTON
            _AddCard(onTap: onAddProduct),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              /// IMAGE
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
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              /// PRODUCT TITLE
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              /// PRICE
              Text(
                '₹ ${product.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 4),

              /// QUANTITY
              Text(
                'Qty: ${product.quantity}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 22,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle, color: Colors.white, size: 32),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Add a New Product',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
