import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';

/// Phase 4 – Screen 5: Order Status Feed
///
/// Read-only feed of all orders with timestamps, ordered newest first.
/// Acts as a full audit log of status transitions visible to staff.
class StaffOrderFeedPage extends ConsumerStatefulWidget {
  const StaffOrderFeedPage({super.key});

  @override
  ConsumerState<StaffOrderFeedPage> createState() => _StaffOrderFeedPageState();
}

class _StaffOrderFeedPageState extends ConsumerState<StaffOrderFeedPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  OrderStatus? _statusFilter; // null = all
  bool _newestFirst = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersProvider);
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profile = user != null
        ? ref.watch(userProfileProvider(user.uid)).valueOrNull
        : null;
    final isCashier = profile?.role == UserRole.cashier;
    final cs = Theme.of(context).colorScheme;

    final statusOptions = [
      null, // All
      OrderStatus.completed,
      OrderStatus.cancelled,
      OrderStatus.ready,
      OrderStatus.preparing,
      OrderStatus.queued,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: isCashier
            ? BackButton(onPressed: () => context.go(AppRoutes.staffHome))
            : null,
        title: const Text('Order Status Feed & Logs'),
        actions: [
          IconButton(
            tooltip: _newestFirst ? 'Showing newest first' : 'Showing oldest first',
            icon: Icon(_newestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
            onPressed: () {
              setState(() {
                _newestFirst = !_newestFirst;
              });
            },
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final sortedOrders = List<CafeOrder>.from(orders);
          if (!_newestFirst) {
            sortedOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          } else {
            sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          var filtered = sortedOrders.where((order) {
            if (_statusFilter != null && order.status != _statusFilter) {
              return false;
            }
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final numMatch = order.orderNumber.toString().contains(q);
              final custMatch = order.customerId.toLowerCase().contains(q);
              final idMatch = order.id.toLowerCase().contains(q);
              return numMatch || custMatch || idMatch;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by order #, customer ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                    });
                  },
                ),
              ),

              // ── Status Filter Chips (Buttons for Cancelled, Completed, etc.) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: statusOptions.map((status) {
                      final isSelected = _statusFilter == status;
                      final label = status == null
                          ? 'ALL'
                          : status.label.toUpperCase();
                      final color = status == null
                          ? cs.primary
                          : _statusColor(status);
                      final count = status == null
                          ? orders.length
                          : orders.where((o) => o.status == status).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _statusFilter = status),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withValues(
                                    alpha: isSelected ? 1.0 : 0.35),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
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
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : color,
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

              // ── Orders Feed List ──
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              _statusFilter != null
                                  ? 'No ${_statusFilter!.label.toLowerCase()} orders found.'
                                  : 'No orders found.',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (_statusFilter != null || _query.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _statusFilter = null;
                                      _searchCtrl.clear();
                                      _query = '';
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reset Filters'),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _OrderFeedRow(order: filtered[index])
                              .animate()
                              .fadeIn(delay: (20 * index).ms)
                              .slideX(begin: 0.05, end: 0),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderFeedRow extends StatelessWidget {
  const _OrderFeedRow({required this.order});
  final CafeOrder order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(order.status);

    return AnimatedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
            // Order number
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${order.orderNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order status: ${order.status.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy h:mm a').format(order.createdAt)} • ${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                    Text(
                      'Customer: ${order.customerId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.note != null && order.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${order.note}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x ${item.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (item.customizations.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text(
                                item.customizations.entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            
            // Trailing amount
            Text(
              '₱${order.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: cs.primary,
              ),
            ),
        ],
      ),
    );
  }
}

Color _statusColor(OrderStatus s) {
  switch (s) {
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
