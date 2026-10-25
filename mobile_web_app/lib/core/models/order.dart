import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Matches the `status` field values in `orders/{orderId}`.
enum OrderStatus {
  queued,
  preparing,
  ready,
  received,
  completed,
  cancelled;

  static OrderStatus fromString(String? value) => switch (value) {
        'preparing' => OrderStatus.preparing,
        'ready' => OrderStatus.ready,
        'received' => OrderStatus.received,
        'completed' => OrderStatus.completed,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.queued,
      };

  String get label => switch (this) {
        OrderStatus.queued => 'Queued',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready',
        OrderStatus.received => 'Received',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get firestoreValue => name;
}

/// Matches the `paymentStatus` field values in `orders/{orderId}`.
enum PaymentStatus {
  pending,
  paid;

  static PaymentStatus fromString(String? value) =>
      value == 'paid' ? PaymentStatus.paid : PaymentStatus.pending;

  String get firestoreValue => name;
}

enum OrderType {
  dineIn,
  takeOut;

  static OrderType fromString(String? value) =>
      value == 'takeOut' ? OrderType.takeOut : OrderType.dineIn;

  String get label => this == OrderType.dineIn ? 'Dine In' : 'Take Out';
  String get firestoreValue => name;
}

// ── OrderItem ─────────────────────────────────────────────────────────────────

/// A single line-item embedded in `orders/{orderId}.items[]`.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.customizations = const {},
  });

  final String productId;
  final String name;
  final int quantity;
  final double price;
  final Map<String, String> customizations;

  double get lineTotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawCust = map['customizations'];
    final cust = <String, String>{};
    if (rawCust is Map) {
      rawCust.forEach((k, v) {
        if (k != null && v != null) {
          cust[k.toString()] = v.toString();
        }
      });
    }
    return OrderItem(
      productId: (map['productId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: ((map['price'] as num?) ?? 0).toDouble(),
      customizations: cust,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'customizations': customizations,
      };
}

// ── CafeOrder ─────────────────────────────────────────────────────────────────

/// Represents an order document at `orders/{orderId}` in Firestore.
class CafeOrder {
  const CafeOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.items,
    required this.total,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orderType = OrderType.dineIn,
    this.terminalId,
    this.note,
    this.promoCode,
    this.discountAmount = 0.0,
  });

  final String id;
  final int orderNumber;
  final String customerId;
  final List<OrderItem> items;
  final double total;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderType orderType;
  final String? terminalId;
  final String? note;
  final String? promoCode;
  final double discountAmount;

  // ── Firestore de/serialisation ─────────────────────────────────────────────

  factory CafeOrder.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = <OrderItem>[];
    for (final e in rawItems) {
      if (e is Map) {
        try {
          items.add(OrderItem.fromMap(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return DateTime.now();
    }

    return CafeOrder(
      id: snap.id,
      orderNumber: (data['orderNumber'] as num?)?.toInt() ?? 0,
      customerId: (data['customerId'] as String?) ?? '',
      items: items,
      total: ((data['total'] as num?) ?? 0).toDouble(),
      paymentStatus:
          PaymentStatus.fromString(data['paymentStatus'] as String?),
      status: OrderStatus.fromString(data['status'] as String?),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
      orderType: OrderType.fromString(data['orderType'] as String?),
      terminalId: data['terminalId'] as String?,
      note: data['note'] as String?,
      promoCode: data['promoCode'] as String?,
      discountAmount: ((data['discountAmount'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orderNumber': orderNumber,
        'customerId': customerId,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'paymentStatus': paymentStatus.firestoreValue,
        'status': status.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'orderType': orderType.firestoreValue,
        'terminalId': terminalId ?? FieldValue.delete(),
        'note': (note != null && note!.isNotEmpty) ? note : FieldValue.delete(),
        'promoCode': (promoCode != null && promoCode!.isNotEmpty) ? promoCode : FieldValue.delete(),
        'discountAmount': discountAmount,
      };

  /// Returns a copy with the given [status] and updated `updatedAt`.
  CafeOrder copyWith({OrderStatus? status, PaymentStatus? paymentStatus}) =>
      CafeOrder(
        id: id,
        orderNumber: orderNumber,
        customerId: customerId,
        items: items,
        total: total,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        orderType: orderType,
        terminalId: terminalId,
        note: note,
        promoCode: promoCode,
        discountAmount: discountAmount,
      );
}
