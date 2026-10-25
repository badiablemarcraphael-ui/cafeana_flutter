import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';


class StaffActivityLogsPage extends ConsumerStatefulWidget {
  const StaffActivityLogsPage({super.key});

  @override
  ConsumerState<StaffActivityLogsPage> createState() => _StaffActivityLogsPageState();
}

class _StaffActivityLogsPageState extends ConsumerState<StaffActivityLogsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _page = 0;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(allActivityLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) {
                setState(() {
                  _query = v;
                  _page = 0;
                });
              },
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                var filtered = logs.where((l) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return l.action.toLowerCase().contains(q) ||
                         l.details.toLowerCase().contains(q) ||
                         l.staffEmail.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No activity logs found.'));
                }

                final totalPages = (filtered.length / _pageSize).ceil();
                final startIndex = _page * _pageSize;
                final endIndex = (startIndex + _pageSize > filtered.length)
                    ? filtered.length
                    : startIndex + _pageSize;
                final currentItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: currentItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = currentItems[index];
                          final iconData = _getIconForAction(log.action);
                          return AnimatedGlassCard(
                            padding: const EdgeInsets.all(8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(iconData, color: Theme.of(context).colorScheme.primary),
                              ),
                              title: Text(
                                log.action.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(log.details),
                                  const SizedBox(height: 4),
                                  Text(
                                    'By: ${log.staffEmail}  •  ${DateFormat('MMM d, h:mm a').format(log.timestamp)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.05, end: 0);
                        },
                      ),
                    ),
                    if (totalPages > 1)
                      _LogsPaginationBar(
                        currentPage: _page,
                        totalPages: totalPages,
                        onPageChanged: (p) => setState(() => _page = p),
                      ),
                  ],
                ).animate().fadeIn(duration: 300.ms);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('order')) return Icons.receipt_long;
    if (lower.contains('inventory') || lower.contains('product')) return Icons.inventory_2;
    if (lower.contains('user') || lower.contains('role')) return Icons.person;
    if (lower.contains('promotion') || lower.contains('promo')) return Icons.local_offer;
    return Icons.history;
  }
}

class _LogsPaginationBar extends StatelessWidget {
  const _LogsPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            ),
            Text('Page ${currentPage + 1} of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}
