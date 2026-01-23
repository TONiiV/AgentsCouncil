import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.email,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, String? email, String? error}) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
