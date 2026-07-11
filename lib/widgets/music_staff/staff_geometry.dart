/// Pure, canvas-free geometry helpers shared by [MusicStaffPainter] (and any
/// future hit-testing/drag layer, e.g. Composer Mode's note placement).
///
/// All positions are expressed relative to a treble clef, 5-line staff whose
/// middle line is B4.
library;

import '../../models/rhythm_element.dart';

const double lineSpacing = 10.0;
const double noteWidth = 12.0;
const double noteHeight = 8.0;

const Map<String, int> _letterOrder = {
  'C': 0,
  'D': 1,
  'E': 2,
  'F': 3,
  'G': 4,
  'A': 5,
  'B': 6,
};

const int _middleLineIndex = 4 * 7 + 6; // B4

/// Diatonic step index for [noteName] (e.g. 'C4', 'F#5', 'Bb3'), counting
/// letter-steps only (accidentals don't change vertical staff position).
int _diatonicIndex(String noteName) {
  if (noteName.isEmpty) return _middleLineIndex;
  final letter = noteName[0].toUpperCase();
  final octaveMatch = RegExp(r'-?\d+$').firstMatch(noteName);
  final octave = octaveMatch != null ? int.parse(octaveMatch.group(0)!) : 4;
  final letterIndex = _letterOrder[letter] ?? _letterOrder['B']!;
  return octave * 7 + letterIndex;
}

/// Signed diatonic distance from the middle line (B4). Positive = higher
/// pitch (drawn above the middle line), negative = lower pitch (below it).
int _diffFromMiddle(String noteName) =>
    _diatonicIndex(noteName) - _middleLineIndex;

/// Y coordinate (in the painter's local space) for [noteName], where
/// [centerLineY] is the Y of the staff's middle line and [spacing] is the
/// distance between adjacent staff lines.
double noteY(String noteName, double centerLineY, double spacing) {
  final diff = _diffFromMiddle(noteName);
  return centerLineY - diff * 0.5 * spacing;
}

/// Standard notation convention: notes below the middle line (B4) get stems
/// pointing up; notes on or above the middle line get stems pointing down.
bool stemsUp(String noteName) => _diffFromMiddle(noteName) < 0;

/// How many ledger lines are needed above/below the staff for [noteName].
/// Returns 0 for any pitch that fits within the 5 staff lines (F5 down to E4).
int ledgerLinesNeeded(String noteName) {
  final steps = _diffFromMiddle(noteName).abs();
  if (steps <= 4) return 0;
  return (steps - 3) ~/ 2;
}

/// True if [noteName]'s ledger lines (if any) are drawn above the staff;
/// false if they're drawn below.
bool isLedgerAbove(String noteName) => _diffFromMiddle(noteName) > 4;

double measureWidth(String timeSignature) {
  switch (timeSignature) {
    case '2/4':
      return 140.0;
    case '3/4':
      return 180.0;
    case '6/8':
      return 200.0;
    case '4/4':
    default:
      return 240.0;
  }
}

double targetBeats(String timeSignature) {
  switch (timeSignature) {
    case '2/4':
      return 2.0;
    case '3/4':
    case '6/8':
      return 3.0;
    case '4/4':
    default:
      return 4.0;
  }
}

/// Packs a flat, ordered sequence of [RhythmElement]s into [RhythmMeasure]s
/// sized by [timeSignature]. Never splits an element — if the next element
/// would overflow the current measure's remaining capacity, it starts a new
/// measure instead. Used both to auto-continue into a new measure as notes
/// are added in Composer Mode, and to re-chunk an existing composition
/// whenever its time signature changes — always the single source of truth
/// for how a flat note sequence turns into measures.
List<RhythmMeasure> reflowMeasures(
  List<RhythmElement> flat,
  String timeSignature,
) {
  final double capacity = targetBeats(timeSignature);
  final measures = <RhythmMeasure>[];

  List<RhythmElement> current = [];
  double elapsed = 0.0;

  for (final element in flat) {
    if (current.isNotEmpty && elapsed + element.duration > capacity) {
      measures.add(RhythmMeasure(elements: current, timeSignature: timeSignature));
      current = [];
      elapsed = 0.0;
    }
    current.add(element);
    elapsed += element.duration;
  }

  if (current.isNotEmpty) {
    measures.add(RhythmMeasure(elements: current, timeSignature: timeSignature));
  }

  return measures;
}

