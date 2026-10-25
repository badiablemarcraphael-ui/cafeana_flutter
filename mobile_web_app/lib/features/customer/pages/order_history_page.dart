import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/order_providers.dart';

/// Displays all past orders for the signed-in customer, newest first.
class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  String _selectedFilter = 'All'; // 'All', 'Completed', 'Cancelled', 'Active'

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final ordersAsync = ref.watch(customerOrdersProvider(uid));
    final cs = Theme.of(context).colorScheme;

    const filterOptions = ['All', 'Completed', 'Cancelled', 'Active'];

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const _EmptyOrders();
          }

          final filtered = orders.where((order) {
            switch (_selectedFilter) {
              case 'Completed':
                return order.status == OrderStatus.completed ||
                    order.status == OrderStatus.received;
              case 'Cancelled':
                return order.status == OrderStatus.cancelled;
              case 'Active':
                return order.status == OrderStatus.queued ||
                    order.status == OrderStatus.preparing ||
                    order.status == OrderStatus.ready;
              default:
                return true;
            }
          }).toList();

          return Column(
            children: [
              // ── Filter Chips Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filterOptions.map((opt) {
                      final isSelected = _selectedFilter == opt;
                      Color optColor;
                      switch (opt) {
                        case 'Completed':
                          optColor = Colors.green;
                          break;
                        case 'Cancelled':
                          optColor = Colors.red;
                          break;
                        case 'Active':
                          optColor = Colors.orange;
                          break;
                        default:
                          optColor = cs.primary;
                      }

                      final count = orders.where((o) {
                        switch (opt) {
                          case 'Completed':
                            return o.status == OrderStatus.completed ||
                                o.status == OrderStatus.received;
                          case 'Cancelled':
                            return o.status == OrderStatus.cancelled;
                          case 'Active':
                            return o.status == OrderStatus.queued ||
                                o.status == OrderStatus.preparing ||
                                o.status == OrderStatus.ready;
                          default:
                            return true;
                        }
                      }).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? optColor
                                  : optColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: optColor.withValues(
                                    alpha: isSelected ? 1.0 : 0.35),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : optColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : optColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : optColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 56,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No $_selectedFilter orders found',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (_selectedFilter != 'All')
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _selectedFilter = 'All'),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('View All Orders'),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _OrderHistoryTile(order: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Order tile ────────────────────────────────────────────────────────────────

class _OrderHistoryTile extends ConsumerWidget {
  const _OrderHistoryTile({required this.order});
  final CafeOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted =
        order.status == OrderStatus.completed || order.status == OrderStatus.received;
    final feedbackAsync = ref.watch(feedbackExistsProvider(order.id));
    final hasFeedback = feedbackAsync.valueOrNull ?? false;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.customerOrder(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Order #${order.orderNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),

              // ── Date ─────────────────────────────────────────────────────
              Text(
                _formatDate(order.createdAt),
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),

              // ── Items summary ─────────────────────────────────────────────
              Text(
                order.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // ── Footer ───────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    '₱${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),

                  // Feedback CTA for completed orders without feedback
                  if (isCompleted && !hasFeedback)
                    TextButton.icon(
                      onPressed: () => context
                          .push(AppRoutes.customerFeedback(order.id)),
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('Rate'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4)),
                    ),
                  if (isCompleted && hasFeedback)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text('Rated',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),

                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      OrderStatus.queued => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      OrderStatus.preparing => (cs.secondaryContainer, cs.onSecondaryContainer),
      OrderStatus.ready => (cs.primaryContainer, cs.onPrimaryContainer),
      OrderStatus.received => (Colors.green[50]!, Colors.green[800]!),
      OrderStatus.completed => (Colors.green[100]!, Colors.green[900]!),
      OrderStatus.cancelled => (Colors.red[100]!, Colors.red[900]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No orders yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your completed orders will appear here.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
