import 'package:flutter/material.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/framed_staff_card.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../models/composition.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../../services/composition_repository.dart';
import '../../../../widgets/music_staff/composer_staff_view.dart';
import '../../../../widgets/music_staff/staff_geometry.dart' as geometry;
import '../widgets/duration_toolbar.dart';
import '../widgets/playback_button.dart';

/// Snapshot of everything undo/redo needs to restore — the flat note
/// sequence plus the settings that affect how it reflows into measures.
class _EditSnapshot {
  final List<RhythmElement> flatSequence;
  final int bpm;
  final String timeSignature;

  const _EditSnapshot({
    required this.flatSequence,
    required this.bpm,
    required this.timeSignature,
  });
}

/// The Composer Mode editor: a large editable staff, a duration toolbar,
/// playback controls, tempo/time-signature settings, undo/redo and save.
///
/// Pass [existing] to edit a previously saved composition; omit it to start
/// a blank one. Editing state lives directly in this State (matching the
/// rest of the app's pattern of large page-owned State classes rather than
/// a separate controller/provider layer).
class ComposerPage extends StatefulWidget {
  final Composition? existing;

  const ComposerPage({super.key, this.existing});

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  late String _compositionId;
  late String _title;
  late DateTime _createdAt;
  late int _bpm;
  late String _timeSignature;
  late List<RhythmElement> _flatSequence;

  NoteDuration _selectedDuration = NoteDuration.quarter;
  int _selectedFlatIndex = -1;

  final List<_EditSnapshot> _undoStack = [];
  final List<_EditSnapshot> _redoStack = [];

  late final RhythmPlaybackService _playbackService;

