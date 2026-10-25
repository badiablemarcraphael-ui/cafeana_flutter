import 'package:cloud_firestore/cloud_firestore.dart';

enum DiscountType {
  percentage,
  fixed,
}

class Promotion {
  final String id;
  final String code; // e.g., "SUMMER20"
  final String description;
  final DiscountType type;
  final double value; // either percentage (0-100) or fixed amount
  final bool isActive;
  final bool isVisible; // whether shown on customer dashboard
  final String details; // what the promo has / terms & conditions

  const Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    this.isActive = true,
    this.isVisible = true,
    this.details = '',
  });

  factory Promotion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Promotion(
      id: snap.id,
      code: data['code'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: DiscountType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      isVisible: data['isVisible'] as bool? ?? true,
      details: data['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'description': description,
      'type': type.name,
      'value': value,
      'isActive': isActive,
      'isVisible': isVisible,
      'details': details,
    };
  }

  Promotion copyWith({
    String? id,
    String? code,
    String? description,
    DiscountType? type,
    double? value,
    bool? isActive,
    bool? isVisible,
    String? details,
  }) {
    return Promotion(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
      isVisible: isVisible ?? this.isVisible,
      details: details ?? this.details,
    );
  }

  double applyDiscount(double subtotal) {
    if (!isActive) return subtotal;
    if (type == DiscountType.percentage) {
      return subtotal * (1 - (value / 100));
    } else {
      return (subtotal - value).clamp(0, double.infinity);
    }
  }
}
