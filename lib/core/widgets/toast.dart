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
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(style.icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
        return const _ToastStyle(Color(0xFF22C55E), Icons.check_circle_rounded);
      case ToastType.warning:
        return const _ToastStyle(AppTheme.primaryPurple, Icons.access_time_rounded);
      case ToastType.error:
        return const _ToastStyle(Color(0xFFEF4444), Icons.error_rounded);
      case ToastType.info:
        return const _ToastStyle(AppTheme.textSecondary, Icons.info_rounded);
    }
  }
}

class _ToastStyle {
  final Color color;
  final IconData icon;
  const _ToastStyle(this.color, this.icon);
}
