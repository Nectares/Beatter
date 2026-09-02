import 'package:flutter/material.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/framed_staff_card.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../../widgets/music_staff/music_staff_view.dart';
import '../widgets/playback_button.dart';

/// Renders a real staff for any [measures] and offers percussive-click
/// playback via the existing [RhythmPlaybackService].
///
/// Deliberately generic over its data source: today it's fed patterns from
/// [PatternRepository], but a saved Composer Mode composition is just another
/// `List<RhythmMeasure>`, so this widget needs no changes when that arrives.
class StaffPlaybackPanel extends StatefulWidget {
  final String title;
  final List<RhythmMeasure> measures;
  final int bpm;

  const StaffPlaybackPanel({
    super.key,
    required this.title,
    required this.measures,
    this.bpm = 100,
  });

  @override
  State<StaffPlaybackPanel> createState() => _StaffPlaybackPanelState();
}

class _StaffPlaybackPanelState extends State<StaffPlaybackPanel> {
  late final RhythmPlaybackService _playbackService;

  @override
  void initState() {
    super.initState();
    _playbackService = RhythmPlaybackService();
    _playbackService.addListener(_onPlaybackChanged);
    _playbackService.updateSettings(bpm: widget.bpm, soundInstrument: 'stick');
    _playbackService.preparePlayback(widget.measures);
  }

  @override
  void didUpdateWidget(covariant StaffPlaybackPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measures != widget.measures) {
      _playbackService.stop();
      _playbackService.preparePlayback(widget.measures);
    }
  }

  bool _wasPlaying = false;
  bool _wasPaused = false;

  void _onPlaybackChanged() {
    if (!mounted) return;
    // L'evidenziazione della nota arriva al pentagramma dal listenable
    // `highlight`, che ridisegna il solo pentagramma: qui si ricostruisce
    // la schermata solo quando cambia lo stato di riproduzione.
    final bool playing = _playbackService.isPlaying;
    final bool paused = _playbackService.isPaused;
    if (playing == _wasPlaying && paused == _wasPaused) return;
    _wasPlaying = playing;
    _wasPaused = paused;
    setState(() {});
  }

  @override
  void dispose() {
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_playbackService.isPlaying) {
      _playbackService.pause();
    } else {
      _playbackService.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxs,
              ),
              child: Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FramedStaffCard(
              outerPadding: EdgeInsets.zero,
              child: ValueListenableBuilder<PlaybackHighlight>(
                valueListenable: _playbackService.highlight,
                builder: (context, highlight, _) => MusicStaffView(
                  measures: widget.measures,
                  activeMeasureIndex: highlight.measureIndex,
                  activeElementIndex: highlight.elementIndex,
                  activeTripletIndex: highlight.tripletIndex,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PlaybackButtonRow(
            isPlaying: _playbackService.isPlaying,
            isEnabled: widget.measures.isNotEmpty,
            onPlay: _togglePlayback,
            onStop: _playbackService.stopLoop,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Full-screen detail page for viewing a single set of measures, pushed from
/// Sheet Mode's pattern library (portrait) or opened directly (landscape
/// still uses the embedded [StaffPlaybackPanel] inline).
class SheetMusicViewerPage extends StatelessWidget {
  final String title;
  final List<RhythmMeasure> measures;
  final int bpm;

  const SheetMusicViewerPage({
    super.key,
    required this.title,
    required this.measures,
    this.bpm = 100,
  });

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      appBar: BeatterAppBar(title: title, leading: const BackButton()),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: StaffPlaybackPanel(title: '', measures: measures, bpm: bpm),
        ),
      ),
    );
  }
}
