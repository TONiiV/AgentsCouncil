import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app/config.dart';
import 'api_service.dart';

/// Auth state that tracks both Supabase session and guest mode
class AuthState {
  final Session? session;
  final String? guestId;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.session,
    this.guestId,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => session != null;
  bool get isGuest => guestId != null && session == null;
  bool get isSignedIn => isAuthenticated || isGuest;

  AuthState copyWith({
    Session? session,
    String? guestId,
    bool? isLoading,
    String? error,
    bool clearSession = false,
    bool clearGuestId = false,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      guestId: clearGuestId ? null : (guestId ?? this.guestId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Auth service notifier that manages authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true));

  static const _guestIdKey = 'guest_id';

  /// Initialize auth - call this at app startup
  Future<void> initialize() async {
    try {
      // Initialize Supabase
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      // Check for existing session
      final session = Supabase.instance.client.auth.currentSession;

      // Load guest ID from local storage
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString(_guestIdKey);

      // Set guest ID on API service for auth headers (if no session)
      if (session == null && guestId != null) {
        ApiService().setGuestId(guestId);
      }

      state = AuthState(
        session: session,
        guestId: guestId,
        isLoading: false,
      );

      // Listen to auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        state = state.copyWith(
          session: data.session,
          clearSession: data.session == null,
        );

        // If user just signed in and had guest data, offer to claim it
        if (data.session != null && state.guestId != null) {
          await _claimGuestData();
        }
      });
    } catch (e) {
      state = AuthState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Continue as guest - generates and stores a guest ID
  Future<void> continueAsGuest() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final prefs = await SharedPreferences.getInstance();
      var guestId = prefs.getString(_guestIdKey);

      if (guestId == null) {
        guestId = const Uuid().v4();
        await prefs.setString(_guestIdKey, guestId);
      }

      // Set guest ID on API service for auth headers
      ApiService().setGuestId(guestId);

      state = state.copyWith(
        guestId: guestId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with OAuth provider (Google or GitHub)
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.agentscouncil://login-callback',
      );

      // Auth state will be updated via the onAuthStateChange listener
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out - clears both session and guest ID
  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Sign out from Supabase if authenticated
      if (state.isAuthenticated) {
        await Supabase.instance.client.auth.signOut();
      }

      // Clear guest ID from API service
      ApiService().setGuestId(null);

      // Clear guest ID from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestIdKey);

      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Claim guest data when user signs in with OAuth
  Future<void> _claimGuestData() async {
    if (state.guestId == null || state.session == null) return;

    try {
      // Call backend to claim guest data
      await ApiService().claimGuestData(state.guestId!);

      // Clear guest ID from API service since we're now authenticated
      ApiService().setGuestId(null);

      // Clear guest ID from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestIdKey);

      // Update state to clear guest ID
      state = state.copyWith(clearGuestId: true);
    } catch (e) {
      // Log error but don't fail the sign-in
      // The user is still authenticated, just without migrated data
      // ignore: avoid_print
      print('Failed to claim guest data: $e');
    }
  }

  /// Get the current user ID (either Supabase user ID or guest ID)
  String? get currentUserId {
    if (state.session?.user.id != null) {
      return state.session!.user.id;
    }
    return state.guestId;
  }
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
