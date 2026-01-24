import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../shared/shared.dart';

/// Data class to track a single streaming agent
class StreamingAgent {
  final String agentId;
  final String agentName;
  final int insertionOrder; // Preserve order agents started streaming
  RoleType? role;
  ProviderType? provider;
  String content;

  StreamingAgent({
    required this.agentId,
    required this.agentName,
    required this.insertionOrder,
    this.role,
    this.provider,
    this.content = '',
  });
}

class SimChatWidget extends StatefulWidget {
  final String debateId;
  final Stream<dynamic> eventStream;
  final List<AgentResponse> initialResponses;

  const SimChatWidget({
    super.key,
    required this.debateId,
    required this.eventStream,
    required this.initialResponses,
  });

  @override
  State<SimChatWidget> createState() => _SimChatWidgetState();
}

class _SimChatWidgetState extends State<SimChatWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription? _subscription;

  // Track MULTIPLE streaming agents by agent_id (for parallel execution)
  final Map<String, StreamingAgent> _streamingAgents = {};
  int _insertionCounter = 0; // Track order of agent insertion

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(SimChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventStream != oldWidget.eventStream) {
      _subscription?.cancel();
      _subscribeToStream();
    }
    // Handle initial responses update if needed (mostly for first load)
    if (widget.initialResponses.length != oldWidget.initialResponses.length) {
      // Ideally we merge, but for now let's just rely on stream for live updates
      // and initial load for history.
      // logic to append new history could go here if we weren't validly streaming everything
      // But assuming full reload on re-enter, we might want to re-init if list was empty.
      if (_messages.isEmpty && widget.initialResponses.isNotEmpty) {
        _initializeMessages();
      }
    }
  }

  void _initializeMessages() {
    _messages.clear();
    for (var response in widget.initialResponses) {
      _messages.add(ChatMessage(
        agentName: response.agentName,
        content: response.content,
        role: response.role,
        isSystem: false,
        provider: response.provider,
        vote: response.vote,
        timestamp: response.timestamp ?? DateTime.now(),
      ));
    }
    _scrollToBottom();
  }

  void _subscribeToStream() {
    _subscription = widget.eventStream.listen((event) {
      if (event is Map<String, dynamic>) {
        final type = event['event_type'];
        final data = event['data'];

        if (type == 'agent_response_chunk') {
          _handleChunk(data);
        } else if (type == 'agent_thinking') {
          _handleThinking(data);
        } else if (type == 'agent_response') {
          _handleResponseComplete(data);
        } else if (type == 'debate_start') {
          _addModeratorMessage('📢 Debate Started', 'Topic: ${data['topic']}');
        } else if (type == 'round_start') {
          _addModeratorMessage('🔄 Round ${data['round']}',
              'All agents are now deliberating...');
        } else if (type == 'vote') {
          _handleVote(data);
        } else if (type == 'round_complete') {
          final consensus = data['consensus'] == true;
          final summary = data['vote_summary'] as Map<String, dynamic>?;
          final votes = summary != null
              ? 'Agree: ${summary['agree']}, Disagree: ${summary['disagree']}, Abstain: ${summary['abstain']}'
              : '';
          _addModeratorMessage(
            consensus
                ? '✅ Consensus Reached!'
                : '⏳ Round ${data['round']} Complete',
            votes,
          );
        } else if (type == 'debate_complete') {
          final status = data['status'];
          final statusIcon = status == 'consensus_reached' ? '🎉' : '🏁';
          _addModeratorMessage(
              '$statusIcon Debate Concluded', 'Final status: $status');
        }
      }
    });
  }

  void _handleChunk(Map<String, dynamic> data) {
    setState(() {
      final agentId = data['agent_id'] as String;
      final content = data['full_content_so_far'] ?? '';

      if (_streamingAgents.containsKey(agentId)) {
        // Update existing streaming agent
        _streamingAgents[agentId]!.content = content;
        _streamingAgents[agentId]!.role ??= _parseRole(data['role']);
        _streamingAgents[agentId]!.provider ??=
            _parseProvider(data['provider']);
      } else {
        // New streaming agent with insertion order
        _streamingAgents[agentId] = StreamingAgent(
          agentId: agentId,
          agentName: data['agent_name'] ?? 'Agent',
          insertionOrder: _insertionCounter++,
          role: _parseRole(data['role']),
          provider: _parseProvider(data['provider']),
          content: content,
        );
      }
    });
    _scrollToBottom();
  }

  RoleType _parseRole(String? value) {
    if (value == null) return RoleType.custom;
    return RoleType.values.firstWhere(
      (r) => r.name == value,
      orElse: () => RoleType.custom,
    );
  }

  ProviderType _parseProvider(String? value) {
    if (value == null) return ProviderType.openai;
    return ProviderType.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ProviderType.openai,
    );
  }

  void _handleThinking(Map<String, dynamic> data) {
    setState(() {
      final agentId = data['agent_id'] as String;
      if (!_streamingAgents.containsKey(agentId)) {
        _streamingAgents[agentId] = StreamingAgent(
          agentId: agentId,
          agentName: data['agent_name'] ?? 'Agent',
          insertionOrder: _insertionCounter++,
          content: '',
        );
      }
    });
    _scrollToBottom();
  }

  void _handleResponseComplete(Map<String, dynamic> data) {
    setState(() {
      final agentId = data['agent_id'] as String;

      // Finalize message with role/provider from event data
      _messages.add(ChatMessage(
        agentName: data['agent_name'],
        content: data['content'],
        role: _parseRole(data['role']),
        isSystem: false,
        provider: _parseProvider(data['provider']),
        timestamp: DateTime.now(),
      ));

      // Remove from streaming agents
      _streamingAgents.remove(agentId);
    });
    _scrollToBottom();
  }

  void _handleVote(Map<String, dynamic> data) {
    // Add a specialized small message for vote?
    // Or just a system message
    _addSystemMessage("${data['agent_name']} voted: ${data['vote']}");
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        agentName: 'System',
        content: text,
        role: RoleType.custom,
        isSystem: true,
        provider: ProviderType.openai,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addModeratorMessage(String title, String body) {
    setState(() {
      _messages.add(ChatMessage(
        agentName: 'Moderator',
        content: '**$title**\n\n$body',
        role: RoleType.custom,
        isSystem: true,
        isModerator: true,
        provider: ProviderType.openai,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build list of streaming agents sorted by insertion order (preserves start order)
    final streamingList = _streamingAgents.values.toList()
      ..sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + streamingList.length,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          return _buildMessageItem(_messages[index]);
        } else {
          // Streaming items
          final streamingAgent = streamingList[index - _messages.length];
          return _buildStreamingItem(streamingAgent);
        }
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    // Moderator messages (enhanced system messages)
    if (message.isModerator) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CyberColors.holoPurple.withOpacity(0.15),
              CyberColors.neonCyan.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CyberColors.holoPurple.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CyberColors.holoPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('⚖️', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MarkdownBody(
                data: message.content,
                styleSheet: _cyberMarkdownStyleSheet(context),
                shrinkWrap: true,
              ),
            ),
          ],
        ),
      );
    }

    // Simple system messages (votes, etc.)
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CyberColors.midnightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CyberColors.textMuted.withOpacity(0.3)),
          ),
          child: Text(
            message.content,
            style: TextStyle(color: CyberColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final isMe =
        false; // Always left aligned for now as we represent multiple agents

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(message),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.agentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: CyberColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(message.vote?.displayName ?? "",
                        style: TextStyle(
                            fontSize: 10,
                            color: _getVoteColor(message.vote),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CyberColors.midnightCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(0),
                      topRight: const Radius.circular(12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                    border: Border.all(
                        color: _getProviderColor(message.provider)
                            .withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _getProviderColor(message.provider)
                            .withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: message.content,
                    styleSheet: _cyberMarkdownStyleSheet(context),
                    selectable: true,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingItem(StreamingAgent agent) {
    final providerColor = agent.provider != null
        ? _getProviderColor(agent.provider!)
        : CyberColors.neonCyan;
    final roleIcon = agent.role?.icon ?? '💬';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent avatar with role icon and provider color
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(roleIcon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.agentName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: providerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CyberColors.midnightCard.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(color: providerColor.withOpacity(0.3)),
                  ),
                  child: agent.content.isEmpty
                      ? _buildThinkingIndicator(providerColor)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: MarkdownBody(
                                data: agent.content,
                                styleSheet: _cyberMarkdownStyleSheet(context),
                                shrinkWrap: true,
                              ),
                            ),
                            _buildBlinkingCursor(providerColor),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Thinking...',
          style: TextStyle(
              color: color.withOpacity(0.7), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildBlinkingCursor(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: (value * 2).floor() % 2 == 0 ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 250),
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2, bottom: 2),
            color: color,
          ),
        );
      },
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _getProviderColor(message.provider).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          message.role.icon, // Initial or icon
          style: const TextStyle(fontSize: 16),
        ),
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

  Color _getVoteColor(VoteType? vote) {
    switch (vote) {
      case VoteType.agree:
        return CyberColors.successGreen;
      case VoteType.disagree:
        return CyberColors.errorRed;
      case VoteType.abstain:
        return CyberColors.textMuted;
      case null:
        return Colors.transparent;
    }
  }

  MarkdownStyleSheet _cyberMarkdownStyleSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownStyleSheet(
      // Paragraph and body text
      p: textTheme.bodyMedium?.copyWith(
        color: CyberColors.textSecondary,
        height: 1.6,
      ),
      // Headings
      h1: textTheme.headlineMedium?.copyWith(color: CyberColors.textPrimary),
      h2: textTheme.headlineSmall?.copyWith(color: CyberColors.textPrimary),
      h3: textTheme.titleLarge?.copyWith(color: CyberColors.textPrimary),
      h4: textTheme.titleMedium?.copyWith(color: CyberColors.textPrimary),
      // Strong and emphasis
      strong: const TextStyle(
        fontWeight: FontWeight.bold,
        color: CyberColors.textPrimary,
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: CyberColors.textSecondary,
      ),
      // Code styling
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: CyberColors.neonCyan,
        backgroundColor: CyberColors.midnightSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: CyberColors.midnightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CyberColors.neonCyan.withOpacity(0.3)),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      // Blockquote
      blockquoteDecoration: BoxDecoration(
        color: CyberColors.midnightSurface.withOpacity(0.5),
        border: Border(
          left: BorderSide(color: CyberColors.holoPurple, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      // Lists
      listBullet: TextStyle(color: CyberColors.neonCyan),
      listIndent: 20,
      // Links
      a: TextStyle(
        color: CyberColors.neonCyan,
        decoration: TextDecoration.underline,
        decorationColor: CyberColors.neonCyan.withOpacity(0.5),
      ),
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: CyberColors.midnightBorder, width: 1),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String agentName;
  final String content;
  final RoleType role;
  final bool isSystem;
  final bool isModerator;
  final ProviderType provider;
  final VoteType? vote;
  final DateTime timestamp;

  ChatMessage({
    required this.agentName,
    required this.content,
    required this.role,
    required this.isSystem,
    this.isModerator = false,
    required this.provider,
    this.vote,
    required this.timestamp,
  });
}
