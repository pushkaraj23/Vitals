import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'repositories/user_repository.dart';

/// Wraps Firebase Auth and initial user-doc writes.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  Future<User> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }

  Future<User> createAccount(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> createUserDoc(
    String uid,
    String email, {
    String? name,
  }) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'name': ?name,
      'isDemo': false,
      'onboardingComplete': false,
      'conditions': [],
      'medications': [],
      'allergies': [],
      'surgeries': [],
      'familyHistory': [],
      'consent': {'healthData': false},
    });
  }

  Future<void> saveConsent(String uid) async {
    await _db.collection('users').doc(uid).set({
      'consent': {
        'healthData': true,
        'acceptedAt': Timestamp.now(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> saveBasicProfile(
    String uid, {
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
  }) async {
    await _db.collection('users').doc(uid).set({
      'age': age,
      'sex': sex,
      'heightCm': heightCm,
      'weightKg': weightKg,
    }, SetOptions(merge: true));
  }

  Future<void> saveMedicalProfile(
    String uid, {
    required List<String> conditions,
    required List<String> medications,
    required List<String> allergies,
    required List<String> surgeries,
  }) async {
    await _db.collection('users').doc(uid).set({
      'conditions': conditions,
      'medications': medications,
      'allergies': allergies,
      'surgeries': surgeries,
    }, SetOptions(merge: true));
  }

  Future<void> saveFamilyHistory(
    String uid,
    List<FamilyHistoryItem> entries,
  ) async {
    await _db.collection('users').doc(uid).set({
      'familyHistory': entries.map((e) => e.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> completeOnboarding(String uid) async {
    await _db.collection('users').doc(uid).set({
      'onboardingComplete': true,
      'isDemo': false,
    }, SetOptions(merge: true));
  }

  Future<void> updateName(String uid, String name) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'name': name}, SetOptions(merge: true));
  }

  Future<void> deleteAccount(String uid) async {
    final subcols = [
      'daily',
      'baselines',
      'flags',
      'symptoms',
      'habits',
      'reviews',
    ];
    for (final col in subcols) {
      final snap =
          await _db.collection('users').doc(uid).collection(col).get();
      var batch = _db.batch();
      var n = 0;
      for (final d in snap.docs) {
        batch.delete(d.reference);
        n++;
        if (n >= 400) {
          await batch.commit();
          batch = _db.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
    }
    await _db.collection('users').doc(uid).delete();
    await _auth.currentUser?.delete();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  factory AuthException.fromCode(String code) {
    final msg = switch (code) {
      'user-not-found' => 'No account found for that email address.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' =>
        'Email or password is incorrect. Please try again.',
      'email-already-in-use' => 'An account with that email already exists.',
      'weak-password' => 'Password is too weak. Use at least 8 characters.',
      'invalid-email' => 'Please enter a valid email address.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'Network error. Please check your connection and try again.',
      'requires-recent-login' =>
        'Please sign out and sign in again before deleting your account.',
      _ => 'Something went wrong. Please try again.',
    };
    return AuthException(msg);
  }

  final String message;

  @override
  String toString() => message;
}
