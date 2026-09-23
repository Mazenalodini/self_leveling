import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// AuthRepository combining Firebase Auth with a Local Fallback.
class AuthRepository {
  late final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Call this when the app starts.
  Future<void> init() async {
    try {
      _firebaseAuth = FirebaseAuth.instance;
      // Triggers immediate crash if config is entirely missing/invalid
      _firebaseAuth.currentUser;
    } catch (e) {
      log("Firebase configuration failed: $e\nEnsure google-services.json is valid.");
      rethrow;
    }
  }

  /// Stream of Auth State Changes.
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  /// Current user ID (Firebase UID).
  Future<String?> getCurrentUserId() async {
    return _firebaseAuth.currentUser?.uid;
  }

  /// The raw Firebase user.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Returns true if a user is currently signed in.
  Future<bool> isAuthenticated() async {
    final uid = await getCurrentUserId();
    return uid != null && uid.isNotEmpty;
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Auto-send verification email
    await userCredential.user?.sendEmailVerification();
  }

  Future<void> signInWithGoogle() async {
    // Trigger the native OS authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      // User manually canceled the sign-in flow
      throw Exception('Google sign-in canceled');
    }

    // Obtain the auth details and tokens
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a credential mapping
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Communicate credential with Firebase to sign in or sign up automatically
    await _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
