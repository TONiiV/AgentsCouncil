import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Summary screen showing debate results with highlights
class SummaryScreen extends StatelessWidget {
  final Debate debate;

  const SummaryScreen({super.key, required this.debate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GlowText(
          'Debate Summary',
          style: Theme.of(context).textTheme.titleLarge,
          glowColor: CyberColors.holoPurple,
          blurRadius: 4,
        ),
      ),
      body: SingleChildScrollView(
        padding: CyberSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic Header
            _buildTopicCard(context),
            const SizedBox(height: 28),

            // Outcome Status
            _buildOutcomeCard(context),
            const SizedBox(height: 28),

            // Pro/Con Points
            if (debate.proPoints.isNotEmpty ||
                debate.againstPoints.isNotEmpty) ...[
              _buildProConSection(context),
              const SizedBox(height: 28),
            ],

            // Main Summary
            if (debate.summary != null) ...[
              _buildSummaryCard(context),
              const SizedBox(height: 28),
            ],

            // Debate Highlights
            _buildHighlightsSection(context),
            const SizedBox(height: 28),

            // Vote Statistics
            _buildVoteStats(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context) {
    return SolidGlassCard(
      glowColor: CyberColors.neonCyan,
      showHoverGlow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum, color: CyberColors.neonCyan),
              const SizedBox(width: 12),
              Text(
                'TOPIC',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 1,
                      color: CyberColors.neonCyan,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlowText(
            debate.topic,
            style: Theme.of(context).textTheme.headlineMedium,
            glowColor: CyberColors.neonCyan,
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeCard(BuildContext context) {
    final isConsensus = debate.status == DebateStatus.consensusReached;
    final color =
        isConsensus ? CyberColors.successGreen : CyberColors.warningAmber;
    final icon = isConsensus ? Icons.check_circle : Icons.timer_off;
    final statusText =
        isConsensus ? 'Consensus Reached' : 'Round Limit Reached';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            CyberColors.midnightCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: CyberGlow.soft(color),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: CyberGlow.medium(color),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OUTCOME',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: CyberColors.midnightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CyberColors.midnightBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.loop, size: 18, color: CyberColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  '${debate.currentRound} Rounds',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProConSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (debate.proPoints.isNotEmpty)
                Expanded(child: _buildProCard(context)),
              if (debate.proPoints.isNotEmpty &&
                  debate.againstPoints.isNotEmpty)
                const SizedBox(width: 16),
              if (debate.againstPoints.isNotEmpty)
                Expanded(child: _buildConCard(context)),
            ],
          );
        } else {
          return Column(
            children: [
              if (debate.proPoints.isNotEmpty) _buildProCard(context),
              if (debate.proPoints.isNotEmpty &&
                  debate.againstPoints.isNotEmpty)
                const SizedBox(height: 16),
              if (debate.againstPoints.isNotEmpty) _buildConCard(context),
            ],
          );
        }
      },
    );
  }

