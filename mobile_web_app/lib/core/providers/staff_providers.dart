import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../models/feedback_model.dart';
import '../models/user_profile.dart';
import '../models/promotion.dart';
import '../models/activity_log.dart';
import 'firebase_providers.dart';

// ── Staff Products Provider ───────────────────────────────────────────────────

/// Streams all products (including unavailable ones) for staff management.
final allProductsProvider = StreamProvider<List<Product>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('products')
      .orderBy('category')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Product.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// ── Staff Orders Providers ────────────────────────────────────────────────────

/// Streams all active orders (queued, preparing, ready).
final staffActiveOrdersProvider = StreamProvider<List<CafeOrder>>((ref) {
  ref.watch(authStateChangesProvider); // Re-run when auth state changes (fixes web startup race condition)
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .where('status', whereIn: ['queued', 'preparing', 'ready'])
      .snapshots()
      .map((snap) {
        debugPrint('Staff Orders Provider fetched: ${snap.docs.length} docs');
        final orders = snap.docs
            .map((doc) => CafeOrder.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        // Sort client-side to avoid needing a Firestore composite index
        orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return orders;
      });
});

/// Streams all orders (for analytics and history feed).
final allOrdersProvider = StreamProvider<List<CafeOrder>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(200) // limit for performance in this demo
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => CafeOrder.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});
// ── Staff Order Actions Provider ────────────────────────────────────────────────

class StaffOrderActionNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.runTransaction((transaction) async {
        final orderRef = db.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) return;

        final currentStatusStr = orderDoc.data()?['status'] as String?;
        if (currentStatusStr == 'cancelled') return;

        final List<Map<String, dynamic>> productUpdates = [];

        if (newStatus == OrderStatus.cancelled) {
          final items = orderDoc.data()?['items'] as List<dynamic>? ?? [];
          for (final rawItem in items) {
            if (rawItem is! Map) continue;
            final productId = rawItem['productId'] as String?;
            final qty = (rawItem['quantity'] as num?)?.toInt() ?? 0;
            if (productId != null && qty > 0) {
              final productRef = db.collection('products').doc(productId);
              final productDoc = await transaction.get(productRef);
              if (productDoc.exists && productDoc.data()?['stock'] != null) {
                productUpdates.add({
                  'ref': productRef,
                  'qty': qty,
                });
              }
            }
          }
        }

        // Now perform all writes
        transaction.update(orderRef, {
          'status': newStatus.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final update in productUpdates) {
          transaction.update(update['ref'] as DocumentReference, {
            'stock': FieldValue.increment(update['qty'] as int),
          });
        }
      });
      await logSystemActivity(ref, 'Order Update', 'Order $orderId status changed to ${newStatus.name}');
    });
  }

  Future<void> updatePaymentStatus(String orderId, PaymentStatus newStatus) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('orders').doc(orderId).update({
        'paymentStatus': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await logSystemActivity(ref, 'Payment Update', 'Order $orderId payment changed to ${newStatus.name}');
    });
  }
}

final staffOrderActionProvider =
    AsyncNotifierProvider.autoDispose<StaffOrderActionNotifier, void>(
        StaffOrderActionNotifier.new);

// ── Device Status Provider ────────────────────────────────────────────────────

/// Streams the kitchen terminal device status.
final deviceStatusProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('deviceStatus')
      .doc('kitchenTerminal')
      .snapshots()
      .map((snap) => snap.data());
});

// ── Inventory Adjust Provider ─────────────────────────────────────────────────

class InventoryAdjustNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> adjust({
    required Product product,
    required int delta,
    required String reason,
  }) async {
    final db = ref.read(firestoreProvider);
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final productRef = db.collection('products').doc(product.id);
      final logRef = db.collection('inventoryLog').doc();

      await db.runTransaction((tx) async {
        final doc = await tx.get(productRef);
        if (!doc.exists) throw Exception('Product not found');

        final currentStock = (doc.data()?['stock'] as int?) ?? 0;
        final newStock = currentStock + delta;

        tx.update(productRef, {'stock': newStock});
        tx.set(logRef, {
          'productId': product.id,
          'change': delta,
          'reason': reason,
          'staffId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
      await logSystemActivity(ref, 'Inventory Adjust', 'Adjusted ${product.name} by $delta ($reason)');
    });
  }
}

final inventoryAdjustProvider =
    AsyncNotifierProvider.autoDispose<InventoryAdjustNotifier, void>(
        InventoryAdjustNotifier.new);

// ── Master Ingredients Holdings Providers ─────────────────────────────────────

/// Streams all master ingredient holdings (by stock value, descending).
final allIngredientsProvider = StreamProvider<List<Ingredient>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('ingredients')
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((doc) => Ingredient.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        list.sort((a, b) {
          final c = a.category.toLowerCase().compareTo(b.category.toLowerCase());
          return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return list;
      });
});

// ── Standard Add-ons Providers ────────────────────────────────────────────────

/// Streams all standard add-ons (Sauce, Syrup, Espresso Shot, Oatmilk Sub).
final allAddOnsProvider = StreamProvider<List<StandardAddOn>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('addOns')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => StandardAddOn.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// ── Precise Ingredient Stock Adjust Provider ──────────────────────────────────

class IngredientAdjustNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> adjust({
    required Ingredient ingredient,
    required double delta,
    required String reason,
  }) async {
    final db = ref.read(firestoreProvider);
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ingredientRef = db.collection('ingredients').doc(ingredient.id);
      final logRef = db.collection('inventoryLog').doc();

      await db.runTransaction((tx) async {
        final doc = await tx.get(ingredientRef);
        if (!doc.exists) throw Exception('Ingredient not found');

        final currentStock = ((doc.data()?['stockLevel'] as num?) ?? 0).toDouble();
        final newStock = (currentStock + delta).clamp(0.0, double.infinity);
        final costImpact = delta * ingredient.unitCost;

        tx.update(ingredientRef, {
          'stockLevel': newStock,
          'totalValue': newStock * ingredient.unitCost,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(logRef, {
          'productId': ingredient.id,
          'ingredientId': ingredient.id,
          'ingredientName': ingredient.name,
          'change': delta,
          'unit': ingredient.unit,
          'reason': reason,
          'costImpact': costImpact,
          'staffId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
      await logSystemActivity(
          ref,
          'Ingredient Adjust',
          'Adjusted ${ingredient.name} by ${delta > 0 ? "+$delta" : "$delta"} ${ingredient.unit} ($reason)');
    });
  }
}

final ingredientAdjustProvider =
    AsyncNotifierProvider.autoDispose<IngredientAdjustNotifier, void>(
        IngredientAdjustNotifier.new);

// ── Ingredient CRUD Provider ──────────────────────────────────────────────────

class IngredientCrudNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addIngredient(Ingredient ingredient) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final docId = ingredient.id.isNotEmpty
          ? ingredient.id
          : db.collection('ingredients').doc().id;
      final docRef = db.collection('ingredients').doc(docId);
      final newIng = ingredient.copyWith(id: docId);
      await docRef.set(newIng.toFirestore(), SetOptions(merge: true));
      await logSystemActivity(ref, 'Add Ingredient', 'Created ingredient ${ingredient.name} ($docId)');
    });
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db
          .collection('ingredients')
          .doc(ingredient.id)
          .set(ingredient.toFirestore(), SetOptions(merge: true));
      await logSystemActivity(ref, 'Update Ingredient', 'Updated ingredient ${ingredient.name}');
    });
  }

  Future<void> deleteIngredient(String id) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('ingredients').doc(id).delete();
      await logSystemActivity(ref, 'Delete Ingredient', 'Deleted ingredient $id');
    });
  }
}

final ingredientCrudProvider =
    AsyncNotifierProvider.autoDispose<IngredientCrudNotifier, void>(
        IngredientCrudNotifier.new);

// ── Add-On CRUD Provider ──────────────────────────────────────────────────────

class AddOnCrudNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveAddOn(StandardAddOn addOn) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('addOns').doc(addOn.id).set(addOn.toFirestore(), SetOptions(merge: true));
      await logSystemActivity(ref, 'Save Add-On', 'Saved add-on ${addOn.name}');
    });
  }
}

