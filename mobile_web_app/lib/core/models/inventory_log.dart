import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a log entry in the `inventoryLog` collection.
class InventoryLog {
  const InventoryLog({
    required this.id,
    required this.productId,
    required this.change,
    required this.reason,
    required this.staffId,
    required this.timestamp,
    this.orderId,
    this.ingredientId,
    this.ingredientName,
    this.unit = 'units',
    this.costImpact,
  });

  final String id;
  final String productId;
  final double change;
  final String reason;
  final String staffId;
  final DateTime timestamp;
  final String? orderId;
  final String? ingredientId;
  final String? ingredientName;
  final String unit;
  final double? costImpact;

  factory InventoryLog.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return InventoryLog(
      id: snap.id,
      productId: (data['productId'] as String?) ?? '',
      change: ((data['change'] as num?) ?? 0).toDouble(),
      reason: (data['reason'] as String?) ?? 'correction',
      staffId: (data['staffId'] as String?) ?? '',
      timestamp: parseTs(data['timestamp']),
      orderId: data['orderId'] as String?,
      ingredientId: data['ingredientId'] as String?,
      ingredientName: data['ingredientName'] as String?,
      unit: (data['unit'] as String?) ?? 'units',
      costImpact: (data['costImpact'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'change': change,
        'reason': reason,
        'staffId': staffId,
        'timestamp': FieldValue.serverTimestamp(),
        if (orderId != null && orderId!.isNotEmpty) 'orderId': orderId,
        if (ingredientId != null && ingredientId!.isNotEmpty) 'ingredientId': ingredientId,
        if (ingredientName != null && ingredientName!.isNotEmpty) 'ingredientName': ingredientName,
        'unit': unit,
        if (costImpact != null) 'costImpact': costImpact,
      };
}

