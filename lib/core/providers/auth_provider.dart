/// AuthProvider — wraps FirebaseAuth and exposes auth state to the UI layer.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  StreamSubscription<User?>? _sub;
  Timer? _timeoutTimer;

  User? _user;
  bool _isChecked = false;
  bool _hasSeenOnboarding = false;
  // ⚠️ DEMO flavor: true when bypassed via local flag (no Firebase call needed)
  bool _demoAuthenticated = false;

  // When true, signInWithGoogle() bypasses the real Google picker and sets
  // _demoAuthenticated locally. Set by main_demo.dart (demo flavor).
  // When false (live flavor), real Firebase Google Sign-In is used.
  final bool _isDemo;

  AuthProvider({
    FirebaseAuth? auth,
    bool hasSeenOnboarding = false,
    bool isDemo = false,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = GoogleSignIn(),
        _hasSeenOnboarding = hasSeenOnboarding,
        _isDemo = isDemo {
    _timeoutTimer = Timer(const Duration(seconds: 2), () {
      if (!_isChecked) {
        _isChecked = true;
        notifyListeners();
      }
    });

    _sub = _auth.authStateChanges().listen((user) {
      _user = user;
      _isChecked = true;
      _timeoutTimer?.cancel();
      notifyListeners();
    });
  }

  bool get isAuthenticated => _user != null || _demoAuthenticated;
  bool get isChecked => _isChecked;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  User? get currentUser => _user;

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────────────

  /// Opens the Google account picker, exchanges tokens with Firebase Auth.
  ///
  /// DEMO flavor  (_isDemo = true):
  ///   Skips the Google picker entirely — flips _demoAuthenticated locally.
  ///   No network call, no Firebase console config needed, zero credentials.
  ///   isAuthenticated becomes true → GoRouter redirects to /dashboard.
  ///
  /// LIVE flavor  (_isDemo = false):
  ///   Runs the full Google Sign-In → Firebase credential exchange flow.
  ///   Real uid is established — SyncEngine writes to Firestore.
  Future<void> signInWithGoogle() async {
    if (_isDemo) {
      // Demo flavor: bypass Google picker, use local flag only.
      _demoAuthenticated = true;
      _isChecked = true;
      notifyListeners();
      return;
    }

    // Trigger the Google authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User dismissed the picker — not an error
      return;
    }

    // Obtain auth details from the Google sign-in request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a Firebase credential from the Google tokens
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    await _auth.signInWithCredential(credential);
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // Reset demo flag first so isAuthenticated becomes false immediately
    _demoAuthenticated = false;
    // Sign out from both Firebase and Google (clears cached account too)
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
