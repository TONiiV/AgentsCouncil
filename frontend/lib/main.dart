import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'app/theme.dart';
import 'shared/theme_switcher.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AgentsCouncilApp(),
    ),
  );
}

class AgentsCouncilApp extends ConsumerStatefulWidget {
  const AgentsCouncilApp({super.key});

  @override
  ConsumerState<AgentsCouncilApp> createState() => _AgentsCouncilAppState();
}

class _AgentsCouncilAppState extends ConsumerState<AgentsCouncilApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth on app start
    Future.microtask(() {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme variant for dynamic switching
    final themeVariant = ref.watch(themeVariantProvider);

    return MaterialApp(
      title: 'AgentsCouncil',
      debugShowCheckedModeBanner: false,
      theme: CyberTheme.forVariant(themeVariant),
      home: const AuthGate(),
    );
  }
}

/// AuthGate - shows auth screen when signed out, home screen when signed in
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading while initializing
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error if initialization failed
    if (authState.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${authState.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).initialize();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show home screen if signed in (either authenticated or guest)
    if (authState.isSignedIn) {
      return const HomeScreen();
    }

    // Show auth screen if not signed in
    return const AuthScreen();
  }
}

/// Simple auth screen placeholder - will be expanded in Task 8
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to AgentsCouncil',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ref.read(authProvider.notifier).continueAsGuest();
              },
              child: const Text('Continue as Guest'),
            ),
          ],
        ),
      ),
    );
  }
}
