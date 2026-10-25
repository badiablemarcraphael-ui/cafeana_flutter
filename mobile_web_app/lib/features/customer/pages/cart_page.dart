import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/gradient_button.dart';

/// Displays the contents of the shopping cart.
///
/// Allows adjusting quantity, removing items, and navigating to checkout.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => _confirmClear(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                child: const Text('Clear all'),
              ),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _EmptyCart(onBrowse: () => context.go(AppRoutes.customerMenu))
          : Stack(
              children: [
                // ── Items list ──────────────────────────────────────────────
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartItemTile(
                        key: ValueKey(item.id),
                        item: item,
                      )
                          .animate()
                          .fadeIn(delay: (60 * index).ms)
                          .slideX(begin: -0.04, end: 0),
                    );
                  },
                ),

                // ── Glass bottom bar ────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _CartBottomBar(total: total)
                      .animate()
                      .slideY(begin: 1, end: 0, duration: 400.ms,
                          curve: Curves.easeOutCubic),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear Cart?'),
        content: const Text('All items will be removed from your cart.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }
}

// ── Glass bottom bar ──────────────────────────────────────────────────────────

class _CartBottomBar extends ConsumerWidget {
  const _CartBottomBar({required this.total});
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1814).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF2C2420), Color(0xFF40342E)],
                    ).createShader(bounds),
                    child: Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 22,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GradientButton(
                onPressed: () => context.push(AppRoutes.customerCheckout),
                child: const Text('Proceed to Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item, super.key});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final latestItem =
        cartItems.where((i) => i.id == item.id).firstOrNull;
    if (latestItem == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(cartProvider.notifier);

    return AnimatedGlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // ── Product icon ──────────────────────────────────────────────────
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer,
                  cs.primaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.coffee_rounded,
              color: cs.onPrimaryContainer,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // ── Name + price ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latestItem.product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (latestItem.customizations.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    latestItem.customizations.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(', '),
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '₱${latestItem.lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ── Quantity stepper ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepBtn(
                  icon: latestItem.quantity == 1
                      ? Icons.delete_outline_rounded
                      : Icons.remove_rounded,
                  color: latestItem.quantity == 1 ? cs.error : cs.primary,
                  onTap: () async {
                    if (latestItem.quantity == 1) {
                      final confirm = await AppDialogs.confirm(
                        context,
                        title: 'Remove Item',
                        message: 'Are you sure you want to remove ${latestItem.product.name} from your cart?',
                        isDestructive: true,
                        confirmText: 'Remove',
                      );
                      if (!confirm) return;
                      if (context.mounted) {
                        AppDialogs.showNotice(context, '${latestItem.product.name} removed from cart.');
                      }
                    }
                    notifier.decrementItem(latestItem.id);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${latestItem.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                _StepBtn(
                  icon: Icons.add_rounded,
                  color: cs.primary,
                  onTap: () => notifier.addItem(latestItem.product,
                      customizations: latestItem.customizations),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 52,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from the menu to get started.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C2420), Color(0xFF40342E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF2C2420).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Browse Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).scale(
              begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        ],
      ).animate().fadeIn().slideY(begin: 0.08, end: 0),
    );
  }
}
