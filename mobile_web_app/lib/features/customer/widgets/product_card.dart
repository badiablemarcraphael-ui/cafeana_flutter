import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/utils/asset_resolver.dart';
import '../../../core/providers/staff_providers.dart';
import 'product_details_modal.dart';

/// A card widget that displays a single [Product] on the menu screen.
///
/// Shows the product image (or a placeholder icon), name, price, and an
/// "Add" button that opens [ProductDetailsModal] to customize order.
class ProductCard extends ConsumerWidget {
  const ProductCard({required this.product, this.onTap, super.key});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOutOfStock = product.stock != null && product.stock! <= 0;
    final assetPath = resolveProductAssetImage(product.name);

    final allFeedback = ref.watch(staffFeedbackProvider).valueOrNull ?? [];
    final targetName = product.name.trim().toLowerCase();
    final productFeedback = allFeedback
        .where((f) =>
            f.isPublished &&
            (f.productNames
                    .any((p) => p.trim().toLowerCase() == targetName) ||
                f.items
                    .any((i) => i.name.trim().toLowerCase() == targetName) ||
                f.productIds.contains(product.id)))
        .toList();

    final double? avgRating = productFeedback.isNotEmpty
        ? (productFeedback.map((f) => f.rating).reduce((a, b) => a + b) /
            productFeedback.length)
        : null;

    return AnimatedGlassCard(
      padding: EdgeInsets.zero,
      onTap: isOutOfStock
          ? null
          : (onTap ?? () => ProductDetailsModal.show(context, product)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ──────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // ── Image fill
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: ColorFiltered(
                      colorFilter: isOutOfStock
                          ? const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.overlay),
                      child: assetPath != null
                          ? Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(cs),
                            )
                          : product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty
                              ? Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(cs),
                                )
                              : _placeholder(cs),
                    ),
                  ),
                ),

                // ── Gradient overlay at bottom ──────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // ── Out of stock badge ──────────────────────────────────────
                if (isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sold out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // ── Product rating pill ─────────────────────────────────────
                if (avgRating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    // ── Gradient add button ───────────────────────────────
                    if (!isOutOfStock)
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cs.primary,
                              cs.primary.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        child: Center(
          child: Icon(
            Icons.coffee_rounded,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      );
}
