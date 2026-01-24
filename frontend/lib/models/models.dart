/// Data models for AgentsCouncil

enum ProviderType {
  openai,
  anthropic,
  gemini,
  ollama;

  String get displayName {
    switch (this) {
      case ProviderType.openai:
        return 'OpenAI';
      case ProviderType.anthropic:
        return 'Anthropic';
      case ProviderType.gemini:
        return 'Gemini';
      case ProviderType.ollama:
        return 'Ollama';
    }
  }

  String get icon {
    switch (this) {
      case ProviderType.openai:
        return '🤖';
      case ProviderType.anthropic:
        return '🧠';
      case ProviderType.gemini:
        return '✨';
      case ProviderType.ollama:
        return '🦙';
    }
  }
}

enum RoleType {
  investmentAdvisor,
  prExpert,
  politicsExpert,
  legalAdvisor,
  techStrategist,
  devilsAdvocate,
  custom;

  String get value {
    switch (this) {
      case RoleType.investmentAdvisor:
        return 'investment_advisor';
      case RoleType.prExpert:
        return 'pr_expert';
      case RoleType.politicsExpert:
        return 'politics_expert';
      case RoleType.legalAdvisor:
        return 'legal_advisor';
      case RoleType.techStrategist:
        return 'tech_strategist';
      case RoleType.devilsAdvocate:
        return 'devils_advocate';
      case RoleType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case RoleType.investmentAdvisor:
        return 'Investment Advisor';
      case RoleType.prExpert:
        return 'PR Expert';
      case RoleType.politicsExpert:
        return 'Politics Expert';
      case RoleType.legalAdvisor:
        return 'Legal Advisor';
      case RoleType.techStrategist:
        return 'Tech Strategist';
      case RoleType.devilsAdvocate:
        return "Devil's Advocate";
      case RoleType.custom:
        return 'Custom Role';
    }
  }

  String get icon {
    switch (this) {
      case RoleType.investmentAdvisor:
        return '💰';
      case RoleType.prExpert:
        return '📢';
      case RoleType.politicsExpert:
        return '🏛️';
      case RoleType.legalAdvisor:
        return '⚖️';
      case RoleType.techStrategist:
        return '💻';
      case RoleType.devilsAdvocate:
        return '😈';
      case RoleType.custom:
        return '✏️';
    }
  }
}

enum VoteType {
  agree,
  disagree;

  String get displayName => name.toUpperCase();
}

enum DebateStatus {
  pending,
  inProgress,
  consensusReached,
  roundLimitReached,
  cancelled,
  error;

  String get value {
    switch (this) {
      case DebateStatus.pending:
        return 'pending';
      case DebateStatus.inProgress:
        return 'in_progress';
      case DebateStatus.consensusReached:
        return 'consensus_reached';
      case DebateStatus.roundLimitReached:
        return 'round_limit_reached';
      case DebateStatus.cancelled:
        return 'cancelled';
      case DebateStatus.error:
        return 'error';
    }
  }

  static DebateStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return DebateStatus.pending;
      case 'in_progress':
        return DebateStatus.inProgress;
      case 'consensus_reached':
        return DebateStatus.consensusReached;
      case 'round_limit_reached':
        return DebateStatus.roundLimitReached;
      case 'cancelled':
        return DebateStatus.cancelled;
      case 'error':
        return DebateStatus.error;
      default:
        return DebateStatus.pending;
    }
  }

  bool get isComplete =>
      this == DebateStatus.consensusReached ||
      this == DebateStatus.roundLimitReached;
}

class AgentConfig {
  final String id;
  final String name;
  final ProviderType provider;
  final RoleType role;
  final String? customPrompt;
  final String? model;

  AgentConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.role,
    this.customPrompt,
    this.model,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: ProviderType.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => ProviderType.openai,
      ),
      role: RoleType.values.firstWhere(
        (r) => r.value == json['role'],
        orElse: () => RoleType.custom,
      ),
      customPrompt: json['custom_prompt'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider.name,
        'role': role.value,
        if (customPrompt != null) 'custom_prompt': customPrompt,
        if (model != null) 'model': model,
      };
}

