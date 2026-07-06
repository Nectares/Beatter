/// Pure, canvas-free geometry helpers shared by [MusicStaffPainter] (and any
/// future hit-testing/drag layer, e.g. Composer Mode's note placement).
///
/// All positions are expressed relative to a treble clef, 5-line staff whose
/// middle line is B4.

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
    case '3/4':
    case '6/8':
      return 3.0;
    case '4/4':
    default:
      return 4.0;
  }
}
