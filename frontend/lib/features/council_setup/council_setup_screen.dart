import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../shared/shared.dart';

/// Multi-step council setup wizard with cyber retro design
class CouncilSetupScreen extends StatefulWidget {
  final List<String> availableProviders;

  const CouncilSetupScreen({
    super.key,
    required this.availableProviders,
    this.existingCouncil,
  });

  final CouncilConfig? existingCouncil;

  @override
  State<CouncilSetupScreen> createState() => _CouncilSetupScreenState();
}

class _CouncilSetupScreenState extends State<CouncilSetupScreen> {
  final _api = ApiService();
  final _pageController = PageController();

  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basic Info
  final _nameController = TextEditingController();

  // Step 2: Agents
  List<AgentConfig> _agents = [];

  // Step 3: Settings
  int _maxRounds = 5;
  double _consensusThreshold = 0.8;

  final _steps = const [
    CyberStepData(title: 'Basics', icon: Icons.info_outline),
    CyberStepData(title: 'Agents', icon: Icons.smart_toy_outlined),
    CyberStepData(title: 'Settings', icon: Icons.tune),
    CyberStepData(title: 'Review', icon: Icons.check_circle_outline),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingCouncil != null) {
      _nameController.text = widget.existingCouncil!.name;
      _agents = List.from(widget.existingCouncil!.agents);
      _maxRounds = widget.existingCouncil!.maxRounds;
      _consensusThreshold = widget.existingCouncil!.consensusThreshold;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: CyberAnimations.normal,
        curve: CyberAnimations.defaultCurve,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: CyberAnimations.normal,
        curve: CyberAnimations.defaultCurve,
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _nameController.text.isNotEmpty;
      case 1:
        return _agents.length >= 2;
      case 2:
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GlowText(
          widget.existingCouncil != null ? 'Edit Council' : 'Create Council',
          style: Theme.of(context).textTheme.titleLarge,
          glowColor: CyberColors.holoPurple,
          blurRadius: 4,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Stepper Header
          Container(
            decoration: BoxDecoration(
              color: CyberColors.midnightSurface,
              border: Border(
                bottom: BorderSide(
                  color: CyberColors.midnightBorder.withOpacity(0.5),
                ),
              ),
            ),
            child: CyberStepper(
              currentStep: _currentStep,
              steps: _steps,
              onStepTapped: (index) {
                if (index < _currentStep) {
                  setState(() => _currentStep = index);
                  _pageController.animateToPage(
                    index,
                    duration: CyberAnimations.normal,
                    curve: CyberAnimations.defaultCurve,
                  );
                }
              },
            ),
          ),

          // Page Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _BasicInfoStep(
                  nameController: _nameController,
                  onChanged: () => setState(() {}),
                ),
                _AgentsStep(
                  agents: _agents,
                  availableProviders: widget.availableProviders,
                  onAgentsChanged: (agents) => setState(() => _agents = agents),
                ),
                _SettingsStep(
                  maxRounds: _maxRounds,
                  consensusThreshold: _consensusThreshold,
                  onMaxRoundsChanged: (v) => setState(() => _maxRounds = v),
                  onThresholdChanged: (v) =>
                      setState(() => _consensusThreshold = v),
                ),
                _ReviewStep(
                  name: _nameController.text,
                  agents: _agents,
                  maxRounds: _maxRounds,
                  consensusThreshold: _consensusThreshold,
                ),
              ],
            ),
          ),

          // Bottom Navigation
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberColors.midnightSurface,
        border: Border(
          top: BorderSide(
            color: CyberColors.midnightBorder.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            NeonButton(
              label: 'Back',
              icon: Icons.arrow_back,
              isPrimary: false,
              onPressed: _previousStep,
            ),
          const Spacer(),
          if (_currentStep < _steps.length - 1)
            NeonButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: _canProceed ? _nextStep : null,
            )
          else
            NeonButton(
              label: widget.existingCouncil != null
                  ? 'Update Council'
                  : 'Create Council',
              icon: Icons.check,
              color: CyberColors.successGreen,
              isLoading: _isLoading,
              onPressed: _canProceed ? _saveCouncil : null,
            ),
        ],
      ),
    );
  }

  void _saveCouncil() async {
    setState(() => _isLoading = true);

    try {
      CouncilConfig council;
      if (widget.existingCouncil != null) {
        council = await _api.updateCouncil(
          widget.existingCouncil!.id,
          name: _nameController.text,
          agents: _agents,
          maxRounds: _maxRounds,
          consensusThreshold: _consensusThreshold,
        );
      } else {
        council = await _api.createCouncil(
          name: _nameController.text,
          agents: _agents,
          maxRounds: _maxRounds,
          consensusThreshold: _consensusThreshold,
        );
      }
      if (mounted) {
        Navigator.pop(context, council);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save council: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

// =============================================================================
// STEP 1: BASIC INFO
// =============================================================================

class _BasicInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onChanged;

  const _BasicInfoStep({
    required this.nameController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: CyberSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Give your council a name',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a descriptive name that reflects the purpose of this AI council.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          SolidGlassCard(
            showHoverGlow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Council Name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: 'e.g., Investment Advisory Board',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildExampleCards(context),
        ],
      ),
    );
  }

  Widget _buildExampleCards(BuildContext context) {
    final examples = [
      ('Investment Committee', 'For financial decisions'),
      ('Tech Strategy Board', 'For technical discussions'),
      ('Ethics Council', 'For ethical considerations'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Examples',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CyberColors.textMuted,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: examples.map((e) {
            return ActionChip(
              label: Text(e.$1),
              onPressed: () {
                nameController.text = e.$1;
                onChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// =============================================================================
// STEP 2: AGENTS
// =============================================================================

class _AgentsStep extends StatelessWidget {
  final List<AgentConfig> agents;
  final List<String> availableProviders;
  final ValueChanged<List<AgentConfig>> onAgentsChanged;

  const _AgentsStep({
    required this.agents,
    required this.availableProviders,
    required this.onAgentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: CyberSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add AI Agents',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add at least 2 agents with different perspectives',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: agents.length >= 2
                      ? CyberColors.successGreen.withOpacity(0.2)
                      : CyberColors.midnightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: agents.length >= 2
                        ? CyberColors.successGreen.withOpacity(0.5)
                        : CyberColors.midnightBorder,
                  ),
                ),
                child: Text(
                  '${agents.length} / 5',
                  style: TextStyle(
                    color: agents.length >= 2
                        ? CyberColors.successGreen
                        : CyberColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Agent cards
          ...agents.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAgentCard(context, entry.key, entry.value),
            );
          }),

          // Add agent button
          if (agents.length < 5)
            SolidGlassCard(
              glowColor: CyberColors.neonCyan,
              onTap: () => _showAgentDialog(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: CyberColors.neonCyan),
                  const SizedBox(width: 12),
                  Text(
                    'Add Agent',
                    style: TextStyle(
                      color: CyberColors.neonCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context, int index, AgentConfig agent) {
    return SolidGlassCard(
      showHoverGlow: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: CyberGradients.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                agent.role.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ProviderBadge(
                        provider: agent.provider.apiValue, showLabel: false),
                    const SizedBox(width: 8),
                    Text(
                      agent.role.displayName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: CyberColors.neonCyan),
                onPressed: () =>
                    _showAgentDialog(context, agent: agent, index: index),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: CyberColors.errorRed),
                onPressed: () {
                  final updated = List<AgentConfig>.from(agents);
                  updated.removeAt(index);
                  onAgentsChanged(updated);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAgentDialog(BuildContext context,
      {AgentConfig? agent, int? index}) async {
    final result = await showDialog<AgentConfig>(
      context: context,
      builder: (context) => _AddAgentDialog(
        availableProviders: availableProviders,
        existingAgent: agent,
      ),
    );

    if (result != null) {
      final updated = List<AgentConfig>.from(agents);
      if (index != null) {
        updated[index] = result;
      } else {
        updated.add(result);
      }
      onAgentsChanged(updated);
    }
  }
}

class _AddAgentDialog extends StatefulWidget {
  final List<String> availableProviders;
  final AgentConfig? existingAgent;

  const _AddAgentDialog({
    required this.availableProviders,
    this.existingAgent,
  });

  @override
  State<_AddAgentDialog> createState() => _AddAgentDialogState();
}

class _AddAgentDialogState extends State<_AddAgentDialog> {
  final _nameController = TextEditingController();
  final _api = ApiService();
  ProviderType? _selectedProvider;
  RoleType _selectedRole = RoleType.investmentAdvisor;

  List<String> _availableModels = [];
  String? _selectedModel;
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAgent != null) {
      _nameController.text = widget.existingAgent!.name;
      _selectedProvider = widget.existingAgent!.provider;
      _selectedRole = widget.existingAgent!.role;
      _selectedModel = widget.existingAgent!.model;
      if (_selectedProvider != null) {
        _fetchModels(_selectedProvider!);
      }
    }
  }

  Future<void> _fetchModels(ProviderType provider) async {
    setState(() {
      _isLoadingModels = true;
      _availableModels = [];
      _selectedModel = null;
    });

    try {
      final models = await _api.getProviderModels(provider.apiValue);
      if (mounted) {
        setState(() {
          _availableModels = models;
          if (models.isNotEmpty) {
            _selectedModel = models.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load models: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CyberColors.midnightCard,
      title: Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: CyberColors.neonCyan),
          const SizedBox(width: 12),
          Text(widget.existingAgent != null ? 'Edit Agent' : 'Add Agent'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Agent Name',
                  hintText: 'e.g., Financial Advisor',
                ),
              ),
              const SizedBox(height: 24),
              Text('AI Provider',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableProviders.map((p) {
                  final provider = ProviderType.fromApiValue(p);
                  final isSelected = _selectedProvider == provider;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedProvider = provider);
                      _fetchModels(provider);
                    },
                    child: AnimatedContainer(
                      duration: CyberAnimations.fast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CyberColors.neonCyan.withOpacity(0.2)
                            : CyberColors.midnightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? CyberColors.neonCyan
                              : CyberColors.midnightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProviderBadge(provider: p),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedProvider != null) ...[
                const SizedBox(height: 24),
                Text('Model', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                if (_isLoadingModels)
                  const LinearProgressIndicator()
                else if (_availableModels.isEmpty)
                  Text(
                    'No specific models available (will use default)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: CyberColors.textMuted,
                        ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: CyberColors.midnightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CyberColors.midnightBorder),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: CyberColors.midnightCard,
                      items: _availableModels
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedModel = v),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text('Role', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CyberColors.midnightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CyberColors.midnightBorder),
                ),
                child: DropdownButton<RoleType>(
                  value: _selectedRole,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: CyberColors.midnightCard,
                  items: RoleType.values
                      .where((r) => r != RoleType.custom)
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Row(
                              children: [
                                Text(role.icon,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 12),
                                Text(role.displayName),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeonButton(
          label: widget.existingAgent != null ? 'Save' : 'Add Agent',
          onPressed:
              _selectedProvider != null && _nameController.text.isNotEmpty
                  ? () {
                      Navigator.pop(
                        context,
                        AgentConfig(
                          id: widget.existingAgent?.id ?? const Uuid().v4(),
                          name: _nameController.text,
                          provider: _selectedProvider!,
                          role: _selectedRole,
                          model: _selectedModel,
                        ),
                      );
                    }
                  : null,
        ),
      ],
    );
  }
}

// =============================================================================
// STEP 3: SETTINGS
// =============================================================================

class _SettingsStep extends StatelessWidget {
  final int maxRounds;
  final double consensusThreshold;
  final ValueChanged<int> onMaxRoundsChanged;
  final ValueChanged<double> onThresholdChanged;

  const _SettingsStep({
    required this.maxRounds,
    required this.consensusThreshold,
    required this.onMaxRoundsChanged,
    required this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: CyberSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Configure Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-tune how the debate will run',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Max Rounds
          SolidGlassCard(
            showHoverGlow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.refresh, color: CyberColors.neonCyan),
                    const SizedBox(width: 12),
                    Text(
                      'Maximum Rounds',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'How many rounds of debate before stopping',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.remove,
                      onPressed: maxRounds > 1
                          ? () => onMaxRoundsChanged(maxRounds - 1)
                          : null,
                    ),
                    Container(
                      width: 80,
                      alignment: Alignment.center,
                      child: GlowText(
                        '$maxRounds',
                        style: Theme.of(context).textTheme.displaySmall,
                        glowColor: CyberColors.neonCyan,
                      ),
                    ),
                    _RoundButton(
                      icon: Icons.add,
                      onPressed: maxRounds < 10
                          ? () => onMaxRoundsChanged(maxRounds + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Consensus Threshold
          SolidGlassCard(
            showHoverGlow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.how_to_vote, color: CyberColors.holoPurple),
                    const SizedBox(width: 12),
                    Text(
                      'Consensus Threshold',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    GlowText(
                      '${(consensusThreshold * 100).toInt()}%',
                      style: Theme.of(context).textTheme.titleLarge,
                      glowColor: CyberColors.holoPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Percentage of agents that must agree to reach consensus',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: CyberColors.holoPurple,
                    thumbColor: CyberColors.holoPurple,
                    overlayColor: CyberColors.holoPurple.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: consensusThreshold,
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    onChanged: onThresholdChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('50%',
                        style: TextStyle(
                            color: CyberColors.textMuted, fontSize: 12)),
                    Text('100%',
                        style: TextStyle(
                            color: CyberColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _RoundButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled
              ? CyberColors.neonCyan.withOpacity(0.2)
              : CyberColors.midnightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? CyberColors.neonCyan.withOpacity(0.5)
                : CyberColors.midnightBorder,
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled ? CyberColors.neonCyan : CyberColors.textMuted,
        ),
      ),
    );
  }
}

// =============================================================================
// STEP 4: REVIEW
// =============================================================================

class _ReviewStep extends StatelessWidget {
  final String name;
  final List<AgentConfig> agents;
  final int maxRounds;
  final double consensusThreshold;

  const _ReviewStep({
    required this.name,
    required this.agents,
    required this.maxRounds,
    required this.consensusThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: CyberSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Review Your Council',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure everything looks good before creating',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Council Preview Card
          SolidGlassCard(
            glowColor: CyberColors.successGreen,
            showHoverGlow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: CyberGradients.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: CyberGlow.soft(CyberColors.neonCyan),
                      ),
                      child: const Icon(Icons.groups,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlowText(
                            name.isEmpty ? 'Unnamed Council' : name,
                            style: Theme.of(context).textTheme.headlineSmall,
                            glowColor: CyberColors.neonCyan,
                            blurRadius: 4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${agents.length} agents • $maxRounds rounds max',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Divider(color: CyberColors.midnightBorder.withOpacity(0.5)),
                const SizedBox(height: 20),

                // Agents List
                Text(
                  'AGENTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 12),
                ...agents.map((agent) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CyberColors.holoPurple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(agent.role.icon,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(agent.name),
                          ),
                          ProviderBadge(
                              provider: agent.provider.apiValue,
                              showLabel: false),
                        ],
                      ),
                    )),

                const SizedBox(height: 20),
                Divider(color: CyberColors.midnightBorder.withOpacity(0.5)),
                const SizedBox(height: 20),

                // Settings Summary
                Text(
                  'SETTINGS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SettingSummary(
                      icon: Icons.refresh,
                      label: 'Max Rounds',
                      value: '$maxRounds',
                    ),
                    const SizedBox(width: 24),
                    _SettingSummary(
                      icon: Icons.how_to_vote,
                      label: 'Consensus',
                      value: '${(consensusThreshold * 100).toInt()}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingSummary({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CyberColors.textMuted),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: CyberColors.textMuted, fontSize: 11),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CyberColors.neonCyan,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
