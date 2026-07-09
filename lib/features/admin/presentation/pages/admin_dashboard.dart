import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../../services/pattern_repository.dart';
import 'rhythm_creator_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final List<Map<String, dynamic>> stats = [
    {
      'title': 'Utenti Totali',
      'value': '24,582',
      'change': '+12% questo mese',
      'icon': Icons.people_alt_rounded,
      'color': AppColors.primary,
    },
    {
      'title': 'Brani Caricati',
      'value': '142,809',
      'change': '+3,240 questa settimana',
      'icon': Icons.music_note_rounded,
      'color': AppColors.secondary,
    },
    {
      'title': 'Stream Attivi',
      'value': '3,842',
      'change': 'In tempo reale',
      'icon': Icons.sensors_rounded,
      'color': AppColors.tertiary,
    },
    {
      'title': 'Guadagni Stimati',
      'value': '€12,450',
      'change': '+8.4% vs mese scorso',
      'icon': Icons.monetization_on_rounded,
      'color': AppColors.warning,
    },
  ];

  final List<Map<String, String>> logs = [
    {'event': 'Nuovo artista registrato', 'time': '2 min fa', 'detail': 'Kaelen ha creato un profilo'},
    {'event': 'Segnalazione copyright risolta', 'time': '15 min fa', 'detail': 'Brano ID #48293 autorizzato'},
    {'event': 'Aggiornamento server', 'time': '1 ora fa', 'detail': 'Database ottimizzato con successo'},
    {'event': 'Abbonamento Premium attivato', 'time': '2 ore fa', 'detail': 'Utente carme@beatter.com'},
  ];

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final textTheme = Theme.of(context).textTheme;
    final patterns = PatternRepository().patterns;

    return BeatterScaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pannello Amministrazione',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            Text('Beatter Admin', style: textTheme.headlineMedium),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                      tooltip: 'Esci',
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alert Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.tertiary]),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tutti i sistemi sono operativi',
                                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
                                  ),
                                  Text(
                                    'Nessuna anomalia rilevata nelle ultime 24 ore.',
                                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Composizioni e Ritmiche', style: textTheme.titleLarge),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RhythmCreatorPage()),
                              );
                              if (updated == true) {
                                setState(() {});
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('NUOVA RITMICA', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      SizedBox(
                        height: 70,
                        child: patterns.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: EmptyState(
                                  dense: true,
                                  icon: Icons.grid_on_rounded,
                                  title: 'Nessun pattern ancora creato',
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: patterns.length,
                                itemBuilder: (context, index) {
                                  final pat = patterns[index];
                                  final activeStepCount = pat.beats.where((b) => b).length;
                                  return Container(
                                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.md),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.grid_on_rounded, color: AppColors.secondary, size: 20),
                                        const SizedBox(width: AppSpacing.xs),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(pat.name, style: textTheme.titleMedium),
                                            Text(
                                              '${pat.bpm} BPM | $activeStepCount step attivi',
                                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      Text('Statistiche Generali', style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),

                      // Grid of stats
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 2 : 4,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final stat = stats[index];
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: AppTheme.glassCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 24),
                                    const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stat['value'] as String, style: textTheme.headlineSmall),
                                    const SizedBox(height: 2),
                                    Text(
                                      stat['title'] as String,
                                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Text(
                                  stat['change'] as String,
                                  style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl + 4),

                      Text('Registro Attività Recenti', style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),

                      // Activity list
                      if (logs.isEmpty)
                        const EmptyState(icon: Icons.history_rounded, title: 'Nessuna attività recente')
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.md),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 6,
                                    backgroundColor: index == 2 ? AppColors.warning : AppColors.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm + 2),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(log['event']!, style: textTheme.titleMedium),
                                        Text(
                                          log['detail']!,
                                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    log['time']!,
                                    style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
