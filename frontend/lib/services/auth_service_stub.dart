import '../models/auth_state.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Factory function to create the auth notifier for non-web platforms
AuthNotifier createAuthNotifier(ApiService api) => AuthNotifierStub(api);

/// Stub implementation for non-web platforms (macOS, etc.)
class AuthNotifierStub extends AuthNotifier {
  final ApiService _api;

  AuthNotifierStub(this._api)
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
    state = state.copyWith(
      status: AuthStatus.error,
      error:
          'OAuth popup is only supported on web platform. Use the web version of the app.',
    );
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
}
