import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shows a title+message confirmation dialog and resolves to whether the
/// user confirmed. Styling comes from `AppTheme.lightTheme.dialogTheme`;
/// [isDestructive] colors the confirm action as a destructive (red) action
/// instead of the default brand-colored [FilledButton].
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Conferma',
  String cancelLabel = 'Annulla',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        isDestructive
            ? TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(confirmLabel),
              )
            : FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows a single-text-field prompt dialog (rename/save-as flows) and
/// resolves to the entered text, or `null` if cancelled.
Future<String?> showPromptDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hintText,
  String confirmLabel = 'Salva',
  String cancelLabel = 'Annulla',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hintText),
        onSubmitted: (value) => Navigator.pop(ctx, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
