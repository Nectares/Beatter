import 'package:flutter/material.dart';

import '../../../../domain/entities/app_version_config.dart';
import '../../../../theme/app_theme.dart';

/// Cosa ha scelto l'utente davanti alla proposta di aggiornamento.
enum UpdateChoice {
  /// Va allo store.
  update,

  /// Salta questa versione: non se ne riparla finché non ne esce un'altra.
  skip,

  /// Chiude e basta: la proposta torna al prossimo avvio.
  later,
}

/// Dialog di avvio quando c'è una versione più nuova ma quella installata
/// funziona ancora. Non blocca niente: si può chiudere.
class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({super.key, this.config});

  final AppVersionConfig? config;

  /// Mostra il dialog e restituisce la scelta (`null` se chiuso toccando
  /// fuori o col tasto indietro, che vale come [UpdateChoice.later]).
  static Future<UpdateChoice?> show(
    BuildContext context, {
    AppVersionConfig? config,
  }) {
    return showDialog<UpdateChoice>(
      context: context,
      builder: (context) => UpdateAvailableDialog(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String? latest = config?.latestVersion;
    final String? notes = config?.releaseNotes;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Nuova versione disponibile',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest == null
                ? 'C\'è una versione più recente di Beatter.'
                : 'Beatter $latest è disponibile sullo store.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (notes != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              notes,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
      // Tre azioni: con caratteri di sistema grandi l'OverflowBar le
      // impila da sola invece di traboccare.
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(UpdateChoice.skip),
          child: const Text('Salta questa versione'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UpdateChoice.later),
          child: const Text('Più tardi'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(UpdateChoice.update),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Aggiorna'),
        ),
      ],
    );
  }
}
