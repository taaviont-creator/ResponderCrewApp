import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PrimaryActionButtonStyle { primary, danger, secondary }

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PrimaryActionButtonStyle.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PrimaryActionButtonStyle style;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(style);
    final effectiveOnPressed = isLoading ? null : onPressed;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: AppTheme.primaryActionHeight,
      ),
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: colors.background.withValues(alpha: 0.45),
          disabledForegroundColor: colors.foreground.withValues(alpha: 0.8),
          elevation: style == PrimaryActionButtonStyle.secondary ? 0 : 2,
          side: colors.borderColor == null
              ? null
              : BorderSide(color: colors.borderColor!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.foreground,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        softWrap: true,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _ActionColors _colorsFor(PrimaryActionButtonStyle style) {
    switch (style) {
      case PrimaryActionButtonStyle.danger:
        return const _ActionColors(
          background: AppColors.activeCallout,
          foreground: AppColors.background,
        );
      case PrimaryActionButtonStyle.secondary:
        return const _ActionColors(
          background: AppColors.surfaceBlueStrong,
          foreground: AppColors.navy,
          borderColor: AppColors.border,
        );
      case PrimaryActionButtonStyle.primary:
        return const _ActionColors(
          background: AppColors.orange,
          foreground: AppColors.navy,
        );
    }
  }
}

class _ActionColors {
  const _ActionColors({
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final Color background;
  final Color foreground;
  final Color? borderColor;
}
