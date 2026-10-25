import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String staffId;
  final String staffEmail;
  final String action;
  final String details;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.staffId,
    required this.staffEmail,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ActivityLog(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      staffEmail: data['staffEmail'] ?? '',
      action: data['action'] ?? '',
      details: data['details'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffEmail': staffEmail,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
