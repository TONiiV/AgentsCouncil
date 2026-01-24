import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Text widget with neon glow shadow effect
class GlowText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? glowColor;
  final double blurRadius;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const GlowText(
    this.text, {
    super.key,
    this.style,
    this.glowColor,
    this.blurRadius = 8,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.headlineMedium!;
    final effectiveGlowColor = glowColor ?? CyberColors.neonCyan;

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: effectiveStyle.copyWith(
        shadows: [
          Shadow(
            color: effectiveGlowColor.withOpacity(0.8),
            blurRadius: blurRadius,
          ),
          Shadow(
            color: effectiveGlowColor.withOpacity(0.4),
            blurRadius: blurRadius * 2,
          ),
        ],
      ),
    );
  }
}

/// Animated glowing text that pulses
class PulsingGlowText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color? glowColor;

  const PulsingGlowText(
    this.text, {
    super.key,
    this.style,
    this.glowColor,
  });

  @override
  State<PulsingGlowText> createState() => _PulsingGlowTextState();
}

class _PulsingGlowTextState extends State<PulsingGlowText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? Theme.of(context).textTheme.headlineMedium!;
    final effectiveGlowColor = widget.glowColor ?? CyberColors.neonCyan;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.text,
          style: effectiveStyle.copyWith(
            shadows: [
              Shadow(
                color: effectiveGlowColor.withOpacity(0.8 * _animation.value),
                blurRadius: 8 + (8 * _animation.value),
              ),
              Shadow(
                color: effectiveGlowColor.withOpacity(0.4 * _animation.value),
                blurRadius: 16 + (16 * _animation.value),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Gradient text with optional glow
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final bool enableGlow;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = CyberGradients.primary,
    this.enableGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.headlineMedium!;

    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: effectiveStyle.copyWith(
          color: Colors.white,
          shadows: enableGlow
              ? [
                  Shadow(
                    color: CyberColors.neonCyan.withOpacity(0.5),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
