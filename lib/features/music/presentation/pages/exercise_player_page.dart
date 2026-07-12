import 'package:flutter/material.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/framed_staff_card.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_exercise.dart';
import '../../../../services/exercise_generation/difficulty_presets.dart';
import '../../../../services/exercise_generation/exercise_generator.dart';
import '../../../../services/exercise_pdf_exporter.dart';
import '../../../../services/exercise_repository.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../../widgets/music_staff/wrapped_staff_view.dart';
import '../widgets/playback_button.dart';

/// Views a single generated rhythm reading exercise: multi-system staff,
/// single-pass playback with live highlighting, save/rename, regenerate
/// (same settings, new seed) and PDF export.
class ExercisePlayerPage extends StatefulWidget {
  final RhythmExercise exercise;

  const ExercisePlayerPage({super.key, required this.exercise});

  @override
  State<ExercisePlayerPage> createState() => _ExercisePlayerPageState();
}

class _ExercisePlayerPageState extends State<ExercisePlayerPage> {
  late RhythmExercise _exercise;
  late final RhythmPlaybackService _playbackService;
  final ExercisePdfExporter _pdfExporter = ExercisePdfExporter();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    _playbackService = RhythmPlaybackService();
    _playbackService.addListener(_onPlaybackChanged);
    _playbackService.updateSettings(bpm: _exercise.bpm, soundInstrument: 'stick');
    _playbackService.preparePlayback(_exercise.measures);
  }

  @override
  void dispose() {
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  bool get _isSaved => _exercise.id.isNotEmpty;

  DifficultyPreset get _preset => presetById(_exercise.difficultyId);

  // ── Actions ──────────────────────────────────────────────────────────────

  void _togglePlayback() {
    if (_playbackService.isPlaying) {
      _playbackService.pause();
      return;
    }
    if (!_playbackService.isPaused) {
      _playbackService.preparePlayback(_exercise.measures);
    }
    // Reading exercises play through once and stop at the end — no loop.
    _playbackService.play(loop: false);
  }

  void _regenerate() {
    if (_playbackService.isPlaying) _playbackService.stop();

    final regenerated = ExerciseGenerator().generate(
      ExerciseGeneratorConfig(
        preset: _preset,
        timeSignature: _exercise.timeSignature,
        bpm: _exercise.bpm,
        measureCount: _exercise.measureCount,
      ),
    );

    setState(() {
      // A regenerated exercise is new content: it keeps the title only if
      // never saved, and always drops the saved id so the original stays
      // intact in the library.
      _exercise = regenerated.copyWith(title: _isSaved ? '' : _exercise.title);
    });
    _playbackService.preparePlayback(_exercise.measures);
  }

  Future<void> _save() async {
    String title = _exercise.title;
    if (title.isEmpty) {
      final entered = await showPromptDialog(
        context,
        title: 'Titolo esercizio',
        hintText: 'Lettura ${_preset.label} in ${_exercise.timeSignature}',
      );
      if (entered == null) return;
      title = entered.trim().isEmpty
          ? 'Lettura ${_preset.label} in ${_exercise.timeSignature}'
          : entered.trim();
    }

    final saved = await ExerciseRepository().save(_exercise.copyWith(title: title));
    if (!mounted) return;
    setState(() => _exercise = saved);
    Toast.show(ToastType.success, 'Esercizio salvato', context);
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _pdfExporter.export(_exercise);
    } catch (_) {
      if (mounted) {
        Toast.show(ToastType.error, 'Esportazione PDF non riuscita', context);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      appBar: BeatterAppBar(
        title: _exercise.title.isEmpty ? 'Nuovo Esercizio' : _exercise.title,
        centerTitle: false,
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.check_circle_rounded : Icons.save_rounded,
              color: _isSaved ? AppColors.success : AppColors.primary,
            ),
            tooltip: _isSaved ? 'Salvato' : 'Salva',
            onPressed: _isSaved ? null : _save,
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.secondary),
            tooltip: 'Esporta PDF',
            onPressed: _exporting ? null : _exportPdf,
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: _buildMetadataChips(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: FramedStaffCard(
                        outerPadding: EdgeInsets.zero,
                        innerPadding: const EdgeInsets.all(AppSpacing.md),
                        child: WrappedStaffView(
                          measures: _exercise.measures,
                          activeMeasureIndex: _playbackService.currentMeasureIndex,
                          activeElementIndex: _playbackService.currentElementIndex,
                          activeTripletIndex: _playbackService.currentTripletIndex,
                        ),
                      ),
                    ),
                    PlaybackButtonRow(
                      isPlaying: _playbackService.isPlaying,
                      isEnabled: _exercise.measures.isNotEmpty,
                      onPlay: _togglePlayback,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMetronomeToggle(),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: OutlinedButton.icon(
                        onPressed: _regenerate,
                        icon: const Icon(Icons.casino_rounded, size: 20),
                        label: const Text('Rigenera con le stesse impostazioni'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetronomeToggle() {
    final bool enabled = _playbackService.isMetronomeEnabled;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.av_timer_rounded,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Metronomo',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Switch(
          value: enabled,
          onChanged: (value) =>
              _playbackService.updateSettings(isMetronomeEnabled: value),
        ),
      ],
    );
  }

  Widget _buildMetadataChips() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _metaChip(Icons.local_fire_department_rounded, _preset.label, _preset.accentColor),
        _metaChip(Icons.speed_rounded, '${_exercise.bpm} BPM', AppColors.primary),
        _metaChip(Icons.straighten_rounded, _exercise.timeSignature, AppColors.info),
        _metaChip(Icons.grid_view_rounded, '${_exercise.measureCount} battute', AppColors.textSecondary),
      ],
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
