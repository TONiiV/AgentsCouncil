import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/models.dart';
import 'glass_card.dart';

/// A reusable widget for displaying debate history items.
/// 
/// This widget provides consistent styling for debate items across
/// both the home screen and council details screen.
class DebateHistoryTile extends StatelessWidget {
  final Debate debate;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? councilName;
  final bool showCouncilName;

  const DebateHistoryTile({
    super.key,
    required this.debate,
    required this.onTap,
    this.onDelete,
    this.councilName,
    this.showCouncilName = false,
  });

  /// Returns the appropriate color for the debate status.
  Color _getStatusColor() {
    switch (debate.status) {
      case DebateStatus.consensusReached:
        return CyberColors.successGreen;
      case DebateStatus.roundLimitReached:
        return Colors.orange;
      case DebateStatus.cancelled:
        return CyberColors.errorRed;
      case DebateStatus.error:
        return CyberColors.errorRed;
      case DebateStatus.inProgress:
      case DebateStatus.pending:
        return CyberColors.neonBlue;
    }
  }

  /// Returns the appropriate icon for the debate status.
  IconData _getStatusIcon() {
    switch (debate.status) {
      case DebateStatus.consensusReached:
        return Icons.check_circle_outline;
      case DebateStatus.roundLimitReached:
        return Icons.timelapse;
      case DebateStatus.cancelled:
        return Icons.cancel_outlined;
      case DebateStatus.error:
        return Icons.error_outline;
      case DebateStatus.inProgress:
      case DebateStatus.pending:
        return Icons.pending_outlined;
    }
  }

  /// Returns a human-readable status label.
  String _getStatusLabel() {
    switch (debate.status) {
      case DebateStatus.consensusReached:
        return 'CONSENSUS';
      case DebateStatus.roundLimitReached:
        return 'ROUND LIMIT';
      case DebateStatus.cancelled:
        return 'CANCELLED';
      case DebateStatus.error:
        return 'ERROR';
      case DebateStatus.inProgress:
        return 'IN PROGRESS';
      case DebateStatus.pending:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm().format(debate.createdAt);
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: SolidGlassCard(
        glowColor: statusColor,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Status icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debate.topic,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Council name (if showing)
                        if (showCouncilName && councilName != null) ...[
                          Icon(
                            Icons.groups_outlined,
                            size: 12,
                            color: CyberColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              councilName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: CyberColors.neonCyan,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: CyberColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Date
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: CyberColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            date,
                            style: TextStyle(
                              fontSize: 11,
                              color: CyberColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Status chip and round info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: statusColor.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getStatusLabel(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.refresh,
                          size: 12,
                          color: CyberColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Round ${debate.currentRound}',
                          style: TextStyle(
                            fontSize: 11,
                            color: CyberColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: CyberColors.errorRed.withOpacity(0.7),
                        size: 20,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete Debate',
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: CyberColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
