import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/user_profile.dart';
import '../core/providers/firebase_providers.dart';
import '../core/widgets/cafeana_loading_screen.dart';
import '../core/widgets/cafeana_error_recovery_screen.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/public/pages/landing_page.dart';
import '../features/customer/pages/cart_page.dart';
import '../features/customer/pages/checkout_page.dart';
import '../features/customer/pages/customer_home_page.dart';
import '../features/customer/pages/customer_menu_page.dart';
import '../features/customer/pages/feedback_page.dart';
import '../features/customer/pages/community_feedback_page.dart';
import '../features/customer/pages/order_history_page.dart';
import '../features/customer/pages/order_tracking_page.dart';
import '../features/customer/pages/profile_page.dart';
import '../features/customer/shell/customer_shell.dart';
import '../features/staff/pages/staff_analytics_page.dart';
import '../features/staff/pages/staff_feedback_page.dart';
import '../features/staff/pages/staff_home_page.dart';
import '../features/staff/pages/staff_inventory_page.dart';
import '../features/staff/pages/staff_menu_page.dart';
import '../features/staff/pages/staff_order_feed_page.dart';
import '../features/staff/pages/staff_orders_page.dart';
import '../features/staff/pages/staff_promotions_page.dart';
import '../features/staff/pages/staff_transactions_page.dart';
import '../features/staff/pages/staff_users_page.dart';
import '../features/staff/pages/staff_device_monitoring_page.dart';
import '../features/staff/pages/staff_activity_logs_page.dart';
import '../features/staff/shell/staff_shell.dart';

// ── Route path constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  // Public
  static const landing = '/';
  static const loading = '/loading';

  // Auth
  static const login = '/login';

  static const register = '/register'; // handled inside LoginPage via tab
  static const verifyEmail = '/verify-email';

  // Customer — shell tabs
  static const customerHome = '/customer/home';
  static const customerMenu = '/customer/menu';
  static const customerCart = '/customer/cart';
  static const customerOrders = '/customer/orders';
  static const customerProfile = '/customer/profile';

  // Customer — full-screen (outside shell)
  static const customerCheckout = '/customer/checkout';
  static String customerOrder(String orderId) => '/customer/order/$orderId';
  static String customerFeedback(String orderId) =>
      '/customer/feedback/$orderId';
  static const customerCommunityFeedback = '/customer/community-feedback';

  // Staff
  static const staffHome = '/staff/home';
  static const staffOrders = '/staff/orders';
  static const staffMenu = '/staff/menu';
  static const staffInventory = '/staff/inventory';
  static const staffOrderFeed = '/staff/feed';
  static const staffAnalytics = '/staff/analytics';
  static const staffFeedback = '/staff/feedback';
  static const staffUsers = '/staff/users';
  static const staffTransactions = '/staff/transactions';
  static const staffPromotions = '/staff/promotions';
  static const staffDeviceMonitoring = '/staff/devices';
  static const staffActivityLogs = '/staff/logs';
}

// ── Router provider ───────────────────────────────────────────────────────────