  static const List<String> _timeSignatures = ['2/4', '3/4', '4/4', '6/8'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _compositionId = existing?.id ?? '';
    _title = existing?.title ?? '';
    _createdAt = existing?.createdAt ?? DateTime.now();
    _bpm = existing?.bpm ?? 100;
    _timeSignature = existing?.timeSignature ?? '4/4';
    _flatSequence = existing != null
        ? existing.toRhythmMeasures().expand((m) => m.elements).toList()
        : <RhythmElement>[];

    _playbackService = RhythmPlaybackService(enableMelodicPlayback: true);
    _playbackService.addListener(_onPlaybackChanged);
    _playbackService.updateSettings(bpm: _bpm, soundInstrument: 'melodic');
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

  List<RhythmMeasure> get _measures =>
      geometry.reflowMeasures(_flatSequence, _timeSignature);

  /// Maps the canonical flat-sequence selection index to the
  /// (measureIndex, elementIndex) the staff widget/painter expect.
  (int, int)? _measurePositionForFlatIndex(int flatIndex) {
    if (flatIndex < 0) return null;
    int remaining = flatIndex;
    final measures = _measures;
    for (int m = 0; m < measures.length; m++) {
      final count = measures[m].elements.length;
      if (remaining < count) return (m, remaining);
      remaining -= count;
    }
    return null;
  }

  int? _flatIndexForMeasurePosition(int measureIndex, int elementIndex) {
    final measures = _measures;
    if (measureIndex < 0 || measureIndex >= measures.length) return null;
    int flat = 0;
    for (int m = 0; m < measureIndex; m++) {
      flat += measures[m].elements.length;
    }
    return flat + elementIndex;
  }

  // ── Undo/redo ────────────────────────────────────────────────────────────

  void _pushUndoSnapshot() {
    _undoStack.add(
      _EditSnapshot(
        flatSequence: List<RhythmElement>.of(_flatSequence),
        bpm: _bpm,
        timeSignature: _timeSignature,
      ),
    );
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final snapshot = _undoStack.removeLast();
    _redoStack.add(
      _EditSnapshot(
        flatSequence: List<RhythmElement>.of(_flatSequence),
        bpm: _bpm,
        timeSignature: _timeSignature,
      ),
    );
    setState(() {
      _flatSequence = snapshot.flatSequence;
      _bpm = snapshot.bpm;
      _timeSignature = snapshot.timeSignature;
      _selectedFlatIndex = -1;
    });
    _playbackService.updateSettings(bpm: _bpm);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final snapshot = _redoStack.removeLast();
    _undoStack.add(
      _EditSnapshot(
        flatSequence: List<RhythmElement>.of(_flatSequence),
        bpm: _bpm,
        timeSignature: _timeSignature,
      ),
    );
    setState(() {
      _flatSequence = snapshot.flatSequence;
      _bpm = snapshot.bpm;
      _timeSignature = snapshot.timeSignature;
      _selectedFlatIndex = -1;
    });
    _playbackService.updateSettings(bpm: _bpm);
  }

  // ── Staff editing ────────────────────────────────────────────────────────

  void _handleSelectNote(int measureIndex, int elementIndex) {
    if (_playbackService.isPlaying) return;
    final flatIndex = _flatIndexForMeasurePosition(measureIndex, elementIndex);
    setState(() => _selectedFlatIndex = flatIndex ?? -1);
  }

  void _handleDeselect() {
    setState(() => _selectedFlatIndex = -1);
  }

  void _handleInsertNote(
    int measureIndex,
    int insertBeforeElementIndex,
    String pitch,
  ) {
    if (_playbackService.isPlaying) return;
    _pushUndoSnapshot();

    final flatIndex =
        _flatIndexForMeasurePosition(measureIndex, insertBeforeElementIndex) ??
        _flatSequence.length;
    final clampedIndex = flatIndex.clamp(0, _flatSequence.length);

    final newElement = RhythmElement(
      type: _selectedDuration.toRhythmElementType(),
      duration: _selectedDuration.beats,
      noteName: pitch,
    );
    final newList = List<RhythmElement>.of(_flatSequence)
      ..insert(clampedIndex, newElement);

    setState(() {
      _flatSequence = newList;
      _selectedFlatIndex = clampedIndex;
    });
  }

  void _handleDragStart() {
    if (_playbackService.isPlaying) return;
    _pushUndoSnapshot();
  }

  void _handleDragUpdate(String pitch) {
    if (_selectedFlatIndex == -1 || _selectedFlatIndex >= _flatSequence.length) {
      return;
    }
    final old = _flatSequence[_selectedFlatIndex];
    if (old.noteName == pitch) return;

    final newList = List<RhythmElement>.of(_flatSequence);
    newList[_selectedFlatIndex] = RhythmElement(
      type: old.type,
      duration: old.duration,
      noteName: pitch,
    );
    setState(() => _flatSequence = newList);
  }

  void _handleDeleteSelected() {
    if (_selectedFlatIndex == -1) return;
    _pushUndoSnapshot();
    final newList = List<RhythmElement>.of(_flatSequence)
      ..removeAt(_selectedFlatIndex);
    setState(() {
      _flatSequence = newList;
      _selectedFlatIndex = -1;
    });
  }

  void _handleDurationSelected(NoteDuration duration) {
    if (_selectedFlatIndex != -1 && _selectedFlatIndex < _flatSequence.length) {
      _pushUndoSnapshot();
      final old = _flatSequence[_selectedFlatIndex];
      final newList = List<RhythmElement>.of(_flatSequence);
      newList[_selectedFlatIndex] = RhythmElement(
        type: duration.toRhythmElementType(),
        duration: duration.beats,
        noteName: old.noteName,
      );
      setState(() {
        _flatSequence = newList;
        _selectedDuration = duration;
      });
    } else {
      setState(() => _selectedDuration = duration);
    }
  }

  void _handleTimeSignatureChanged(String newSignature) {
    if (newSignature == _timeSignature) return;
    _pushUndoSnapshot();
    setState(() {
      _timeSignature = newSignature;
      _selectedFlatIndex = -1;
    });
  }

  void _handleBpmChangeStart(double value) {
    _pushUndoSnapshot();
  }

  void _handleBpmChanged(double value) {
    setState(() => _bpm = value.round());
    _playbackService.updateSettings(bpm: _bpm);
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  void _togglePlayback() {
    if (_playbackService.isPlaying) {
      _playbackService.pause();
      return;
    }
    if (!_playbackService.isPaused) {
      _playbackService.preparePlayback(_measures);
    }
    _playbackService.play();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    String titleToUse = _title;
    if (_compositionId.isEmpty) {
      final entered = await _promptForTitle();
      if (entered == null || entered.trim().isEmpty) return;
      titleToUse = entered.trim();
    }

    final composition = Composition.fromElements(
      id: _compositionId,
      title: titleToUse,
      createdAt: _createdAt,
      modifiedAt: DateTime.now(),
      bpm: _bpm,
      timeSignature: _timeSignature,
      elements: _flatSequence,
    );

    final saved = await CompositionRepository().save(composition);
    if (!mounted) return;
    setState(() {
      _compositionId = saved.id;
      _title = saved.title;
      _createdAt = saved.createdAt;
    });
    Toast.show(ToastType.success, 'Composizione salvata', context);
  }

  Future<String?> _promptForTitle() {
    return showPromptDialog(
      context,
      title: 'Titolo composizione',
      hintText: 'La mia melodia',
      confirmLabel: 'Salva',
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final measures = _measures;
    final selectedPos = _measurePositionForFlatIndex(_selectedFlatIndex);

    return BeatterScaffold(
      appBar: BeatterAppBar(
        title: _title.isEmpty ? 'Nuova Composizione' : _title,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            color: AppColors.textPrimary,
            onPressed: _undoStack.isEmpty ? null : _undo,
            tooltip: 'Annulla',
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            color: AppColors.textPrimary,
            onPressed: _redoStack.isEmpty ? null : _redo,
            tooltip: 'Ripeti',
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            color: AppColors.primary,
            onPressed: _handleSave,
            tooltip: 'Salva',
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: TwoPaneLayout(
            portrait: (context) => _buildPortraitBody(measures, selectedPos),
            landscapePrimary: (context) =>
                _buildLandscapePrimary(measures, selectedPos),
            landscapeSecondary: (context) => _buildLandscapeSecondary(),
            primaryFlex: 0.66,
            secondaryFlex: 0.34,
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody(
    List<RhythmMeasure> measures,
    (int, int)? selectedPos,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStaffArea(measures, selectedPos, height: 160),
          _buildToolbarRow(),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTimeSignatureSelector(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: _buildBpmControl(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _buildPlaybackControls(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildLandscapePrimary(
    List<RhythmMeasure> measures,
    (int, int)? selectedPos,
  ) {
    return Column(
      children: [
        Expanded(child: _buildStaffArea(measures, selectedPos, height: 220)),
        _buildToolbarRow(),
      ],
    );
  }

  Widget _buildLandscapeSecondary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeSignatureSelector(),
          const SizedBox(height: AppSpacing.lg),
          _buildBpmControl(),
          const SizedBox(height: AppSpacing.xl),
          _buildPlaybackControls(),
        ],
      ),
    );
  }

  Widget _buildStaffArea(
    List<RhythmMeasure> measures,
    (int, int)? selectedPos, {
    required double height,
  }) {
    return FramedStaffCard(
      child: ComposerStaffView(
        measures: measures,
        canvasHeight: height,
        selectedMeasureIndex: selectedPos?.$1 ?? -1,
        selectedElementIndex: selectedPos?.$2 ?? -1,
        activeMeasureIndex: _playbackService.currentMeasureIndex,
        activeElementIndex: _playbackService.currentElementIndex,
        onSelectNote: _handleSelectNote,
        onDeselect: _handleDeselect,
        onInsertNote: _handleInsertNote,
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
      ),
    );
  }

  Widget _buildToolbarRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: DurationToolbar(
              selected: _selectedDuration,
              onSelected: _handleDurationSelected,
            ),
          ),
          if (_selectedFlatIndex != -1) ...[
            const SizedBox(width: AppSpacing.xxs),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Elimina nota',
              onPressed: _handleDeleteSelected,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSignatureSelector() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _timeSignatures.map((sig) {
        final bool selected = sig == _timeSignature;
        return ChoiceChip(
          label: Text(sig),
          selected: selected,
          onSelected: (_) => _handleTimeSignatureChanged(sig),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundColor: AppColors.surfaceBorder.withValues(alpha: 0.3),
          side: BorderSide(color: selected ? AppColors.primary : Colors.transparent),
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBpmControl() {
    return Row(
      children: [
        const Icon(Icons.speed_rounded, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 66,
          child: Text(
            '$_bpm BPM',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: Theme.of(context).sliderTheme,
            child: Slider(
              value: _bpm.toDouble(),
              min: 40,
              max: 220,
              onChangeStart: _handleBpmChangeStart,
              onChanged: _handleBpmChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final bool hasNotes = _flatSequence.isNotEmpty;
    return PlaybackButtonRow(
      isPlaying: _playbackService.isPlaying,
      isEnabled: hasNotes,
      onPlay: _togglePlayback,
      onStop: _playbackService.stopLoop,
    );
  }
}
