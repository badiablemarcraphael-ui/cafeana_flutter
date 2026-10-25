import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import 'firebase_providers.dart';

// ── Available products stream ─────────────────────────────────────────────────

/// Streams all products where `isAvailable == true`, ordered by category then name.
///
/// Used by the menu screen to build the category-grouped product list.
final availableProductsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('products')
      .orderBy('category')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => Product.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .where((product) => product.isAvailable)
            .toList(),
      );
});
