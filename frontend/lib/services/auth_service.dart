import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import 'api_service.dart';

// Conditional import - use native implementation for iOS/macOS/Windows/etc,
// web implementation for browser
import 'auth_service_native.dart' if (dart.library.html) 'auth_service_web.dart'
    as platform;

/// Provider for the auth notifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return platform.createAuthNotifier(ApiService());
});

/// Abstract interface for auth operations
abstract class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(super.state);

  Future<void> loginWithGoogle();
  Future<void> logout();
  Future<void> checkExistingAuth();
}
