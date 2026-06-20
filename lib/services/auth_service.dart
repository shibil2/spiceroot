import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth + Firestore-backed admin allowlist (`admin/config`).
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const String _adminCollection = 'admin';
  static const String _configDoc = 'config';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// True when the signed-in user's email is listed in Firestore admin config.
  Future<bool> isAdmin() async {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;

    final snap = await _db.collection(_adminCollection).doc(_configDoc).get();
    final data = snap.data();
    if (data == null) return false;

    final single = (data['adminEmail'] as String?)?.trim().toLowerCase();
    if (single != null && single == email) return true;

    final list = data['adminEmails'];
    if (list is List) {
      for (final entry in list) {
        if (entry.toString().trim().toLowerCase() == email) return true;
      }
    }

    return false;
  }
}
