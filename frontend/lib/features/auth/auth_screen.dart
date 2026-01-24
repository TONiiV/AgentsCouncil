import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../shared/shared.dart';

/// Auth screen with OAuth and Guest login options
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CyberColors.midnightBg,
              CyberColors.midnightSurface,
              CyberColors.midnightBg,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background glow
            _buildBackgroundGlow(),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 48 : 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 48),
                        _buildWelcomeCard(authState),
                        const SizedBox(height: 24),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      CyberColors.neonCyan
                          .withOpacity(_glowAnimation.value * 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      CyberColors.holoPurple
                          .withOpacity(_glowAnimation.value * 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo icon with animated glow
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: CyberGradients.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: CyberColors.neonCyan
                        .withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups,
                size: 48,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        // App name with glow
        GlowText(
          'AgentsCouncil',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          glowColor: CyberColors.neonCyan,
          blurRadius: 12,
        ),
        const SizedBox(height: 8),
        Text(
          'AI-Powered Multi-Agent Debate Platform',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CyberColors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(AuthState authState) {
    return SolidGlassCard(
      glowColor: CyberColors.neonCyan,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Get Started',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to sync your councils and debates across devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CyberColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Google sign-in button
          _AuthButton(
            label: 'Continue with Google',
            icon: _GoogleIcon(),
            onPressed: authState.isLoading
                ? null
                : () => _signInWithProvider(OAuthProvider.google),
            isLoading: authState.isLoading,
          ),
          const SizedBox(height: 12),

          // GitHub sign-in button
          _AuthButton(
            label: 'Continue with GitHub',
            icon: const Icon(Icons.code, size: 20),
            onPressed: authState.isLoading
                ? null
                : () => _signInWithProvider(OAuthProvider.github),
            isLoading: authState.isLoading,
          ),

          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: CyberColors.midnightBorder.withOpacity(0.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CyberColors.textMuted,
                      ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: CyberColors.midnightBorder.withOpacity(0.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Guest button
          NeonButton(
            label: 'Continue as Guest',
            icon: Icons.person_outline,
            isPrimary: false,
            isLoading: authState.isLoading,
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authProvider.notifier).continueAsGuest(),
            width: double.infinity,
          ),

          if (authState.error != null) ...[
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
                      authState.error!,
                      style: TextStyle(
                        color: CyberColors.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Guest data is stored locally on this device.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CyberColors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to sync across devices and claim your data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CyberColors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    await ref.read(authProvider.notifier).signInWithOAuth(provider);
  }
}

/// Custom auth button with provider styling
class _AuthButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _AuthButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: CyberAnimations.fast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered && widget.onPressed != null
              ? CyberGlow.soft(CyberColors.textSecondary)
              : null,
        ),
        child: OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: CyberColors.textPrimary,
            backgroundColor: _isHovered
                ? CyberColors.midnightSurface
                : CyberColors.midnightCard,
            side: BorderSide(
              color: _isHovered
                  ? CyberColors.textSecondary.withOpacity(0.5)
                  : CyberColors.midnightBorder,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(CyberColors.textMuted),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.icon,
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Google "G" icon widget
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simple Google G using text (no external assets needed)
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4), // Google Blue
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
