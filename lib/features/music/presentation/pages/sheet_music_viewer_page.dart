import 'package:flutter/material.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
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

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
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
    final bool isPlaying = _playbackService.isPlaying;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassCardDecoration(borderRadius: 16),
              child: MusicStaffView(
                measures: widget.measures,
                activeMeasureIndex: _playbackService.currentMeasureIndex,
                activeElementIndex: _playbackService.currentElementIndex,
                activeTripletIndex: _playbackService.currentTripletIndex,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlaybackButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: widget.measures.isEmpty ? null : _togglePlayback,
                primary: true,
              ),
              const SizedBox(width: 16),
              PlaybackButton(
                icon: Icons.stop_rounded,
                onTap: widget.measures.isEmpty
                    ? null
                    : _playbackService.stopLoop,
              ),
            ],
          ),
          const SizedBox(height: 20),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: StaffPlaybackPanel(title: '', measures: measures, bpm: bpm),
        ),
      ),
    );
  }
}
