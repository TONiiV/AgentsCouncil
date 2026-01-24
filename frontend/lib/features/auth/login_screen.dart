import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../../shared/glass_card.dart';
import '../../shared/neon_button.dart';
import '../../shared/glow_text.dart';
import '../../providers/auth_provider.dart';

/// Login screen with OAuth providers (Google, GitHub)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final signIn = ref.read(signInWithOAuthProvider);
      await signIn(provider);
      // Navigation will be handled by auth state listener
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CyberColors.midnightBg,
              CyberColors.midnightSurface,
              CyberColors.midnightCard.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Logo/Icon
                    Icon(
                      Icons.groups_rounded,
                      size: 80,
                      color: CyberColors.neonCyan,
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    GlowText(
                      'AgentsCouncil',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      glowColor: CyberColors.neonCyan,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'AI Debate & Collaboration Platform',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: CyberColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Login Card
                    GlassCard(
                      enableGlow: true,
                      glowColor: CyberColors.neonCyan,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in to continue',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: CyberColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Google Sign In Button
                          NeonButton(
                            label: 'Continue with Google',
                            icon: Icons.g_mobiledata_rounded,
                            onPressed: _isLoading
                                ? null
                                : () =>
                                    _signInWithProvider(OAuthProvider.google),
                            color: CyberColors.neonCyan,
                            isPrimary: true,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 16),

                          // GitHub Sign In Button
                          NeonButton(
                            label: 'Continue with GitHub',
                            icon: Icons.code_rounded,
                            onPressed: _isLoading
                                ? null
                                : () =>
                                    _signInWithProvider(OAuthProvider.github),
                            color: CyberColors.holoPurple,
                            isPrimary: false,
                            isLoading: false,
                          ),

                          // Error Message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CyberColors.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: CyberColors.errorRed.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: CyberColors.errorRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: CyberColors.errorRed,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms & Privacy
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: CyberColors.textMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
