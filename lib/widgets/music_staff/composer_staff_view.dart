import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/rhythm_element.dart';
import 'music_staff_painter.dart';
import 'staff_geometry.dart' as geometry;

/// The editable staff for Composer Mode: tap empty space to place a note,
/// tap an existing note to select it (tap again to deselect), drag a
/// selected note vertically to change its pitch.
///
/// Does not reuse [MusicStaffView]'s `InteractiveViewer` — its pan/zoom
/// gestures would conflict with dragging a selected note's pitch. Hit-testing
/// uses the exact same [geometry.computeLayout] the painter draws with, so
/// the two can never disagree about where a note actually is.
class ComposerStaffView extends StatefulWidget {
  final List<RhythmMeasure> measures;
  final int selectedMeasureIndex; // -1 = none selected
  final int selectedElementIndex;
  final int activeMeasureIndex; // -1 = not playing
  final int activeElementIndex;
  final void Function(int measureIndex, int elementIndex) onSelectNote;
  final VoidCallback onDeselect;
  final void Function(
    int measureIndex,
    int insertBeforeElementIndex,
    String pitch,
  )
  onInsertNote;
  final VoidCallback onDragStart;
  final void Function(String pitch) onDragUpdate;
  final ScrollController? scrollController;
  final double canvasHeight;

  const ComposerStaffView({
    super.key,
    required this.measures,
    this.selectedMeasureIndex = -1,
    this.selectedElementIndex = -1,
    this.activeMeasureIndex = -1,
    this.activeElementIndex = -1,
    required this.onSelectNote,
    required this.onDeselect,
    required this.onInsertNote,
    required this.onDragStart,
    required this.onDragUpdate,
    this.scrollController,
    this.canvasHeight = 160.0,
  });

  @override
  State<ComposerStaffView> createState() => _ComposerStaffViewState();
}

class _ComposerStaffViewState extends State<ComposerStaffView> {
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  bool get _hasSelection => widget.selectedElementIndex != -1;

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  double _contentWidth() {
    const double leadingWidth =
        geometry.staffLeadingX +
        geometry.staffClefWidth +
        geometry.staffTimeSigWidth;
    double width = leadingWidth;
    for (final measure in widget.measures) {
      width +=
          geometry.measureWidth(measure.timeSignature) +
          geometry.staffMeasureGap;
    }
    return width;
  }

  void _handleTapUp(TapUpDetails details) {
    final Offset pos = details.localPosition;
    final double midY = widget.canvasHeight / 2;

    if (widget.measures.isEmpty) {
      final pitch = geometry.noteNameFromY(pos.dy, midY, geometry.lineSpacing);
      widget.onInsertNote(0, 0, pitch);
      return;
    }

    final layout = geometry.computeLayout(widget.measures);

    // 1. Hit-test existing notes first — tap toggles selection.
    for (final measureLayout in layout) {
      final measure = widget.measures[measureLayout.measureIndex];
      for (final position in measureLayout.elements) {
        final element = measure.elements[position.elementIndex];
        final double y = geometry.noteY(
          element.noteName,
          midY,
          geometry.lineSpacing,
        );
        final hitRect = Rect.fromCenter(
          center: Offset(position.x, y),
          width: 24,
          height: 20,
        );
        if (hitRect.contains(pos)) {
          final bool alreadySelected =
              position.measureIndex == widget.selectedMeasureIndex &&
              position.elementIndex == widget.selectedElementIndex;
          if (alreadySelected) {
            widget.onDeselect();
          } else {
            widget.onSelectNote(position.measureIndex, position.elementIndex);
          }
          return;
        }
      }
    }

    // 2. No existing note hit — insert a new one at the tapped position.
    geometry.MeasureLayout target = layout.last;
    for (final measureLayout in layout) {
      if (pos.dx <= measureLayout.endX) {
        target = measureLayout;
        break;
      }
    }

    int insertIndex = target.elements.length;
    for (int i = 0; i < target.elements.length; i++) {
      if (target.elements[i].x >= pos.dx) {
        insertIndex = i;
        break;
      }
    }

    final pitch = geometry.noteNameFromY(pos.dy, midY, geometry.lineSpacing);
    widget.onInsertNote(target.measureIndex, insertIndex, pitch);
  }

  void _handlePanStart(DragStartDetails details) {
    widget.onDragStart();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final double midY = widget.canvasHeight / 2;
    final pitch = geometry.noteNameFromY(
      details.localPosition.dy,
      midY,
      geometry.lineSpacing,
    );
    widget.onDragUpdate(pitch);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = widget.measures.isEmpty
            ? constraints.maxWidth
            : _contentWidth().clamp(constraints.maxWidth, double.infinity);

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: widget.canvasHeight,
            child: RepaintBoundary(
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _handleTapUp,
                    onPanStart: _hasSelection ? _handlePanStart : null,
                    onPanUpdate: _hasSelection ? _handlePanUpdate : null,
                    child: CustomPaint(
                      size: Size(width, widget.canvasHeight),
                      painter: MusicStaffPainter(
                        measures: widget.measures,
                        activeMeasureIndex: _hasSelection
                            ? widget.selectedMeasureIndex
                            : widget.activeMeasureIndex,
                        activeElementIndex: _hasSelection
                            ? widget.selectedElementIndex
                            : widget.activeElementIndex,
                      ),
                    ),
                  ),
                  if (widget.measures.isEmpty)
                    IgnorePointer(
                      child: Center(
                        child: Text(
                          'Tocca per iniziare a comporre',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