  Widget _buildProCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberColors.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CyberColors.successGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thumb_up, color: CyberColors.successGreen, size: 20),
              const SizedBox(width: 10),
              GlowText(
                'PRO',
                style: TextStyle(
                  color: CyberColors.successGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
                glowColor: CyberColors.successGreen,
                blurRadius: 4,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...debate.proPoints
              .map((p) => _buildPoint(p, CyberColors.successGreen)),
        ],
      ),
    );
  }

  Widget _buildConCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CyberColors.errorRed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thumb_down, color: CyberColors.errorRed, size: 20),
              const SizedBox(width: 10),
              GlowText(
                'AGAINST',
                style: TextStyle(
                  color: CyberColors.errorRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
                glowColor: CyberColors.errorRed,
                blurRadius: 4,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...debate.againstPoints
              .map((p) => _buildPoint(p, CyberColors.errorRed)),
        ],
      ),
    );
  }

  Widget _buildPoint(String point, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
          Expanded(
            child: Text(
              point,
              style: const TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return SolidGlassCard(
      showHoverGlow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: CyberColors.holoPurple),
              const SizedBox(width: 12),
              Text(
                'SUMMARY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 1,
                      color: CyberColors.holoPurple,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MarkdownBody(
            data: debate.summary!,
            styleSheet: MarkdownStyleSheet(
              h1: Theme.of(context).textTheme.headlineMedium,
              h2: Theme.of(context).textTheme.headlineSmall,
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
              listBullet: TextStyle(color: CyberColors.neonCyan),
              blockquoteDecoration: BoxDecoration(
                color: CyberColors.midnightSurface,
                border: Border(
                  left: BorderSide(color: CyberColors.holoPurple, width: 3),
                ),
              ),
              blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(BuildContext context) {
    // Get notable quotes from the debate
    final highlights = _extractHighlights();
    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_quote, color: CyberColors.electricPink),
            const SizedBox(width: 12),
            Text(
              'KEY MOMENTS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: CyberColors.electricPink,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final highlight = highlights[index];
              return _buildHighlightCard(context, highlight);
            },
          ),
        ),
      ],
    );
  }

  List<_HighlightData> _extractHighlights() {
    final highlights = <_HighlightData>[];

    for (final round in debate.rounds) {
      for (final response in round.responses) {
        // Take first sentence or first 150 chars as highlight
        var content = response.content;
        final firstSentence = content.indexOf('. ');
        if (firstSentence > 0 && firstSentence < 150) {
          content = content.substring(0, firstSentence + 1);
        } else if (content.length > 150) {
          content = '${content.substring(0, 147)}...';
        }

        highlights.add(_HighlightData(
          agentName: response.agentName,
          role: response.role,
          provider: response.provider,
          content: content,
          roundNumber: round.roundNumber,
        ));
      }
    }

    // Return up to 6 highlights
    return highlights.take(6).toList();
  }

  Widget _buildHighlightCard(BuildContext context, _HighlightData highlight) {
    final providerColor = _getProviderColor(highlight.provider);

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberColors.midnightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: providerColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(highlight.role.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  highlight.agentName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CyberColors.midnightSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'R${highlight.roundNumber}',
                  style: TextStyle(
                    color: CyberColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              '"${highlight.content}"',
              style: TextStyle(
                color: CyberColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteStats(BuildContext context) {
    // Calculate total votes
    int agree = 0, disagree = 0;
    for (final round in debate.rounds) {
      if (round.voteSummary != null) {
        agree += round.voteSummary!['agree'] ?? 0;
        disagree += round.voteSummary!['disagree'] ?? 0;
      }
    }

    final total = agree + disagree;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.how_to_vote, color: CyberColors.neonCyan),
            const SizedBox(width: 12),
            Text(
              'VOTE BREAKDOWN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: CyberColors.neonCyan,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SolidGlassCard(
          showHoverGlow: false,
          child: Column(
            children: [
              _buildVoteBar(agree, disagree, total),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildVoteStat(
                      'Agree', agree, CyberColors.successGreen, total),
                  _buildVoteStat(
                      'Disagree', disagree, CyberColors.errorRed, total),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoteBar(int agree, int disagree, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (agree > 0)
              Expanded(
                flex: agree,
                child: Container(
                  decoration: BoxDecoration(
                    color: CyberColors.successGreen,
                    boxShadow: [
                      BoxShadow(
                        color: CyberColors.successGreen.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            if (disagree > 0)
              Expanded(
                flex: disagree,
                child: Container(color: CyberColors.errorRed),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteStat(String label, int value, Color color, int total) {
    final percent = total > 0 ? (value / total * 100).round() : 0;

    return Column(
      children: [
        GlowText(
          '$value',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          glowColor: color,
          blurRadius: 4,
        ),
        const SizedBox(height: 4),
        Text(
          '$percent%',
          style: TextStyle(color: color, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: CyberColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Color _getProviderColor(ProviderType provider) {
    switch (provider) {
      case ProviderType.openai:
        return CyberColors.openaiGreen;
      case ProviderType.anthropic:
        return CyberColors.anthropicOrange;
      case ProviderType.gemini:
        return CyberColors.geminiBlue;
      case ProviderType.ollama:
        return CyberColors.ollamaYellow;
    }
  }
}

class _HighlightData {
  final String agentName;
  final RoleType role;
  final ProviderType provider;
  final String content;
  final int roundNumber;

  _HighlightData({
    required this.agentName,
    required this.role,
    required this.provider,
    required this.content,
    required this.roundNumber,
  });
}
