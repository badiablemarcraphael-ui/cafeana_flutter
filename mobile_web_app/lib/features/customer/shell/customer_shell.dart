import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/widgets/nav_toggle_handle.dart';

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
  /// Whether the bottom nav bar is expanded. Toggled by the user via the
  /// handle; it no longer auto-hides on scroll.
  bool _isOpen = true;

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Complementary nav bar colours ──────────────────────────────────────────
    // Light: deep espresso base anchors the warm gradient above it.
    // Dark: rich dark-roast base with subtle caramel border.
    final navBg = isDark
        ? const Color(0xFF1A1210) // deep dark roast
        : const Color(0xFFF9F6F0); // match light background top color
    final selectedColor = isDark
        ? const Color(0xFFDCA87C) // warm caramel glow
        : const Color(0xFFC88D5D); // caramel accent
    final unselectedColor = isDark
        ? const Color(0xFF8C7B72) // muted warm grey
        : const Color(0xFF8C8077); // outline color
    final indicatorColor = isDark
        ? const Color(0xFFDCA87C).withValues(alpha: 0.18)
        : const Color(0xFFC88D5D).withValues(alpha: 0.15);
    final borderColor = isDark
        ? const Color(0xFFDCA87C).withValues(alpha: 0.15)
        : const Color(0xFFEBE3DB); // match light background bottom color

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = 68.0 + bottomInset;

    return Scaffold(
      extendBody: false,
      body: Stack(
        children: [
          Positioned.fill(child: widget.child),
          // ── Open / close handle, attached to the top of the nav bar ──────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: NavToggleHandle.animationDuration,
              curve: Curves.easeInOutCubic,
              // When the bar is closed, keep the handle above the system
              // gesture area / home indicator.
              padding: EdgeInsets.only(bottom: _isOpen ? 0 : bottomInset),
              child: Center(
                child: NavToggleHandle(
                  isOpen: _isOpen,
                  onTap: () => setState(() => _isOpen = !_isOpen),
                  edge: NavHandleEdge.bottom,
                  backgroundColor: navBg,
                  borderColor: borderColor,
                  iconColor: selectedColor,
                ),
              ),
            ),
          ),
        ],
      ),
      // Slides down out of view when closed, and back up when opened.
      bottomNavigationBar: ClipRect(
        child: AnimatedAlign(
          duration: NavToggleHandle.animationDuration,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          heightFactor: _isOpen ? 1 : 0,
          child: SizedBox(
            height: navHeight,
            child: Container(
              decoration: BoxDecoration(
                color: navBg,
                border: Border(top: BorderSide(color: borderColor, width: 1.5)),
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
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      color: selectedColor,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.menu_book_outlined,
                      color: unselectedColor,
                    ),
                    selectedIcon: Icon(
                      Icons.menu_book_rounded,
                      color: selectedColor,
                    ),
                    label: 'Menu',
                  ),
                  NavigationDestination(
                    icon: cartCount > 0
                        ? Badge(
                            label: Text('$cartCount'),
                            child: Icon(
                              Icons.shopping_cart_outlined,
                              color: unselectedColor,
                            ),
                          )
                        : Icon(
                            Icons.shopping_cart_outlined,
                            color: unselectedColor,
                          ),
                    selectedIcon: cartCount > 0
                        ? Badge(
                            label: Text('$cartCount'),
                            child: Icon(
                              Icons.shopping_cart_rounded,
                              color: selectedColor,
                            ),
                          )
                        : Icon(
                            Icons.shopping_cart_rounded,
                            color: selectedColor,
                          ),
                    label: 'Cart',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.receipt_long_outlined,
                      color: unselectedColor,
                    ),
                    selectedIcon: Icon(
                      Icons.receipt_long_rounded,
                      color: selectedColor,
                    ),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline, color: unselectedColor),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: selectedColor,
                    ),
                    label: 'Profile',
                  ),
                ],
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