class CouncilConfig {
  final String id;
  final String name;
  final List<AgentConfig> agents;
  final int maxRounds;
  final double consensusThreshold;

  CouncilConfig({
    required this.id,
    required this.name,
    required this.agents,
    this.maxRounds = 5,
    this.consensusThreshold = 0.8,
  });

  factory CouncilConfig.fromJson(Map<String, dynamic> json) {
    return CouncilConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      agents: (json['agents'] as List)
          .map((a) => AgentConfig.fromJson(a as Map<String, dynamic>))
          .toList(),
      maxRounds: json['max_rounds'] as int? ?? 5,
      consensusThreshold:
          (json['consensus_threshold'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agents': agents.map((a) => a.toJson()).toList(),
        'max_rounds': maxRounds,
        'consensus_threshold': consensusThreshold,
      };
}

class AgentResponse {
  final String agentId;
  final String agentName;
  final RoleType role;
  final ProviderType provider;
  final String content;
  final VoteType? vote;
  final String? reasoning;
  final DateTime? timestamp;

  AgentResponse({
    required this.agentId,
    required this.agentName,
    required this.role,
    required this.provider,
    required this.content,
    this.vote,
    this.reasoning,
    this.timestamp,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      agentId: json['agent_id'] as String,
      agentName: json['agent_name'] as String,
      role: RoleType.values.firstWhere(
        (r) => r.value == json['role'],
        orElse: () => RoleType.custom,
      ),
      provider: ProviderType.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => ProviderType.openai,
      ),
      content: json['content'] as String,
      vote: json['vote'] != null
          ? VoteType.values.firstWhere(
              (v) => v.name == json['vote'],
              orElse: () => VoteType.disagree,
            )
          : null,
      reasoning: json['reasoning'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

class DebateRound {
  final int roundNumber;
  final List<AgentResponse> responses;
  final Map<String, VoteType> votes;
  final Map<String, int>? voteSummary;
  final bool consensusReached;

  DebateRound({
    required this.roundNumber,
    required this.responses,
    required this.votes,
    this.voteSummary,
    this.consensusReached = false,
  });

  factory DebateRound.fromJson(Map<String, dynamic> json) {
    return DebateRound(
      roundNumber: json['round_number'] as int,
      responses: (json['responses'] as List?)
              ?.map((r) => AgentResponse.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      votes: (json['votes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              VoteType.values.firstWhere(
                (vt) => vt.name == v,
                orElse: () => VoteType.disagree,
              ),
            ),
          ) ??
          {},
      voteSummary: (json['vote_summary'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ),
      consensusReached: json['consensus_reached'] as bool? ?? false,
    );
  }
}

class Debate {
  final String id;
  final String councilId;
  final String topic;
  final DebateStatus status;
  final List<DebateRound> rounds;
  final int currentRound;
  final String? summary;
  final List<String> proPoints;
  final List<String> againstPoints;
  final DateTime createdAt;

  Debate({
    required this.id,
    required this.councilId,
    required this.topic,
    required this.status,
    required this.rounds,
    required this.currentRound,
    this.summary,
    this.proPoints = const [],
    this.againstPoints = const [],
    required this.createdAt,
  });

  factory Debate.fromJson(Map<String, dynamic> json) {
    return Debate(
      id: json['id'] as String,
      councilId: json['council_id'] as String,
      topic: json['topic'] as String,
      status: DebateStatus.fromValue(json['status'] as String),
      rounds: (json['rounds'] as List?)
              ?.map((r) => DebateRound.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      currentRound: json['current_round'] as int? ?? 0,
      summary: json['summary'] as String?,
      proPoints: (json['pro_points'] as List?)?.cast<String>() ?? [],
      againstPoints: (json['against_points'] as List?)?.cast<String>() ?? [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
