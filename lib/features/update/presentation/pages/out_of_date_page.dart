import 'package:flutter/material.dart';

import '../../../../domain/entities/app_version_config.dart';
import '../../../../theme/app_theme.dart';

/// Schermata di blocco: la build installata è sotto la minima supportata,
/// quindi prende il posto di tutta l'app — anche a sessione già aperta —
/// finché l'utente non aggiorna.
class OutOfDatePage extends StatelessWidget {
  const OutOfDatePage({
    super.key,
    required this.onUpdate,
    this.installedVersion,
    this.config,
    this.onRetry,
  });

  /// Porta allo store della piattaforma.
  final VoidCallback onUpdate;

  final String? installedVersion;
  final AppVersionConfig? config;

  /// Ricontrolla i requisiti: serve a chi ha appena aggiornato da un'altra
  /// finestra, e a chi era offline quando il controllo è partito.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String message = config?.blockingMessage ??
        'Questa versione di Beatter non è più supportata. '
            'Aggiornala per continuare ad allenarti: i tuoi esercizi, i '
            'record e le composizioni restano dove sono.';

    return PopScope(
      // Niente uscita "indietro" da qui: è un blocco, non un avviso.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: AppTheme.glassCardDecoration(
                      borderRadius: AppRadius.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.system_update_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Aggiorna Beatter',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: onUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text(
                              'Aggiorna l\'app',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          TextButton(
                            onPressed: onRetry,
                            child: const Text('Ho già aggiornato, riprova'),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _versionLine,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _versionLine {
    final installed = installedVersion;
    final required = config?.minSupportedVersion;
    if (installed == null && required == null) return '';
    if (required == null) return 'Versione installata $installed';
    if (installed == null) return 'Versione minima richiesta $required';
    return 'Versione installata $installed · minima richiesta $required';
  }
}
