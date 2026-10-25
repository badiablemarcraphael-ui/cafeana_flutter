import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.staffId,
    required this.staffEmail,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  final String id;
  final String staffId;
  final String staffEmail;
  final String action;
  final String details;
  final DateTime timestamp;

  factory ActivityLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return ActivityLog(
      id: snap.id,
      staffId: data['staffId'] as String? ?? '',
      staffEmail: data['staffEmail'] as String? ?? '',
      action: data['action'] as String? ?? '',
      details: data['details'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffEmail': staffEmail,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
