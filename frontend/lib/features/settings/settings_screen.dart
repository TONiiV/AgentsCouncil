import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../shared/shared.dart';

/// Settings screen with auth status and account management
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: CyberColors.neonCyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountSection(context, ref, authState),
            const SizedBox(height: 32),
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_circle_outlined, color: CyberColors.neonCyan),
            const SizedBox(width: 12),
            Text(
              'Account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SolidGlassCard(
          glowColor: authState.isAuthenticated
              ? CyberColors.successGreen
              : CyberColors.holoPurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auth status indicator
              _buildAuthStatus(context, authState),
              const SizedBox(height: 24),

              // Auth actions
              if (authState.isAuthenticated) ...[
                // Authenticated user
                _buildUserInfo(context, authState),
                const SizedBox(height: 24),
                NeonButton(
                  label: 'Sign Out',
                  icon: Icons.logout,
                  color: CyberColors.errorRed,
                  isPrimary: false,
                  onPressed: () => _signOut(context, ref),
                  width: double.infinity,
                ),
              ] else if (authState.isGuest) ...[
                // Guest user
                _buildGuestInfo(context, authState),
                const SizedBox(height: 24),
                Text(
                  'Sign in to sync your councils and debates across devices',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CyberColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildSignInButtons(context, ref, authState),
                const SizedBox(height: 16),
                Divider(color: CyberColors.midnightBorder.withOpacity(0.5)),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'Sign Out (Clear Guest Data)',
                  icon: Icons.logout,
                  color: CyberColors.errorRed,
                  isPrimary: false,
                  onPressed: () => _signOut(context, ref),
                  width: double.infinity,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthStatus(BuildContext context, AuthState authState) {
    final isAuthenticated = authState.isAuthenticated;
    final statusColor =
        isAuthenticated ? CyberColors.successGreen : CyberColors.warningAmber;
    final statusText = isAuthenticated ? 'Signed In' : 'Guest Mode';
    final statusIcon =
        isAuthenticated ? Icons.verified_user : Icons.person_outline;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: statusColor,
                    ),
              ),
              Text(
                isAuthenticated
                    ? 'Data synced to cloud'
                    : 'Data stored locally',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CyberColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: CyberGlow.soft(statusColor),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(BuildContext context, AuthState authState) {
    final user = authState.session?.user;
    final email = user?.email ?? 'Unknown';
    final provider = user?.appMetadata['provider'] as String? ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(context, 'Email', email),
        const SizedBox(height: 8),
        _buildInfoRow(context, 'Provider', _formatProvider(provider)),
        const SizedBox(height: 8),
        _buildInfoRow(context, 'User ID', user?.id ?? 'Unknown',
            truncate: true),
      ],
    );
  }

  Widget _buildGuestInfo(BuildContext context, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(context, 'Guest ID', authState.guestId ?? 'Unknown',
            truncate: true),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {bool truncate = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CyberColors.textMuted,
                ),
          ),
        ),
        Expanded(
          child: Text(
            truncate && value.length > 20
                ? '${value.substring(0, 8)}...${value.substring(value.length - 8)}'
                : value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButtons(
      BuildContext context, WidgetRef ref, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SignInButton(
          label: 'Continue with Google',
          icon: _GoogleIcon(),
          onPressed: authState.isLoading
              ? null
              : () => ref
                  .read(authProvider.notifier)
                  .signInWithOAuth(OAuthProvider.google),
          isLoading: authState.isLoading,
        ),
        const SizedBox(height: 12),
        _SignInButton(
          label: 'Continue with GitHub',
          icon: const Icon(Icons.code, size: 20),
          onPressed: authState.isLoading
              ? null
              : () => ref
                  .read(authProvider.notifier)
                  .signInWithOAuth(OAuthProvider.github),
          isLoading: authState.isLoading,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: CyberColors.neonCyan),
            const SizedBox(width: 12),
            Text(
              'About',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SolidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: CyberGradients.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        const Icon(Icons.groups, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AgentsCouncil',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'AI-Powered Multi-Agent Debate Platform',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: CyberColors.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: CyberColors.midnightBorder.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Create councils of AI agents with different perspectives and watch them debate any topic.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CyberColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'github':
        return 'GitHub';
      default:
        return provider;
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberColors.midnightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: CyberColors.midnightBorder.withOpacity(0.6)),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: CyberColors.errorRed),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? If you\'re using guest mode, your local data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          NeonButton(
            label: 'Sign Out',
            color: CyberColors.errorRed,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) {
        Navigator.of(context)
            .pop(); // Return to previous screen (auth will redirect)
      }
    }
  }
}

/// Sign in button for settings screen
class _SignInButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SignInButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                          fontSize: 14,
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
            color: Color(0xFF4285F4),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
