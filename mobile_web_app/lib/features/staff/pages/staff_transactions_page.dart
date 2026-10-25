import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/providers/staff_providers.dart';
import '../../../core/models/order.dart';
import '../../../core/widgets/animated_glass_card.dart';

class StaffTransactionsPage extends ConsumerStatefulWidget {
  const StaffTransactionsPage({super.key});

  @override
  ConsumerState<StaffTransactionsPage> createState() =>
      _StaffTransactionsPageState();
}

class _StaffTransactionsPageState extends ConsumerState<StaffTransactionsPage> {
  // ── Search & Filter state ──────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _query = '';
  DateTimeRange? _dateRange;
  String? _statusFilter; // null = all
  int _page = 0;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filter logic ──────────────────────────────────────────────────────────
  List<CafeOrder> _applyFilters(List<CafeOrder> all) {
    var filtered = all.where((order) {
      // Text search: order id or customer id
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final idMatch = order.id.toLowerCase().contains(q);
        final numMatch = order.orderNumber.toString().contains(q);
        final custMatch = order.customerId.toLowerCase().contains(q);
        if (!idMatch && !numMatch && !custMatch) return false;
      }
      // Date range
      if (_dateRange != null) {
        final date = order.createdAt;
        final start = _dateRange!.start;
        final end = _dateRange!.end.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      // Status
      if (_statusFilter != null) {
        if (order.status.firestoreValue != _statusFilter) return false;
      }
      return true;
    }).toList();
    return filtered;
  }

  // ── Date range picker ─────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _page = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales & Transactions')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allOrders) {
          final filtered = _applyFilters(allOrders);
          final totalPages = (filtered.length / _pageSize).ceil().clamp(
            1,
            9999,
          );
          final start = _page * _pageSize;
          final end = (start + _pageSize).clamp(0, filtered.length);
          final pageOrders = filtered.sublist(start, end);

          return Column(
            children: [
              // ── Search & Filter bar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Search input
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by order #, customer…',
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
                        fillColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _query = v.trim();
                        _page = 0;
                      }),
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 10),

                    // Filter row: date + status
                    Row(
                      children: [
                        // Date range chip
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDateRange,
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _dateRange != null
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest.withValues(
                                        alpha: 0.5,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _dateRange != null
                                      ? cs.primary.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: _dateRange != null
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _dateRange == null
                                          ? 'Pick date range'
                                          : '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _dateRange != null
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                        fontWeight: _dateRange != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_dateRange != null) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _dateRange = null;
                                        _page = 0;
                                      }),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Status filter
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _statusFilter,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                            hint: const Text(
                              'All Statuses',
                              style: TextStyle(fontSize: 13),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'All Statuses',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              ...[
                                'queued',
                                'preparing',
                                'ready',
                                'completed',
                                'cancelled',
                              ].map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.toUpperCase(),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _statusFilter = v;
                              _page = 0;
                            }),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),

              // ── Results count ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filtered.length} transaction${filtered.length == 1 ? '' : 's'} found',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty ||
                        _dateRange != null ||
                        _statusFilter != null) ...[
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _dateRange = null;
                          _statusFilter = null;
                          _page = 0;
                        }),
                        icon: const Icon(Icons.filter_alt_off, size: 14),
                        label: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions match your filters.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: pageOrders.length,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        itemBuilder: (context, index) {
                          final order = pageOrders[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child:
                                AnimatedGlassCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      onTap: () => _showTransactionDetails(
                                        context,
                                        order,
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: _StatusBadge(
                                          status: order.status,
                                        ),
                                        title: Text(
                                          'Order #${order.orderNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${DateFormat('MMM d, yyyy h:mm a').format(order.createdAt)}\nID: ${order.id.substring(0, 8).toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        isThreeLine: true,
                                        trailing: Text(
                                          '₱${order.total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: (30 * index).ms)
                                    .slideX(begin: 0.05, end: 0),
                          );
                        },
                      ).animate().fadeIn(duration: 300.ms),
              ),

              // ── Pagination bar ──────────────────────────────────────────
              if (filtered.isNotEmpty)
                _PaginationBar(
                  page: _page,
                  totalPages: totalPages,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPrev: _page > 0 ? () => setState(() => _page--) : null,
                  onNext: _page < totalPages - 1
                      ? () => setState(() => _page++)
                      : null,
                  onPageSelected: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, CafeOrder order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Receipt #${order.id.substring(0, 8).toUpperCase()}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date: ${DateFormat('MMM d, yyyy h:mm a').format(order.createdAt)}',
                ),
                Text('Customer: ${order.customerId}'),
                Text('Type: ${order.orderType.name.toUpperCase()}'),
                Text('Status: ${order.status.name.toUpperCase()}'),
                const Divider(),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        if (item.customizations.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                              item.customizations.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '₱${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color color;
    switch (status) {
      case OrderStatus.queued:
        color = Colors.orange;
        break;
      case OrderStatus.preparing:
        color = Colors.blue;
        break;
      case OrderStatus.ready:
        color = Colors.green;
        break;
      case OrderStatus.completed:
        color = cs.primary;
        break;
      default:
        color = cs.onSurfaceVariant;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ── Pagination Bar ────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            '$start–$end of $totalItems',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Previous
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPrev,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(36, 36),
                  ),
                ),
                // Page numbers (show up to 5)
                ...(() {
                  final visible = <int>{
                    0,
                    totalPages - 1,
                    for (int i = page - 1; i <= page + 1; i++)
                      if (i >= 0 && i < totalPages) i
                  }.toList()..sort();
                  
                  final List<Widget> widgets = [];
                  int prev = -1;
                  for (final i in visible) {
                    if (prev != -1 && i - prev > 1) {
                      widgets.add(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('…'),
                        ),
                      );
                    }
                    widgets.add(
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: TextButton(
                          onPressed: () => onPageSelected(i),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: i == page
                                ? cs.primary
                                : Colors.transparent,
                            foregroundColor: i == page
                                ? cs.onPrimary
                                : cs.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    );
                    prev = i;
                  }
                  return widgets;
                })(),
                // Next
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
          ),
        ],
      ),
    );
  }
}
