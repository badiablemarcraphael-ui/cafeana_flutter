import 'package:cloud_firestore/cloud_firestore.dart';

// ── Role enum ─────────────────────────────────────────────────────────────────

/// The role assigned to a Cafeana user, stored in Firestore under `users/{uid}.role`.
enum UserRole {
  customer,
  owner,
  cashier,
  kitchen;

  /// Parse from a Firestore string value. Defaults to [customer] for unknown values.
  static UserRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'cashier':
        return UserRole.cashier;
      case 'kitchen':
        return UserRole.kitchen;
      case 'staff': // Fallback for old databases
        return UserRole.owner;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }

  /// Returns true if the role is a staff role (owner, cashier, or kitchen).
  bool get isStaff => this != UserRole.customer;
}

// ── Model ─────────────────────────────────────────────────────────────────────

/// Represents a user profile document stored at `users/{uid}` in Firestore.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String uid;
  final String email;
  final UserRole role;
  final String? displayName;

  // ── Firestore de/serialisation ─────────────────────────────────────────────

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return UserProfile(
      uid: snap.id,
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromString(data['role'] as String?),
      displayName: data['displayName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'role': role.name,
        'displayName': displayName ?? FieldValue.delete(),
      };

  // ── Utilities ──────────────────────────────────────────────────────────────

  @override
  String toString() =>
      'UserProfile(uid: $uid, email: $email, role: ${role.name})';
}
