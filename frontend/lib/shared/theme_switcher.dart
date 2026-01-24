import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';

/// Provider for managing the current theme variant
final themeVariantProvider = StateProvider<CyberThemeVariant>((ref) {
  return CyberThemeVariant.midnight;
});

/// Widget to switch between theme variants
class ThemeSwitcher extends ConsumerWidget {
  final bool showLabels;
  
  const ThemeSwitcher({
    super.key,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentVariant = ref.watch(themeVariantProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CyberColors.midnightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberColors.midnightBorder.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CyberThemeVariant.values.map((variant) {
          return _ThemeOption(
            variant: variant,
            isSelected: currentVariant == variant,
            showLabel: showLabels,
            onTap: () {
              ref.read(themeVariantProvider.notifier).state = variant;
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final CyberThemeVariant variant;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.variant,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
  });

  Color get _color {
    switch (variant) {
      case CyberThemeVariant.midnight:
        return CyberColors.neonCyan;
      case CyberThemeVariant.neon:
        return CyberColors.electricPink;
      case CyberThemeVariant.sunset:
        return CyberColors.holoPurple;
    }
  }

  String get _label {
    switch (variant) {
      case CyberThemeVariant.midnight:
        return 'Midnight';
      case CyberThemeVariant.neon:
        return 'Neon';
      case CyberThemeVariant.sunset:
        return 'Sunset';
    }
  }

  IconData get _icon {
    switch (variant) {
      case CyberThemeVariant.midnight:
        return Icons.nightlight_round;
      case CyberThemeVariant.neon:
        return Icons.flash_on;
      case CyberThemeVariant.sunset:
        return Icons.wb_twilight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CyberAnimations.fast,
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? CyberGlow.soft(_color) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 18,
              color: isSelected ? _color : CyberColors.textMuted,
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                _label,
                style: TextStyle(
                  color: isSelected ? _color : CyberColors.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Floating theme switcher button that expands on tap
class FloatingThemeSwitcher extends ConsumerStatefulWidget {
  const FloatingThemeSwitcher({super.key});

  @override
  ConsumerState<FloatingThemeSwitcher> createState() => _FloatingThemeSwitcherState();
}

class _FloatingThemeSwitcherState extends ConsumerState<FloatingThemeSwitcher> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currentVariant = ref.watch(themeVariantProvider);

    return AnimatedContainer(
      duration: CyberAnimations.normal,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: CyberColors.midnightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CyberColors.midnightBorder.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getVariantColor(currentVariant).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.palette_outlined,
                color: _getVariantColor(currentVariant),
                size: 24,
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: CyberAnimations.fast,
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 8),
                ...CyberThemeVariant.values.map((variant) {
                  return _buildVariantButton(variant, currentVariant == variant);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantButton(CyberThemeVariant variant, bool isSelected) {
    final color = _getVariantColor(variant);
    
    return GestureDetector(
      onTap: () {
        ref.read(themeVariantProvider.notifier).state = variant;
        setState(() => _isExpanded = false);
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
          ),
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isSelected ? CyberGlow.soft(color) : null,
            ),
          ),
        ),
      ),
    );
  }

  Color _getVariantColor(CyberThemeVariant variant) {
    switch (variant) {
      case CyberThemeVariant.midnight:
        return CyberColors.neonCyan;
      case CyberThemeVariant.neon:
        return CyberColors.electricPink;
      case CyberThemeVariant.sunset:
        return CyberColors.holoPurple;
    }
  }
}
