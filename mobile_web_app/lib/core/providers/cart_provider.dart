import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import 'firebase_providers.dart';

// ── CartNotifier ──────────────────────────────────────────────────────────────

/// Manages the in-memory shopping cart. Never persisted to Firestore directly —
/// the cart is converted to an order document during checkout.
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Adds [product] to the cart, or increments its quantity by 1 if already present.
  void addItem(Product product, {Map<String, String> customizations = const {}}) {
    final index = state.indexWhere((i) => i.product.id == product.id && _mapEquals(i.customizations, customizations));
    if (index >= 0) {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == index)
            state[i].copyWith(quantity: state[i].quantity + 1)
          else
            state[i],
      ];
    } else {
      state = [...state, CartItem(product: product, quantity: 1, customizations: customizations)];
    }
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  /// Decrements the quantity of [itemId] by 1. Removes it if quantity reaches 0.
  void decrementItem(String itemId) {
    final index = state.indexWhere((i) => i.id == itemId);
    if (index < 0) return;
    final item = state[index];
    if (item.quantity <= 1) {
      removeItem(itemId);
    } else {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == index)
            item.copyWith(quantity: item.quantity - 1)
          else
            state[i],
      ];
    }
  }

  /// Removes the item with [itemId] from the cart entirely.
  void removeItem(String itemId) {
    state = state.where((i) => i.id != itemId).toList();
  }

  /// Sets the quantity of [itemId] to [quantity]. Removes the item if [quantity] <= 0.
  void setQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    state = [
      for (final item in state)
        if (item.id == itemId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
  }

  /// Empties the cart completely (called after successful checkout).
  void clear() => state = [];
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// The shopping cart — a list of [CartItem] objects.
final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

/// Computed total price for all items in the cart (Subtotal).
final cartTotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0.0, (totalSum, item) => totalSum + item.lineTotal);
});

/// The currently applied promotion, if any.
final appliedPromotionProvider = StateProvider<Promotion?>((ref) => null);

/// Computed discount amount based on the subtotal and applied promotion.
final cartDiscountProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartTotalProvider);
  final promo = ref.watch(appliedPromotionProvider);

  if (promo == null || !promo.isActive) return 0.0;

  if (promo.type == DiscountType.percentage) {
    return subtotal * (promo.value / 100);
  } else {
    // Fixed amount, do not exceed subtotal
    return promo.value > subtotal ? subtotal : promo.value;
  }
});

/// Final total after discount.
final cartFinalTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartTotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  return subtotal - discount;
});

/// Number of distinct products in the cart (used for nav badge).
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).length;
});

/// Fetches only active promotions for validation during checkout.
final activePromotionsProvider = FutureProvider<List<Promotion>>((ref) async {
  final db = ref.watch(firestoreProvider);
  final snap = await db.collection('promotions').where('isActive', isEqualTo: true).get();
  return snap.docs.map((doc) => Promotion.fromFirestore(doc)).toList();
});
