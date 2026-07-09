import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum ToastType { success, warning, error, info }

/// A small, on-brand toast notification built on the standard [SnackBar] —
/// no extra dependency, consistent with the rest of the app.
class Toast {
  const Toast._();

  static void show(ToastType type, String message, BuildContext context) {
    final _ToastStyle style = _styleFor(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: style.color,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md + 2)),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(style.icon, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static _ToastStyle _styleFor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const _ToastStyle(AppColors.success, Icons.check_circle_rounded);
      case ToastType.warning:
        return const _ToastStyle(AppColors.warning, Icons.access_time_rounded);
      case ToastType.error:
        return const _ToastStyle(AppColors.error, Icons.error_rounded);
      case ToastType.info:
        return const _ToastStyle(AppColors.info, Icons.info_rounded);
    }
  }
}

class _ToastStyle {
  final Color color;
  final IconData icon;
  const _ToastStyle(this.color, this.icon);
}
