import 'package:flutter/material.dart';
import '../../models/rhythm_element.dart';
import 'figuration_images.dart';
import 'music_staff_painter.dart';
import 'staff_geometry.dart' as geometry;

/// Renders measures across multiple staff systems (rows), wrapping whole
/// measures onto new rows when they'd exceed the available width — like
/// professional notation software — instead of [MusicStaffView]'s single
/// horizontally-scrolling system.
///
/// Playback highlighting works exactly as in the single-row view: pass the
/// global [activeMeasureIndex]/[activeElementIndex] and each system
/// translates them into its own local slice.
class WrappedStaffView extends StatelessWidget {
  final List<RhythmMeasure> measures;
  final int activeMeasureIndex;
  final int activeElementIndex;
  final int? activeTripletIndex;
  final double systemHeight;

  /// Notazione ritmica a linea singola (Sheet Mode).
  final bool singleLine;

  /// Sopra questa larghezza (tablet/desktop) ogni riga punta a
  /// [_tabletMaxMeasures] misure, ma mai a costo di rimpicciolire le note
  /// oltre [_minSystemScale]: se non ci stanno, la riga ne prende meno.
  static const double _tabletBreakpoint = 600;
  static const int _tabletMaxMeasures = 4;

  /// Scala minima accettabile per le note: una riga non viene mai compressa
  /// sotto questo fattore (tranne il caso limite inevitabile di una singola
  /// misura più larga dell'intero budget, che resta comunque ≥ 1 per riga).
  static const double _minSystemScale = 0.65;

  const WrappedStaffView({
    super.key,
    required this.measures,
    this.activeMeasureIndex = -1,
    this.activeElementIndex = -1,
    this.activeTripletIndex,
    this.systemHeight = 130,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (measures.isEmpty) return const SizedBox.shrink();

    // Kick del caricamento (idempotente) dei glifi delle figurazioni; il
    // ListenableBuilder ridipinge i sistemi appena sono pronti.
    FigurationImages.instance.ensureLoaded();

    return ListenableBuilder(
      listenable: FigurationImages.instance,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          // Su tablet/desktop il budget di riga è allargato di 1/minScale:
          // una riga può "sforare" la larghezza reale sapendo che il
          // FittedBox la ridurrà al massimo fino alla scala minima. Le note
          // non scendono mai sotto quella taglia; il numero di misure per
          // riga (fino a 4) diventa la variabile dipendente.
          final bool wide = constraints.maxWidth >= _tabletBreakpoint;
          final systems = geometry.computeSystemBreaks(
            measures,
            wide ? constraints.maxWidth / _minSystemScale : constraints.maxWidth,
            maxMeasuresPerSystem: wide ? _tabletMaxMeasures : 1 << 30,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int s = 0; s < systems.length; s++)
                _buildSystem(systems[s], s == 0, constraints.maxWidth),
            ],
          );
        },
      ),
    );
  }

  /// One staff system. Measures have a fixed engraved width, so a system
  /// that can't fit even one measure at natural size (narrow phones in
  /// portrait) is scaled down uniformly rather than overflowing the card.
  Widget _buildSystem(geometry.SystemBreak system, bool isFirst, double maxWidth) {
    final slice = measures.sublist(system.start, system.start + system.count);
    final double naturalWidth = geometry.staffLeadingX +
        geometry.staffClefWidth +
        geometry.staffTimeSigWidth +
        slice.fold<double>(
          0,
          (sum, m) =>
              sum + geometry.measureContentWidth(m) + geometry.staffMeasureGap,
        );

    final int localActive = _localActiveMeasure(system);
    final staff = SizedBox(
      // Staff lines are drawn across the full row so trailing space still
      // reads as an engraved system, like professional notation.
      width: naturalWidth < maxWidth ? maxWidth : naturalWidth,
      height: systemHeight,
      child: CustomPaint(
        painter: MusicStaffPainter(
          measures: slice,
          activeMeasureIndex: localActive,
          activeElementIndex: localActive >= 0 ? activeElementIndex : -1,
          activeTripletIndex: activeTripletIndex,
          showTimeSignature: isFirst,
          singleLine: singleLine,
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(fit: BoxFit.scaleDown, child: staff),
    );
  }

  int _localActiveMeasure(geometry.SystemBreak system) {
    final int local = activeMeasureIndex - system.start;
    if (activeMeasureIndex < 0 || local < 0 || local >= system.count) return -1;
    return local;
  }
}
