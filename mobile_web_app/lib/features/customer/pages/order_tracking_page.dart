import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/premium_section_header.dart';
import '../../../core/services/notification_service.dart';

/// Real-time order tracking screen.
///
/// Streams the order document and shows:
/// - The status stepper with live status
/// - Ordered items list
/// - "Mark as Received" CTA (when status == `ready`)
/// - "Leave Feedback" CTA (when status == `completed`)
class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          return _OrderDetail(order: order);
        },
      ),
    );
  }
}

// ── Order detail body ─────────────────────────────────────────────────────────

class _OrderDetail extends ConsumerStatefulWidget {
  const _OrderDetail({required this.order});
  final CafeOrder order;

  @override
  ConsumerState<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends ConsumerState<_OrderDetail> {
  String? _lastNotifiedStatus;

  @override
  void initState() {
    super.initState();
    _triggerAutoNotification(widget.order);
  }

  @override
  void didUpdateWidget(covariant _OrderDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status) {
      _triggerAutoNotification(widget.order);
    }
  }

  void _triggerAutoNotification(CafeOrder order) {
    if (_lastNotifiedStatus != order.status.name) {
      _lastNotifiedStatus = order.status.name;
      NotificationService.instance.showOrderStatusNotification(
        orderNumber: order.orderNumber,
        status: order.status.name,
        orderId: order.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final cs = Theme.of(context).colorScheme;
    final isReady = order.status == OrderStatus.ready;
    final isCompleted = order.status == OrderStatus.completed || order.status == OrderStatus.received;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        AnimatedGlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(order.createdAt),
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _PaymentChip(status: order.paymentStatus),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.06, end: 0),

        // ── Push / Taskbar Notification prompt & test ─────────────────────────
        _OrderNotificationBanner(orderNumber: order.orderNumber),

        const SizedBox(height: 16),

        // ── Status card ───────────────────────────────────────────────────────
        _StatusCard(order: order).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06, end: 0),

        const SizedBox(height: 20),

        // ── Items ─────────────────────────────────────────────────────────────
        PremiumSectionHeader(
          title: 'Ordered Items',
          icon: Icons.fastfood_rounded,
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 10),

        AnimatedGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}×',
                              style: TextStyle(
                                fontSize: 11,
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
                                item.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (item.customizations.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    item.customizations.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(', '),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${item.lineTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  )),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(
                        colors: [Color(0xFF6D4C41), Color(0xFFF59E0B)],
                      ).createShader(bounds),
                      child: Text(
                        '₱${order.total.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 18,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms),

        if (order.note != null && order.note!.isNotEmpty) ...[
          const SizedBox(height: 12),
          AnimatedGlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.note!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ── CTAs ──────────────────────────────────────────────────────────────
        if (isReady) ...[
          GradientButton(
            onPressed: () async {
              await ref.read(markReceivedProvider)(order.id);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Mark as Received'),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08, end: 0),
        ],

        if (isCompleted) ...[
          GradientButton(
            onPressed: () =>
                context.push(AppRoutes.customerFeedback(order.id)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.star_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Leave Feedback'),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.customerOrders),
              icon: const Icon(Icons.history_rounded),
              label: const Text('View Order History'),
            ),
          ).animate().fadeIn(delay: 480.ms),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Premium status card ───────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});
  final CafeOrder order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPulsing = order.status == OrderStatus.queued ||
        order.status == OrderStatus.preparing;

    final statusData = _getStatusData(order.status, cs);

    return AnimatedGlassCard(
      padding: const EdgeInsets.all(20),
      accentColor: statusData.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Status icon with optional pulse ─────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isPulsing)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusData.color.withValues(alpha: 0.2),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.5, 1.5),
                          duration: 1400.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeOut(duration: 1400.ms),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusData.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusData.icon,
                        color: statusData.color, size: 22),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.status.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: statusData.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusData.message,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Status stepper ───────────────────────────────────────────────
          _PremiumStatusStepper(currentStatus: order.status),
        ],
      ),
    );
  }

  _StatusData _getStatusData(OrderStatus status, ColorScheme cs) {
    return switch (status) {
      OrderStatus.queued => _StatusData(
          icon: Icons.access_time_rounded,
          color: Colors.orange,
          message: 'Your order is in the queue. Hang tight!',
        ),
      OrderStatus.preparing => _StatusData(
          icon: Icons.soup_kitchen_outlined,
          color: cs.primary,
          message: 'Our barista is crafting your order ☕',
        ),
      OrderStatus.ready => _StatusData(
          icon: Icons.done_all_rounded,
          color: Colors.green,
          message: 'Your order is ready for pickup! 🎉',
        ),
      OrderStatus.received => _StatusData(
          icon: Icons.shopping_bag_outlined,
          color: Colors.blue,
          message: "You've received your order. Enjoy!",
        ),
      OrderStatus.completed => _StatusData(
          icon: Icons.star_rounded,
          color: Colors.purple,
          message: 'Order completed. How was it?',
        ),
      OrderStatus.cancelled => _StatusData(
          icon: Icons.cancel_outlined,
          color: Colors.red,
          message: 'Order cancelled.',
        ),
    };
  }
}

class _StatusData {
  final IconData icon;
  final Color color;
  final String message;
  const _StatusData(
      {required this.icon, required this.color, required this.message});
}

// ── Premium status stepper ────────────────────────────────────────────────────

class _PremiumStatusStepper extends StatelessWidget {
  const _PremiumStatusStepper({required this.currentStatus});
  final OrderStatus currentStatus;

  static const _steps = [
    (OrderStatus.queued, Icons.access_time_rounded, 'Queued'),
    (OrderStatus.preparing, Icons.soup_kitchen_outlined, 'Preparing'),
    (OrderStatus.ready, Icons.done_all_rounded, 'Ready'),
    (OrderStatus.received, Icons.shopping_bag_outlined, 'Received'),
    (OrderStatus.completed, Icons.star_rounded, 'Done'),
  ];

  int get _currentIndex {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == currentStatus) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idx = _currentIndex;

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIdx = i ~/ 2;
          final isPassed = stepIdx < idx;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: isPassed
                    ? LinearGradient(
                        colors: [cs.primary, cs.primary.withValues(alpha: 0.5)],
                      )
                    : null,
                color: isPassed ? null : cs.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final (status, icon, label) = _steps[stepIdx];
        final isDone = stepIdx < idx;
        final isActive = stepIdx == idx;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              width: isActive ? 36 : 28,
              height: isActive ? 36 : 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDone || isActive
                    ? LinearGradient(
                        colors: [
                          cs.primary,
                          cs.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDone || isActive
                    ? null
                    : cs.surfaceContainerHighest,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                isDone ? Icons.check_rounded : icon,
                color: isDone || isActive ? Colors.white : cs.onSurfaceVariant,
                size: isActive ? 18 : 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Payment chip ──────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPaid
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 12,
            color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? 'Paid' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification Banner widget (Automatic live notification status) ──────────

class _OrderNotificationBanner extends StatefulWidget {
  const _OrderNotificationBanner({required this.orderNumber});
  final int orderNumber;

  @override
  State<_OrderNotificationBanner> createState() =>
      _OrderNotificationBannerState();
}

class _OrderNotificationBannerState extends State<_OrderNotificationBanner> {
  @override
  void initState() {
    super.initState();
    // Proactively ensure notification permissions are active without requiring manual tap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Automatic Live Alerts Active',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Taskbar & mobile notifications pop automatically as kitchen updates your order.',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
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
