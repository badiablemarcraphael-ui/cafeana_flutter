import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user_profile.dart';

part 'firebase_providers.g.dart';

// ── Raw Firebase instances ────────────────────────────────────────────────────

/// Provides the [FirebaseAuth] singleton.
@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// Provides the [FirebaseFirestore] singleton.
@riverpod
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

// ── Auth state ────────────────────────────────────────────────────────────────

/// Stream of the currently signed-in [User], or `null` if signed out.
@riverpod
Stream<User?> authStateChanges(Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

// ── User profile ──────────────────────────────────────────────────────────────

/// Stream of the [UserProfile] document for the given Firebase Auth [uid].
///
/// Emits `null` while the document does not exist yet.
@riverpod
Stream<UserProfile?> userProfile(Ref ref, String uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? UserProfile.fromFirestore(snap) : null);
}
