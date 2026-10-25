import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/promotion.dart';
import '../../../core/providers/auth_service.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/providers/product_providers.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/hero_mesh_header.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/widgets/premium_section_header.dart';
import '../widgets/product_card.dart';
import '../widgets/product_details_modal.dart';
import '../widgets/location_map_card.dart';

/// The customer home screen.
///
/// Shows:
/// - A greeting banner with the user's display name
/// - An active order card (if any order is queued/preparing/ready)
/// - An exclusive promotions carousel (if visible promos exist)
/// - A quick action to browse the menu
class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    final activeOrderAsync = ref.watch(activeOrderProvider(uid));
    final productsAsync = ref.watch(availableProductsProvider);
    final promosAsync = ref.watch(customerPromotionsProvider);

    final cs = Theme.of(context).colorScheme;
    final displayName = profile?.displayName ?? user?.displayName ?? 'there';
    final now = DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: HeroMeshHeader(
                greeting: _greeting(now),
                name: _firstName(displayName),
                defaultAvatarIcon: Icons.person_rounded,
                roleName: 'Customer',
                onLogoutTap: () async {
                  final confirm = await AppDialogs.confirm(
                    context,
                    title: 'Log Out',
                    message: 'Are you sure you want to log out?',
                    isDestructive: true,
                    confirmText: 'Log Out',
                  );
                  if (confirm) {
                    ref.read(authServiceProvider.notifier).signOut();
                  }
                },
              ),
              titlePadding: EdgeInsets.zero,
            ),
            actions: const [],
          ),

          // ── Body content ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Active order card ──────────────────────────────────────
                activeOrderAsync.when(
                  data: (order) {
                    if (order == null) {
                      return const _EmptyOrderBanner()
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.08, end: 0);
                    }
                    return _ActiveOrderCard(order: order)
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideY(begin: 0.08, end: 0);
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Browse Menu CTA ────────────────────────────────────────
                _MenuHeroBanner(
                  onTap: () => context.go(AppRoutes.customerMenu),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 24),

                // ── Special Offers & Promotions (Seen on Dashboard) ────────
                promosAsync.when(
                  data: (promos) {
                    if (promos.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumSectionHeader(
                          title: 'Special Promos & Deals',
                          icon: Icons.local_offer_rounded,
                          accentColor: cs.primary,
                        ).animate().fadeIn(delay: 250.ms),
                        const SizedBox(height: 12),
                        _CustomerPromosSection(promos: promos),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Featured Products ──
                productsAsync.when(
                  data: (products) {
                    final featured = products.where((p) => p.isFeatured).toList();
                    if (featured.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumSectionHeader(
                          title: 'Featured Today',
                          icon: Icons.star_rounded,
                          accentColor: cs.secondary,
                        ).animate().fadeIn(),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: ListView.separated(
                            clipBehavior: Clip.none,
                            scrollDirection: Axis.horizontal,
                            itemCount: featured.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: 220,
                                child: ProductCard(
                                  product: featured[index],
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ProductDetailsModal(
                                        product: featured[index],
                                      ),
                                    );
                                  },
                                ),
                              ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1, end: 0);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Quick links section ────────────────────────────────────
                PremiumSectionHeader(
                  title: 'Quick Links',
                  icon: Icons.flash_on_rounded,
                  accentColor: cs.tertiary,
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.receipt_long_rounded,
                        label: 'My Orders',
                        subtitle: 'Order history',
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.15),
                            cs.primary.withValues(alpha: 0.05),
                          ],
                        ),
                        iconColor: cs.primary,
                        onTap: () => context.go(AppRoutes.customerOrders),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.shopping_bag_rounded,
                        label: 'My Cart',
                        subtitle: 'Review items',
                        gradient: LinearGradient(
                          colors: [
                            cs.tertiary.withValues(alpha: 0.15),
                            cs.tertiary.withValues(alpha: 0.05),
                          ],
                        ),
                        iconColor: cs.tertiary,
                        onTap: () => context.go(AppRoutes.customerCart),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 24),
                
                PremiumSectionHeader(
                  title: 'Visit Us',
                  icon: Icons.storefront_rounded,
                  accentColor: cs.secondary,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 12),
                
                const LocationMapCard().animate().fadeIn(delay: 450.ms).slideY(begin: 0.08, end: 0),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(String name) {
    final parts = name.trim().split(' ');
    return parts.isEmpty ? name : parts.first;
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon ⛅';
    return 'Good evening 🌙';
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _EmptyOrderBanner extends StatelessWidget {
  const _EmptyOrderBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? cs.secondary.withValues(alpha: 0.1) : cs.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.secondary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, color: cs.secondary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active orders',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : cs.primary,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grab a fresh cup to start your day right.',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final CafeOrder order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPulsing = order.status == OrderStatus.queued ||
        order.status == OrderStatus.preparing;

    return AnimatedGlassCard(
      onTap: () => context.push(AppRoutes.customerOrder(order.id)),
      padding: const EdgeInsets.all(16),
      accentColor: cs.primary,
      child: Row(
        children: [
          // ── Status icon with optional pulse ──────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              if (isPulsing)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.15),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.4, 1.4),
                      duration: 1200.ms,
                      curve: Curves.easeOut,
                    )
                    .fadeOut(duration: 1200.ms),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.soup_kitchen_outlined,
                    color: cs.onPrimary, size: 24),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                _StatusChip(status: order.status),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_right, color: cs.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (status) {
      OrderStatus.queued => (
          Colors.orange.withValues(alpha: 0.15),
          Colors.orange.shade700,
          Icons.access_time_rounded
        ),
      OrderStatus.preparing => (
          cs.primary.withValues(alpha: 0.15),
          cs.primary,
          Icons.soup_kitchen_outlined
        ),
      OrderStatus.ready => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade700,
          Icons.done_all_rounded
        ),
      OrderStatus.received => (
          cs.secondary.withValues(alpha: 0.15),
          cs.secondary,
          Icons.shopping_bag_outlined
        ),
      OrderStatus.completed => (
          Colors.purple.withValues(alpha: 0.15),
          Colors.purple.shade700,
          Icons.star_outline_rounded
        ),
      OrderStatus.cancelled => (
          Colors.red.withValues(alpha: 0.15),
          Colors.red.shade700,
          Icons.cancel_outlined
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuHeroBanner extends StatelessWidget {
  const _MenuHeroBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFDCA87C), // Lighter Caramel
              Color(0xFFC88D5D), // Caramel
              Color(0xFF2C2420), // Espresso
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C2420).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Decorative background text ──────────────────────────────────
            Positioned(
              right: -10,
              bottom: -20,
              child: Text(
                '☕',
                style: TextStyle(
                  fontSize: 100,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // ── Content ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✨ Fresh & Hot',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Browse Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fresh coffee & bites',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Promotion Widgets ────────────────────────────────────────────────

class _CustomerPromosSection extends StatelessWidget {
  const _CustomerPromosSection({required this.promos});

  final List<Promotion> promos;

  @override
  Widget build(BuildContext context) {
    if (promos.length == 1) {
      return _CustomerPromoCard(promo: promos.first);
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: promos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 290,
            child: _CustomerPromoCard(promo: promos[index]),
          );
        },
      ),
    );
  }
}

class _CustomerPromoCard extends StatelessWidget {
  const _CustomerPromoCard({required this.promo});

  final Promotion promo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final discountTag = promo.type == DiscountType.percentage
        ? '${promo.value.toInt()}% OFF'
        : '₱${promo.value.toStringAsFixed(0)} OFF';

    return AnimatedGlassCard(
      onTap: () => _showPromoDetailsDialog(context, promo),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  discountTag,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      promo.code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: cs.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            promo.description.isNotEmpty ? promo.description : '${promo.code} Promo',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (promo.details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              promo.details,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                'View Details & Terms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 12, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showPromoDetailsDialog(BuildContext context, Promotion promo) {
  final cs = Theme.of(context).colorScheme;
  final discountTag = promo.type == DiscountType.percentage
      ? '${promo.value.toInt()}% OFF'
      : '₱${promo.value.toStringAsFixed(0)} OFF';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_offer_rounded, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  discountTag,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: cs.primary,
                  ),
                ),
                Text(
                  promo.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (promo.description.isNotEmpty) ...[
              Text(
                promo.description,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],

            // Details Section: What the promo has
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Promo Details & Inclusions:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    promo.details.isNotEmpty
                        ? promo.details
                        : (promo.description.isNotEmpty
                            ? promo.description
                            : 'Valid for eligible orders at checkout.'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Promo Code Copy Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROMO CODE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SelectableText(
                          promo.code,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy Code',
                    color: cs.primary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: promo.code));
                      AppDialogs.showNotice(context, 'Promo code ${promo.code} copied!');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: promo.code));
            Navigator.pop(ctx);
            AppDialogs.showNotice(context, 'Code ${promo.code} copied! Apply at checkout.');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Code'),
        ),
      ],
    ),
  );
}
