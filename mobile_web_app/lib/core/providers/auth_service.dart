import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import '../models/user_profile.dart';
import 'firebase_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Represents the current async state of auth operations (sign-in, register).
typedef AuthState = AsyncValue<void>;

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthServiceNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AsyncValue.data(null);

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  FirebaseFirestore get _db => ref.read(firestoreProvider);

  // ── Sign in ──────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
  }

  // ── Register ─────────────────────────────────────────────────────────────

  /// Creates a Firebase Auth account and writes a `users/{uid}` document
  /// with `role: "customer"` to Firestore.
  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;

      // Send verification email
      await user.sendEmailVerification();

      // Update display name in Firebase Auth
      await user.updateDisplayName(name);

      // Write users/{uid} profile document
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': name,
        'email': email,
        'role': UserRole.customer.name, // "customer"
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Forgot password ───────────────────────────────────────────────────────

  /// Sends a password-reset email via Firebase Auth.
  Future<void> sendPasswordReset(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _auth.sendPasswordResetEmail(email: email),
    );
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  //
  // Strategy:
  //   • Web  → FirebaseAuth.signInWithPopup(GoogleAuthProvider()) — no extra
  //            package config needed, works with the Firebase project's
  //            OAuth client ID already embedded in firebase_options.dart.
  //   • Native (Android / iOS) → google_sign_in v7 package flow.

  static bool _googleInitialized = false;

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        // ── Web: use Firebase signInWithPopup directly ──────────────────────
        final provider = GoogleAuthProvider();
        final userCred = await _auth.signInWithPopup(provider);
        await _upsertUserProfile(userCred.user!);
      } else {
        // ── Native: use google_sign_in v7 ──────────────────────────────────
        if (!_googleInitialized) {
          await gsi.GoogleSignIn.instance.initialize(
            serverClientId: '495457806256-ctcoa5rjq8ueo93s40keat6fu43ocu2n.apps.googleusercontent.com',
          );
          _googleInitialized = true;
        }
        gsi.GoogleSignInAccount googleUser;
        try {
          googleUser = await gsi.GoogleSignIn.instance.authenticate();
        } on gsi.GoogleSignInException catch (e) {
          if (e.code.toString() == 'sign_in_canceled') {
            state = const AsyncValue.data(null);
            return;
          }
          throw Exception('Google Sign-In failed. Please check SHA-1/SHA-256 keys in Firebase. Details: $e');
        } catch (e) {
          if (e is PlatformException && (e.code == 'sign_in_canceled' || e.code == 'CANCELED')) {
             state = const AsyncValue.data(null);
             return;
          }
          throw Exception('Google Sign-In failed. Please check SHA-1/SHA-256 keys in Firebase. Details: $e');
        }
        
        // Obtain auth details from the request
        final authData = googleUser.authentication;
        final idToken = authData.idToken;
        
        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
        );
        final userCred = await _auth.signInWithCredential(credential);
        await _upsertUserProfile(userCred.user!);
      }
    });
  }

  /// Creates a Firestore user profile on first sign-in, skips if it exists.
  Future<void> _upsertUserProfile(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'role': UserRole.customer.name,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!kIsWeb) {
        if (!_googleInitialized) {
          await gsi.GoogleSignIn.instance.initialize(
            serverClientId: '495457806256-ctcoa5rjq8ueo93s40keat6fu43ocu2n.apps.googleusercontent.com',
          );
          _googleInitialized = true;
        }
        try {
          await gsi.GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
    });
  }

  /// Clears any previous error state without performing an action.
  void clearError() => state = const AsyncValue.data(null);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authServiceProvider =
    NotifierProvider<AuthServiceNotifier, AuthState>(AuthServiceNotifier.new);
