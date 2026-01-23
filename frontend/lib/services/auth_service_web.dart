import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/auth_state.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Factory function to create the auth notifier for web platform
AuthNotifier createAuthNotifier(ApiService api) => AuthNotifierWeb(api);

/// Web implementation with OAuth popup flow
class AuthNotifierWeb extends AuthNotifier {
  final ApiService _api;
  StreamSubscription? _messageSubscription;

  AuthNotifierWeb(this._api)
      : super(const AuthState(status: AuthStatus.initial)) {
    checkExistingAuth();
    _listenForOAuthCallback();
  }

  @override
  Future<void> checkExistingAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final accounts = await _api.getOAuthAccounts();
      if (accounts.isNotEmpty) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: accounts.first['email'] as String?,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  void _listenForOAuthCallback() {
    _messageSubscription = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is Map && data['type'] == 'oauth_callback') {
        if (data['success'] == true) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            email: data['email'] as String?,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            error: (data['error'] as String?) ?? 'OAuth failed',
          );
        }
      }
    });
  }

  @override
  Future<void> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final loginUrl = await _api.getOAuthLoginUrl();

      // Open popup window
      final popup = html.window.open(
        loginUrl,
        'google_oauth',
        'width=500,height=600,menubar=no,toolbar=no,location=no',
      );

      if (popup == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Popup was blocked. Please allow popups for this site.',
        );
      }
      // The popup will close itself and send a postMessage when complete
      // which is handled by _listenForOAuthCallback
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Failed to start OAuth: $e',
      );
    }
  }

  @override
  Future<void> logout() async {
    if (state.email != null) {
      try {
        await _api.deleteOAuthAccount(state.email!);
      } catch (_) {}
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
