import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/feedback_model.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/utils/profanity_filter.dart';

/// Feedback screen — collects a 1–5 star rating and an optional comment.
///
/// The feedback document ID equals the [orderId] (one feedback per order).
/// On success, navigates back to order history.
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  List<String> _detectedFoulWords = const [];

  @override
  void initState() {
    super.initState();
    _commentCtrl.addListener(_onCommentChanged);
  }

  void _onCommentChanged() {
    final words = ProfanityFilter.getDetectedWords(_commentCtrl.text);
    if (words.length != _detectedFoulWords.length ||
        !words.every(_detectedFoulWords.contains)) {
      setState(() {
        _detectedFoulWords = words;
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_onCommentChanged);
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackState = ref.watch(feedbackProvider);
    final cs = Theme.of(context).colorScheme;

    // Listen for success or error
    ref.listen<AsyncValue<void>>(feedbackProvider, (previous, state) {
      // Only navigate when transitioning from loading → data (actual success)
      if (previous?.isLoading == true && state is AsyncData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thanks for your feedback! ⭐'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(feedbackProvider.notifier).reset();
        context.go(AppRoutes.customerOrders);
      } else if (state is AsyncError) {
        final error = state.error;
        String message = 'Unable to submit feedback. Please try again.';
        if (error is FirebaseException) {
          if (error.code == 'permission-denied') {
            message =
                'Submission denied: Ensure you are logged in and this order is completed/received.';
          } else {
            message = error.message ?? message;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    final hasFoulLanguage = _detectedFoulWords.isNotEmpty;

    final existingFeedbackAsync =
        ref.watch(feedbackExistsProvider(widget.orderId));
    final hasExistingFeedback = existingFeedbackAsync.valueOrNull ?? false;
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final order = orderAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasExistingFeedback) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have already submitted feedback for this order. Submitting again will update your review.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ── Icon ──────────────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.coffee,
                  size: 44, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'How was your experience?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${widget.orderId.substring(0, 6).toUpperCase()}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),

            if (order != null && order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: order.items.map((item) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_cafe_rounded,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 5),
                        Text(
                          '${item.quantity}× ${item.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 36),

            // ── Star rating ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: _rating >= starIndex ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _rating >= starIndex
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 44,
                        color: _rating >= starIndex
                            ? Colors.amber[600]
                            : cs.outlineVariant,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            Text(
              _ratingLabel(_rating),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _rating > 0 ? Colors.amber[700] : cs.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // ── Comment with Profanity Restriction ────────────────────────
            TextFormField(
              controller: _commentCtrl,
              onChanged: (_) => _onCommentChanged(),
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Your comment (optional)',
                hintText: 'Tell us what you think...',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                enabledBorder: hasFoulLanguage
                    ? OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                focusedBorder: hasFoulLanguage
                    ? OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                errorText: hasFoulLanguage
                    ? 'Inappropriate language is not permitted'
                    : null,
              ),
            ),

            // ── Warning Banner for Foul Words ─────────────────────────────
            if (hasFoulLanguage) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respectful Community Policy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please remove inappropriate words (${_detectedFoulWords.take(3).join(', ')}) before submitting your review.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade800,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────────────────
            FilledButton(
              onPressed: (_rating == 0 || hasFoulLanguage || feedbackState.isLoading)
                  ? null
                  : _submit,
              child: feedbackState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Submit Feedback'),
            ),

            if (_rating == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tap a star to rate',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              )
            else if (hasFoulLanguage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Remove foul words to enable submission',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                ),
              ),

            // ── Skip ──────────────────────────────────────────────────────
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(AppRoutes.customerOrders),
              child: Text('Skip',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final commentText = _commentCtrl.text.trim();
    final foulWords = ProfanityFilter.getDetectedWords(commentText);
    if (foulWords.isNotEmpty) {
      setState(() {
        _detectedFoulWords = foulWords;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please remove inappropriate language (${foulWords.take(2).join(', ')}) before submitting.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = ref.read(authStateChangesProvider).valueOrNull ??
        ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to submit feedback.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final order = ref.read(orderProvider(widget.orderId)).valueOrNull;
    final productNames = order?.items.map((i) => i.name).toList() ?? [];
    final productIds = order?.items.map((i) => i.productId).toList() ?? [];
    final items = order?.items ?? [];

    final feedback = CafeanaFeedback(
      orderId: widget.orderId,
      customerId: user.uid,
      rating: _rating,
      comment: commentText.isEmpty ? null : commentText,
      productNames: productNames,
      productIds: productIds,
      items: items,
    );

    await ref.read(feedbackProvider.notifier).submit(feedback);
  }

  String _ratingLabel(int rating) => switch (rating) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Great',
        5 => 'Excellent! ✨',
        _ => 'Select a rating',
      };
}
