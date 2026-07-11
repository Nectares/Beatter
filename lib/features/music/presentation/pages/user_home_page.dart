import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/navigation/shell_visibility.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/decorative_glow_background.dart';
import '../../../../core/widgets/feature_card.dart';
import '../../../../core/widgets/toast.dart';

import '../navigation/main_navigation_shell.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  // Lista dei moduli futuri per la sezione "Prossimamente"
  static const List<Map<String, String>> comingSoonFeatures = [
    {
      'title': 'Rhythm Generator',
      'description':
          'Letture ritmiche sul pentagramma. Allena il tuo timing con il player audio integrato.',
      'icon': '🎼',
    },
    {
      'title': 'Ear Training Assistant',
      'description':
          'Allena il tuo orecchio a riconoscere accordi, intervalli e intonazione in modo interattivo.',
      'icon': '👂',
    },
    {
      'title': 'Chord Progression Architect',
      'description':
          'Crea progressioni armoniche complesse ed esportale in formato MIDI per le tue produzioni.',
      'icon': '🎹',
    },
    {
      'title': 'Scale & Arpeggio Explorer',
      'description':
          'Esplora scale esotiche, modi gregoriani e arpeggi con grafici interattivi su tastiera e manico.',
      'icon': '🎸',
    },
    {
      'title': 'Interactive Drum Sequencer',
      'description':
          'Un sequencer a griglia avanzato multitraccia per creare beat personalizzati con campioni di batteria storici.',
      'icon': '🥁',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BeatterScaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: DecorativeGlowBackground(
          child: SafeArea(
            child: Column(
              children: [
                // App Bar superiore personalizzata
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: context.responsive(
                      portrait: 16.0,
                      landscape: 8.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Opens the phone drawer. Hidden on tablet/desktop
                      // chrome, where the rail is always visible instead —
                      // ShellMenuButton figures that out on its own.
                      if (ShellMenuButton.maybe(context)
                          case final menuButton?) ...[
                        menuButton,
                        const SizedBox(width: AppSpacing.xxs),
                      ],
                      // User info
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.secondary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Benvenuto,',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Utente Standard',
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenuto principale scorrevole
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            // Titolo Sezione
                            Text(
                              'Funzionalità Attive',
                              style: textTheme.headlineSmall?.copyWith(
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),

                            FeatureCard(
                              icon: Icons.loop_rounded,
                              title: 'Flow Mode',
                              subtitle:
                                  'Allenamento ritmico in loop infinito. Esegui pattern temporali senza interruzioni e mantieni il groove.',
                              accentColor: AppColors.primary,
                              // Switches the shell's selected tab instead of
                              // pushing a second, independent FlowModePage
                              // route — that used to create a duplicate,
                              // separately-stateful instance of the same
                              // destination.
                              onTap: () => NavigationShellController.maybeOf(
                                context,
                              )?.selectTab(AppTab.flowMode.index),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            FeatureCard(
                              icon: Icons.menu_book_rounded,
                              title: 'Sheet Mode',
                              subtitle:
                                  'Sfoglia le tue partiture su un vero pentagramma a cinque linee.',
                              accentColor: AppColors.secondary,
                              isAvailable: false,
                              onTap: () => Toast.show(
                                ToastType.warning,
                                'Funzionalità in arrivo!',
                                context,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            FeatureCard(
                              icon: Icons.change_history_rounded,
                              title: 'Polyrhythm Lab',
                              subtitle:
                                  'Poliritmie animate e sincronizzate: guarda e senti il ritmo, non contarlo, non pensarlo, vivilo.',
                              accentColor: AppColors.secondary,
                              // onTap: () => NavigationShellController.maybeOf(
                              //   context,
                              // )?.selectTab(AppTab.polyrhythmLab.index),
                              isAvailable: false,
                              onTap: () => Toast.show(
                                ToastType.warning,
                                'Funzionalità in arrivo!',
                                context,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            FeatureCard(
                              icon: Icons.edit_note_rounded,
                              title: 'Composer Mode',
                              subtitle:
                                  'Componi, riproduci e salva le tue melodie su un vero pentagramma.',
                              accentColor: AppColors.tertiary,
                              isAvailable: false,
                              onTap: () => Toast.show(
                                ToastType.warning,
                                'Funzionalità in arrivo!',
                                context,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.xxxl - 4),

                            // Intestazione sezione "Prossimamente"
                            Text(
                              'Prossimamente',
                              style: textTheme.headlineSmall?.copyWith(
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),

                            _buildComingSoonGrid(context),
                            const SizedBox(height: AppSpacing.xxl - 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonGrid(BuildContext context) {
    final int columns = switch (context.screenTier) {
      ScreenTier.expanded => 3,
      ScreenTier.medium => 2,
      ScreenTier.compact => context.isLandscape ? 2 : 1,
    };

    if (columns == 1) {
      return Column(
        children: comingSoonFeatures
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildComingSoonCard(context, f),
              ),
            )
            .toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comingSoonFeatures.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) =>
          _buildComingSoonCard(context, comingSoonFeatures[index]),
    );
  }

  Widget _buildComingSoonCard(
    BuildContext context,
    Map<String, String> feature,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.55,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md + 2,
                vertical: AppSpacing.md,
              ),
              decoration: AppTheme.glassCardDecoration(
                borderRadius: AppRadius.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      feature['icon']!,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          feature['description']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Badge "Coming Soon" in alto a destra
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Coming Soon',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
