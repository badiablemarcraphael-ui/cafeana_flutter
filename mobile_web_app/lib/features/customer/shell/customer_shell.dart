import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers/cart_provider.dart';
/// Persistent navigation shell for the customer-facing app section.
///
/// Provides a 5-tab bottom navigation bar:
/// - Home / Menu / Cart / Orders / Profile
class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Complementary nav bar colours ──────────────────────────────────────────
    // Light: deep espresso base anchors the warm gradient above it.
    // Dark: rich dark-roast base with subtle caramel border.
    final navBg = isDark
        ? const Color(0xFF1A1210)      // deep dark roast
        : const Color(0xFFF9F6F0);     // match light background top color
    final selectedColor = isDark
        ? const Color(0xFFDCA87C)      // warm caramel glow
        : const Color(0xFFC88D5D);     // caramel accent
    final unselectedColor = isDark
        ? const Color(0xFF8C7B72)      // muted warm grey
        : const Color(0xFF8C8077);     // outline color
    final indicatorColor = isDark
        ? const Color(0xFFDCA87C).withValues(alpha: 0.18)
        : const Color(0xFFC88D5D).withValues(alpha: 0.15);
    final borderColor = isDark
        ? const Color(0xFFDCA87C).withValues(alpha: 0.15)
        : const Color(0xFFEBE3DB);     // match light background bottom color

    final navHeight = 68.0 + MediaQuery.paddingOf(context).bottom;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.reverse) {
          if (_isVisible) setState(() => _isVisible = false);
        } else if (notification.direction == ScrollDirection.forward) {
          if (!_isVisible) setState(() => _isVisible = true);
        }
        return false;
      },
      child: Scaffold(
        extendBody: false,
        body: widget.child,
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isVisible ? navHeight : 0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: navHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: navBg,
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: _selectedIndex(context),
                  onDestinationSelected: (index) => _onTap(context, index),
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  height: 68,
                  indicatorColor: indicatorColor,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, color: unselectedColor),
                      selectedIcon: Icon(Icons.home_rounded, color: selectedColor),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined, color: unselectedColor),
                      selectedIcon: Icon(Icons.menu_book_rounded, color: selectedColor),
                      label: 'Menu',
                    ),
                    NavigationDestination(
                      icon: cartCount > 0
                          ? Badge(label: Text('$cartCount'), child: Icon(Icons.shopping_cart_outlined, color: unselectedColor))
                          : Icon(Icons.shopping_cart_outlined, color: unselectedColor),
                      selectedIcon: cartCount > 0
                          ? Badge(label: Text('$cartCount'), child: Icon(Icons.shopping_cart_rounded, color: selectedColor))
                          : Icon(Icons.shopping_cart_rounded, color: selectedColor),
                      label: 'Cart',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined, color: unselectedColor),
                      selectedIcon: Icon(Icons.receipt_long_rounded, color: selectedColor),
                      label: 'Orders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline, color: unselectedColor),
                      selectedIcon: Icon(Icons.person_rounded, color: selectedColor),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.customerMenu)) return 1;
    if (location.startsWith(AppRoutes.customerCart)) return 2;
    if (location.startsWith(AppRoutes.customerOrders)) return 3;
    if (location.startsWith(AppRoutes.customerProfile)) return 4;
    return 0; // customerHome
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.customerHome);
      case 1:
        context.go(AppRoutes.customerMenu);
      case 2:
        context.go(AppRoutes.customerCart);
      case 3:
        context.go(AppRoutes.customerOrders);
      case 4:
        context.go(AppRoutes.customerProfile);
    }
  }
}
