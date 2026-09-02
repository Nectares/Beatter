import 'dart:async';

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
import '../../../../services/reading_score_repository.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../../widgets/music_staff/wrapped_staff_view.dart';
import '../widgets/metronome_sound_dropdown.dart';
import '../widgets/playback_button.dart';
import '../widgets/volume_slider_row.dart';

/// Views a single generated rhythm reading exercise: multi-system staff,
/// single-pass playback with live highlighting, save/rename, regenerate
/// (same settings, new seed) and PDF export.
///
/// Con [readingControls] (Reading Mode) espone in più: il toggle "ascolta e
/// ripeti" che ferma l'esecuzione ogni N battute lasciando all'utente una
/// finestra della stessa durata per rifare il ritmo, la scelta tra ripetere
/// col tap sullo schermo (con guida visiva e pad) o da solo, e il pad TAP.
class ExercisePlayerPage extends StatefulWidget {
  final RhythmExercise exercise;
  final bool readingControls;

  const ExercisePlayerPage({
    super.key,
    required this.exercise,
    this.readingControls = false,
  });

  @override
  State<ExercisePlayerPage> createState() => _ExercisePlayerPageState();
}

/// Lo stato del servizio che la schermata del player rende visibile — vedi
/// `_ExercisePlayerPageState._visibleState`.
typedef PlayerVisibleState = ({
  bool playing,
  bool paused,
  bool echo,
  int good,
  int miss,
  int streak,
  bool metronomeOn,
  String metronomeSound,
  double metronomeVolume,
  double noteVolume,
  String instrument,
});

class _ExercisePlayerPageState extends State<ExercisePlayerPage> {
  late RhythmExercise _exercise;
  late final RhythmPlaybackService _playbackService;
  final ExercisePdfExporter _pdfExporter = ExercisePdfExporter();
  bool _exporting = false;

  // Impostazioni Reading Mode (attive solo con widget.readingControls).
  bool _readingEnabled = true;
  int _echoEveryMeasures = 1;
  bool _tapRepeat = true;

  // Punteggio Reading Mode: record persistito per esercizio e feedback
  // transitorio dell'ultimo tap (true = good, false = miss).
  final ReadingScoreRepository _scoreRepository = ReadingScoreRepository();
  ReadingScore? _record;
  bool _wasPlaying = false;
  bool? _tapFlash;
  Timer? _tapFlashTimer;

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    _playbackService = RhythmPlaybackService();
    _playbackService.addListener(_onPlaybackChanged);
    // Suono note di default silenzioso: l'esercizio di lettura si esegue
    // sul metronomo; bacchetta/rullante si attivano dal menù a tendina.
    _playbackService.updateSettings(bpm: _exercise.bpm, soundInstrument: 'silent');
    _preparePlayback();

