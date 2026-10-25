import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/feedback_model.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/widgets/animated_glass_card.dart';

class CommunityFeedbackPage extends ConsumerStatefulWidget {
  const CommunityFeedbackPage({this.initialProduct, super.key});

  final String? initialProduct;

  @override
  ConsumerState<CommunityFeedbackPage> createState() =>
      _CommunityFeedbackPageState();
}

class _CommunityFeedbackPageState extends ConsumerState<CommunityFeedbackPage> {
  String? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(staffFeedbackProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedProduct == null
            ? 'Community Feedback'
            : '$_selectedProduct Reviews'),
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (allFeedback) {
          final published = allFeedback.where((f) => f.isPublished).toList();

          if (published.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('No community feedback yet.'),
                ],
              ),
            );
          }

          // Build product counts for published feedback
          final productCounts = <String, int>{};
          for (final fb in published) {
            final names = fb.productNames.isNotEmpty
                ? fb.productNames
                : (fb.items.isNotEmpty
                    ? fb.items.map((i) => i.name).toList()
                    : _getOrderProductNames(fb.orderId));
            for (final name in names) {
              productCounts[name] = (productCounts[name] ?? 0) + 1;
            }
          }

          final filtered = _filterFeedback(published);

          final avg = filtered.isEmpty
              ? 0.0
              : filtered.map((f) => f.rating).reduce((a, b) => a + b) /
                  filtered.length;

          return Column(
            children: [
              _AvgRatingBanner(
                avg: avg,
                total: filtered.length,
                selectedProduct: _selectedProduct,
                onClearFilter: _selectedProduct != null
                    ? () => setState(() => _selectedProduct = null)
                    : null,
              ),
              if (productCounts.isNotEmpty)
                _ProductFilterBar(
                  selectedProduct: _selectedProduct,
                  totalAll: published.length,
                  productCounts: productCounts,
                  onSelectProduct: (product) {
                    setState(() => _selectedProduct = product);
                  },
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.coffee_outlined,
                                size: 54, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No reviews found for "$_selectedProduct"',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedProduct = null),
                              icon: const Icon(Icons.clear_all_rounded),
                              label: const Text('View All Reviews'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final fb = filtered[index];
                          return _CommunityFeedbackCard(
                            feedback: fb,
                            selectedProduct: _selectedProduct,
                            onSelectProduct: (product) {
                              setState(() => _selectedProduct = product);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _getOrderProductNames(String orderId) {
    final order = ref.watch(orderProvider(orderId)).valueOrNull;
    if (order == null) return const [];
    return order.items.map((i) => i.name).toList();
  }

  List<CafeanaFeedback> _filterFeedback(List<CafeanaFeedback> list) {
    if (_selectedProduct == null) return list;
    final target = _selectedProduct!.trim().toLowerCase();
    return list.where((f) {
      if (f.productNames.any((p) => p.trim().toLowerCase() == target)) {
        return true;
      }
      if (f.items.any((i) => i.name.trim().toLowerCase() == target)) {
        return true;
      }
      final order = ref.watch(orderProvider(f.orderId)).valueOrNull;
      if (order != null &&
          order.items.any((i) => i.name.trim().toLowerCase() == target)) {
        return true;
      }
      return false;
    }).toList();
  }
}

class _AvgRatingBanner extends StatelessWidget {
  const _AvgRatingBanner({
    required this.avg,
    required this.total,
    this.selectedProduct,
    this.onClearFilter,
  });

  final double avg;
  final int total;
  final String? selectedProduct;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.primaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            avg.toStringAsFixed(1),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarRow(rating: avg.round()),
                const SizedBox(height: 4),
                Text(
                  selectedProduct == null
                      ? 'Based on $total review${total == 1 ? '' : 's'}'
                      : '$total review${total == 1 ? '' : 's'} for $selectedProduct',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedProduct != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selectedProduct != null && onClearFilter != null)
            ActionChip(
              avatar: const Icon(Icons.close_rounded, size: 14),
              label: const Text('All Reviews'),
              onPressed: onClearFilter,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _ProductFilterBar extends StatelessWidget {
  const _ProductFilterBar({
    required this.selectedProduct,
    required this.totalAll,
    required this.productCounts,
    required this.onSelectProduct,
  });

  final String? selectedProduct;
  final int totalAll;
  final Map<String, int> productCounts;
  final ValueChanged<String?> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sortedProducts = productCounts.keys.toList()
      ..sort((a, b) =>
          (productCounts[b] ?? 0).compareTo(productCounts[a] ?? 0));

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selectedProduct == null,
              label: Text('All Drinks ($totalAll)'),
              avatar: const Icon(Icons.local_cafe_rounded, size: 14),
              onSelected: (_) => onSelectProduct(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...sortedProducts.map((name) {
            final count = productCounts[name] ?? 0;
            final isSelected = selectedProduct != null &&
                selectedProduct!.toLowerCase() == name.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                avatar: const Icon(Icons.coffee_rounded, size: 14),
                label: Text('$name ($count)'),
                onSelected: (_) => onSelectProduct(isSelected ? null : name),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          5,
          (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Colors.amber,
            size: 18,
          ),
        ),
      );
}

class _CommunityFeedbackCard extends ConsumerWidget {
  const _CommunityFeedbackCard({
    required this.feedback,
    this.selectedProduct,
    this.onSelectProduct,
  });

  final CafeanaFeedback feedback;
  final String? selectedProduct;
  final ValueChanged<String>? onSelectProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final orderAsync = ref.watch(orderProvider(feedback.orderId));
    final order = orderAsync.valueOrNull;

    final items = feedback.items.isNotEmpty
        ? feedback.items
        : (order?.items ?? const <OrderItem>[]);

    final productNames = feedback.productNames.isNotEmpty
        ? feedback.productNames
        : (items.isNotEmpty
            ? items.map((i) => i.name).toList()
            : (order != null
                ? order.items.map((i) => i.name).toList()
                : const <String>[]));

    return AnimatedGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: feedback.rating),
              const Spacer(),
              if (feedback.createdAt != null)
                Text(
                  DateFormat('MMM d, yyyy').format(feedback.createdAt!),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
            ],
          ),

          // ── Ordered Product Badges ──────────────────────────────────────────
          if (items.isNotEmpty || productNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.isNotEmpty
                  ? items.map((item) {
                      final isMatch = selectedProduct != null &&
                          item.name.toLowerCase() ==
                              selectedProduct!.toLowerCase();
                      return InkWell(
                        onTap: () => onSelectProduct?.call(item.name),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMatch
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isMatch
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(alpha: 0.5),
                              width: isMatch ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.coffee_rounded,
                                size: 12,
                                color: isMatch
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.quantity}× ${item.name}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isMatch
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isMatch
                                      ? cs.onPrimaryContainer
                                      : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                  : productNames.map((name) {
                      final isMatch = selectedProduct != null &&
                          name.toLowerCase() ==
                              selectedProduct!.toLowerCase();
                      return InkWell(
                        onTap: () => onSelectProduct?.call(name),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMatch
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isMatch
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(alpha: 0.5),
                              width: isMatch ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.coffee_rounded,
                                size: 12,
                                color: isMatch
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isMatch
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isMatch
                                      ? cs.onPrimaryContainer
                                      : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ],

          if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${ProfanityFilter.maskProfanity(feedback.comment!)}"',
              style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5),
            ),
          ],
          if (feedback.reply != null && feedback.reply!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.secondaryContainer),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: cs.secondary),
                      const SizedBox(width: 8),
                      Text('Owner Reply',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: cs.secondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(feedback.reply!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