/// Provides the app's [GoRouter] instance.
///
/// Redirect logic:
/// 1. Not authenticated → `/login`.
/// 2. Authenticated but on login page → role-based home.
/// 3. Wrong-role route → corrected home.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.landing,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) async {
      final authAsync = ref.read(authStateChangesProvider);
      final location = state.matchedLocation;
      final isOnLoadingPage = location == AppRoutes.loading;
      final isOnLoginPage = location == AppRoutes.login;
      final isOnLandingPage = location == AppRoutes.landing;

      // 0. While Firebase Auth is restoring session on initial boot:
      if (authAsync.isLoading) {
        // If on a protected route, hold on /loading to prevent premature landing kick
        final isProtected = location.startsWith('/customer') || location.startsWith('/staff');
        if (isProtected) {
          final target = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.loading}?from=$target&msg=${Uri.encodeComponent('Restoring session...')}';
        }
        return null;
      }

      final user = authAsync.valueOrNull;

      // 1. Not signed in → can only be on landing or login.
      if (user == null) {
        if (isOnLandingPage || isOnLoginPage) return null;
        return AppRoutes.landing;
      }

      // 2. Not verified (and using email provider) → redirect to verify-email.
      if (!user.emailVerified && user.providerData.any((p) => p.providerId == 'password')) {
        if (location != AppRoutes.verifyEmail) {
          return AppRoutes.verifyEmail;
        }
        return null;
      }
      
      // If they are on verifyEmail but already verified, redirect to role home
      if (location == AppRoutes.verifyEmail) {
        return _roleRedirect(ref, user);
      }

      // 3. If currently on loading screen, check if profile is ready
      if (isOnLoadingPage) {
        final profileAsync = ref.read(userProfileProvider(user.uid));
        if (profileAsync.isLoading) {
          return null;
        }
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) {
          final decodedFrom = Uri.decodeComponent(from);
          if (decodedFrom.startsWith('/customer') || decodedFrom.startsWith('/staff')) {
            return decodedFrom;
          }
        }
        return _roleRedirect(ref, user);
      }

      // 4. Signed in but on public page → redirect to correct shell.
      if (isOnLoginPage || isOnLandingPage) {
        return _roleRedirect(ref, user);
      }

      // 5. On a customer route but role is staff (or vice versa) → redirect.
      if (location.startsWith('/customer') || location.startsWith('/staff')) {
        final redirect = await _roleRedirect(ref, user);
        if (redirect != null && !redirect.startsWith(AppRoutes.loading)) {
          final expectedPrefix =
              location.startsWith('/customer') ? '/customer' : '/staff';
          if (!redirect.startsWith(expectedPrefix)) return redirect;
        }
      }

      // 6. Granular staff role permissions
      if (location.startsWith('/staff')) {
        final profile = ref.read(userProfileProvider(user.uid)).valueOrNull;
        if (profile != null) {
          final role = profile.role;
          
          if (role == UserRole.kitchen) {
            // Kitchen can only access Orders
            if (location != AppRoutes.staffOrders) {
              return AppRoutes.staffOrders;
            }
          } else if (role == UserRole.cashier) {
            // Cashier can access Home, Orders, Feed, Menu, and Inventory
            if (location != AppRoutes.staffHome && 
                location != AppRoutes.staffOrders && 
                location != AppRoutes.staffOrderFeed &&
                location != AppRoutes.staffMenu &&
                location != AppRoutes.staffInventory) {
              return AppRoutes.staffHome;
            }
          }
          // Owner has full access
        }
      }

      return null;
    },
    routes: [
      // ── Public ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.landing,
        name: 'landing',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: AppRoutes.loading,
        name: 'loading',
        builder: (context, state) {
          final msg = state.uri.queryParameters['msg'] ?? 'Brewing your experience...';
          return CafeanaLoadingScreen(
            message: msg,
            onRetry: () => context.go(AppRoutes.landing),
          );
        },
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        name: 'verifyEmail',
        builder: (context, state) => const VerifyEmailPage(),
      ),

      // ── Customer shell (bottom nav tabs) ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.customerHome,
            name: 'customer-home',
            builder: (context, state) => const CustomerHomePage(),
          ),
          GoRoute(
            path: AppRoutes.customerMenu,
            name: 'customer-menu',
            builder: (context, state) => const CustomerMenuPage(),
          ),
          GoRoute(
            path: AppRoutes.customerCart,
            name: 'customer-cart',
            builder: (context, state) => const CartPage(),
          ),
          GoRoute(
            path: AppRoutes.customerOrders,
            name: 'customer-orders',
            builder: (context, state) => const OrderHistoryPage(),
          ),
          GoRoute(
            path: AppRoutes.customerProfile,
            name: 'customer-profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Customer full-screen routes (no shell / nav bar) ──────────────────
      GoRoute(
        path: AppRoutes.customerCheckout,
        name: 'customer-checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/customer/order/:orderId',
        name: 'customer-order-tracking',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderTrackingPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/customer/feedback/:orderId',
        name: 'customer-feedback',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return FeedbackPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.customerCommunityFeedback,
        name: 'customer-community-feedback',
        builder: (context, state) => CommunityFeedbackPage(
          initialProduct: state.uri.queryParameters['product'],
        ),
      ),

      // ── Staff shell ───────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => StaffShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.staffHome,
            name: 'staff-home',
            builder: (context, state) => const StaffHomePage(),
          ),
          GoRoute(
            path: AppRoutes.staffOrders,
            name: 'staff-orders',
            builder: (context, state) => const StaffOrdersPage(),
          ),
          GoRoute(
            path: AppRoutes.staffMenu,
            name: 'staff-menu',
            builder: (context, state) => const StaffMenuPage(),
          ),
          GoRoute(
            path: AppRoutes.staffInventory,
            name: 'staff-inventory',
            builder: (context, state) => const StaffInventoryPage(),
          ),
          GoRoute(
            path: AppRoutes.staffOrderFeed,
            name: 'staff-order-feed',
            builder: (context, state) => const StaffOrderFeedPage(),
          ),
          GoRoute(
            path: AppRoutes.staffAnalytics,
            name: 'staff-analytics',
            builder: (context, state) => const StaffAnalyticsPage(),
          ),
          GoRoute(
            path: AppRoutes.staffFeedback,
            name: 'staff-feedback',
            builder: (context, state) => const StaffFeedbackPage(),
          ),
          GoRoute(
            path: AppRoutes.staffUsers,
            name: 'staff-users',
            builder: (context, state) => const StaffUsersPage(),
          ),
          GoRoute(
            path: AppRoutes.staffTransactions,
            name: 'staff-transactions',
            builder: (context, state) => const StaffTransactionsPage(),
          ),
          GoRoute(
            path: AppRoutes.staffPromotions,
            name: 'staff-promotions',
            builder: (context, state) => const StaffPromotionsPage(),
          ),
          GoRoute(
            path: AppRoutes.staffDeviceMonitoring,
            name: 'staff-device-monitoring',
            builder: (context, state) => const StaffDeviceMonitoringPage(),
          ),
          GoRoute(
            path: AppRoutes.staffActivityLogs,
            name: 'staff-activity-logs',
            builder: (context, state) => const StaffActivityLogsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => CafeanaErrorRecoveryScreen(
      errorMessage: state.error?.toString(),
      onRetry: () => context.go(AppRoutes.landing),
    ),
  );
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns the correct initial route for [user] based on their Firestore role.
///
/// Returns [AppRoutes.loading] while the profile is still loading.
Future<String?> _roleRedirect(Ref ref, User user) async {
  final profileAsync = ref.read(userProfileProvider(user.uid));
  if (profileAsync.isLoading) {
    return '${AppRoutes.loading}?msg=${Uri.encodeComponent('Preparing your profile...')}';
  }

  final profile = profileAsync.valueOrNull;
  if (profile == null) return null;

  return profile.role.isStaff
      ? (profile.role == UserRole.kitchen ? AppRoutes.staffOrders : AppRoutes.staffHome)
      : AppRoutes.customerHome;
}


// ── Auth change notifier ──────────────────────────────────────────────────────

class _AuthChangeNotifier extends ChangeNotifier {
  ProviderSubscription? _profileSub;

  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, next) {
      final user = next.valueOrNull;
      
      _profileSub?.close();
      _profileSub = null;
      
      if (user != null) {
        _profileSub = ref.listen(userProfileProvider(user.uid), (_, __) {
          notifyListeners();
        });
      }
      
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _profileSub?.close();
    super.dispose();
  }
}