    if (widget.readingControls) {
      // Il repository dei record sincronizza col backend (Firestore da
      // loggati): resta in ascolto per gli aggiornamenti remoti.
      _scoreRepository.addListener(_onRecordChanged);
      _scoreRepository.init().then((_) => _onRecordChanged());
    }
  }

  void _onRecordChanged() {
    if (!mounted || _exercise.id.isEmpty) return;
    setState(() => _record = _scoreRepository.recordFor(_exercise.id));
  }

  /// A fine sessione (playback terminato o fermato) consolida il punteggio
  /// nei record dell'esercizio e segnala l'eventuale nuovo record.
  Future<void> _persistScore() async {
    if (!widget.readingControls ||
        !_readingEnabled ||
        !_tapRepeat ||
        _exercise.id.isEmpty) {
      return;
    }
    final int good = _playbackService.echoGood;
    final int strike = _playbackService.echoBestStreak;
    if (good == 0) return;

    final improved =
        await _scoreRepository.submit(_exercise.id, good: good, strike: strike);
    if (improved && mounted) {
      Toast.show(ToastType.success, 'Nuovo record! 🏆', context);
    }
  }

  /// (Ri)costruisce la timeline con le impostazioni correnti del Reading
  /// Mode: finestre di eco ogni N battute quando attivo, playback normale
  /// altrimenti.
  void _preparePlayback() {
    _playbackService.updateSettings(echoGuideEnabled: _tapRepeat);
    _playbackService.preparePlayback(
      _exercise.measures,
      echoEveryMeasures:
          widget.readingControls && _readingEnabled ? _echoEveryMeasures : null,
    );
  }

  /// Le impostazioni reading cambiano la timeline: fermano l'esecuzione e
  /// la ripreparano da capo.
  void _updateReadingSettings(VoidCallback change) {
    _playbackService.stop();
    setState(change);
    _preparePlayback();
  }

  @override
  void dispose() {
    _tapFlashTimer?.cancel();
    // Uscita a metà sessione: consolida comunque il punteggio raggiunto.
    _persistScore();
    if (widget.readingControls) {
      _scoreRepository.removeListener(_onRecordChanged);
    }
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    super.dispose();
  }

  /// Quello che la pagina mostra davvero del servizio: trasporto, fase di
  /// eco, punteggio e i controlli audio (che qui stanno nella schermata,
  /// non in un pannello a parte). L'evidenziazione della nota non c'è
  /// dentro: quella arriva al pentagramma dal listenable `highlight` e ne
  /// ridisegna solo quello, invece di ricostruire la pagina a ogni nota.
  PlayerVisibleState get _visibleState => (
        playing: _playbackService.isPlaying,
        paused: _playbackService.isPaused,
        echo: _playbackService.isEchoPhase,
        good: _playbackService.echoGood,
        miss: _playbackService.echoMiss,
        streak: _playbackService.echoStreak,
        metronomeOn: _playbackService.isMetronomeEnabled,
        metronomeSound: _playbackService.metronomeSound,
        metronomeVolume: _playbackService.metronomeVolume,
        noteVolume: _playbackService.noteVolume,
        instrument: _playbackService.soundInstrument,
      );

  PlayerVisibleState? _lastVisibleState;

  void _onPlaybackChanged() {
    // Transizione play → fermo (fine naturale o stop, non la pausa, che
    // riprende la stessa sessione): salva il punteggio.
    final bool playing = _playbackService.isPlaying;
    if (_wasPlaying && !playing && !_playbackService.isPaused) {
      _persistScore();
    }
    _wasPlaying = playing;

    if (!mounted) return;
    final state = _visibleState;
    if (state == _lastVisibleState) return;
    _lastVisibleState = state;
    setState(() {});
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
      _preparePlayback();
    }
    // Reading exercises play through once and stop at the end — no loop.
    _playbackService.play(loop: false);
  }

  /// Ricomincia l'esecuzione dall'inizio, anche se in pausa a metà.
  void _restartPlayback() {
    _playbackService.stop();
    _preparePlayback();
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
    _preparePlayback();
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
      // Dialog modale di attesa: la rasterizzazione dei sistemi e
      // l'assemblaggio del PDF richiedono qualche secondo.
      await runWithBusyDialog(
        context,
        message: 'Generazione PDF…',
        task: () => _pdfExporter.export(_exercise),
      );
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
      // BoxConstraints.expand: la SingleChildScrollView si restringe al
      // proprio contenuto, e senza vincolo il Container (e quindi il
      // gradiente) si restringerebbe con lei — con poche battute su tablet
      // la pagina "finiva" a metà schermo lasciando bianco sotto i
      // controlli. Così il gradiente copre sempre l'intero viewport.
      body: Container(
        constraints: const BoxConstraints.expand(),
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
                        child: ValueListenableBuilder<PlaybackHighlight>(
                          valueListenable: _playbackService.highlight,
                          builder: (context, highlight, _) => WrappedStaffView(
                            measures: _exercise.measures,
                            activeMeasureIndex: highlight.measureIndex,
                            activeElementIndex: highlight.elementIndex,
                            activeTripletIndex: highlight.tripletIndex,
                            singleLine: true,
                            // Durante la finestra di eco la guida cambia
                            // colore: "ascolta" è primario, "ripeti"
                            // terziario.
                            activeColor: highlight.isEcho
                                ? AppColors.tertiary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    PlaybackButtonRow(
                      isPlaying: _playbackService.isPlaying,
                      isEnabled: _exercise.measures.isNotEmpty,
                      onPlay: _togglePlayback,
                      onRestart: _restartPlayback,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMetronomeToggle(),
                    const SizedBox(height: AppSpacing.xs),
                    VolumeSliderRow(
                      icon: Icons.volume_up_rounded,
                      label: 'Volume metronomo',
                      value: _playbackService.metronomeVolume,
                      onChanged: (value) =>
                          _playbackService.updateSettings(metronomeVolume: value),
                    ),
                    VolumeSliderRow(
                      icon: Icons.music_note_rounded,
                      label: 'Volume note',
                      value: _playbackService.noteVolume,
                      onChanged: (value) =>
                          _playbackService.updateSettings(noteVolume: value),
                    ),
                    if (widget.readingControls) ...[
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: _buildReadingCard(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (!widget.readingControls)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: OutlinedButton.icon(
                          onPressed: _regenerate,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
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
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
                    color:
                        enabled ? AppColors.textPrimary : AppColors.textMuted,
                  ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Switch(
              value: enabled,
              onChanged: (value) =>
                  _playbackService.updateSettings(isMetronomeEnabled: value),
            ),
          ],
        ),
        _buildSoundInstrumentDropdown(),
        MetronomeSoundDropdown(playbackService: _playbackService),
      ],
    );
  }

  /// Lo stesso menù a tendina del suono delle note usato in Flow Mode:
  /// silenzio (default), bacchetta o rullante.
  Widget _buildSoundInstrumentDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: DropdownButton<String>(
        value: _playbackService.soundInstrument,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        items: const [
          DropdownMenuItem(value: 'silent', child: Text('🔇 Silent')),
          DropdownMenuItem(value: 'snare', child: Text('🥁 Snare')),
          DropdownMenuItem(value: 'stick', child: Text('🥢 Stick')),
        ],
        onChanged: (v) {
          if (v != null) {
            _playbackService.updateSettings(soundInstrument: v);
          }
        },
      ),
    );
  }

  // ── Reading Mode ─────────────────────────────────────────────────────────

  Widget _buildReadingCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                size: 20,
                color: _readingEnabled ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Ascolta e ripeti',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch(
                value: _readingEnabled,
                onChanged: (value) =>
                    _updateReadingSettings(() => _readingEnabled = value),
              ),
            ],
          ),
          if (_readingEnabled) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  'Pausa ogni',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final n in const [1, 2, 4]) ...[
                  ChoiceChip(
                    label: Text(n == 1 ? '1 battuta' : '$n battute'),
                    selected: _echoEveryMeasures == n,
                    onSelected: (_) =>
                        _updateReadingSettings(() => _echoEveryMeasures = n),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _echoEveryMeasures == n
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: _echoEveryMeasures == n
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  _tapRepeat ? Icons.touch_app_rounded : Icons.self_improvement_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _tapRepeat
                        ? 'Ripeti con i tap sullo schermo (guida visiva)'
                        : 'Ripeti da solo, senza guida',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Switch(
                  value: _tapRepeat,
                  onChanged: (value) =>
                      _updateReadingSettings(() => _tapRepeat = value),
                ),
              ],
            ),
            if (_tapRepeat) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildTapPad(),
              const SizedBox(height: AppSpacing.sm),
              _buildScoreRow(),
            ],
          ],
        ],
      ),
    );
  }

  void _onTapPad() {
    if (!_playbackService.isPlaying) return;
    _playbackService.playTap();
    final bool hit = _playbackService.registerEchoTap();

    // Flash verde/rosso del pad sull'esito del tap (solo in fase eco:
    // fuori finestra il tap è ignorato e non deve segnare rosso).
    if (!_playbackService.isEchoPhase && !hit) return;
    _tapFlashTimer?.cancel();
    setState(() => _tapFlash = hit);
    _tapFlashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _tapFlash = null);
    });
  }

  /// Il pad su cui l'utente batte il ritmo durante la finestra di eco:
  /// si "accende" quando tocca a lui, ogni tap suona la bacchetta e
  /// lampeggia verde (good) o rosso (miss) in base al giudizio.
  Widget _buildTapPad() {
    final bool echoing =
        _playbackService.isPlaying && _playbackService.isEchoPhase;

    final Color accent = switch (_tapFlash) {
      true => AppColors.success,
      false => AppColors.error,
      null => echoing ? AppColors.tertiary : AppColors.surfaceBorder,
    };
    final Color content = switch (_tapFlash) {
      true => AppColors.success,
      false => AppColors.error,
      null => echoing ? AppColors.tertiary : AppColors.textMuted,
    };

    return GestureDetector(
      onTapDown: (_) => _onTapPad(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: _tapFlash != null ? 0.22 : (echoing ? 0.18 : 0.25)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: accent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, color: content),
            const SizedBox(width: AppSpacing.xs),
            Text(
              echoing
                  ? 'RIPETI — batti il ritmo!'
                  : (_playbackService.isPlaying ? 'Ascolta…' : 'TAP'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: content,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Punteggio live della sessione (punti, good, strike) più il record
  /// personale dell'esercizio.
  Widget _buildScoreRow() {
    final service = _playbackService;

    Widget stat(IconData icon, String label, String value, Color color) {
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
              '$label $value',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            stat(Icons.stars_rounded, 'Punti', '${service.echoScore}',
                AppColors.primary),
            stat(Icons.check_circle_rounded, 'Good', '${service.echoGood}',
                AppColors.success),
            stat(Icons.bolt_rounded, 'Strike', '${service.echoStreak}',
                AppColors.tertiary),
            stat(Icons.close_rounded, 'Miss', '${service.echoMiss}',
                AppColors.error),
          ],
        ),
        if (_record != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Record: Good ${_record!.good} • Strike ${_record!.strike}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
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
