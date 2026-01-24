import 'package:flutter/material.dart';
import 'package:agents_council/app/theme.dart';
import 'package:agents_council/models/models.dart';
import 'package:agents_council/services/api_service.dart';
import 'package:agents_council/shared/shared.dart';
import '../council_setup/council_setup_screen.dart';
import '../debate/debate_screen.dart';

class CouncilDetailsScreen extends StatefulWidget {
  final CouncilConfig council;

  const CouncilDetailsScreen({super.key, required this.council});

  @override
  State<CouncilDetailsScreen> createState() => _CouncilDetailsScreenState();
}

class _CouncilDetailsScreenState extends State<CouncilDetailsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Debate> _history = [];
  late CouncilConfig _council;

  @override
  void initState() {
    super.initState();
    _council = widget.council;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final debates = await _api.listDebates(councilId: _council.id);
      // Sort by newest first
      debates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _history = debates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history: $e')),
        );
      }
    }
  }

  Future<void> _startDebate() async {
    final topic = await showDialog<String>(
      context: context,
      builder: (context) => _TopicInputDialog(),
    );

    if (topic != null && topic.isNotEmpty) {
      try {
        final debate = await _api.startDebate(
          councilId: _council.id,
          topic: topic,
        );
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DebateScreen(debateId: debate.id),
            ),
          );
          _loadHistory(); // Refresh after returning
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

  Future<void> _editCouncil() async {
    final updated = await Navigator.push<CouncilConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => CouncilSetupScreen(
          existingCouncil: _council,
          availableProviders: const ['openai', 'anthropic', 'gemini', 'ollama'],
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _council = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Council updated successfully')),
      );
    }
  }

  Future<void> _deleteCouncil() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Council?'),
        content: Text('Are you sure you want to delete "${_council.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteCouncil(_council.id);
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete council: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_council.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editCouncil,
            tooltip: 'Edit Council',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteCouncil,
            tooltip: 'Delete Council',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCouncilStats(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: NeonButton(
                              label: 'START NEW DEBATE',
                              icon: Icons.play_arrow,
                              onPressed: _startDebate,
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'HISTORY',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.grey,
                                  letterSpacing: 1.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  if (_history.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No debates yet.\nStart one to see history here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildHistoryItem(_history[index]),
                        childCount: _history.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
            ),
    );
  }

  Widget _buildCouncilStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'AGENTS',
            value: '${_council.agents.length}',
            icon: Icons.groups,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'ROUNDS',
            value: '${_council.maxRounds}',
            icon: Icons.refresh,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'CONSENSUS',
            value: '${(_council.consensusThreshold * 100).toInt()}%',
            icon: Icons.handshake,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Debate debate) {
    return DebateHistoryTile(
      debate: debate,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DebateScreen(debateId: debate.id),
          ),
        );
        _loadHistory();
      },
      onDelete: () => _deleteDebate(debate),
      showCouncilName: false,
    );
  }

  Future<void> _deleteDebate(Debate debate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Debate?'),
        content: Text('Are you sure you want to delete "${debate.topic}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          NeonButton(
            label: 'Delete',
            color: CyberColors.errorRed,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteDebate(debate.id);
        if (mounted) {
          _loadHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debate deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete debate: $e')),
          );
        }
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberColors.surfaceDb.withOpacity(0.5),
        border: Border.all(color: CyberColors.glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: CyberColors.textSecondary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: CyberColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Debate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter a topic for the council to discuss:'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'e.g. Should AI have rights?',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeonButton(
          label: 'START',
          onPressed: () => Navigator.pop(context, _controller.text),
          isPrimary: true,
          width: 100,
        ),
      ],
    );
  }
}
