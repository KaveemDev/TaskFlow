import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PremiumButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final double width;

  const PremiumButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isPrimary = true,
    this.isLoading = false,
    this.width = double.infinity,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.lightImpact();
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    final Color backgroundColor = widget.isPrimary
        ? colorScheme.primary.withValues(alpha: isDisabled ? 0.5 : 1.0)
        : colorScheme.surface;

    final Color foregroundColor = widget.isPrimary
        ? colorScheme.onPrimary.withValues(alpha: isDisabled ? 0.5 : 1.0)
        : colorScheme.onSurface.withValues(alpha: isDisabled ? 0.5 : 1.0);

    final BorderSide? border = widget.isPrimary
        ? null
        : BorderSide(
            color: colorScheme.outline.withValues(
              alpha: isDisabled ? 0.2 : 1.0,
            ),
            width: 1,
          );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          width: widget.width,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: border != null ? Border.fromBorderSide(border) : null,
            boxShadow: widget.isPrimary && !isDisabled && !_isPressed
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        foregroundColor,
                      ),
                    ),
                  ).animate().fadeIn()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: foregroundColor, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(),
          ),
        ),
      ),
    );
  }
}
