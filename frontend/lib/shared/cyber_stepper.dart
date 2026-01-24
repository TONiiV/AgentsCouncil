import 'package:flutter/material.dart';
import '../app/theme.dart';

/// A cyberpunk-style stepper with neon accents and connecting lines
class CyberStepper extends StatelessWidget {
  final int currentStep;
  final List<CyberStepData> steps;
  final ValueChanged<int>? onStepTapped;

  const CyberStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(child: _buildConnector(isCompleted));
          } else {
            // Step indicator
            final stepIndex = index ~/ 2;
            return _buildStep(context, stepIndex);
          }
        }),
      ),
    );
  }

  Widget _buildStep(BuildContext context, int index) {
    final step = steps[index];
    final isActive = index == currentStep;
    final isCompleted = index < currentStep;
    
    Color getColor() {
      if (isCompleted) return CyberColors.successGreen;
      if (isActive) return CyberColors.neonCyan;
      return CyberColors.midnightBorder;
    }

    return GestureDetector(
      onTap: onStepTapped != null ? () => onStepTapped!(index) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: CyberAnimations.normal,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted
                  ? getColor().withOpacity(0.2)
                  : CyberColors.midnightSurface,
              border: Border.all(
                color: getColor(),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive ? CyberGlow.soft(getColor()) : null,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      color: getColor(),
                      size: 20,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: getColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: TextStyle(
              color: isActive 
                  ? CyberColors.textPrimary 
                  : CyberColors.textMuted,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 28), // Align with circle center
      decoration: BoxDecoration(
        gradient: isCompleted
            ? const LinearGradient(
                colors: [CyberColors.successGreen, CyberColors.neonCyan],
              )
            : null,
        color: isCompleted ? null : CyberColors.midnightBorder,
        borderRadius: BorderRadius.circular(1),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: CyberColors.successGreen.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Data class for each step in the stepper
class CyberStepData {
  final String title;
  final IconData? icon;

  const CyberStepData({
    required this.title,
    this.icon,
  });
}

/// Compact horizontal stepper for tight spaces
class CompactStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color? activeColor;

  const CompactStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? CyberColors.neonCyan;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Container(
          width: 24,
          height: 4,
          margin: EdgeInsets.only(right: index < totalSteps - 1 ? 4 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isActive ? color : CyberColors.midnightBorder,
            boxShadow: isActive
                ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
        );
      }),
    );
  }
}
