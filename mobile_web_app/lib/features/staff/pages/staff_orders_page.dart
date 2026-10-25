import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/router.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/models/order.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_service.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';

/// Staff orders queue screen with search, status filter chips, and pagination.
class StaffOrdersPage extends ConsumerStatefulWidget {
  const StaffOrdersPage({super.key});

  @override
  ConsumerState<StaffOrdersPage> createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends ConsumerState<StaffOrdersPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  OrderStatus? _statusFilter; // null = all active
  int _page = 0;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CafeOrder> _applyFilters(List<CafeOrder> all) {
    return all.where((order) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final numMatch = order.orderNumber.toString().contains(q);
        final custMatch = order.customerId.toLowerCase().contains(q);
        if (!numMatch && !custMatch) return false;
      }
      if (_statusFilter != null && order.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context, ) {
    final isTerminalFilter = _statusFilter == OrderStatus.completed ||
        _statusFilter == OrderStatus.cancelled;
    final ordersAsync = isTerminalFilter
        ? ref.watch(allOrdersProvider)
        : ref.watch(staffActiveOrdersProvider);
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profile = user != null
        ? ref.watch(userProfileProvider(user.uid)).valueOrNull
        : null;
    final isCashier = profile?.role == UserRole.cashier;
    final cs = Theme.of(context).colorScheme;

    // Status filter options for the live queue and logs
    final statusOptions = [
      null, // All
      OrderStatus.queued,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
      OrderStatus.cancelled,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: isCashier
            ? BackButton(onPressed: () => context.go(AppRoutes.staffHome))
            : null,
        title: const Text('Live Order Queue'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              final confirm = await AppDialogs.confirm(
                context,
                title: 'Log Out',
                message: 'Are you sure you want to log out?',
                isDestructive: true,
                confirmText: 'Log Out',
              );
              if (confirm) {
                await ref.read(authServiceProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.3),
              cs.surface,
              cs.secondaryContainer.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: ordersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, st) {
            debugPrint('Staff Orders Error: $e\n$st');
            return Center(
              child: Text(
                'Error loading orders:\n$e',
                style: const TextStyle(color: Colors.red),
              ),
            );
          },
          data: (orders) {
            final filtered = _applyFilters(orders);
            final totalPages =
                (filtered.length / _pageSize).ceil().clamp(1, 9999);
            final start = _page * _pageSize;
            final end = (start + _pageSize).clamp(0, filtered.length);
            final pageOrders = filtered.sublist(start, end);

            return Column(
              children: [
                // ── Search bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by order # or customer…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _query = '';
                                _page = 0;
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => setState(() {
                      _query = v.trim();
                      _page = 0;
                    }),
                  ).animate().fadeIn(duration: 300.ms),
                ),

                // ── Status filter chips ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: statusOptions.map((status) {
                        final isSelected = _statusFilter == status;
                        final label = status == null
                            ? 'All'
                            : status.name.toUpperCase();
                        final color = status == null
                            ? cs.primary
                            : _statusColor(status, cs);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _statusFilter = status;
                              _page = 0;
                            }),
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withValues(
                                      alpha: isSelected ? 1.0 : 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status != null) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.white
                                            : color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ),

                // ── Count bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} order${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),

                // ── Order list ─────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC88D5D).withValues(alpha: 0.1), // Soft Caramel tint
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFC88D5D), // Caramel border
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC88D5D).withValues(alpha: 0.2), // Richer circular bg
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: Color(0xFF2C2420), // Deep Espresso
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    orders.isEmpty
                                        ? 'All caught up!'
                                        : 'No orders match filters.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2C2420), // Deep Espresso
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    orders.isEmpty
                                        ? 'No active orders in the queue right now.'
                                        : 'Try clearing your search or status filter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF2C2420).withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: pageOrders.length,
                          itemBuilder: (context, index) {
                            final order = pageOrders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ActiveOrderCard(order: order)
                                  .animate()
                                  .fadeIn(delay: (50 * index).ms)
                                  .slideY(begin: 0.1, end: 0),
                            );
                          },
                        ),
                ),

                // ── Pagination ─────────────────────────────────────────────
                if (filtered.isNotEmpty)
                  _OrderPaginationBar(
                    page: _page,
                    totalPages: totalPages,
                    totalItems: filtered.length,
                    pageSize: _pageSize,
                    onPrev:
                        _page > 0 ? () => setState(() => _page--) : null,
                    onNext: _page < totalPages - 1
                        ? () => setState(() => _page++)
                        : null,
                    onPageSelected: (p) => setState(() => _page = p),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status, ColorScheme cs) {
    switch (status) {
      case OrderStatus.queued:
        return Colors.orange;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.indigo;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.received:
        return Colors.teal;
    }
  }
}

