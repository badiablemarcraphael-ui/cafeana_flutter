import 'package:cloud_firestore/cloud_firestore.dart';
import 'order.dart';

/// Represents a feedback document at `feedback/{feedbackId}` in Firestore.
///
/// The document ID equals the `orderId` — enforcing one feedback per order.
class CafeanaFeedback {
  const CafeanaFeedback({
    required this.orderId,
    required this.customerId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.isPublished = false,
    this.reply,
    this.productNames = const [],
    this.productIds = const [],
    this.items = const [],
  });

  final String orderId;
  final String customerId;

  /// Integer rating from 1 to 5.
  final int rating;

  /// Optional free-text comment; max 500 chars.
  final String? comment;

  final DateTime? createdAt;
  
  /// Whether the feedback is published for customers to see.
  final bool isPublished;
  
  /// Optional reply from the owner/staff.
  final String? reply;

  /// List of product names ordered (e.g. ['Americano', 'Strawberry Milk']).
  final List<String> productNames;

  /// List of product IDs ordered (e.g. ['prod_americano']).
  final List<String> productIds;

  /// Full item details for the order.
  final List<OrderItem> items;

  Map<String, dynamic> toFirestore() => {
        'orderId': orderId,
        'customerId': customerId,
        'rating': rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublished': isPublished,
        if (reply != null && reply!.isNotEmpty) 'reply': reply,
        if (productNames.isNotEmpty) 'productNames': productNames,
        if (productIds.isNotEmpty) 'productIds': productIds,
        if (items.isNotEmpty) 'items': items.map((i) => i.toMap()).toList(),
      };

  factory CafeanaFeedback.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    final rawItems = data['items'] as List<dynamic>?;
    final itemsList = rawItems != null
        ? rawItems
            .map((e) =>
                OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <OrderItem>[];

    final rawNames = data['productNames'] as List<dynamic>?;
    final productNamesList = rawNames != null
        ? rawNames.map((e) => e.toString()).toList()
        : itemsList.map((i) => i.name).toList();

    final rawIds = data['productIds'] as List<dynamic>?;
    final productIdsList = rawIds != null
        ? rawIds.map((e) => e.toString()).toList()
        : itemsList.map((i) => i.productId).toList();

    return CafeanaFeedback(
      orderId: (data['orderId'] as String?) ?? snap.id,
      customerId: (data['customerId'] as String?) ?? '',
      rating: (data['rating'] as int?) ?? 0,
      comment: data['comment'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      isPublished: (data['isPublished'] as bool?) ?? false,
      reply: data['reply'] as String?,
      productNames: productNamesList,
      productIds: productIdsList,
      items: itemsList,
    );
  }

  CafeanaFeedback copyWith({
    bool? isPublished,
    String? reply,
    List<String>? productNames,
    List<String>? productIds,
    List<OrderItem>? items,
  }) {
    return CafeanaFeedback(
      orderId: orderId,
      customerId: customerId,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
      isPublished: isPublished ?? this.isPublished,
      reply: reply ?? this.reply,
      productNames: productNames ?? this.productNames,
      productIds: productIds ?? this.productIds,
      items: items ?? this.items,
    );
  }
}