final addOnCrudProvider =
    AsyncNotifierProvider.autoDispose<AddOnCrudNotifier, void>(
        AddOnCrudNotifier.new);

// ── Financial & Inventory Overview Data Class & Provider ──────────────────────

class InventoryOverviewData {
  final double totalStockValue;
  final int activeMenuItemsCount;
  final double avgMargin16oz;
  final int highYieldAddOnsCount;
  final int lowStockIngredientsCount;
  final Map<String, double> categoryMargins;

  const InventoryOverviewData({
    required this.totalStockValue,
    required this.activeMenuItemsCount,
    required this.avgMargin16oz,
    required this.highYieldAddOnsCount,
    required this.lowStockIngredientsCount,
    required this.categoryMargins,
  });
}

final inventoryOverviewProvider = Provider<InventoryOverviewData>((ref) {
  final ingredients = ref.watch(allIngredientsProvider).valueOrNull ?? [];
  final products = ref.watch(allProductsProvider).valueOrNull ?? [];
  final addOns = ref.watch(allAddOnsProvider).valueOrNull ?? [];

  final totalStockValue = ingredients.fold<double>(
    0.0,
    (total, ing) => total + ing.totalValue,
  );

  final activeMenuItemsCount = products.where((p) => p.isAvailable).length;

  final productsWithCost = products.where((p) => p.cost != null && p.cost! > 0 && p.price > 0).toList();
  final avgMargin16oz = productsWithCost.isNotEmpty
      ? productsWithCost.fold<double>(0.0, (total, p) => total + p.marginPercentage) / productsWithCost.length
      : 52.0;

  final lowStockIngredientsCount = ingredients.where((i) => i.isLowStock).length;

  final Map<String, List<double>> catMarginsMap = {};
  for (final p in productsWithCost) {
    catMarginsMap.putIfAbsent(p.category, () => []).add(p.marginPercentage);
  }

  final Map<String, double> categoryMargins = {};
  for (final entry in catMarginsMap.entries) {
    categoryMargins[entry.key] =
        entry.value.reduce((a, b) => a + b) / entry.value.length;
  }

  return InventoryOverviewData(
    totalStockValue: totalStockValue > 0 ? totalStockValue : 37584.0,
    activeMenuItemsCount: activeMenuItemsCount > 0 ? activeMenuItemsCount : 43,
    avgMargin16oz: avgMargin16oz,
    highYieldAddOnsCount: addOns.isNotEmpty ? addOns.length : 4,
    lowStockIngredientsCount: lowStockIngredientsCount,
    categoryMargins: categoryMargins.isNotEmpty
        ? categoryMargins
        : {
            'Classics': 58.0,
            'Specialty': 54.0,
            'Premiums': 48.0,
            'Non-Coffee': 65.0,
            'Fizzy Drinks': 55.0,
          },
  );
});

// ── Staff Feedback Provider ───────────────────────────────────────────────────

final staffFeedbackProvider = StreamProvider<List<CafeanaFeedback>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('feedback')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => CafeanaFeedback.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

class FeedbackActionNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> togglePublish(CafeanaFeedback feedback) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('feedback').doc(feedback.orderId).update({
        'isPublished': !feedback.isPublished,
      });
      await logSystemActivity(ref, 'Feedback Publish Toggle', 'Toggled publish state for feedback on order ${feedback.orderId}');
    });
  }

  Future<void> replyToFeedback(CafeanaFeedback feedback, String reply) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('feedback').doc(feedback.orderId).update({
        'reply': reply,
      });
      await logSystemActivity(ref, 'Feedback Reply', 'Replied to feedback on order ${feedback.orderId}');
    });
  }
}

final feedbackActionProvider =
    AsyncNotifierProvider.autoDispose<FeedbackActionNotifier, void>(
        FeedbackActionNotifier.new);

// ── Product CRUD Provider ─────────────────────────────────────────────────────

class ProductCrudNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addProduct(Product product) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final docRef = db.collection('products').doc();
        final newProduct = product.copyWith(id: docRef.id);
        await docRef.set(newProduct.toFirestore(), SetOptions(merge: true));
      } catch (e, st) {
        debugPrint('Error in addProduct: $e\n$st');
        rethrow;
      }
    });
  }

  Future<void> updateProduct(Product product) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await db.collection('products').doc(product.id).update(product.toFirestore());
      } catch (e, st) {
        debugPrint('Error in updateProduct: $e\n$st');
        rethrow;
      }
    });
  }

  Future<void> deleteProduct(String id) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('products').doc(id).delete();
    });
  }

  /// Saves the exact ingredient builds for both cup sizes of a drink.
  /// `recipe` = Large (16 oz), `recipeSmall` = Small (12 oz).
  Future<void> updateRecipes({
    required Product product,
    required List<RecipeItem> large,
    required List<RecipeItem> small,
  }) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('products').doc(product.id).update({
        'recipe': large.map((r) => r.toMap()).toList(),
        'recipeSmall': small.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await logSystemActivity(ref, 'Update Recipe',
          'Updated ${product.name} recipe (Small: ${small.length} items, Large: ${large.length} items)');
    });
  }

  Future<void> toggleAvailability(Product product) async {
    final db = ref.read(firestoreProvider);
    await db.collection('products').doc(product.id).update({
      'isAvailable': !product.isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final productCrudProvider =
    AsyncNotifierProvider.autoDispose<ProductCrudNotifier, void>(
        ProductCrudNotifier.new);
// ── User Management Providers ─────────────────────────────────────────────────

final allUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('users')
      .orderBy('email')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => UserProfile.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

class UserRoleNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateRole(String uid, UserRole newRole) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('users').doc(uid).update({
        'role': newRole.name,
      });
      await logSystemActivity(ref, 'Role Update', 'Changed role of $uid to ${newRole.name}');
    });
  }
}

final userRoleProvider =
    AsyncNotifierProvider.autoDispose<UserRoleNotifier, void>(
        UserRoleNotifier.new);

// ── Promotions Providers ──────────────────────────────────────────────────────

final allPromotionsProvider = StreamProvider<List<Promotion>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('promotions')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Promotion.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

/// Streams active promotions that are set to visible for the customer dashboard.
final customerPromotionsProvider = StreamProvider<List<Promotion>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('promotions')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Promotion.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((p) => p.isActive && p.isVisible)
          .toList());
});

class PromotionCrudNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addPromotion(Promotion promo) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final docRef = db.collection('promotions').doc();
      final newPromo = Promotion(
        id: docRef.id,
        code: promo.code,
        description: promo.description,
        type: promo.type,
        value: promo.value,
        isActive: promo.isActive,
        isVisible: promo.isVisible,
        details: promo.details,
      );
      await docRef.set(newPromo.toFirestore());
    });
  }

  Future<void> updatePromotion(Promotion promo) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('promotions').doc(promo.id).update(promo.toFirestore());
    });
  }

  Future<void> deletePromotion(String id) async {
    final db = ref.read(firestoreProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await db.collection('promotions').doc(id).delete();
    });
  }

  Future<void> toggleActive(Promotion promo) async {
    final db = ref.read(firestoreProvider);
    await db.collection('promotions').doc(promo.id).update({
      'isActive': !promo.isActive,
    });
  }

  Future<void> toggleVisibility(Promotion promo) async {
    final db = ref.read(firestoreProvider);
    await db.collection('promotions').doc(promo.id).update({
      'isVisible': !promo.isVisible,
    });
  }
}

final promotionCrudProvider =
    AsyncNotifierProvider.autoDispose<PromotionCrudNotifier, void>(
        PromotionCrudNotifier.new);

// ── Activity Logs Provider ────────────────────────────────────────────────────

Future<void> logSystemActivity(Ref ref, String action, String details) async {
  final db = ref.read(firestoreProvider);
  final user = ref.read(authStateChangesProvider).valueOrNull;
  if (user == null) return;

  try {
    await db.collection('activityLogs').add({
      'staffId': user.uid,
      'staffEmail': user.email ?? 'Unknown',
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('Failed to log activity: $e');
  }
}

final allActivityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('activityLogs')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => ActivityLog.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});
