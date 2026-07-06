import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/rhythm_element.dart';
import 'music_staff_painter.dart';

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
    const double leadingWidth = 100.0; // clef + time signature
    const double measureGap = 10.0;
    double width = leadingWidth;
    for (final measure in widget.measures) {
      width += _measureWidthFor(measure.timeSignature) + measureGap;
    }
    return width;
  }

  double _measureWidthFor(String timeSignature) {
    switch (timeSignature) {
      case '3/4':
        return 180.0;
      case '6/8':
        return 200.0;
      case '4/4':
      default:
        return 240.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.measures.isEmpty) {
      return _buildEmptyState();
    }

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
                  child: CustomPaint(
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
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: AppTheme.glassCardDecoration(borderRadius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.piano_off_outlined, color: AppTheme.textMuted, size: 32),
          const SizedBox(height: 8),
          Text(
            'Nessuna nota da mostrare',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
