import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_engine.dart';
import '../models/order.dart';
import 'firebase_providers.dart';
import 'staff_providers.dart';

/// The date range currently selected on the analytics page.
final analyticsSelectionProvider = StateProvider<AnalyticsSelection>(
  (ref) => const AnalyticsSelection(AnalyticsPreset.thisMonth),
);

/// Streams EVERY order (no limit) so analytics totals match the database.
/// Sorts client-side to be 100% immune to missing Firestore composite index errors.
final analyticsOrdersProvider = StreamProvider<List<CafeOrder>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .snapshots()
      .map((snap) {
        final list = <CafeOrder>[];
        for (final doc in snap.docs) {
          try {
            list.add(CafeOrder.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>));
          } catch (_) {
            // Gracefully skips any malformed documents so analytics never crashes
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

/// Live Firebase Firestore Sync Status metadata.
class LiveFirebaseSyncStatus {
  const LiveFirebaseSyncStatus({
    required this.isLive,
    required this.ordersCount,
    required this.productsCount,
    required this.feedbackCount,
    required this.ingredientsCount,
    required this.lastSynced,
  });

  final bool isLive;
  final int ordersCount;
  final int productsCount;
  final int feedbackCount;
  final int ingredientsCount;
  final DateTime lastSynced;
}

final liveFirebaseSyncStatusProvider = Provider<LiveFirebaseSyncStatus>((ref) {
  final orders = ref.watch(analyticsOrdersProvider).valueOrNull ?? const [];
  final products = ref.watch(allProductsProvider).valueOrNull ?? const [];
  final feedback = ref.watch(staffFeedbackProvider).valueOrNull ?? const [];
  final ingredients = ref.watch(allIngredientsProvider).valueOrNull ?? const [];
  final isOrdersLoaded = ref.watch(analyticsOrdersProvider).hasValue;

  return LiveFirebaseSyncStatus(
    isLive: isOrdersLoaded,
    ordersCount: orders.length,
    productsCount: products.length,
    feedbackCount: feedback.length,
    ingredientsCount: ingredients.length,
    lastSynced: DateTime.now(),
  );
});

/// Refreshes all live Firestore streams for analytics.
void refreshLiveFirebaseAnalytics(WidgetRef ref) {
  ref.invalidate(analyticsOrdersProvider);
  ref.invalidate(allProductsProvider);
  ref.invalidate(staffFeedbackProvider);
  ref.invalidate(allIngredientsProvider);
}

/// Fully computed analytics for the selected range. Recomputes whenever
/// orders, products, feedback or the selected range change.
final analyticsReportProvider = Provider<AsyncValue<AnalyticsReport>>((ref) {
  final ordersAsync = ref.watch(analyticsOrdersProvider);
  final productsAsync = ref.watch(allProductsProvider);
  final feedbackAsync = ref.watch(staffFeedbackProvider);
  final selection = ref.watch(analyticsSelectionProvider);

  if (ordersAsync.hasError) {
    return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
  }
  final orders = ordersAsync.valueOrNull;
  final products = productsAsync.valueOrNull;
  if (orders == null || (products == null && productsAsync.isLoading)) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(computeAnalytics(
    orders: orders,
    products: products ?? const [],
    // Feedback is optional – a permission error must not block analytics.
    feedback: feedbackAsync.valueOrNull ?? const [],
    selection: selection,
  ));
});
