import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient.dart';

/// Cup sizes sold by Cafeana.
enum DrinkSize {
  small('Small', 12),
  large('Large', 16);

  const DrinkSize(this.label, this.ounces);

  final String label;
  final int ounces;

  String get display => '$label ($ounces oz)';

  /// Resolves the size stored in an order/cart `customizations['Size']`.
  /// Anything that is not 'Large' (including legacy 'Regular') is Small.
  static DrinkSize fromCustomization(String? value) =>
      (value ?? '').toLowerCase().startsWith('large') ? DrinkSize.large : DrinkSize.small;
}

/// Represents a product document at `products/{productId}` in Firestore.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.isFeatured = false,
    this.stock,
    this.imageUrl,
    this.itemId,
    this.cost,
    this.servingSize = '16 oz',
    this.recipe = const [],
    this.recipeSmall = const [],
  });

  final String id;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;
  final bool isFeatured;

  /// `null` means unlimited stock.
  final int? stock;

  /// Firebase Storage URL or null.
  final String? imageUrl;

  /// Formal menu item ID, e.g. 'M001', 'M002', 'M004', 'M009'
  final String? itemId;

  /// Standard drink cost in PHP (e.g. ₱47.70 for Cafe Latte)
  final double? cost;

  /// Standard serving portion size (e.g. '16 oz')
  final String servingSize;

  /// Standard Operating Recipe for the LARGE (16 oz) cup.
  /// Kept under the `recipe` key for backward compatibility.
  final List<RecipeItem> recipe;

  /// Standard Operating Recipe for the SMALL (12 oz) cup (`recipeSmall` key).
  /// When empty, [recipeFor] auto-scales the Large recipe to 75%.
  final List<RecipeItem> recipeSmall;

  /// Whether the Small recipe is auto-derived (no explicit amounts saved).
  bool get isSmallAutoScaled => recipeSmall.isEmpty && recipe.isNotEmpty;

  /// Returns the exact ingredient build for [size].
  List<RecipeItem> recipeFor(DrinkSize size) => switch (size) {
        DrinkSize.large => recipe,
        DrinkSize.small => recipeSmall.isNotEmpty ? recipeSmall : autoScaleSmall(recipe),
      };

  /// Ingredient ID of the 16 oz cup set and its 12 oz counterpart.
  static const largeCupId = 'ING080';
  static const smallCupId = 'ING082';
  static const smallCupName = '12 oz Cup + Lid + Straw';

  /// Scales a 16 oz recipe down to 12 oz (12/16 = 75%).
  /// Countable items (sets / units / pcs) are not scaled, and the 16 oz cup
  /// is swapped for the 12 oz cup. Amounts are rounded to 0.1.
  static List<RecipeItem> autoScaleSmall(List<RecipeItem> large) {
    const factor = 12 / 16;
    return [
      for (final r in large)
        if (r.ingredientId == largeCupId)
          r.copyWith(ingredientId: smallCupId, name: smallCupName)
        else if (const {'set', 'unit', 'pc', 'pcs'}.contains(r.unit.toLowerCase()))
          r
        else
          r.copyWith(quantity: (r.quantity * factor * 10).roundToDouble() / 10),
    ];
  }

  /// Profit per unit sold: price - cost
  double get profit => price - (cost ?? 0.0);

  /// Cost percentage of selling price: (cost / price) * 100
  double get costPercentage =>
      (price > 0 && cost != null) ? (cost! / price) * 100 : 0.0;

  /// Profit margin percentage: (profit / price) * 100
  double get marginPercentage =>
      (price > 0 && cost != null) ? ((price - cost!) / price) * 100 : 0.0;

  // ── Firestore de/serialisation ───────────────────────────────────────────────

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    List<RecipeItem> parseRecipe(dynamic raw) => raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map((m) => RecipeItem.fromMap(m))
            .toList()
        : <RecipeItem>[];
    final recipeList = parseRecipe(data['recipe']);
    final recipeSmallList = parseRecipe(data['recipeSmall']);

    return Product(
      id: snap.id,
      name: (data['name'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      category: (data['category'] as String?) ?? 'other',
      isAvailable: (data['isAvailable'] as bool?) ?? false,
      isFeatured: (data['isFeatured'] as bool?) ?? false,
      stock: data['stock'] as int?,
      imageUrl: data['imageUrl'] as String?,
      itemId: data['itemId'] as String?,
      cost: (data['cost'] as num?)?.toDouble(),
      servingSize: (data['servingSize'] as String?) ?? '16 oz',
      recipe: recipeList,
      recipeSmall: recipeSmallList,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'price': price,
        'category': category,
        'isAvailable': isAvailable,
        'isFeatured': isFeatured,
        'stock': stock ?? FieldValue.delete(),
        'imageUrl': imageUrl ?? FieldValue.delete(),
        if (itemId != null) 'itemId': itemId,
        if (cost != null) 'cost': cost,
        'servingSize': servingSize,
        if (recipe.isNotEmpty)
          'recipe': recipe.map((r) => r.toMap()).toList(),
        if (recipeSmall.isNotEmpty)
          'recipeSmall': recipeSmall.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    bool? isAvailable,
    bool? isFeatured,
    int? stock,
    String? imageUrl,
    String? itemId,
    double? cost,
    String? servingSize,
    List<RecipeItem>? recipe,
    List<RecipeItem>? recipeSmall,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      itemId: itemId ?? this.itemId,
      cost: cost ?? this.cost,
      servingSize: servingSize ?? this.servingSize,
      recipe: recipe ?? this.recipe,
      recipeSmall: recipeSmall ?? this.recipeSmall,
    );
  }

  @override
  String toString() => 'Product($id, ${itemId ?? ""}: $name, ₱$price, cost: ₱$cost)';
}
