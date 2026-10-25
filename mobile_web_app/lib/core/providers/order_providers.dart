import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/feedback_model.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/notification_service.dart';
import 'cart_provider.dart';
import 'firebase_providers.dart';
import '../utils/profanity_filter.dart';

// ── Stream providers ──────────────────────────────────────────────────────────

/// Streams all orders for [uid], newest first.
///
/// Used on the Order History screen.
final customerOrdersProvider =
    StreamProvider.family<List<CafeOrder>, String>((ref, uid) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => CafeOrder.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

/// Streams a single order document in real-time.
///
/// Used on the Order Tracking screen.
final orderProvider =
    StreamProvider.family<CafeOrder?, String>((ref, orderId) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((snap) =>
          snap.exists ? CafeOrder.fromFirestore(snap) : null);
});

/// Streams active orders (queued|preparing|ready) for [uid].
///
/// Used on the Home screen to show a "Track Order" card.
final activeOrderProvider =
    StreamProvider.family<CafeOrder?, String>((ref, uid) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .where('status', whereIn: ['queued', 'preparing', 'ready'])
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty
          ? null
          : CafeOrder.fromFirestore(
              snap.docs.first as DocumentSnapshot<Map<String, dynamic>>));
});

// ── Checkout notifier ─────────────────────────────────────────────────────────

/// Holds the result of the most recent checkout attempt.
typedef CheckoutState = AsyncValue<String?>; // String = new orderId

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const AsyncValue.data(null);

  FirebaseFirestore get _db => ref.read(firestoreProvider);

  /// Runs a Firestore transaction to:
  /// 1. Read and atomically increment `counters/global.nextOrderNumber`
  /// 2. Create a new `orders/{id}` document with status `queued`
  ///
  /// Returns the new order document ID via state.
  Future<String?> placeOrder(
    List<CartItem> items,
    String customerId, {
    String? note,
    OrderType orderType = OrderType.dineIn,
    String? promoCode,
    double discountAmount = 0.0,
  }) async {
    state = const AsyncValue.loading();

    String? newOrderId;

    state = await AsyncValue.guard(() async {
      try {
        final customerFcmToken =
            await NotificationService.instance.getFcmToken();

        await _db.runTransaction((txn) async {
          // Step 1: read + increment counter atomically
          final counterRef = _db.collection('counters').doc('global');
          final counterSnap = await txn.get(counterRef);

          final int currentNumber = counterSnap.exists
              ? (counterSnap.data()!['nextOrderNumber'] as int? ?? 0)
              : 0;
          final int orderNumber = currentNumber + 1;

          txn.set(counterRef, {'nextOrderNumber': orderNumber});

          // Step 2: create the order document
          final orderRef = _db.collection('orders').doc();
          newOrderId = orderRef.id;

          final total = items.fold<double>(0, (s, i) => s + i.lineTotal);

          txn.set(orderRef, {
            'orderNumber': orderNumber,
            'customerId': customerId,
            if (customerFcmToken != null) 'customerFcmToken': customerFcmToken,
            'items': items
                .map((i) => {
                      'productId': i.product.id,
                      'name': i.product.name,
                      'quantity': i.quantity,
                      'price': i.product.price,
                      'customizations': i.customizations,
                    })
                .toList(),
            'total': total,
            'paymentStatus': 'pending',
            'status': 'queued',
            'orderType': orderType.name,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (note != null && note.isNotEmpty) 'note': note,
            if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
            'discountAmount': discountAmount,
          });

          // Step 3: Deduct stock and log the change for tracked items & ingredients
          for (final item in items) {
            // Deduct recipe-based raw ingredients for the ordered cup size
            // (Small 12 oz / Large 16 oz) with exact precision in g / ml / sets.
            final size = DrinkSize.fromCustomization(item.customizations['Size']);
            final sizedRecipe = item.product.recipeFor(size);
            if (sizedRecipe.isNotEmpty) {
              for (final recipeItem in sizedRecipe) {
                if (recipeItem.ingredientId.isNotEmpty && recipeItem.quantity > 0) {
                  final ingRef = _db.collection('ingredients').doc(recipeItem.ingredientId);
                  final deductedAmount = recipeItem.quantity * item.quantity;
                  txn.update(ingRef, {
                    'stockLevel': FieldValue.increment(-deductedAmount),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  final logRef = _db.collection('inventoryLog').doc();
                  txn.set(logRef, {
                    'productId': item.product.id,
                    'ingredientId': recipeItem.ingredientId,
                    'ingredientName': recipeItem.name,
                    'change': -deductedAmount,
                    'unit': recipeItem.unit,
                    'size': size.label,
                    'reason': 'Order #$orderNumber (${item.product.name} - ${size.display})',
                    'staffId': customerId,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              }
            }

            // Also decrement product unit stock if tracked
            if (item.product.stock != null) {
              final productRef = _db.collection('products').doc(item.product.id);
              txn.update(productRef, {
                'stock': FieldValue.increment(-item.quantity),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              final logRef = _db.collection('inventoryLog').doc();
              txn.set(logRef, {
                'productId': item.product.id,
                'change': -item.quantity,
                'unit': 'units',
                'reason': 'Order #$orderNumber',
                'staffId': customerId,
                'timestamp': FieldValue.serverTimestamp(),
              });
            }
          }
        });
        return newOrderId;
      } catch (e, st) {
        debugPrint('Error in placeOrder: $e\n$st');
        rethrow;
      }
    });

    // Clear cart on success
    if (newOrderId != null && !state.hasError) {
      ref.read(cartProvider.notifier).clear();
    }

    return newOrderId;
  }

  void reset() => state = const AsyncValue.data(null);
}

final checkoutProvider =
    NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);

// ── Order mutation providers ──────────────────────────────────────────────────

/// Marks a single order's `paymentStatus` as `paid` (simulated payment).
final markPaidProvider = Provider((ref) {
  final db = ref.watch(firestoreProvider);
  return (String orderId) => db.collection('orders').doc(orderId).update({
        'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
});

/// Marks an order as `received` (customer confirms pickup).
final markReceivedProvider = Provider((ref) {
  final db = ref.watch(firestoreProvider);
  return (String orderId) => db.collection('orders').doc(orderId).update({
        'status': 'received',
        'updatedAt': FieldValue.serverTimestamp(),
      });
});

/// Marks an order as `completed`.
final markCompletedProvider = Provider((ref) {
  final db = ref.watch(firestoreProvider);
  return (String orderId) => db.collection('orders').doc(orderId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
});

// ── Feedback provider ─────────────────────────────────────────────────────────

class FeedbackNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  FirebaseFirestore get _db => ref.read(firestoreProvider);

  Future<void> submit(CafeanaFeedback feedback) async {
    if (feedback.comment != null &&
        ProfanityFilter.hasProfanity(feedback.comment!)) {
      state = AsyncValue.error(
        Exception('Feedback contains inappropriate language.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db
        .collection('feedback')
        .doc(feedback.orderId)
        .set(feedback.toFirestore(), SetOptions(merge: true)));
  }

  void reset() => state = const AsyncValue.data(null);
}

final feedbackProvider =
    NotifierProvider<FeedbackNotifier, AsyncValue<void>>(FeedbackNotifier.new);

/// Checks whether feedback already exists for [orderId].
final feedbackExistsProvider =
    FutureProvider.family<bool, String>((ref, orderId) async {
  final db = ref.watch(firestoreProvider);
  final snap = await db.collection('feedback').doc(orderId).get();
  return snap.exists;
});
