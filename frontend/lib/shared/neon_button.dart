import 'package:flutter/material.dart';
import '../app/theme.dart';

/// A button with neon glow effect and optional pulse animation
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isPrimary;
  final bool isLoading;
  final bool enablePulse;
  final double? width;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isPrimary = true,
    this.isLoading = false,
    this.enablePulse = false,
    this.width,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.enablePulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NeonButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enablePulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.enablePulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? CyberColors.neonCyan;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final glowIntensity = widget.enablePulse 
              ? 0.3 + (_pulseAnimation.value * 0.3)
              : (_isHovered ? 0.5 : 0.2);

          return Container(
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: isDisabled ? null : [
                BoxShadow(
                  color: buttonColor.withOpacity(glowIntensity),
                  blurRadius: _isHovered ? 20 : 12,
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.isPrimary
            ? _buildPrimaryButton(buttonColor, isDisabled)
            : _buildOutlinedButton(buttonColor, isDisabled),
      ),
    );
  }

  Widget _buildPrimaryButton(Color color, bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? color.withOpacity(0.3) : color,
        foregroundColor: CyberColors.midnightBg,
        disabledBackgroundColor: color.withOpacity(0.2),
        disabledForegroundColor: CyberColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildOutlinedButton(Color color, bool isDisabled) {
    return OutlinedButton(
      onPressed: isDisabled ? null : widget.onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? color.withOpacity(0.5) : color,
        side: BorderSide(
          color: isDisabled ? color.withOpacity(0.3) : color.withOpacity(0.6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            widget.isPrimary ? CyberColors.midnightBg : widget.color ?? CyberColors.neonCyan,
          ),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Text(widget.label),
        ],
      );
    }

    return Text(widget.label);
  }
}

/// Floating action button with neon glow
class NeonFAB extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? color;

  const NeonFAB({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.color,
  });

  @override
  State<NeonFAB> createState() => _NeonFABState();
}

class _NeonFABState extends State<NeonFAB> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final fabColor = widget.color ?? CyberColors.neonCyan;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: CyberAnimations.fast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.label != null ? 28 : 16),
          boxShadow: [
            BoxShadow(
              color: fabColor.withOpacity(_isHovered ? 0.5 : 0.3),
              blurRadius: _isHovered ? 24 : 16,
              spreadRadius: _isHovered ? 4 : 0,
            ),
          ],
        ),
        child: widget.label != null
            ? FloatingActionButton.extended(
                onPressed: widget.onPressed,
                backgroundColor: fabColor,
                foregroundColor: CyberColors.midnightBg,
                icon: Icon(widget.icon),
                label: Text(widget.label!),
              )
            : FloatingActionButton(
                onPressed: widget.onPressed,
                backgroundColor: fabColor,
                foregroundColor: CyberColors.midnightBg,
                child: Icon(widget.icon),
              ),
      ),
    );
  }
}
