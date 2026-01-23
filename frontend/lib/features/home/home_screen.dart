import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../shared/shared.dart';
import '../council_setup/council_setup_screen.dart';
import '../debate/debate_screen.dart';
import '../council/council_details_screen.dart';
import '../settings/settings_screen.dart';

/// Home screen with council management and cyber retro design
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _api = ApiService();
  List<CouncilConfig> _councils = [];
  List<Debate> _debates = [];
  bool _isLoading = true;
  String? _error;
  List<String> _availableProviders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final isHealthy = await _api.checkHealth();
      if (!isHealthy) {
        setState(() {
          _error =
              'Backend server is not running.\n\nStart it with:\ncd backend && uvicorn app.main:app --reload';
          _isLoading = false;
        });
        return;
      }

      final results = await Future.wait([
        _api.listCouncils(),
        _api.listDebates(),
        _api.getAvailableProviders(),
      ]);

      setState(() {
        _councils = results[0] as List<CouncilConfig>;
        _debates = results[1] as List<Debate>;
        _availableProviders = results[2] as List<String>;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to connect to server: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: _error == null
          ? NeonFAB(
              icon: Icons.add,
              label: 'New Council',
              onPressed: _createNewCouncil,
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CyberColors.midnightSurface,
            CyberColors.midnightBg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(
            color: CyberColors.midnightBorder.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo with glow
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: CyberGradients.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: CyberGlow.medium(CyberColors.neonCyan),
                ),
                child: const Icon(
                  Icons.groups,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlowText(
                      'AgentsCouncil',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      glowColor: CyberColors.neonCyan,
                      blurRadius: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI-Powered Multi-Agent Debate Platform',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: CyberColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: Icon(
                  Icons.refresh,
                  color: CyberColors.neonCyan,
                ),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
                icon: Icon(
                  Icons.settings,
                  color: CyberColors.neonCyan,
                ),
                tooltip: 'Settings',
              ),
            ],
          ),
          if (_availableProviders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Available Providers',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 12),
                ..._availableProviders.map((p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ProviderBadge(provider: p),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(CyberColors.neonCyan),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to backend...',
            style: TextStyle(color: CyberColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SolidGlassCard(
          glowColor: CyberColors.errorRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: CyberColors.errorRed.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 36,
                  color: CyberColors.errorRed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connection Error',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              NeonButton(
                label: 'Retry Connection',
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_councils.isNotEmpty) ...[
            _buildSectionHeader(
                'Your Councils', Icons.groups_outlined, _councils.length),
            const SizedBox(height: 16),
            _buildCouncilGrid(),
            const SizedBox(height: 40),
          ],
          if (_debates.isNotEmpty) ...[
            _buildSectionHeader(
                'Recent Debates', Icons.forum_outlined, _debates.length),
            const SizedBox(height: 16),
            ..._debates.map(_buildDebateCard),
          ],
          if (_councils.isEmpty && _debates.isEmpty) _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: CyberColors.neonCyan, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: CyberColors.neonCyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: CyberColors.neonCyan,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCouncilGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800
            ? 3
            : constraints.maxWidth > 500
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: _councils.length,
          itemBuilder: (context, index) => _buildCouncilCard(_councils[index]),
        );
      },
    );
  }

  Widget _buildCouncilCard(CouncilConfig council) {
    return SolidGlassCard(
      glowColor: CyberColors.holoPurple,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CouncilDetailsScreen(council: council),
          ),
        );
        _loadData(); // Refresh list after returning
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: CyberGradients.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups, color: Colors.white, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CyberColors.neonCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: CyberColors.neonCyan,
                  size: 20,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            council.name,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatBadge(
                Icons.smart_toy_outlined,
                '${council.agents.length} agents',
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                Icons.refresh,
                '${council.maxRounds} rounds',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CyberColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: CyberColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Finds the council name for a debate.
  String? _getCouncilName(String councilId) {
    final council = _councils.where((c) => c.id == councilId).firstOrNull;
    return council?.name;
  }

  Widget _buildDebateCard(Debate debate) {
    return DebateHistoryTile(
      debate: debate,
      onTap: () => _viewDebate(debate),
      showCouncilName: true,
      councilName: _getCouncilName(debate.councilId),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SolidGlassCard(
        showHoverGlow: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: CyberGradients.glass(CyberColors.neonCyan),
                shape: BoxShape.circle,
                border: Border.all(
                  color: CyberColors.neonCyan.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 48,
                color: CyberColors.neonCyan.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Welcome to AgentsCouncil',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first AI council to start multi-agent debates',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            NeonButton(
              label: 'Create Your First Council',
              icon: Icons.add,
              onPressed: _createNewCouncil,
              enablePulse: true,
            ),
          ],
        ),
      ),
    );
  }

  void _createNewCouncil() async {
    final result = await Navigator.push<CouncilConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => CouncilSetupScreen(
          availableProviders: _availableProviders,
        ),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  void _startDebateWithCouncil(CouncilConfig council) async {
    final topic = await showDialog<String>(
      context: context,
      builder: (context) => _TopicInputDialog(),
    );

    if (topic != null && topic.isNotEmpty) {
      try {
        final debate = await _api.startDebate(
          councilId: council.id,
          topic: topic,
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DebateScreen(debateId: debate.id),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start debate: $e')),
          );
        }
      }
    }
  }

  void _viewDebate(Debate debate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebateScreen(debateId: debate.id),
      ),
    );
  }
}

class _TopicInputDialog extends StatefulWidget {
  @override
  State<_TopicInputDialog> createState() => _TopicInputDialogState();
}

class _TopicInputDialogState extends State<_TopicInputDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CyberColors.midnightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: CyberColors.midnightBorder.withOpacity(0.6)),
      ),
      title: Row(
        children: [
          Icon(Icons.forum_outlined, color: CyberColors.neonCyan),
          const SizedBox(width: 12),
          const Text('Start New Debate'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter the topic for AI agents to debate...',
            hintStyle: TextStyle(color: CyberColors.textMuted),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeonButton(
          label: 'Start Debate',
          icon: Icons.play_arrow,
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    );
  }
}