// ── Active Order Card ─────────────────────────────────────────────────────────

class _ActiveOrderCard extends ConsumerWidget {
  final CafeOrder order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final timeFormatter = DateFormat.jm();

    Color cardColor;
    switch (order.status) {
      case OrderStatus.queued:
        cardColor = cs.surfaceContainerHighest;
        break;
      case OrderStatus.preparing:
        cardColor = cs.primaryContainer;
        break;
      case OrderStatus.ready:
        cardColor = cs.tertiaryContainer;
        break;
      case OrderStatus.completed:
        cardColor = Colors.green.withValues(alpha: 0.15);
        break;
      case OrderStatus.cancelled:
        cardColor = Colors.red.withValues(alpha: 0.15);
        break;
      default:
        cardColor = cs.surface;
    }

    return AnimatedGlassCard(
      color: cardColor.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.orderNumber}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                timeFormatter.format(order.createdAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(
                  order.status.name.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                backgroundColor: cs.surface,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  order.orderType.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                backgroundColor: order.orderType == OrderType.dineIn
                    ? Colors.purple.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
              ),
            ],
          ),
          const Divider(height: 24),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (item.customizations.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...item.customizations.entries.map(
                            (e) => Text(
                              '- ${e.key}: ${e.value}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.note!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: _buildActionButtons(context, ref),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, WidgetRef ref) {
    switch (order.status) {
      case OrderStatus.queued:
        if (order.paymentStatus == PaymentStatus.pending) {
          return [
            OutlinedButton(
              onPressed: () => _cancelOrderWithNotice(context, ref),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Order'),
            ),
            ElevatedButton(
              onPressed: () => _showGCashQRDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
              child: const Text('Show GCash QR'),
            ),
            ElevatedButton(
              onPressed: () => ref
                  .read(staffOrderActionProvider.notifier)
                  .updatePaymentStatus(order.id, PaymentStatus.paid),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              child: const Text('Mark as Paid'),
            ),
          ];
        } else {
          return [
            OutlinedButton(
              onPressed: () => _cancelOrderWithNotice(context, ref),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Order'),
            ),
            ElevatedButton(
              onPressed: () => ref
                  .read(staffOrderActionProvider.notifier)
                  .updateOrderStatus(order.id, OrderStatus.preparing),
              child: const Text('Start Preparing'),
            ),
          ];
        }
      case OrderStatus.preparing:
        return [
          OutlinedButton(
            onPressed: () => _cancelOrderWithNotice(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
          ElevatedButton(
            onPressed: () => ref
                .read(staffOrderActionProvider.notifier)
                .updateOrderStatus(order.id, OrderStatus.ready),
            child: const Text('Mark as Ready'),
          ),
        ];
      case OrderStatus.ready:
        return [
          OutlinedButton(
            onPressed: () => _cancelOrderWithNotice(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
          OutlinedButton(
            onPressed: () => ref
                .read(staffOrderActionProvider.notifier)
                .updateOrderStatus(order.id, OrderStatus.completed),
            child: const Text('Complete (Handed over)'),
          ),
        ];
      default:
        return [];
    }
  }

  void _showGCashQRDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GCash QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask the customer to scan this QR code to pay.'),
            const SizedBox(height: 20),
            // Placeholder for GCash QR code image.
            // If you have a specific asset, replace this Icon with Image.asset('assets/images/gcash_qr.png')
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.qr_code_2, size: 150, color: Colors.blueAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrderWithNotice(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This will mark it as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(staffOrderActionProvider.notifier).updateOrderStatus(order.id, OrderStatus.cancelled);
    }
  }
}

// ── Pagination bar ────────────────────────────────────────────────────────────

class _OrderPaginationBar extends StatelessWidget {
  const _OrderPaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
    required this.onPageSelected,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = (page * pageSize + 1).clamp(1, totalItems);
    final end = ((page + 1) * pageSize).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$start–$end of $totalItems',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPrev,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                ),
              ),
              ...List.generate(totalPages, (i) => i).where((i) {
                if (totalPages <= 5) return true;
                if (i == 0 || i == totalPages - 1) return true;
                return (i - page).abs() <= 1;
              }).map(
                (i) => SizedBox(
                  width: 32,
                  height: 32,
                  child: TextButton(
                    onPressed: () => onPageSelected(i),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor:
                          i == page ? cs.primary : Colors.transparent,
                      foregroundColor:
                          i == page ? cs.onPrimary : cs.onSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child:
                        Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onNext,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
