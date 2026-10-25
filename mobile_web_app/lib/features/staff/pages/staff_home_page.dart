import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers/auth_service.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/widgets/hero_mesh_header.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/premium_section_header.dart';

/// Phase 4 – Screen 1: Staff Dashboard (Home)
///
/// Shows:
///  • Gradient hero with greeting + display name + role badge
///  • Quick summary cards (active orders, low stock count)
///  • Device status pill indicator
///  • Quick-action tiles to each staff section
class StaffHomePage extends ConsumerWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profileAsync =
        user != null ? ref.watch(userProfileProvider(user.uid)) : null;

    if (profileAsync == null || profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profileAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Text(
              'Error loading profile: ${profileAsync.error}\n${profileAsync.stackTrace}'),
        ),
      );
    }
    
    final activeOrdersAsync = ref.watch(staffActiveOrdersProvider);
    final productsAsync = ref.watch(allProductsProvider);
    final deviceAsync = ref.watch(deviceStatusProvider);

    final profile = profileAsync.value;
    final displayName = profile?.displayName ?? user?.displayName ?? user?.email ?? 'Staff';
    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text(
              'User profile not found. Please log in again or contact admin.'),
        ),
      );
    }

    final role = profile.role;
    final isOwner = role == UserRole.owner;
    final isCashier = role == UserRole.cashier;
    final isKitchen = role == UserRole.kitchen;

    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffActiveOrdersProvider);
          ref.invalidate(allProductsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Gradient hero SliverAppBar ──────────────────────────────────
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
                  defaultAvatarIcon: switch (role) {
                    UserRole.owner => Icons.star_rounded,
                    UserRole.cashier => Icons.point_of_sale_rounded,
                    UserRole.kitchen => Icons.soup_kitchen_outlined,
                    UserRole.customer => Icons.person_rounded,
                  },
                  roleName: _roleName(role),
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

            // ── Body Content ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Quick stats ─────────────────────────────────────────
                  Row(
                    children: [
                      if (isOwner || isCashier || isKitchen)
                        Expanded(
                          child: _QuickStat(
                            icon: Icons.pending_actions_rounded,
                            label: 'Active Orders',
                            color: Colors.orange,
                            valueAsync: activeOrdersAsync
                                .whenData((o) => o.length.toString()),
                            onTap: () => context.go(AppRoutes.staffOrders),
                          )
                              .animate()
                              .fadeIn()
                              .slideY(begin: 0.08, end: 0),
                        ),
                      if (isOwner || isCashier) ...[
                        if (isOwner || isCashier || isKitchen)
                          const SizedBox(width: 12),
                        Expanded(
                          child: productsAsync.when(
                            loading: () =>
                                const _QuickStatLoading(label: 'Low Stock'),
                            error: (_, __) =>
                                const _QuickStatLoading(label: 'Low Stock'),
                            data: (products) {
                              final lowCount = products
                                  .where((p) =>
                                      p.stock != null && p.stock! <= 10)
                                  .length;
                              return _QuickStat(
                                icon: Icons.inventory_2_outlined,
                                label: 'Low Stock',
                                color: lowCount > 0
                                    ? Colors.red
                                    : Colors.green,
                                valueAsync: AsyncData(lowCount.toString()),
                                onTap: () =>
                                    context.go(AppRoutes.staffInventory),
                              )
                                  .animate(delay: 80.ms)
                                  .fadeIn()
                                  .slideY(begin: 0.08, end: 0);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Device status pill ────────────────────────────────────
                  deviceAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (data) {
                      final online = (data?['online'] as bool?) ?? false;
                      return AnimatedGlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        accentColor:
                            online ? Colors.green : cs.error,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: online
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : cs.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.kitchen_rounded,
                                size: 18,
                                color: online
                                    ? Colors.green.shade700
                                    : cs.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kitchen Terminal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'ESP32 device',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: online
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : cs.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: online
                                          ? Colors.green.shade600
                                          : cs.error,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    online ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: online
                                          ? Colors.green.shade700
                                          : cs.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 150.ms).fadeIn();
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Management tiles ──────────────────────────────────────
                  PremiumSectionHeader(
                    title: 'Management',
                    icon: Icons.manage_accounts_rounded,
                    accentColor: cs.tertiary,
                  ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 10),

                  if (isOwner || isCashier || isKitchen)
                    _NavTile(
                      icon: Icons.receipt_long_rounded,
                      label: 'Live Order Queue',
                      subtitle: 'View & advance queued orders',
                      onTap: () => context.go(AppRoutes.staffOrders),
                      index: 0,
                    ),
                  if (isOwner || isCashier)
                    _NavTile(
                      icon: Icons.menu_book_rounded,
                      label: 'Menu Management',
                      subtitle: 'Add, edit, or remove products',
                      onTap: () => context.go(AppRoutes.staffMenu),
                      index: 1,
                    ),
                  if (isOwner || isCashier)
                    _NavTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventory Tracking',
                      subtitle: 'Monitor stock & adjust manually',
                      onTap: () => context.go(AppRoutes.staffInventory),
                      index: 2,
                    ),
                  if (isOwner || isCashier)
                    _NavTile(
                      icon: Icons.history_rounded,
                      label: 'Order Status Feed',
                      subtitle: 'Full audit log of order events',
                      onTap: () => context.go(AppRoutes.staffOrderFeed),
                      index: 3,
                    ),
                  if (isOwner) ...[
                    _NavTile(
                      icon: Icons.group_rounded,
                      label: 'User Management',
                      subtitle: 'Manage roles and accounts',
                      onTap: () => context.go(AppRoutes.staffUsers),
                      index: 4,
                    ),
                    _NavTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Sales & Analytics',
                      subtitle: 'Revenue, trends & top products',
                      onTap: () => context.go(AppRoutes.staffAnalytics),
                      index: 5,
                    ),
                    _NavTile(
                      icon: Icons.rate_review_rounded,
                      label: 'Customer Feedback',
                      subtitle: 'Reviews & ratings',
                      onTap: () => context.go(AppRoutes.staffFeedback),
                      index: 6,
                    ),
                    _NavTile(
                      icon: Icons.receipt_rounded,
                      label: 'Sales & Transactions',
                      subtitle: 'Detailed receipt history',
                      onTap: () => context.go(AppRoutes.staffTransactions),
                      index: 7,
                    ),
                    _NavTile(
                      icon: Icons.local_offer_rounded,
                      label: 'Promotions',
                      subtitle: 'Manage discounts and codes',
                      onTap: () => context.go(AppRoutes.staffPromotions),
                      index: 8,
                    ),
                    _NavTile(
                      icon: Icons.devices_rounded,
                      label: 'Device Monitoring',
                      subtitle: 'Monitor ESP32 Kitchen Terminal',
                      onTap: () =>
                          context.go(AppRoutes.staffDeviceMonitoring),
                      index: 9,
                    ),
                    _NavTile(
                      icon: Icons.history_outlined,
                      label: 'Activity Logs',
                      subtitle: 'System-wide audit trail',
                      onTap: () => context.go(AppRoutes.staffActivityLogs),
                      index: 10,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon ⛅';
    return 'Good evening 🌙';
  }

  String _firstName(String name) {
    final parts = name.split('@').first.split(' ');
    return parts.first.isNotEmpty ? parts.first : name;
  }



  String _roleName(UserRole role) => switch (role) {
        UserRole.owner => 'Owner',
        UserRole.cashier => 'Cashier',
        UserRole.kitchen => 'Kitchen',
        UserRole.customer => 'Customer',
      };
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.color,
    required this.valueAsync,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AsyncValue<String> valueAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon badge ──────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),

          // ── Count ───────────────────────────────────────────────────────
          valueAsync.when(
            data: (v) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                v,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
              ),
            ),
            loading: () => const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Text('—'),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatLoading extends StatelessWidget {
  const _QuickStatLoading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_empty, size: 22),
          ),
          const SizedBox(height: 12),
          const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.index,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // ── Gradient icon circle ─────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primaryContainer,
                    cs.primaryContainer.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.primary),
            ),
          ],
        ),
      ).animate(delay: (50 + index * 40).ms).fadeIn().slideX(begin: 0.04, end: 0),
    );
  }
}
