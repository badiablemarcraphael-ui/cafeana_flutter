import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'lib/firebase_options.dart';

void main() async {
  debugPrint('Initializing...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Signing in...');
  await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'cashier@seed.com', password: 'password123');
  debugPrint('Signed in as: ${FirebaseAuth.instance.currentUser?.uid}');
  
  try {
    debugPrint('Querying orders...');
    final snap = await FirebaseFirestore.instance.collection('orders').limit(1).get();
    debugPrint('Success! Docs: ${snap.docs.length}');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
