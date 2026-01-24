import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../models/auth_state.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Factory function to create the auth notifier for native platforms
AuthNotifier createAuthNotifier(ApiService api) => AuthNotifierNative(api);

/// Native implementation using url_launcher + polling
/// Works on iOS, macOS, Windows, Linux, Android
class AuthNotifierNative extends AuthNotifier {
  final ApiService _api;
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 2);
  static const _pollTimeout = Duration(minutes: 5);

  AuthNotifierNative(this._api)
      : super(const AuthState(status: AuthStatus.initial)) {
    checkExistingAuth();
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

  @override
  Future<void> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Get the OAuth login URL from the backend
      final loginUrl = await _api.getOAuthLoginUrl();
      final uri = Uri.parse(loginUrl);

      // Try to launch the URL in external browser
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          // Start polling for auth completion
          _startPollingForAuth();
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            error: 'Could not open browser. Please try again.',
          );
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Cannot open URL: $loginUrl',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Failed to start OAuth: $e',
      );
    }
  }

  void _startPollingForAuth() {
    _stopPolling();

    final startTime = DateTime.now();

    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      // Check for timeout
      if (DateTime.now().difference(startTime) > _pollTimeout) {
        _stopPolling();
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'OAuth timed out. Please try again.',
        );
        return;
      }

      try {
        final accounts = await _api.getOAuthAccounts();
        if (accounts.isNotEmpty) {
          _stopPolling();
          state = state.copyWith(
            status: AuthStatus.authenticated,
            email: accounts.first['email'] as String?,
          );
        }
      } catch (e) {
        // Continue polling on error - backend might be temporarily unavailable
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> logout() async {
    _stopPolling();

    if (state.email != null) {
      try {
        await _api.deleteOAuthAccount(state.email!);
      } catch (_) {}
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
