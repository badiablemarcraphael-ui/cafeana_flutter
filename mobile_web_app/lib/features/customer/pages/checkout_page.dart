import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/models/order.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/premium_section_header.dart';
import '../../../core/services/notification_service.dart';

/// Checkout screen — shows order summary and triggers the Firestore transaction.
///
/// Flow:
/// 1. User reviews order items and total
/// 2. Optionally marks order as paid immediately (simulated)
/// 3. Taps "Confirm Order" → runs [CheckoutNotifier.placeOrder]
/// 4. On success → navigates to [OrderTrackingPage]
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _noteCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  OrderType _orderType = OrderType.dineIn;
  String _promoStatus = '';

  @override
  void dispose() {
    _noteCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final finalTotal = ref.watch(cartFinalTotalProvider);
    final appliedPromo = ref.watch(appliedPromotionProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final cs = Theme.of(context).colorScheme;

    // Listen for successful checkout → request notification permission & navigate to tracking
    ref.listen<AsyncValue<String?>>(checkoutProvider, (previous, state) async {
      if (previous?.isLoading == true) {
        if (state case AsyncData(value: final orderId?) when orderId.isNotEmpty) {
          final router = GoRouter.of(context);
          if (mounted) {
            // Prompt for push / taskbar notification permission so user receives live status
            await NotificationService.instance.requestPermission();
            ref.read(checkoutProvider.notifier).reset();
            router.go(AppRoutes.customerOrder(orderId));
          }
        }
      }
    });

    if (cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 64,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Your cart is empty.'),
              const SizedBox(height: 20),
              GradientButton(
                onPressed: () => context.go(AppRoutes.customerMenu),
                width: 180,
                height: 50,
                child: const Text('Browse Menu'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
            children: [
              // ── Order summary card ─────────────────────────────────────────
              PremiumSectionHeader(
                title: 'Order Summary',
                icon: Icons.receipt_long_rounded,
              ),
              const SizedBox(height: 12),

              AnimatedGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...cartItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      cs.primaryContainer,
                                      cs.primaryContainer
                                          .withValues(alpha: 0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}×',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onPrimaryContainer,
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
                                      item.product.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (item.customizations.isNotEmpty)
                                      Text(
                                        item.customizations.entries
                                            .map((e) => '${e.key}: ${e.value}')
                                            .join(', '),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${item.lineTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Promo Code ────────────────────────────────────────────────
              PremiumSectionHeader(
                title: 'Promo Code',
                icon: Icons.local_offer_rounded,
                accentColor: cs.tertiary,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _promoCtrl,
                      decoration: InputDecoration(
                        hintText: 'Enter promo code',
                        prefixIcon: const Icon(Icons.discount_outlined),
                        errorText: _promoStatus.isNotEmpty
                            ? _promoStatus
                            : null,
                      ),
                      onChanged: (_) {
                        if (_promoStatus.isNotEmpty) {
                          setState(() => _promoStatus = '');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GradientButton(
                    onPressed: () => _applyPromo(ref),
                    width: 90,
                    height: 54,
                    borderRadius: 16,
                    child: const Text('Apply'),
                  ),
                ],
              ),

              if (appliedPromo != null) ...[
                const SizedBox(height: 10),
                AnimatedGlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  accentColor: Colors.green,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Code: ${appliedPromo.code}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.red, size: 18),
                        onPressed: () {
                          ref.read(appliedPromotionProvider.notifier).state =
                              null;
                          _promoCtrl.clear();
                        },
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Total breakdown ────────────────────────────────────────────
              AnimatedGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PriceLine(
                      label: 'Subtotal',
                      value: '₱${subtotal.toStringAsFixed(2)}',
                    ),
                    if (discount > 0) ...[
                      const SizedBox(height: 6),
                      _PriceLine(
                        label: 'Discount',
                        value: '-₱${discount.toStringAsFixed(2)}',
                        valueColor: Colors.green.shade600,
                        labelColor: Colors.green.shade600,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              Color(0xFF2C2420),
                              Color(0xFF564942)
                            ],
                          ).createShader(bounds),
                          child: Text(
                            '₱${finalTotal.toStringAsFixed(2)}',
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
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Order Type ────────────────────────────────────────────────
              PremiumSectionHeader(
                title: 'Order Type',
                icon: Icons.restaurant_rounded,
              ),
              const SizedBox(height: 12),

              SegmentedButton<OrderType>(
                segments: const [
                  ButtonSegment(
                    value: OrderType.dineIn,
                    label: Text('Dine-in'),
                    icon: Icon(Icons.restaurant_rounded),
                  ),
                  ButtonSegment(
                    value: OrderType.takeOut,
                    label: Text('Take-out'),
                    icon: Icon(Icons.takeout_dining_rounded),
                  ),
                ],
                selected: {_orderType},
                onSelectionChanged: (val) =>
                    setState(() => _orderType = val.first),
              ),

              const SizedBox(height: 20),

              // ── Special instructions ───────────────────────────────────────
              PremiumSectionHeader(
                title: 'Special Instructions',
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. extra hot, no sugar...',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),



              // ── Error display ─────────────────────────────────────────────
              if (checkoutState case AsyncError(:final error)) ...[
                const SizedBox(height: 12),
                AnimatedGlassCard(
                  padding: const EdgeInsets.all(14),
                  accentColor: cs.error,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: cs.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error.toString().replaceFirst('Exception: ', ''),
                          style: TextStyle(
                            color: cs.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // ── Confirm button (fixed bottom) ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: GradientButton(
                onPressed: checkoutState.isLoading ? null : _confirmOrder,
                isLoading: checkoutState.isLoading,
                child: const Text('Confirm Order'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrder() async {
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Error: User is not authenticated. Please log in again.')),
        );
      }
      return;
    }

    try {
      final items = ref.read(cartProvider);
      final promo = ref.read(appliedPromotionProvider);
      final discount = ref.read(cartDiscountProvider);
      await ref.read(checkoutProvider.notifier).placeOrder(
            items,
            user.uid,
            note: _noteCtrl.text.trim(),
            orderType: _orderType,
            promoCode: promo?.code,
            discountAmount: discount,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    }
  }

  Future<void> _applyPromo(WidgetRef ref) async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final promosAsync = await ref.read(activePromotionsProvider.future);
    final match = promosAsync.where((p) => p.code == code).firstOrNull;

    if (match != null) {
      ref.read(appliedPromotionProvider.notifier).state = match;
      setState(() => _promoStatus = '');
    } else {
      setState(() => _promoStatus = 'Invalid or expired promo code');
    }
  }
}

// ── Price line widget ─────────────────────────────────────────────────────────

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
