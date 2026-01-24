import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../shared/shared.dart';
import '../summary/summary_screen.dart';
import 'widgets/sim_chat_widget.dart';

/// Debate screen with theme switching and cyber retro design
class DebateScreen extends ConsumerStatefulWidget {
  final String debateId;

  const DebateScreen({super.key, required this.debateId});

  @override
  ConsumerState<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends ConsumerState<DebateScreen> {
  final _api = ApiService();
  final _wsService = WebSocketService();

  Debate? _debate;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadDebate();
    _connectWebSocket();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  void _connectWebSocket() {
    _wsService.connect(widget.debateId);
    _wsSubscription = _wsService.events.listen((event) {
      // Don't reload on chunks to avoid flicker/perf issues
      if (event['event_type'] != 'agent_response_chunk') {
        _loadDebate();
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_debate?.status == DebateStatus.inProgress) {
        _loadDebate();
      }
    });
  }

  Future<void> _loadDebate() async {
    try {
      final debate = await _api.getDebate(widget.debateId);
      if (mounted) {
        setState(() {
          _debate = debate;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load debate: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildError()
              : _buildContent(),
      floatingActionButton: _debate?.status.isComplete == true
          ? NeonFAB(
              icon: Icons.summarize,
              label: 'View Summary',
              color: CyberColors.holoPurple,
              onPressed: _viewSummary,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _debate?.topic ?? 'Debate',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Theme Switcher
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: ThemeSwitcher(showLabels: false),
        ),
        if (_debate?.status == DebateStatus.inProgress)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _cancelDebate,
              icon: Icon(Icons.stop, color: CyberColors.errorRed, size: 18),
              label:
                  Text('Stop', style: TextStyle(color: CyberColors.errorRed)),
            ),
          ),
      ],
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
            'Loading debate...',
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
              Icon(Icons.error_outline, size: 48, color: CyberColors.errorRed),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              NeonButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _loadDebate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_debate == null) return const SizedBox();

    // Flatten all responses for the chat widget
    final allResponses = _debate!.rounds.expand((r) => r.responses).toList();

    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: SimChatWidget(
            debateId: widget.debateId,
            eventStream: _wsService.events,
            initialResponses: allResponses,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final debate = _debate!;
    final isComplete = debate.status.isComplete;
    final isError = debate.status == DebateStatus.error;

    Color statusColor;
    if (isComplete) {
      statusColor = CyberColors.successGreen;
    } else if (isError) {
      statusColor = CyberColors.errorRed;
    } else {
      statusColor = CyberColors.warningAmber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: CyberColors.midnightCard,
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Badge with Glow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              boxShadow: CyberGlow.soft(statusColor),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusIndicator(
                  isActive: !isComplete,
                  activeColor: statusColor,
                  size: 8,
                ),
                const SizedBox(width: 8),
                Text(
                  debate.status.value.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Round Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberColors.midnightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CyberColors.midnightBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.loop, size: 16, color: CyberColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Round ${debate.currentRound}',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Response Count
          if (debate.rounds.isNotEmpty)
            Text(
              '${debate.rounds.expand((r) => r.responses).length} responses',
              style: TextStyle(color: CyberColors.textMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(DebateRound round) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SolidGlassCard(
        showHoverGlow: false,
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Round Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberColors.holoPurple.withOpacity(0.2),
                    CyberColors.midnightCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: CyberGradients.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: CyberGlow.soft(CyberColors.electricPink),
                    ),
                    child: Text(
                      'Round ${round.roundNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (round.voteSummary != null)
                    _buildVoteSummary(round.voteSummary!),
                ],
              ),
            ),

            // Agent Responses
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children:
                    round.responses.map((r) => _buildResponseCard(r)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteSummary(Map<String, int> summary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VoteBadge(
          icon: Icons.check,
          count: summary['agree'] ?? 0,
          color: CyberColors.successGreen,
        ),
        const SizedBox(width: 8),
        _VoteBadge(
          icon: Icons.close,
          count: summary['disagree'] ?? 0,
          color: CyberColors.errorRed,
        ),
        const SizedBox(width: 8),
        _VoteBadge(
          icon: Icons.remove,
          count: summary['abstain'] ?? 0,
          color: CyberColors.textMuted,
        ),
      ],
    );
  }

  Widget _buildResponseCard(AgentResponse response) {
    final providerColor = _getProviderColor(response.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberColors.midnightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: providerColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: providerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(response.role.icon,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.agentName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        ProviderBadge(
                          provider: response.provider.apiValue,
                          showLabel: false,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          response.role.displayName,
                          style: TextStyle(
                            color: CyberColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (response.vote != null)
                VoteChip(
                  status: _mapVote(response.vote!),
                  showLabel: true,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Response Content
          Text(
            response.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.7,
                ),
          ),
        ],
      ),
    );
  }

  Color _getProviderColor(ProviderType provider) {
    switch (provider) {
      case ProviderType.openai:
        return CyberColors.openaiGreen;
      case ProviderType.anthropic:
        return CyberColors.anthropicOrange;
      case ProviderType.gemini:
      case ProviderType.googleOauth:
        return CyberColors.geminiBlue;
      case ProviderType.ollama:
        return CyberColors.ollamaYellow;
    }
  }

  VoteStatus _mapVote(VoteType vote) {
    switch (vote) {
      case VoteType.agree:
        return VoteStatus.agree;
      case VoteType.disagree:
        return VoteStatus.disagree;
      case VoteType.abstain:
        return VoteStatus.abstain;
    }
  }

  void _viewSummary() {
    if (_debate != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SummaryScreen(debate: _debate!),
        ),
      );
    }
  }

  void _cancelDebate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberColors.midnightCard,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: CyberColors.warningAmber),
            const SizedBox(width: 12),
            const Text('Cancel Debate?'),
          ],
        ),
        content: const Text('This will stop the debate immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          NeonButton(
            label: 'Yes, Cancel',
            color: CyberColors.errorRed,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.cancelDebate(widget.debateId);
        _loadDebate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel: $e')),
          );
        }
      }
    }
  }
}

class _VoteBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _VoteBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
