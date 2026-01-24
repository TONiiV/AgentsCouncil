import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign in with OAuth (Google or GitHub)
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.agentscouncil://login-callback/',
      );
      return response;
    } catch (e) {
      print('OAuth sign in error: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Get user ID
  String? getUserId() {
    return currentUser?.id;
  }

  // Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }
}
