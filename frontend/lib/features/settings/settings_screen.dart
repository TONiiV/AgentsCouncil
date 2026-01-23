import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../models/auth_state.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../shared/shared.dart';

/// Settings screen with Google OAuth management and providers info
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _api = ApiService();
  List<String> _availableProviders = [];
  bool _isLoadingProviders = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    // Check for existing auth on screen load
    ref.read(authProvider.notifier).checkExistingAuth();
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await _api.getAvailableProviders();
      if (mounted) {
        setState(() {
          _availableProviders = providers;
          _isLoadingProviders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProviders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings, color: CyberColors.neonCyan),
            const SizedBox(width: 12),
            GlowText(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
              glowColor: CyberColors.neonCyan,
              blurRadius: 4,
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: CyberColors.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: CyberSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoogleAuthSection(),
            const SizedBox(height: 32),
            _buildProvidersSection(),
            const SizedBox(height: 32),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: CyberColors.neonCyan, size: 22),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _buildGoogleAuthSection() {
    final authState = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Google Account', Icons.account_circle_outlined),
        const SizedBox(height: 16),
        SolidGlassCard(
          glowColor: _getAuthGlowColor(authState.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildGoogleLogo(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google OAuth',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        _buildAuthStatusText(authState),
                      ],
                    ),
                  ),
                  _buildAuthStatusBadge(authState.status),
                ],
              ),
              const SizedBox(height: 20),
              _buildAuthDescription(authState),
              const SizedBox(height: 20),
              _buildAuthActions(authState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4285F4), // Google Blue
            const Color(0xFF34A853), // Google Green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: CyberGlow.soft(const Color(0xFF4285F4)),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthStatusText(AuthState authState) {
    String text;
    Color color;

    switch (authState.status) {
      case AuthStatus.authenticated:
        text = authState.email ?? 'Connected';
        color = CyberColors.successGreen;
        break;
      case AuthStatus.loading:
        text = 'Connecting...';
        color = CyberColors.warningAmber;
        break;
      case AuthStatus.error:
        text = authState.error ?? 'Connection failed';
        color = CyberColors.errorRed;
        break;
      default:
        text = 'Not connected';
        color = CyberColors.textMuted;
    }

    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAuthStatusBadge(AuthStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case AuthStatus.authenticated:
        color = CyberColors.successGreen;
        icon = Icons.check_circle;
        break;
      case AuthStatus.loading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(CyberColors.neonCyan),
          ),
        );
      case AuthStatus.error:
        color = CyberColors.errorRed;
        icon = Icons.error;
        break;
      default:
        color = CyberColors.textMuted;
        icon = Icons.radio_button_unchecked;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildAuthDescription(AuthState authState) {
    String description;

    if (authState.isAuthenticated) {
      description =
          'Your Google account is connected. This enables access to Gemini AI models through your personal Google Cloud credentials.';
    } else {
      description =
          'Connect your Google account to enable Gemini AI models. This uses OAuth to securely access your Google Cloud credentials.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberColors.midnightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberColors.midnightBorder.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: CyberColors.neonCyan.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CyberColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthActions(AuthState authState) {
    if (authState.status == AuthStatus.loading) {
      return const SizedBox.shrink();
    }

    if (authState.isAuthenticated) {
      return Row(
        children: [
          Expanded(
            child: NeonButton(
              label: 'Sign Out',
              icon: Icons.logout,
              onPressed: () => ref.read(authProvider.notifier).logout(),
              color: CyberColors.errorRed,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: NeonButton(
            label: 'Sign in with Google',
            icon: Icons.login,
            onPressed: () => ref.read(authProvider.notifier).loginWithGoogle(),
            enablePulse: true,
          ),
        ),
      ],
    );
  }

  Color _getAuthGlowColor(AuthStatus status) {
    switch (status) {
      case AuthStatus.authenticated:
        return CyberColors.successGreen;
      case AuthStatus.error:
        return CyberColors.errorRed;
      default:
        return CyberColors.neonCyan;
    }
  }

  Widget _buildProvidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AI Providers', Icons.smart_toy_outlined),
        const SizedBox(height: 16),
        SolidGlassCard(
          glowColor: CyberColors.holoPurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Providers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'These AI providers are currently configured and ready to use in your councils.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CyberColors.textMuted,
                    ),
              ),
              const SizedBox(height: 20),
              if (_isLoadingProviders)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(CyberColors.holoPurple),
                  ),
                )
              else if (_availableProviders.isEmpty)
                _buildNoProvidersMessage()
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _availableProviders
                      .map((p) => _buildProviderChip(p))
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoProvidersMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberColors.warningAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberColors.warningAmber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: CyberColors.warningAmber,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No AI providers configured. Please add API keys to your environment or connect your Google account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CyberColors.warningAmber,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String provider) {
    final color = _getProviderColor(provider);
    final icon = _getProviderIcon(provider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            _formatProviderName(provider),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return CyberColors.openaiGreen;
      case 'anthropic':
        return CyberColors.anthropicOrange;
      case 'google':
      case 'gemini':
        return CyberColors.geminiBlue;
      case 'ollama':
        return CyberColors.ollamaYellow;
      default:
        return CyberColors.neonCyan;
    }
  }

  IconData _getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return Icons.auto_awesome;
      case 'anthropic':
        return Icons.psychology;
      case 'google':
      case 'gemini':
        return Icons.diamond;
      case 'ollama':
        return Icons.memory;
      default:
        return Icons.smart_toy;
    }
  }

  String _formatProviderName(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic';
      case 'google':
        return 'Google';
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      default:
        return provider;
    }
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('About', Icons.info_outline),
        const SizedBox(height: 16),
        SolidGlassCard(
          glowColor: CyberColors.electricPink,
          showHoverGlow: false,
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
                    child: const Icon(
                      Icons.groups,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlowText(
                        'AgentsCouncil',
                        style: Theme.of(context).textTheme.titleLarge,
                        glowColor: CyberColors.neonCyan,
                        blurRadius: 4,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Multi-Agent AI Debate Platform',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CyberColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Create councils of AI agents powered by different providers to debate topics, analyze problems, and reach consensus through structured multi-agent collaboration.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
