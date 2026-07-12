import 'package:flutter/material.dart';
import '../../core/widgets/empty_state.dart';
import '../../theme/app_theme.dart';
import '../../models/rhythm_element.dart';
import 'figuration_images.dart';
import 'music_staff_painter.dart';
import 'staff_geometry.dart' as geometry;

/// Interactive wrapper around [MusicStaffPainter]: horizontal scrolling,
/// pinch-zoom, a cross-fade when the rendered measures change, and an empty
/// state for when there's nothing to show yet.
///
/// [onNoteTap] is unused today (Sheet Mode is read-only) but is exposed now
/// so Composer Mode can hook in tap-to-place/tap-to-edit later without
/// changing this widget's public API.
class MusicStaffView extends StatefulWidget {
  final List<RhythmMeasure> measures;
  final int activeMeasureIndex;
  final int activeElementIndex;
  final int? activeTripletIndex;
  final void Function(int measureIndex, int elementIndex)? onNoteTap;
  final ScrollController? scrollController;

  const MusicStaffView({
    super.key,
    required this.measures,
    this.activeMeasureIndex = -1,
    this.activeElementIndex = -1,
    this.activeTripletIndex,
    this.onNoteTap,
    this.scrollController,
  });

  @override
  State<MusicStaffView> createState() => _MusicStaffViewState();
}

class _MusicStaffViewState extends State<MusicStaffView> {
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  double _contentWidth() {
    const double leadingWidth =
        geometry.staffLeadingX + geometry.staffClefWidth + geometry.staffTimeSigWidth;
    double width = leadingWidth;
    for (final measure in widget.measures) {
      width += geometry.measureContentWidth(measure) + geometry.staffMeasureGap;
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.measures.isEmpty) {
      return _buildEmptyState();
    }

    FigurationImages.instance.ensureLoaded();

    return SizedBox(
      height: 160,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = _contentWidth().clamp(constraints.maxWidth, double.infinity);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: InteractiveViewer(
              key: ValueKey(widget.measures.length.toString() +
                  widget.measures.map((m) => m.elements.length).join(',')),
              constrained: false,
              minScale: 0.6,
              maxScale: 2.5,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: 160,
                  child: ListenableBuilder(
                    listenable: FigurationImages.instance,
                    builder: (context, _) => CustomPaint(
                      painter: MusicStaffPainter(
                        measures: widget.measures,
                        activeMeasureIndex: widget.activeMeasureIndex,
                        activeElementIndex: widget.activeElementIndex,
                        activeTripletIndex: widget.activeTripletIndex,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 160,
      decoration: AppTheme.glassCardDecoration(borderRadius: 16),
      child: const EmptyState(icon: Icons.piano_off_outlined, title: 'Nessuna nota da mostrare', dense: true),
    );
  }
}
