import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/firebase_providers.dart';
import '../widgets/device_status_banner.dart';

class _StaffNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _StaffNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}

/// Persistent navigation shell for the staff-facing app section.
class StaffShell extends ConsumerStatefulWidget {
  const StaffShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profile = user != null ? ref.watch(userProfileProvider(user.uid)).valueOrNull : null;
    if (profile == null) {
      return Scaffold(body: widget.child); // Do not show nav bar while loading
    }
    final role = profile.role;
    final isOwner = role == UserRole.owner;
    final isCashier = role == UserRole.cashier;
    final isKitchen = role == UserRole.kitchen;

    // Build the list of allowed destinations
    final destinations = <_StaffNavDestination>[
      if (isOwner || isCashier)
        const _StaffNavDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Home',
          route: AppRoutes.staffHome,
        ),
      if (isOwner || isCashier || isKitchen)
        const _StaffNavDestination(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Queue',
          route: AppRoutes.staffOrders,
        ),
      if (isOwner || isCashier)
        const _StaffNavDestination(
          icon: Icons.notifications_active_outlined,
          selectedIcon: Icons.notifications_active,
          label: 'Feed',
          route: AppRoutes.staffOrderFeed,
        ),
      if (isOwner || isCashier)
        const _StaffNavDestination(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          label: 'Menu',
          route: AppRoutes.staffMenu,
        ),
      if (isOwner || isCashier)
        const _StaffNavDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Inventory',
          route: AppRoutes.staffInventory,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Analytics',
          route: AppRoutes.staffAnalytics,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.rate_review_outlined,
          selectedIcon: Icons.rate_review,
          label: 'Feedback',
          route: AppRoutes.staffFeedback,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          label: 'Users',
          route: AppRoutes.staffUsers,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Sales',
          route: AppRoutes.staffTransactions,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.local_offer_outlined,
          selectedIcon: Icons.local_offer,
          label: 'Promos',
          route: AppRoutes.staffPromotions,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.devices_outlined,
          selectedIcon: Icons.devices,
          label: 'Devices',
          route: AppRoutes.staffDeviceMonitoring,
        ),
      if (isOwner)
        const _StaffNavDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: 'Logs',
          route: AppRoutes.staffActivityLogs,
        ),
    ];

    final loc = GoRouterState.of(context).matchedLocation;

    // Find the currently selected index, default to 0
    int selectedIndex = destinations.indexWhere((d) => loc.startsWith(d.route));
    if (selectedIndex == -1) selectedIndex = 0;

    if (isKitchen) {
      return Scaffold(
        body: Column(
          children: [
            const DeviceStatusBanner(),
            Expanded(
              child: widget.child,
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Complementary rail colours — espresso anchor with caramel accents
    final railBg = isDark ? const Color(0xFF1A1210) : const Color(0xFFF9F6F0);
    final selectedColor = isDark ? const Color(0xFFDCA87C) : const Color(0xFFC88D5D);
    final unselectedColor = isDark ? const Color(0xFF8C7B72) : const Color(0xFF8C8077);
    final borderColor = isDark ? const Color(0xFFDCA87C).withValues(alpha: 0.18) : const Color(0xFFEBE3DB);

    return Scaffold(
      body: Row(
        children: [
            // ── Complementary Navigation Rail ───────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isVisible ? 72 : 0, // 72 is the default width of NavigationRail
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: railBg,
                      border: Border(
                        right: BorderSide(color: borderColor, width: 1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(4, 0),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: IntrinsicHeight(
                              child: NavigationRail(
                                selectedIndex: selectedIndex,
                                onDestinationSelected: (index) {
                                  if (index >= 0 && index < destinations.length) {
                                    context.go(destinations[index].route);
                                  }
                                },
                                backgroundColor: Colors.transparent,
                                labelType: NavigationRailLabelType.all,
                                selectedIconTheme: IconThemeData(color: selectedColor, size: 24),
                                unselectedIconTheme: IconThemeData(color: unselectedColor, size: 22),
                                selectedLabelTextStyle: TextStyle(
                                  color: selectedColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                unselectedLabelTextStyle: TextStyle(
                                  color: unselectedColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                                useIndicator: true,
                                indicatorColor: const Color(0xFFDCA87C).withValues(alpha: 0.20),
                                destinations: destinations.map((d) {
                                  return NavigationRailDestination(
                                    icon: Icon(d.icon),
                                    selectedIcon: Icon(d.selectedIcon),
                                    label: Text(d.label),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // ── Page content ────────────────────────────────────────────────
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    if (_isVisible) setState(() => _isVisible = false);
                  } else if (notification.direction == ScrollDirection.forward) {
                    if (!_isVisible) setState(() => _isVisible = true);
                  }
                  return false;
                },
                child: Column(
                  children: [
                    const DeviceStatusBanner(),
                    Expanded(
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}