/// A contiguous run of measures that fits on one staff system (one row).
class SystemBreak {
  final int start;
  final int count;

  const SystemBreak({required this.start, required this.count});
}

/// Splits [measures] into staff systems no wider than [maxWidth], wrapping
/// onto additional rows like professional notation software. Greedy: each
/// system takes as many whole measures as fit (always at least one, so a
/// narrow screen can never produce an infinite loop). Pure geometry — used
/// by both the on-screen wrapped staff view and the PDF exporter, so screen
/// and paper can never disagree about where lines break.
List<SystemBreak> computeSystemBreaks(
  List<RhythmMeasure> measures,
  double maxWidth,
) {
  const double leading = staffLeadingX + staffClefWidth + staffTimeSigWidth;
  final breaks = <SystemBreak>[];

  int start = 0;
  while (start < measures.length) {
    double width = leading;
    int count = 0;
    while (start + count < measures.length) {
      final double next =
          measureWidth(measures[start + count].timeSignature) + staffMeasureGap;
      if (count > 0 && width + next > maxWidth) break;
      width += next;
      count++;
    }
    breaks.add(SystemBreak(start: start, count: count));
    start += count;
  }

  return breaks;
}

/// Inverse of [noteY]: the nearest natural note name for a Y coordinate.
/// Only ever returns natural (unaccidented) notes, matching the fact that
/// vertical staff position never encodes accidentals in this codebase.
String noteNameFromY(double y, double centerLineY, double spacing) {
  final int diff = ((centerLineY - y) * 2 / spacing).round();
  final int index = _middleLineIndex + diff;
  final int octave = (index / 7).floor();
  final int letterIndex = index - octave * 7;
  final String letter =
      _letterOrder.entries.firstWhere((e) => e.value == letterIndex).key;
  return '$letter$octave';
}

/// The on-screen X position of a single element within a measure, and each
/// measure's horizontal extent — the exact math [MusicStaffPainter] draws
/// with, extracted so hit-testing (Composer Mode's tap-to-place/select) can
/// never diverge from what's actually drawn.
class ElementPosition {
  final int measureIndex;
  final int elementIndex;
  final double x;

  const ElementPosition({
    required this.measureIndex,
    required this.elementIndex,
    required this.x,
  });
}

class MeasureLayout {
  final int measureIndex;
  final double startX;
  final double endX;
  final List<ElementPosition> elements;

  const MeasureLayout({
    required this.measureIndex,
    required this.startX,
    required this.endX,
    required this.elements,
  });
}

const double staffLeadingX = 20.0;
const double staffClefWidth = 45.0;
const double staffTimeSigWidth = 35.0;
const double staffMeasureGap = 10.0;

/// Computes the X position of every element across [measures], plus each
/// measure's start/end X. Used by both [MusicStaffPainter] (drawing) and any
/// interactive staff (hit-testing), so the two can never disagree.
List<MeasureLayout> computeLayout(List<RhythmMeasure> measures) {
  final layouts = <MeasureLayout>[];
  if (measures.isEmpty) return layouts;

  double currentX = staffLeadingX + staffClefWidth + staffTimeSigWidth;

  for (int m = 0; m < measures.length; m++) {
    final measure = measures[m];
    final double width = measureWidth(measure.timeSignature);
    final double endX = currentX + width;
    final double beatsPerMeasure = targetBeats(measure.timeSignature);

    double elapsedBeats = 0.0;
    final elements = <ElementPosition>[];
    for (int e = 0; e < measure.elements.length; e++) {
      final element = measure.elements[e];
      final double elementX =
          currentX + (elapsedBeats / beatsPerMeasure) * (width - 30.0) + 15.0;
      elements.add(
        ElementPosition(measureIndex: m, elementIndex: e, x: elementX),
      );
      elapsedBeats += element.duration;
    }

    layouts.add(
      MeasureLayout(
        measureIndex: m,
        startX: currentX,
        endX: endX,
        elements: elements,
      ),
    );
    currentX = endX + staffMeasureGap;
  }

  return layouts;
}
