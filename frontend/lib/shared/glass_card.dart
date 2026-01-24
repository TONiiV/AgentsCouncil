import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// A frosted glass effect card with optional neon border glow
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final double borderRadius;
  final bool enableGlow;
  final VoidCallback? onTap;
  final double glassOpacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor,
    this.borderRadius = 16,
    this.enableGlow = false,
    this.onTap,
    this.glassOpacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? CyberColors.neonCyan;
    
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(glassOpacity),
                Colors.white.withOpacity(glassOpacity * 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: enableGlow 
                  ? effectiveGlowColor.withOpacity(0.5)
                  : CyberColors.midnightBorder.withOpacity(0.5),
              width: enableGlow ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: padding ?? CyberSpacing.cardPadding,
            child: child,
          ),
        ),
      ),
    );

    if (enableGlow) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: CyberGlow.soft(effectiveGlowColor),
        ),
        child: card,
      );
    }

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A solid card with glass-like appearance for areas without blur support
class SolidGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showHoverGlow;

  const SolidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor,
    this.borderRadius = 16,
    this.onTap,
    this.showHoverGlow = true,
  });

  @override
  State<SolidGlassCard> createState() => _SolidGlassCardState();
}

class _SolidGlassCardState extends State<SolidGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = widget.glowColor ?? CyberColors.neonCyan;
    
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CyberAnimations.fast,
          decoration: BoxDecoration(
            color: CyberColors.midnightCard,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isHovered && widget.showHoverGlow
                  ? effectiveGlowColor.withOpacity(0.6)
                  : CyberColors.midnightBorder.withOpacity(0.5),
              width: _isHovered && widget.showHoverGlow ? 1.5 : 1,
            ),
            boxShadow: _isHovered && widget.showHoverGlow
                ? CyberGlow.soft(effectiveGlowColor)
                : null,
          ),
          child: Padding(
            padding: widget.padding ?? CyberSpacing.cardPadding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
