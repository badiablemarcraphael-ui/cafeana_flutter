import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/feedback_model.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/widgets/animated_glass_card.dart';

/// Phase 4 – Screen 7: Feedback Review
///
/// Lists all customer feedback sorted by newest first.
/// Supports product-specific feedback filtering (e.g., Americano, Spanish Latte),
/// recalculating average rating for that item, and displaying product tags on each review.
class StaffFeedbackPage extends ConsumerStatefulWidget {
  const StaffFeedbackPage({super.key});

  @override
  ConsumerState<StaffFeedbackPage> createState() => _StaffFeedbackPageState();
}

class _StaffFeedbackPageState extends ConsumerState<StaffFeedbackPage> {
  String? _selectedProduct;

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(staffFeedbackProvider);
    final allProductsAsync = ref.watch(allProductsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: feedbackAsync.when(
          data: (list) {
            if (list.isEmpty) return const Text('Feedback Review');
            final effectiveList = _filterFeedback(list);
            final avg = effectiveList.isEmpty
                ? 0.0
                : effectiveList.map((f) => f.rating).reduce((a, b) => a + b) /
                    effectiveList.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedProduct == null
                    ? 'Feedback Review'
                    : '$_selectedProduct Feedback'),
                Text(
                  '${effectiveList.length} review${effectiveList.length == 1 ? '' : 's'}'
                  '${_selectedProduct != null ? ' for $_selectedProduct' : ''}  •  '
                  'Avg ★ ${avg.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            );
          },
          loading: () => const Text('Feedback Review'),
          error: (_, __) => const Text('Feedback Review'),
        ),
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (feedbackList) {
          if (feedbackList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('No feedback yet'),
                ],
              ),
            );
          }

          final allProducts = allProductsAsync.valueOrNull ?? [];
          final filteredList = _filterFeedback(feedbackList);

          // Calculate average rating for displayed feedback
          final avg = filteredList.isEmpty
              ? 0.0
              : filteredList.map((f) => f.rating).reduce((a, b) => a + b) /
                  filteredList.length;

          // Collect unique products from feedback and menu
          final productCounts = <String, int>{};
          for (final fb in feedbackList) {
            final names = fb.productNames.isNotEmpty
                ? fb.productNames
                : (fb.items.isNotEmpty
                    ? fb.items.map((i) => i.name).toList()
                    : _getOrderProductNames(fb.orderId));
            for (final name in names) {
              productCounts[name] = (productCounts[name] ?? 0) + 1;
            }
          }

          return Column(
            children: [
              _AvgRatingBanner(
                avg: avg,
                total: filteredList.length,
                selectedProduct: _selectedProduct,
                onClearFilter: _selectedProduct != null
                    ? () => setState(() => _selectedProduct = null)
                    : null,
              ),
              _ProductFilterBar(
                selectedProduct: _selectedProduct,
                totalAll: feedbackList.length,
                productCounts: productCounts,
                menuProducts: allProducts.map((p) => p.name).toList(),
                onSelectProduct: (product) {
                  setState(() {
                    _selectedProduct = product;
                  });
                },
              ),
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.coffee_outlined,
                                size: 54, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No feedback found for "$_selectedProduct"',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedProduct = null),
                              icon: const Icon(Icons.clear_all_rounded),
                              label: const Text('View All Feedback'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _FeedbackCard(
                            feedback: filteredList[index],
                            selectedProduct: _selectedProduct,
                            onSelectProduct: (product) {
                              setState(() => _selectedProduct = product);
                            },
                          )
                              .animate()
                              .fadeIn(delay: (50 * index).ms)
                              .slideX(begin: 0.05, end: 0),
                        ),
                      ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms);
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

// ── Subwidgets ────────────────────────────────────────────────────────────────

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
    required this.menuProducts,
    required this.onSelectProduct,
  });

  final String? selectedProduct;
  final int totalAll;
  final Map<String, int> productCounts;
  final List<String> menuProducts;
  final ValueChanged<String?> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sortedReviewedProducts = productCounts.keys.toList()
      ..sort((a, b) =>
          (productCounts[b] ?? 0).compareTo(productCounts[a] ?? 0));

    final otherMenuProducts = menuProducts
        .where((p) => !productCounts.containsKey(p))
        .toList()
      ..sort();

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
              label: Text('All Products ($totalAll)'),
              avatar: const Icon(Icons.apps_rounded, size: 14),
              onSelected: (_) => onSelectProduct(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...sortedReviewedProducts.map((name) {
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
          if (otherMenuProducts.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Filter by other products',
              child: const Chip(
                avatar: Icon(Icons.more_horiz_rounded, size: 16),
                label: Text('More Products...'),
                visualDensity: VisualDensity.compact,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Select a product:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                ...otherMenuProducts.map(
                  (name) => PopupMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        const Icon(Icons.coffee_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text(name),
                      ],
                    ),
                  ),
                ),
              ],
              onSelected: (product) => onSelectProduct(product),
            ),
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

class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({
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
    final isPublishing = ref.watch(feedbackActionProvider).isLoading;

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

    // Auto-backfill Firestore document if it's missing product details
    if (feedback.productNames.isEmpty &&
        order != null &&
        order.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseFirestore.instance
            .collection('feedback')
            .doc(feedback.orderId)
            .update({
          'productNames': order.items.map((i) => i.name).toList(),
          'productIds': order.items.map((i) => i.productId).toList(),
          'items': order.items.map((i) => i.toMap()).toList(),
        }).catchError((_) {});
      });
    }

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
                  DateFormat('MMM d, HH:mm').format(feedback.createdAt!),
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
                                color:
                                    isMatch ? cs.primary : cs.onSurfaceVariant,
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
                                color:
                                    isMatch ? cs.primary : cs.onSurfaceVariant,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '"${feedback.comment}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: ProfanityFilter.hasProfanity(feedback.comment!)
                          ? Colors.red.shade700
                          : null,
                    ),
                  ),
                ),
                if (ProfanityFilter.hasProfanity(feedback.comment!))
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded,
                            size: 13, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Flagged: Inappropriate',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Order: #${feedback.orderId.length > 6 ? feedback.orderId.substring(0, 6).toUpperCase() : feedback.orderId.toUpperCase()}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              if (order != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• Order #${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 24),
          if (feedback.reply != null && feedback.reply!.isNotEmpty) ...[
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
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: feedback.isPublished,
                    onChanged: isPublishing
                        ? null
                        : (val) {
                            ref
                                .read(feedbackActionProvider.notifier)
                                .togglePublish(feedback);
                          },
                  ),
                  Text(
                    feedback.isPublished ? 'Published' : 'Hidden',
                    style: TextStyle(
                        fontSize: 12,
                        color: feedback.isPublished
                            ? cs.primary
                            : cs.onSurfaceVariant),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.reply, size: 16),
                label: Text(feedback.reply == null || feedback.reply!.isEmpty
                    ? 'Reply'
                    : 'Edit Reply'),
                onPressed: () => _showReplyDialog(context, ref, productNames),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(
      BuildContext context, WidgetRef ref, List<String> productNames) {
    showDialog(
      context: context,
      builder: (context) => _ReplyDialog(
        feedback: feedback,
        productNames: productNames,
        onSave: (replyText) {
          ref
              .read(feedbackActionProvider.notifier)
              .replyToFeedback(feedback, replyText);
        },
      ),
    );
  }
}

