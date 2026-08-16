import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';

const String _restoreRequestWhatsappNumber = '918796577741';

class ArchivedProductsScreen extends ConsumerStatefulWidget {
  const ArchivedProductsScreen({super.key});

  @override
  ConsumerState<ArchivedProductsScreen> createState() =>
      _ArchivedProductsScreenState();
}

class _ArchivedProductsScreenState
    extends ConsumerState<ArchivedProductsScreen> {
  List<Product>? _archived;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ref.read(productsProvider.notifier).fetchArchived();
    if (mounted) setState(() => _archived = items);
  }

  Future<void> _requestRestore(Product p) async {
    final message = 'Hi, please restore this archived product:\n\n'
        'Title: ${p.title}\n'
        'WooCommerce ID: ${p.wooId ?? "not published"}\n'
        'Price: ₹${p.price.toStringAsFixed(0)}\n'
        'Quantity: ${p.quantity}\n\n'
        'Thank you!';
    final uri = Uri.parse(
        'https://wa.me/$_restoreRequestWhatsappNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(trProvider)('whatsappOpenFailed')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('archivedProductsBtn'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _archived == null
                ? const Center(child: CircularProgressIndicator())
                : _archived!.isEmpty
                    ? Center(child: Text(tr('noArchivedProducts')))
                    : ListView.builder(
                        itemCount: _archived!.length,
                        itemBuilder: (context, i) {
                          final p = _archived![i];
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('₹ ${p.price.toStringAsFixed(0)}'),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _requestRestore(p),
                                    icon: const Icon(Icons.chat_outlined,
                                        color: Color(0xFF25D366)),
                                    label: Text(tr('requestRestoreWhatsapp')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
