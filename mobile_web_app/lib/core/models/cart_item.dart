import 'product.dart';

/// A line-item in the local shopping cart (never persisted to Firestore directly).
///
/// The cart is held entirely in-memory by [CartNotifier].
class CartItem {
  CartItem({
    String? id,
    required this.product,
    required this.quantity,
    this.customizations = const {},
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + product.id;

  final String id;
  final Product product;
  final int quantity;
  final Map<String, String> customizations;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        product: product,
        quantity: quantity ?? this.quantity,
        customizations: customizations,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