class _ReplyTemplate {
  const _ReplyTemplate({
    required this.label,
    required this.icon,
    required this.color,
    required this.text,
    required this.description,
    required this.isRecommended,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String text;
  final String description;
  final bool isRecommended;
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({
    required this.feedback,
    required this.productNames,
    required this.onSave,
  });

  final CafeanaFeedback feedback;
  final List<String> productNames;
  final ValueChanged<String> onSave;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _controller;
  int? _selectedTemplateIndex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.feedback.reply ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyAutoFill(int index, String text) {
    setState(() {
      _selectedTemplateIndex = index;
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rating = widget.feedback.rating;

    // ── 3 Pre-defined Auto-fills Feature ──────────────────────────────────────
    final templates = [
      _ReplyTemplate(
        label: 'Thank Customer',
        icon: Icons.thumb_up_alt_rounded,
        color: Colors.teal,
        description: 'For positive 4–5★ customer reviews',
        text:
            "Thank you so much for the wonderful feedback! We're thrilled that you enjoyed your drink and look forward to serving you again soon! ☕✨",
        isRecommended: rating >= 4,
      ),
      _ReplyTemplate(
        label: 'Apologize & Improve',
        icon: Icons.volunteer_activism_rounded,
        color: Colors.deepOrange,
        description: 'For issues & complaints (1–2★)',
        text:
            "Thank you for bringing this to our attention. We sincerely apologize that your experience fell short of our standards, and we are working with our café team right away to ensure better quality.",
        isRecommended: rating <= 2,
      ),
      _ReplyTemplate(
        label: 'Value Suggestions',
        icon: Icons.lightbulb_outline_rounded,
        color: Colors.amber.shade800,
        description: 'For constructive ideas & neutral 3★ reviews',
        text:
            "We really appreciate your honest review and helpful suggestions! We've noted your feedback to help us refine our menu and service for your next visit. Have a wonderful day!",
        isRecommended: rating == 3,
      ),
    ];

    final hasFoulInReply = ProfanityFilter.hasProfanity(_controller.text);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.reply_rounded, color: cs.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reply to Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Order #${widget.feedback.orderId.length > 6 ? widget.feedback.orderId.substring(0, 6).toUpperCase() : widget.feedback.orderId.toUpperCase()} • ${widget.feedback.rating} ★ Rating',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: cs.onSurfaceVariant),
                ),
                if (widget.productNames.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ordered: ${widget.productNames.join(', ')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer's comment quote if present
              if (widget.feedback.comment != null && widget.feedback.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.feedback.comment!,
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── 3 Auto-fills Header ──────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  const Text(
                    '3 Quick Auto-fills (tap to insert):',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── 3 Auto-fills Options ─────────────────────────────────────────
              Column(
                children: List.generate(templates.length, (idx) {
                  final t = templates[idx];
                  final isSelected = _controller.text == t.text || _selectedTemplateIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => _applyAutoFill(idx, t.text),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? t.color.withValues(alpha: 0.12)
                              : cs.surfaceContainerHighest.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? t.color : cs.outlineVariant.withValues(alpha: 0.4),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: t.color.withValues(alpha: 0.15),
                              child: Icon(t.icon, size: 14, color: t.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        t.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? t.color : cs.onSurface,
                                        ),
                                      ),
                                      if (t.isRecommended) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.shade400),
                                          ),
                                          child: Text(
                                            '★ Recommended',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                              size: 18,
                              color: isSelected ? t.color : cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // ── Reply Text Field ─────────────────────────────────────────────
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Reply Message',
                  hintText: 'Type your reply or tap one of the 3 auto-fills above...',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: hasFoulInReply
                      ? 'Inappropriate language detected. Please keep replies professional.'
                      : null,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          tooltip: 'Clear',
                          onPressed: () => setState(() {
                            _controller.clear();
                            _selectedTemplateIndex = null;
                          }),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Submit Reply'),
          onPressed: hasFoulInReply
              ? null
              : () {
                  widget.onSave(_controller.text.trim());
                  Navigator.pop(context);
                },
        ),
      ],
    );
  }
}
