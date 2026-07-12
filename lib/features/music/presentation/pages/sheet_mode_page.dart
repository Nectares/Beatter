import 'package:flutter/material.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_exercise.dart';
import '../../../../services/exercise_generation/difficulty_presets.dart';
import '../../../../services/exercise_generation/exercise_generator.dart';
import '../../../../services/exercise_pdf_exporter.dart';
import '../../../../services/exercise_repository.dart';
import '../widgets/composition_list_tile.dart';
import 'exercise_player_page.dart';

/// Sheet Mode: the rhythm reading exercise generator. The "Genera" tab
/// configures difficulty/metro/tempo/length and produces a brand-new
/// procedural exercise; the "Salvati" tab lists everything the user kept,
/// with open/rename/duplicate/delete/export actions.
class SheetModePage extends StatefulWidget {
  const SheetModePage({super.key});

  @override
  State<SheetModePage> createState() => _SheetModePageState();
}

class _SheetModePageState extends State<SheetModePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final ExerciseRepository _repository = ExerciseRepository();
  bool _exercisesLoading = true;

  // Generator settings.
  DifficultyPreset _preset = kDifficultyPresets.first;
  String _timeSignature = '4/4';
  int _bpm = 80;
  int _measureCount = 8;

  static const List<String> _timeSignatures = ['2/4', '3/4', '4/4', '6/8'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository.addListener(_onExercisesChanged);
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    await _repository.init();
    if (mounted) setState(() => _exercisesLoading = false);
  }

  void _onExercisesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _repository.removeListener(_onExercisesChanged);
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _generateExercise() {
    final exercise = ExerciseGenerator().generate(
      ExerciseGeneratorConfig(
        preset: _preset,
        timeSignature: _timeSignature,
        bpm: _bpm,
        measureCount: _measureCount,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExercisePlayerPage(exercise: exercise)),
    );
  }

  void _openExercise(RhythmExercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExercisePlayerPage(exercise: exercise)),
    );
  }

  Future<void> _renameExercise(RhythmExercise exercise) async {
    final entered = await showPromptDialog(
      context,
      title: 'Rinomina esercizio',
      initialValue: exercise.title,
      confirmLabel: 'Rinomina',
    );
    if (entered == null || entered.trim().isEmpty) return;
    await _repository.rename(exercise.id, entered.trim());
  }

  Future<void> _deleteExercise(RhythmExercise exercise) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Elimina esercizio',
      message: 'Vuoi eliminare "${exercise.title}"? L\'operazione non è reversibile.',
      confirmLabel: 'Elimina',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _repository.delete(exercise.id);
    if (mounted) Toast.show(ToastType.success, 'Esercizio eliminato', context);
  }

  Future<void> _exportExercise(RhythmExercise exercise) async {
    try {
      await ExercisePdfExporter().export(exercise);
    } catch (_) {
      if (mounted) {
        Toast.show(ToastType.error, 'Esportazione PDF non riuscita', context);
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      appBar: BeatterAppBar(
        title: 'Sheet Mode',
        leading: ShellMenuButton.maybe(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Genera'),
            Tab(text: 'Esercizi Salvati'),
          ],
        ),
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneratorTab(),
              _buildSavedTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Generator tab ────────────────────────────────────────────────────────

  Widget _buildGeneratorTab() {
    return TwoPaneLayout(
      portrait: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Difficoltà'),
                _buildPresetSelector(),
                const SizedBox(height: AppSpacing.lg),
                _buildSettingsCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildGenerateButton(),
              ],
            ),
          ),
        ),
      ),
      landscapePrimary: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Difficoltà'),
            _buildPresetSelector(),
          ],
        ),
      ),
      landscapeSecondary: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSettingsCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildGenerateButton(),
          ],
        ),
      ),
      primaryFlex: 0.45,
      secondaryFlex: 0.55,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Column(
      children: kDifficultyPresets.map((preset) {
        final bool selected = preset.id == _preset.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => setState(() => _preset = preset),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg)
                    .copyWith(
                  border: Border.all(
                    color: selected ? preset.accentColor : AppColors.surfaceBorder,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: preset.accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: preset.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.label,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.check_circle_rounded, color: preset.accentColor, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metro',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _timeSignatures.map((sig) {
              final bool selected = sig == _timeSignature;
              return ChoiceChip(
                label: Text(sig),
                selected: selected,
                onSelected: (_) => setState(() => _timeSignature = sig),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundColor: AppColors.surfaceBorder.withValues(alpha: 0.3),
                side: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSliderRow(
            icon: Icons.speed_rounded,
            label: '$_bpm BPM',
            value: _bpm.toDouble(),
            min: 40,
            max: 220,
            onChanged: (v) => setState(() => _bpm = v.round()),
          ),
          _buildSliderRow(
            icon: Icons.grid_view_rounded,
            label: '$_measureCount battute',
            value: _measureCount.toDouble(),
            min: 2,
            max: 32,
            divisions: 30,
            onChanged: (v) => setState(() => _measureCount = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return FilledButton.icon(
      onPressed: _generateExercise,
      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Text('Genera Esercizio'),
      ),
    );
  }

  // ── Saved tab ────────────────────────────────────────────────────────────

  Widget _buildSavedTab() {
    if (_exercisesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final exercises = _repository.exercises;
    if (exercises.isEmpty) {
      return EmptyState(
        icon: Icons.library_music_outlined,
        title: 'Nessun esercizio salvato',
        message: 'Genera un esercizio e salvalo per ritrovarlo qui.',
        action: FilledButton.icon(
          onPressed: () => _tabController.animateTo(0),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Vai al generatore'),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            final preset = presetById(exercise.difficultyId);
            return CompositionListTile(
              title: exercise.title,
              subtitle:
                  '${preset.label} • ${exercise.bpm} BPM • ${exercise.timeSignature} • ${exercise.measureCount} battute',
              icon: Icons.menu_book_rounded,
              onTap: () => _openExercise(exercise),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                onSelected: (action) {
                  switch (action) {
                    case 'open':
                      _openExercise(exercise);
                    case 'rename':
                      _renameExercise(exercise);
                    case 'duplicate':
                      _repository.duplicate(exercise.id);
                    case 'export':
                      _exportExercise(exercise);
                    case 'delete':
                      _deleteExercise(exercise);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.play_arrow_rounded),
                      title: Text('Apri'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.drive_file_rename_outline_rounded),
                      title: Text('Rinomina'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Duplica'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_rounded),
                      title: Text('Esporta PDF'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      title: Text('Elimina', style: TextStyle(color: AppColors.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
