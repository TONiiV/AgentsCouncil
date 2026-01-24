import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app/config.dart';

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

      state = AuthState(
        session: session,
        guestId: guestId,
        isLoading: false,
      );

      // Listen to auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        state = state.copyWith(
          session: data.session,
          clearSession: data.session == null,
        );
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

  /// Sign out - clears both session and guest ID
  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Sign out from Supabase if authenticated
      if (state.isAuthenticated) {
        await Supabase.instance.client.auth.signOut();
      }

      // Clear guest ID
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
