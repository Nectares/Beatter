import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/decorative_glow_background.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/pages/login_page.dart';

/// User settings. Currently hosts the **Account** section, whose destructive
/// "Delete Account" action erases the account and all associated data.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      appBar: const BeatterAppBar(title: 'Impostazioni'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: DecorativeGlowBackground(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _AccountSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Account" settings group. Visually separated from the rest of the
/// screen and, for now, home to the single (destructive) delete action.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final email = AuthService.currentUser?.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            'ACCOUNT',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.8,
              color: AppColors.textMuted.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (email != null && email.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(
                  height: 1,
                  color: AppColors.surfaceBorder.withValues(alpha: 0.8),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              const _DeleteAccountTile(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'L\'eliminazione dell\'account è definitiva e irreversibile: '
            'rimuove profilo, esercizi, composizioni, statistiche e ogni altro '
            'dato associato.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// The red, destructive "Delete Account" row. Owns the two-step confirmation
/// flow, the progress dialog and error reporting.
class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _onDeletePressed(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elimina account',
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elimina definitivamente account e dati',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.error.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    // First confirmation: what will happen, and that it is irreversible.
    final first = await showConfirmDialog(
      context,
      title: 'Eliminare l\'account?',
      message:
          'Questa operazione è irreversibile. Verranno eliminati per sempre il '
          'tuo profilo, gli esercizi e le composizioni salvati, le statistiche, '
          'i punti e i file associati. Non sarà possibile recuperare l\'account.',
      confirmLabel: 'Continua',
      cancelLabel: 'Annulla',
      isDestructive: true,
    );
    if (!first || !context.mounted) return;

    // Second confirmation: explicit "delete permanently" gate.
    final second = await showConfirmDialog(
      context,
      title: 'Confermi l\'eliminazione?',
      message:
          'Ultima conferma: l\'account e tutti i suoi dati verranno eliminati '
          'definitivamente e non potranno essere ripristinati.',
      confirmLabel: 'Elimina definitivamente',
      cancelLabel: 'Annulla',
      isDestructive: true,
    );
    if (!second || !context.mounted) return;

    // Run the deletion behind a non-dismissible loader.
    try {
      await runWithBusyDialog(
        context,
        message: 'Eliminazione dell\'account in corso...',
        task: AuthService.deleteAccount,
      );
    } on AppFailure catch (e) {
      if (context.mounted) Toast.show(ToastType.error, e.message, context);
      return;
    } catch (_) {
      if (context.mounted) {
        Toast.show(
          ToastType.error,
          'Eliminazione non riuscita. Riprova più tardi.',
          context,
        );
      }
      return;
    }

    if (!context.mounted) return;
    // The app-level ScaffoldMessenger (from MaterialApp) outlives the route
    // change, so showing the toast before tearing down the stack keeps it
    // visible on the login screen.
    Toast.show(ToastType.success, 'Account eliminato.', context);
    // Account gone and local session cleared — return to the start screen,
    // discarding the whole navigation stack.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}
