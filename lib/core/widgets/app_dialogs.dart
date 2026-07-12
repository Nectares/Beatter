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

/// Esegue [task] mostrando un dialog modale di attesa (spinner + messaggio)
/// non dismissibile: l'utente vede che l'app sta lavorando e non può
/// innescare tap doppi, ma la UI continua ad animare. Il dialog si chiude
/// da solo al completamento (o al fallimento) del task, il cui risultato /
/// errore viene propagato al chiamante.
Future<T> runWithBusyDialog<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  bool dialogOpen = true;

  // Non awaited: il future del dialog si risolve solo alla sua chiusura.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  // Lascia montare il dialog prima di iniziare (ed eventualmente finire)
  // il lavoro, così il pop di chiusura non rimuove la route sbagliata.
  await Future<void>.delayed(Duration.zero);

  try {
    return await task();
  } finally {
    if (dialogOpen) navigator.pop();
  }
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
