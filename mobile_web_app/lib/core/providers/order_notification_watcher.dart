import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import 'firebase_providers.dart';
import 'order_providers.dart';
import 'staff_providers.dart';

/// Riverpod provider that keeps the Order Notification Watcher running across the app.
final orderNotificationWatcherProvider =
    Provider<OrderNotificationWatcher>((ref) {
  final watcher = OrderNotificationWatcher(ref);
  ref.onDispose(() => watcher.dispose());
  return watcher;
});

/// Watches active customer and staff orders in real-time, popping system/taskbar
/// notifications whenever an order status changes or a new order arrives.
class OrderNotificationWatcher {
  OrderNotificationWatcher(this.ref) {
    _init();
  }

  final Ref ref;
  ProviderSubscription? _authSub;
  ProviderSubscription? _customerSub;
  ProviderSubscription? _staffSub;

  final Map<String, String> _lastKnownCustomerStatus = {};
  final Set<String> _knownStaffOrderIds = {};
  bool _isFirstCustomerLoad = true;
  bool _isFirstStaffLoad = true;

  void _init() {
    // 1. Initialize notification service (channels, permissions, service worker)
    NotificationService.instance.initialize();

    // 2. Listen to notification taps to navigate directly to order tracking
    NotificationService.onNotificationOrderTapped.addListener(_handleOrderTap);

    // 2. Watch Authentication state changes
    _authSub = ref.listen(authStateChangesProvider, (_, next) {
      final user = next.asData?.value;
      if (user != null) {
        NotificationService.instance.saveTokenToFirestore(user.uid);
        _watchCustomerOrders(user.uid);
        _watchStaffOrders(user.uid);
      } else {
        _customerSub?.close();
        _staffSub?.close();
        _lastKnownCustomerStatus.clear();
        _knownStaffOrderIds.clear();
      }
    }, fireImmediately: true);
  }

  void _watchCustomerOrders(String uid) {
    _customerSub?.close();
    _customerSub = ref.listen(
      customerOrdersProvider(uid),
      (_, next) {
        final orders = next.valueOrNull;
        if (orders == null) return;

        for (final o in orders) {
          final previousStatus = _lastKnownCustomerStatus[o.id];
          final isLiveOrder = o.status == OrderStatus.queued ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.ready;

          if (previousStatus != null && previousStatus != o.status.name) {
            // Status changed on active order! Automatically pop notification
            NotificationService.instance.showOrderStatusNotification(
              orderNumber: o.orderNumber,
              status: o.status.name,
              orderId: o.id,
            );
          } else if (previousStatus == null) {
            // New order, or active order on initial load
            if (!_isFirstCustomerLoad || isLiveOrder) {
              NotificationService.instance.showOrderStatusNotification(
                orderNumber: o.orderNumber,
                status: o.status.name,
                orderId: o.id,
              );
            }
          }
          _lastKnownCustomerStatus[o.id] = o.status.name;
        }
        _isFirstCustomerLoad = false;
      },
      fireImmediately: true,
    );
  }

  void _watchStaffOrders(String uid) {
    final profileAsync = ref.read(userProfileProvider(uid));
    final profile = profileAsync.valueOrNull;
    if (profile?.role.isStaff == true) {
      _staffSub?.close();
      _staffSub = ref.listen(
        staffActiveOrdersProvider,
        (_, next) {
          final orders = next.valueOrNull;
          if (orders == null) return;

          if (_isFirstStaffLoad) {
            for (final o in orders) {
              _knownStaffOrderIds.add(o.id);
            }
            _isFirstStaffLoad = false;
            return;
          }

          for (final o in orders) {
            if (!_knownStaffOrderIds.contains(o.id) &&
                o.status == OrderStatus.queued) {
              NotificationService.instance.showNotification(
                title: 'New Order Incoming! 🔔 (#${o.orderNumber})',
                body:
                    'Order #${o.orderNumber} is queued for kitchen preparation.',
                tag: 'staff-order-${o.orderNumber}',
                payload: o.id,
              );
              _knownStaffOrderIds.add(o.id);
            }
          }
        },
        fireImmediately: true,
      );
    }
  }

  void _handleOrderTap() {
    final orderId = NotificationService.onNotificationOrderTapped.value;
    if (orderId != null && orderId.isNotEmpty) {
      try {
        debugPrint('[OrderNotificationWatcher] Navigating to /customer/order/$orderId');
        final router = ref.read(routerProvider);
        router.push('/customer/order/$orderId');
        // Reset the tapped value after navigation
        NotificationService.onNotificationOrderTapped.value = null;
      } catch (e) {
        debugPrint('[OrderNotificationWatcher] Tap navigation error: $e');
      }
    }
  }

  void dispose() {
    NotificationService.onNotificationOrderTapped.removeListener(_handleOrderTap);
    _authSub?.close();
    _customerSub?.close();
    _staffSub?.close();
  }
}
