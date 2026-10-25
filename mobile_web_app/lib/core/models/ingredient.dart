import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a raw ingredient holding in `ingredients/{ingredientId}`.
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.packSize,
    required this.unit,
    required this.unitCost,
    required this.stockLevel,
    this.minStockLevel = 500.0,
    double? packQuantity,
    this.updatedAt,
    // ignore: prefer_initializing_formals
  }) : _packQuantity = packQuantity;

  /// Unique holding ID, e.g. 'ING050', 'ING001'
  final String id;

  /// Display name, e.g. 'Matcha Powder', 'Espresso Beans (House)'
  final String name;

  /// Ingredient category: 'Coffee', 'Powder', 'Sauce', 'Syrup', 'Fruit', 'Dairy', 'Packaging', etc.
  final String category;

  /// Commercial packaging size, e.g. '500 g pack', '1.9 kg bottle', '1 kg bag', '1 L pack', '750 ml bottle'
  final String packSize;

  /// Base measurement unit: 'g', 'ml', 'set', 'unit'
  final String unit;

  /// Cost in PHP per base unit, e.g. 3.60 / g, 0.90 / g, 0.68 / g, 0.60 / ml
  final double unitCost;

  /// Current stock level in base units (g, ml, sets)
  final double stockLevel;

  /// Minimum safety stock threshold for low-stock alerts
  final double minStockLevel;

  final DateTime? updatedAt;

  final double? _packQuantity;

  /// Exact amount of base units ([unit]) contained in ONE pack,
  /// e.g. 500 (g) for a '500 g pack', 1900 (g) for a '1.9 kg bottle'.
  /// Falls back to parsing [packSize] for older documents.
  double get packQuantity {
    final q = _packQuantity;
    if (q != null && q > 0) return q;
    return parsePackQuantity(packSize) ?? 1.0;
  }

  /// Container word of the pack, e.g. 'pack', 'bottle', 'bag'.
  String get packContainer {
    final m = RegExp(r'[\d.,]+\s*[a-zA-Z]+\s+(.+)$').firstMatch(packSize.trim());
    return m?.group(1)?.trim() ?? 'pack';
  }

  /// Number of packs currently on hand (may be fractional for opened packs).
  double get packsOnHand => packQuantity > 0 ? stockLevel / packQuantity : 0;

  /// Low-stock alert threshold expressed in packs.
  double get minPacks => packQuantity > 0 ? minStockLevel / packQuantity : 0;

  /// Total inventory holding value: stockLevel * unitCost
  double get totalValue => stockLevel * unitCost;

  /// Whether current stock has hit or fallen below the threshold
  bool get isLowStock => stockLevel <= minStockLevel;

  /// Parses a pack description like '1.9 kg bottle', '750 ml bottle',
  /// '1 L pack' or '100 set sleeve' into base units (g / ml / set).
  static double? parsePackQuantity(String packSize) {
    final m = RegExp(r'([\d.,]+)\s*([a-zA-Z]+)').firstMatch(packSize);
    if (m == null) return null;
    final value = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (value == null) return null;
    return switch (m.group(2)!.toLowerCase()) {
      'kg' => value * 1000,
      'l' || 'liter' || 'litre' => value * 1000,
      _ => value,
    };
  }

  factory Ingredient.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Ingredient(
      id: snap.id,
      name: (data['name'] as String?) ?? snap.id,
      category: (data['category'] as String?) ?? 'General',
      packSize: (data['packSize'] as String?) ?? '',
      unit: (data['unit'] as String?) ?? 'g',
      unitCost: ((data['unitCost'] as num?) ?? 0).toDouble(),
      stockLevel: ((data['stockLevel'] as num?) ?? 0).toDouble(),
      minStockLevel: ((data['minStockLevel'] as num?) ?? 500).toDouble(),
      packQuantity: (data['packQuantity'] as num?)?.toDouble(),
      updatedAt: parseTs(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'category': category,
        'packSize': packSize,
        'packQuantity': packQuantity,
        'unit': unit,
        'unitCost': unitCost,
        'stockLevel': stockLevel,
        'minStockLevel': minStockLevel,
        'totalValue': totalValue,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Ingredient copyWith({
    String? id,
    String? name,
    String? category,
    String? packSize,
    String? unit,
    double? unitCost,
    double? stockLevel,
    double? minStockLevel,
    double? packQuantity,
    DateTime? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      packSize: packSize ?? this.packSize,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      stockLevel: stockLevel ?? this.stockLevel,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      packQuantity: packQuantity ?? _packQuantity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Ingredient($id, $name, $stockLevel$unit @ ₱$unitCost/$unit)';
}

/// Represents an ingredient line item in a Standard Operating Recipe (BOM).
class RecipeItem {
  const RecipeItem({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.unitCost = 0.0,
  });

  /// ID of the ingredient in `ingredients` collection
  final String ingredientId;

  /// Display name of the ingredient component
  final String name;

  /// Quantity consumed per serving, e.g. 18 (g), 200 (ml), 1 (set)
  final double quantity;

  /// Measurement unit: 'g', 'ml', 'set', 'unit'
  final String unit;

  /// Cost per base unit (snapshot or dynamically fetched)
  final double unitCost;

  /// Line cost contribution: quantity * unitCost
  double get costContribution => quantity * unitCost;

  factory RecipeItem.fromMap(Map<String, dynamic> map) => RecipeItem(
        ingredientId: (map['ingredientId'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        quantity: ((map['quantity'] as num?) ?? 0).toDouble(),
        unit: (map['unit'] as String?) ?? 'g',
        unitCost: ((map['unitCost'] as num?) ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'ingredientId': ingredientId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unitCost': unitCost,
        'costContribution': costContribution,
      };

  RecipeItem copyWith({
    String? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    double? unitCost,
  }) {
    return RecipeItem(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}

/// Represents a standard menu add-on and its profit margins (from Page 3 of Report).
class StandardAddOn {
  const StandardAddOn({
    required this.id,
    required this.name,
    required this.costedWith,
    required this.cost,
    required this.price,
    this.ingredientId,
    this.portionSize,
    this.unit,
  });

  final String id;
  final String name; // e.g. 'Sauce (15g)', 'Syrup (15ml)'
  final String costedWith; // e.g. 'Caramel Sauce', 'Vanilla Syrup'
  final double cost; // e.g. 6.75, 9.00
  final double price; // e.g. 20.00, 25.00
  final String? ingredientId;
  final double? portionSize;
  final String? unit;

  double get profit => price - cost;
  double get costPercentage => price > 0 ? (cost / price) * 100 : 0.0;
  double get marginPercentage => price > 0 ? (profit / price) * 100 : 0.0;

  factory StandardAddOn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    return StandardAddOn(
      id: snap.id,
      name: (data['name'] as String?) ?? snap.id,
      costedWith: (data['costedWith'] as String?) ?? '',
      cost: ((data['cost'] as num?) ?? 0).toDouble(),
      price: ((data['price'] as num?) ?? 0).toDouble(),
      ingredientId: data['ingredientId'] as String?,
      portionSize: (data['portionSize'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'costedWith': costedWith,
        'cost': cost,
        'price': price,
        'profit': profit,
        'costPercentage': costPercentage,
        if (ingredientId != null) 'ingredientId': ingredientId,
        if (portionSize != null) 'portionSize': portionSize,
        if (unit != null) 'unit': unit,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
