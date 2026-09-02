import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/navigation/shell_visibility.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../services/polyrhythm/polyrhythm_controller.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/polyrhythm/polygon_renderer.dart';
import '../widgets/polyrhythm/polyrhythm_control_panel.dart';
import '../widgets/polyrhythm/polyrhythm_dark_style.dart';
import '../widgets/polyrhythm/polyrhythm_painter.dart';
import '../widgets/polyrhythm/polyrhythm_settings_sheet.dart';

/// The "Polyrhythm Lab" flagship mode: an immersive, audio-synced
/// polyrhythm visualizer/trainer. This page only wires state (creates and
/// disposes [PolyrhythmController], follows the shared
/// landscape-while-visible pattern Flow Mode uses) and lays out chrome —
/// every bit of animation/timing/drawing logic lives in the controller,
/// the engine, and the renderer classes, not here.
///
/// The canvas (`CustomPaint` + its `PolyrhythmPainter`) is built once,
/// directly in [build] rather than inside any `ListenableBuilder` —
/// [PolyrhythmController] drives the canvas through the painter's own
/// `repaint` listenable (see `PolyrhythmPainter`), so this widget's
/// `build` never needs to re-run on tempo/volume/mode changes. Only the
/// two small pieces that actually render controller-derived *text/chrome*
/// (the background tint and the learning-mode chip row) are wrapped in
/// their own narrow `ListenableBuilder`s.
class PolyrhythmLabPage extends StatefulWidget {
  const PolyrhythmLabPage({super.key});

  @override
  State<PolyrhythmLabPage> createState() => _PolyrhythmLabPageState();
}

class _PolyrhythmLabPageState extends State<PolyrhythmLabPage>
    with SingleTickerProviderStateMixin {
  late final PolyrhythmController _controller;
  final PolygonRenderer _polygonRenderer = PolygonRenderer();

  bool? _lastAppliedVisibility;

  @override
  void initState() {
    super.initState();
    _controller = PolyrhythmController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Same pattern as FlowModePage: this page stays mounted inside the
    // shell's IndexedStack even while another tab shows, so the landscape
    // rotation it wants can't be tied to initState/dispose (those only
    // fire once, at shell creation/teardown) — ShellVisibility reports
    // the actual on-screen state instead.
    final bool visible = ShellVisibility.of(context);
    if (_lastAppliedVisibility == visible) return;
    _lastAppliedVisibility = visible;
    // Alla prima apertura della scheda: da qui in poi i suoni delle voci
    // sono pronti, prima di allora la modalità non costa nessun player.
    if (visible) _controller.primeVoiceSounds();
    SystemChrome.setPreferredOrientations(
      visible
          ? const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = context.isLandscape;

    return BeatterScaffold(
      backgroundColor: PolyrhythmDarkStyle.pureBlack,
      overlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.black,
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              height: double.infinity,
              decoration: PolyrhythmDarkStyle.backgroundDecoration(
                graphiteVariant: _controller.graphiteBackground,
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _controller.registerTap(),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PolyrhythmPainter(
                    engine: _controller.engine,
                    controller: _controller,
                    polygonRenderer: _polygonRenderer,
                  ),
                  isComplex: true,
                  willChange: true,
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _buildTopRow(context),
            ),
          ),
          SafeArea(
            child: PolyrhythmControlPanel(
              controller: _controller,
              isLandscape: isLandscape,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              if (ShellMenuButton.maybe(
                    context,
                    color: PolyrhythmDarkStyle.textOnDark,
                  )
                  case final menuButton?) ...[
                menuButton,
                const SizedBox(width: 4),
              ],
              const Text(
                'Polyrhythm Lab',
                style: TextStyle(
                  color: PolyrhythmDarkStyle.textOnDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: PolyrhythmDarkStyle.textOnDark,
                ),
                tooltip: 'Impostazioni',
                onPressed: () =>
                    PolyrhythmSettingsSheet.show(context, _controller),
              ),
            ],
          ),
        ),
        if (_controller.learningMode || _controller.practiceMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.learningMode)
                  Center(child: _buildLearningNumberChips()),
                if (_controller.practiceMode) ...[
                  if (_controller.learningMode) const SizedBox(height: 8),
                  Center(child: _buildPracticeScoreRow()),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // Learning Mode: instead of the shape name, each voice shows its raw
  // rhythm number (2, 3, 4...) — tapping a chip mutes just that voice's
  // audio (via `controller.toggleMute`) so a learner can isolate the
  // others by ear. The marker/flash keep animating for a muted voice —
  // only the sound is gated.
  Widget _buildLearningNumberChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: _controller.activePolygons.map((polygon) {
        final bool muted = _controller.mutedPolygonIds.contains(polygon.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _controller.toggleMute(polygon.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: muted
                  ? Colors.white.withValues(alpha: 0.04)
                  : polygon.color.withValues(alpha: 0.16),
              border: Border.all(
                color: muted
                    ? Colors.white.withValues(alpha: 0.25)
                    : polygon.color,
                width: muted ? 1 : 1.6,
              ),
            ),
            child: muted
                ? const Icon(
                    Icons.volume_off_rounded,
                    size: 15,
                    color: Colors.white38,
                  )
                : Text(
                    '${polygon.subdivisions}',
                    style: TextStyle(
                      color: polygon.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  // Practice Mode: a compact live readout, shown here in addition to the
  // fuller stats block in the settings sheet.
  Widget _buildPracticeScoreRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scoreItem(
            Icons.check_circle_rounded,
            '${_controller.practiceHits}',
            AppColors.success,
          ),
          const SizedBox(width: 12),
          _scoreItem(
            Icons.cancel_rounded,
            '${_controller.practiceMisses}',
            AppColors.error,
          ),
          const SizedBox(width: 12),
          _scoreItem(
            Icons.bolt_rounded,
            '${_controller.practiceStreak}',
            AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _scoreItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
