/// AuthProvider — wraps FirebaseAuth and exposes auth state to the UI layer.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _sub;

  User? _user;
  bool _isChecked = false;

  AuthProvider({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _sub = _auth.authStateChanges().listen((user) {
      _user = user;
      _isChecked = true;
      notifyListeners();
    });
  }

  bool get isAuthenticated => _user != null;
  bool get isChecked => _isChecked;
  User? get currentUser => _user;

  // ── Sign In ────────────────────────────────────────────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────

  Future<void> signUpWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
