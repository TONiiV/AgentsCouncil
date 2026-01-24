import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Colored chip for highlighting debate points with pro/con/neutral styling
class HighlightChip extends StatelessWidget {
  final String label;
  final HighlightType type;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isCompact;

  const HighlightChip({
    super.key,
    required this.label,
    this.type = HighlightType.neutral,
    this.icon,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: type.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: type.color.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: isCompact ? 14 : 16,
                color: type.color,
              ),
              SizedBox(width: isCompact ? 4 : 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: type.color,
                fontSize: isCompact ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum HighlightType {
  pro,
  con,
  neutral,
  info,
  warning;

  Color get color {
    switch (this) {
      case HighlightType.pro:
        return CyberColors.successGreen;
      case HighlightType.con:
        return CyberColors.errorRed;
      case HighlightType.neutral:
        return CyberColors.neonCyan;
      case HighlightType.info:
        return CyberColors.holoPurple;
      case HighlightType.warning:
        return CyberColors.warningAmber;
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case HighlightType.pro:
        return Icons.thumb_up_outlined;
      case HighlightType.con:
        return Icons.thumb_down_outlined;
      case HighlightType.neutral:
        return Icons.remove;
      case HighlightType.info:
        return Icons.info_outline;
      case HighlightType.warning:
        return Icons.warning_amber_outlined;
    }
  }
}

/// Vote indicator chip showing agree/disagree/abstain status
class VoteChip extends StatelessWidget {
  final VoteStatus status;
  final bool showLabel;

  const VoteChip({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: status.color.withOpacity(0.3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum VoteStatus {
  agree,
  disagree,
  abstain;

  Color get color {
    switch (this) {
      case VoteStatus.agree:
        return CyberColors.successGreen;
      case VoteStatus.disagree:
        return CyberColors.errorRed;
      case VoteStatus.abstain:
        return CyberColors.textMuted;
    }
  }

  IconData get icon {
    switch (this) {
      case VoteStatus.agree:
        return Icons.check_circle_outline;
      case VoteStatus.disagree:
        return Icons.cancel_outlined;
      case VoteStatus.abstain:
        return Icons.remove_circle_outline;
    }
  }

  String get label {
    switch (this) {
      case VoteStatus.agree:
        return 'AGREE';
      case VoteStatus.disagree:
        return 'DISAGREE';
      case VoteStatus.abstain:
        return 'ABSTAIN';
    }
  }
}

/// Provider badge with brand colors
class ProviderBadge extends StatelessWidget {
  final String provider;
  final bool showLabel;
  final double size;

  const ProviderBadge({
    super.key,
    required this.provider,
    this.showLabel = true,
    this.size = 24,
  });

  Color get _color {
    switch (provider.toLowerCase()) {
      case 'openai':
        return CyberColors.openaiGreen;
      case 'anthropic':
        return CyberColors.anthropicOrange;
      case 'gemini':
        return CyberColors.geminiBlue;
      default:
        return CyberColors.neonCyan;
    }
  }

  IconData get _icon {
    switch (provider.toLowerCase()) {
      case 'openai':
        return Icons.auto_awesome;
      case 'anthropic':
        return Icons.psychology;
      case 'gemini':
        return Icons.stars;
      default:
        return Icons.smart_toy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: size * 0.7, color: _color),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              provider.toUpperCase(),
              style: TextStyle(
                color: _color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status indicator with animated pulse for active states
class StatusIndicator extends StatefulWidget {
  final bool isActive;
  final Color? activeColor;
  final String? label;
  final double size;

  const StatusIndicator({
    super.key,
    required this.isActive,
    this.activeColor,
    this.label,
    this.size = 8,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? 
        (widget.isActive ? CyberColors.successGreen : CyberColors.textMuted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(_animation.value * 0.8),
                          blurRadius: widget.size,
                          spreadRadius: widget.size * 0.3 * _animation.value,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.label!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
