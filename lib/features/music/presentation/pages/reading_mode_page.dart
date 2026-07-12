import 'package:flutter/material.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/navigation/shell_visibility.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_exercise.dart';
import '../../../../services/exercise_generation/difficulty_presets.dart';
import '../../../../services/exercise_repository.dart';
import '../navigation/main_navigation_shell.dart';
import '../widgets/composition_list_tile.dart';
import 'exercise_player_page.dart';

/// Reading Mode: "ascolta e ripeti" sugli esercizi salvati in Sheet Mode.
/// La pagina è la libreria degli esercizi; aprendone uno si entra nel
/// player con i controlli reading (pausa ogni N battute, ripetizione col
/// tap guidato o da soli).
class ReadingModePage extends StatefulWidget {
  const ReadingModePage({super.key});

  @override
  State<ReadingModePage> createState() => _ReadingModePageState();
}

class _ReadingModePageState extends State<ReadingModePage> {
  final ExerciseRepository _repository = ExerciseRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onExercisesChanged);
    _load();
  }

  Future<void> _load() async {
    await _repository.init();
    if (mounted) setState(() => _loading = false);
  }

  void _onExercisesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.removeListener(_onExercisesChanged);
    super.dispose();
  }

  void _openExercise(RhythmExercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExercisePlayerPage(exercise: exercise, readingControls: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      appBar: BeatterAppBar(
        title: 'Reading Mode',
        leading: ShellMenuButton.maybe(context),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final exercises = _repository.exercises;
    if (exercises.isEmpty) {
      // Come nella tab "Salvati" di Sheet Mode: stato vuoto con azione che
      // porta dritti al generatore (cambio tab della shell).
      final shell = NavigationShellController.maybeOf(context);
      return EmptyState(
        icon: Icons.repeat_rounded,
        title: 'Nessun esercizio da ripetere',
        message:
            'Genera un esercizio in Sheet Mode e salvalo: lo ritroverai qui '
            'per allenarti in modalità ascolta e ripeti.',
        action: shell == null
            ? null
            : FilledButton.icon(
                onPressed: () => shell.selectTab(AppTab.sheetMode.index),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Vai a Sheet Mode'),
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
              icon: Icons.repeat_rounded,
              onTap: () => _openExercise(exercise),
            );
          },
        ),
      ),
    );
  }
}
