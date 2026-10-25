import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/providers/product_providers.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/utils/asset_resolver.dart';
import '../../../core/utils/profanity_filter.dart';

/// Modal bottom sheet to view product details and customize the order
/// (e.g., size, sugar level, ice level) before adding to cart.
class ProductDetailsModal extends ConsumerStatefulWidget {
  const ProductDetailsModal({required this.product, super.key});

  final Product product;

  static void show(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ProductDetailsModal(product: product),
    );
  }

  @override
  ConsumerState<ProductDetailsModal> createState() => _ProductDetailsModalState();
}

class _ProductDetailsModalState extends ConsumerState<ProductDetailsModal> {
  int _quantity = 1;
  String _selectedSize = DrinkSize.small.label;
  String _selectedSugar = '100%';
  String _selectedIce = 'Normal Ice';
  final Map<String, int> _addonQuantities = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final product = widget.product;
    
    final availableProductsAsync = ref.watch(availableProductsProvider);
    final addOns = availableProductsAsync.valueOrNull
            ?.where((p) => p.category.toLowerCase() == 'add-ons')
            .toList() ??
        [];

    final allFeedback = ref.watch(staffFeedbackProvider).valueOrNull ?? [];
    final targetName = product.name.trim().toLowerCase();
    final productFeedback = allFeedback.where((f) {
      if (!f.isPublished) return false;
      if (f.productNames.any((p) => p.trim().toLowerCase() == targetName)) {
        return true;
      }
      if (f.items.any((i) => i.name.trim().toLowerCase() == targetName)) {
        return true;
      }
      if (f.productIds.contains(product.id)) {
        return true;
      }
      return false;
    }).toList();

    final hasFeedback = productFeedback.isNotEmpty;
    final productAvg = hasFeedback
        ? productFeedback.map((f) => f.rating).reduce((a, b) => a + b) /
            productFeedback.length
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header / Image ──────────────────────────────────────────────
          Builder(
            builder: (context) {
              final assetPath = resolveProductAssetImage(product.name);
              
              if (assetPath != null) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.asset(
                    assetPath,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(cs),
                  ),
                );
              } else if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    product.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(cs),
                  ),
                );
              } else {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: _placeholder(cs),
                );
              }
            }
          ),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                // ── Info ──────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasFeedback)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              productAvg.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${productFeedback.length} review${productFeedback.length == 1 ? '' : 's'})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline_rounded,
                                size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // ── Customizations ────────────────────────────────────────
                Text('Size', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: DrinkSize.small.label,
                      label: Text('Small ${DrinkSize.small.ounces} oz'),
                    ),
                    ButtonSegment(
                      value: DrinkSize.large.label,
                      label: Text('Large ${DrinkSize.large.ounces} oz (+₱20)'),
                    ),
                  ],
                  selected: {_selectedSize},
                  onSelectionChanged: (val) => setState(() => _selectedSize = val.first),
                ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                Text('Sugar Level', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '0%', label: Text('0%')),
                    ButtonSegment(value: '50%', label: Text('50%')),
                    ButtonSegment(value: '100%', label: Text('100%')),
                  ],
                  selected: {_selectedSugar},
                  onSelectionChanged: (val) => setState(() => _selectedSugar = val.first),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                Text('Ice Level', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Less Ice', label: Text('Less')),
                    ButtonSegment(value: 'Normal Ice', label: Text('Normal')),
                    ButtonSegment(value: 'Extra Ice', label: Text('Extra')),
                  ],
                  selected: {_selectedIce},
                  onSelectionChanged: (val) => setState(() => _selectedIce = val.first),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 32),

                // ── Add-ons ─────────────────────────────────────────────
                if (addOns.isNotEmpty) ...[
                  Text('Add-ons', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...addOns.map((addon) {
                    final qty = _addonQuantities[addon.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${addon.name} (+₱${addon.price.toStringAsFixed(2)})',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: qty > 0 ? () => setState(() => _addonQuantities[addon.id] = qty - 1) : null,
                                icon: const Icon(Icons.remove, size: 16),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$qty',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() => _addonQuantities[addon.id] = qty + 1),
                                icon: const Icon(Icons.add, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // ── Product Customer Reviews ───────────────────────────────
                if (hasFeedback) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.reviews_rounded,
                                    size: 16, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Feedback for ${product.name}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  productAvg.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...productFeedback.take(3).map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: cs.outlineVariant
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            i < f.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (f.createdAt != null)
                                          Text(
                                            DateFormat('MMM d, yyyy')
                                                .format(f.createdAt!),
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: cs.onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                    if (f.comment != null &&
                                        f.comment!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '"${ProfanityFilter.maskProfanity(f.comment!)}"',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    if (f.reply != null &&
                                        f.reply!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.reply,
                                                size: 12, color: cs.secondary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Owner: ${f.reply}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.secondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Quantity ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$_quantity',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Add to Cart Button ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: () async {
                  final confirm = await AppDialogs.confirm(
                    context,
                    title: 'Add to Cart',
                    message: 'Are you sure you want to add $_quantity ${product.name}(s) to your cart?',
                    confirmText: 'Add to Cart',
                  );
                  if (!confirm) return;

                  final customizations = <String, String>{
                    'Size': _selectedSize,
                    'Sugar': _selectedSugar,
                    'Ice': _selectedIce,
                  };
                  
                  double addonsPrice = 0;
                  for (final addon in addOns) {
                    final qty = _addonQuantities[addon.id] ?? 0;
                    if (qty > 0) {
                      customizations[addon.name] = 'x$qty';
                      addonsPrice += addon.price * qty;
                    }
                  }

                  // Re-calculate price if large
                  final finalPrice = (_selectedSize == 'Large' ? product.price + 20 : product.price) + addonsPrice;
                  final customizedProduct = product.copyWith(price: finalPrice);

                  for (var i = 0; i < _quantity; i++) {
                    ref.read(cartProvider.notifier).addItem(customizedProduct, customizations: customizations);
                  }
                  
                  if (context.mounted) {
                    AppDialogs.showNotice(context, '${product.name} added to cart.');
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        height: 200,
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.coffee, size: 64, color: cs.onSurfaceVariant),
        ),
      );
}
