import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/rhythm_element.dart';
import 'staff_geometry.dart' as geometry;

/// Draws a real 5-line treble-clef staff with note heads, stems, flags,
/// rests, ledger lines and triplets for a list of [RhythmMeasure]s.
///
/// Migrated from the former `RhythmStaffPainter` (which only ever rendered
/// to an unreachable page) into a shared location so both Sheet Mode and,
/// later, Composer Mode can use it.
class MusicStaffPainter extends CustomPainter {
  final List<RhythmMeasure> measures;
  final int activeMeasureIndex;
  final int activeElementIndex;
  final int? activeTripletIndex;

  static const double lineSpacing = geometry.lineSpacing;
  static const double noteWidth = geometry.noteWidth;
  static const double noteHeight = geometry.noteHeight;

  MusicStaffPainter({
    required this.measures,
    required this.activeMeasureIndex,
    required this.activeElementIndex,
    this.activeTripletIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;

    final linePaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final barPaint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Five staff lines.
    for (int i = -2; i <= 2; i++) {
      final y = midY + i * lineSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (measures.isEmpty) return;

    _drawTrebleClef(canvas, geometry.staffLeadingX, midY, lineSpacing);

    final String timeSig = measures.first.timeSignature;
    _drawTimeSignature(
      canvas,
      geometry.staffLeadingX + geometry.staffClefWidth,
      midY,
      timeSig,
    );

    final layout = geometry.computeLayout(measures);

    for (final measureLayout in layout) {
      final measure = measures[measureLayout.measureIndex];

      for (final position in measureLayout.elements) {
        final element = measure.elements[position.elementIndex];
        final bool isActive = (position.measureIndex == activeMeasureIndex &&
            position.elementIndex == activeElementIndex);

        _drawRhythmElement(
          canvas: canvas,
          element: element,
          x: position.x,
          midY: midY,
          spacing: lineSpacing,
          isActive: isActive,
          activeTripletIndex: activeTripletIndex,
        );
      }

      canvas.drawLine(
        Offset(measureLayout.endX, midY - 2 * lineSpacing),
        Offset(measureLayout.endX, midY + 2 * lineSpacing),
        barPaint,
      );
    }
  }

  void _drawTrebleClef(Canvas canvas, double x, double y, double s) {
    final clefPaint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    path.moveTo(x + 10, y + 2.5 * s);
    path.cubicTo(x + 18, y + 2.5 * s, x + 22, y + 1.5 * s, x + 22, y + 0.8 * s);
    path.cubicTo(x + 22, y + 0.1 * s, x + 15, y - 0.4 * s, x + 8, y + 0.2 * s);
    path.cubicTo(x + 2, y + 0.8 * s, x + 5, y + 1.6 * s, x + 12, y + 1.6 * s);
    path.cubicTo(x + 18, y + 1.6 * s, x + 20, y + 1.0 * s, x + 14, y + 0.6 * s);

    path.moveTo(x + 8, y + 0.2 * s);
    path.cubicTo(x - 5, y - 1.0 * s, x + 5, y - 3.2 * s, x + 12, y - 3.8 * s);
    path.cubicTo(x + 15, y - 4.1 * s, x + 18, y - 4.0 * s, x + 16, y - 3.2 * s);

    path.lineTo(x + 12, y + 3.2 * s);
    path.cubicTo(x + 10, y + 3.8 * s, x + 4, y + 4.0 * s, x + 2, y + 3.6 * s);

    canvas.drawPath(path, clefPaint);
  }

  void _drawTimeSignature(Canvas canvas, double x, double y, String timeSig) {
    String topNum = '4';
    String bottomNum = '4';
    if (timeSig == '2/4') {
      topNum = '2';
      bottomNum = '4';
    } else if (timeSig == '3/4') {
      topNum = '3';
      bottomNum = '4';
    } else if (timeSig == '6/8') {
      topNum = '6';
      bottomNum = '8';
    }

    final textStyle = const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      fontFamily: 'serif',
      height: 0.9,
    );

    final topPainter = TextPainter(
      text: TextSpan(text: topNum, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    topPainter.paint(canvas, Offset(x, y - 2.0 * lineSpacing - 2));

    final bottomPainter = TextPainter(
      text: TextSpan(text: bottomNum, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    bottomPainter.paint(canvas, Offset(x, y));
  }

  void _drawRhythmElement({
    required Canvas canvas,
    required RhythmElement element,
    required double x,
    required double midY,
    required double spacing,
    required bool isActive,
    int? activeTripletIndex,
  }) {
    final notePaint = Paint()
      ..color = isActive ? AppColors.primary : AppColors.textPrimary
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = isActive ? AppColors.primary : AppColors.textPrimary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final restPaint = Paint()
      ..color = isActive ? AppColors.tertiary : AppColors.textSecondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (isActive) {
      final glowPaint = Paint()
        ..color = (element.isRest ? AppColors.tertiary : AppColors.primary)
            .withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, midY), 22, glowPaint);
    }

    switch (element.type) {
      case RhythmElementType.whole:
        {
          final y = geometry.noteY(element.noteName, midY, spacing);
          _drawLedgerLines(canvas, x, element.noteName, midY, spacing);
          _drawNoteHead(canvas, x, y, notePaint, hollow: true);
        }
        break;

      case RhythmElementType.half:
        {
          final y = geometry.noteY(element.noteName, midY, spacing);
          final up = geometry.stemsUp(element.noteName);
          _drawLedgerLines(canvas, x, element.noteName, midY, spacing);
          _drawNoteHead(canvas, x, y, notePaint, hollow: true);
          _drawStem(canvas, x, y, spacing, up, stemPaint);
        }
        break;

      case RhythmElementType.quarter:
        {
          final y = geometry.noteY(element.noteName, midY, spacing);
          final up = geometry.stemsUp(element.noteName);
          _drawLedgerLines(canvas, x, element.noteName, midY, spacing);
          _drawNoteHead(canvas, x, y, notePaint);
          _drawStem(canvas, x, y, spacing, up, stemPaint);
        }
        break;

      case RhythmElementType.eighth:
        {
          final y = geometry.noteY(element.noteName, midY, spacing);
          final up = geometry.stemsUp(element.noteName);
          _drawLedgerLines(canvas, x, element.noteName, midY, spacing);
          _drawNoteHead(canvas, x, y, notePaint);
          final stemEnd = _drawStem(canvas, x, y, spacing, up, stemPaint);
          _drawFlag(canvas, x, stemEnd, up, 1, stemPaint);
        }
        break;

      case RhythmElementType.sixteenth:
        {
          final y = geometry.noteY(element.noteName, midY, spacing);
          final up = geometry.stemsUp(element.noteName);
          _drawLedgerLines(canvas, x, element.noteName, midY, spacing);
          _drawNoteHead(canvas, x, y, notePaint);
          final stemEnd = _drawStem(canvas, x, y, spacing, up, stemPaint);
          _drawFlag(canvas, x, stemEnd, up, 2, stemPaint);
        }
        break;

      case RhythmElementType.quarterRest:
        _drawQuarterRest(canvas, x, midY, spacing, restPaint);
        break;

      case RhythmElementType.eighthRest:
        _drawEighthRest(canvas, x, midY, spacing, 1, restPaint);
        break;

      case RhythmElementType.sixteenthRest:
        _drawEighthRest(canvas, x, midY, spacing, 2, restPaint);
        break;

      case RhythmElementType.triplet:
        _drawTriplet(canvas, x, midY, spacing, element.tripletNotes, isActive,
            activeTripletIndex);
        break;
    }
  }

  /// Draws short horizontal ledger-line strokes above/below the staff for
  /// notes outside its 5 lines (e.g. middle C below, or a high G above).
  void _drawLedgerLines(
      Canvas canvas, double x, String noteName, double midY, double spacing) {
    final count = geometry.ledgerLinesNeeded(noteName);
    if (count == 0) return;

    final ledgerPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;

    final above = geometry.isLedgerAbove(noteName);
    final double edge = above ? midY - 2 * spacing : midY + 2 * spacing;
    final double step = above ? -spacing : spacing;

    for (int i = 1; i <= count; i++) {
      final y = edge + step * i;
      canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), ledgerPaint);
    }
  }

  void _drawNoteHead(Canvas canvas, double x, double y, Paint paint, {bool hollow = false}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-20 * math.pi / 180);
    final headPaint = hollow
        ? (Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5)
        : paint;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: noteWidth, height: noteHeight),
      headPaint,
    );
    canvas.restore();
  }

  Offset _drawStem(
      Canvas canvas, double x, double y, double spacing, bool isUp, Paint paint) {
    final double stemLen = spacing * 3.0;
    final double stemX = isUp ? x + noteWidth / 2 - 1 : x - noteWidth / 2 + 1;
    final double stemYEnd = isUp ? y - stemLen : y + stemLen;

    canvas.drawLine(Offset(stemX, y), Offset(stemX, stemYEnd), paint);

    return Offset(stemX, stemYEnd);
  }

  void _drawFlag(
      Canvas canvas, double x, Offset stemEnd, bool isUp, int flagsCount, Paint paint) {
    final flagPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(stemEnd.dx, stemEnd.dy);

    for (int i = 0; i < flagsCount; i++) {
      final double yOffset = i * 4.5 * (isUp ? 1 : -1);
      final path = Path();

      if (isUp) {
        path.moveTo(0, yOffset);
        path.cubicTo(4, yOffset + 5, 10, yOffset + 10, 8, yOffset + 18);
        path.cubicTo(8, yOffset + 12, 4, yOffset + 8, 0, yOffset + 6);
      } else {
        path.moveTo(0, yOffset);
        path.cubicTo(4, yOffset - 5, 10, yOffset - 10, 8, yOffset - 18);
        path.cubicTo(8, yOffset - 12, 4, yOffset - 8, 0, yOffset - 6);
      }

      canvas.drawPath(path, flagPaint);
    }

    canvas.restore();
  }

  void _drawQuarterRest(Canvas canvas, double x, double y, double s, Paint paint) {
    final path = Path();
    path.moveTo(x - 3, y - 1.2 * s);
    path.lineTo(x + 4, y - 0.5 * s);
    path.lineTo(x - 4, y + 0.2 * s);
    path.lineTo(x + 4, y + 0.9 * s);
    path.quadraticBezierTo(x, y + 1.6 * s, x - 5, y + 1.2 * s);

    canvas.drawPath(path, paint);
  }

  void _drawEighthRest(
      Canvas canvas, double x, double y, double s, int restsCount, Paint paint) {
    final restPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < restsCount; i++) {
      final double yOffset = i * 0.8 * s - 0.2 * s;

      final double startY = y - 0.7 * s + yOffset;
      final double endY = y + 0.8 * s + yOffset;

      canvas.drawLine(Offset(x + 3, startY), Offset(x - 3, endY), paint);

      canvas.drawCircle(Offset(x - 1, startY + 3), 2.5, restPaint);

      final hookPath = Path()
        ..moveTo(x - 1, startY + 3)
        ..quadraticBezierTo(x - 5, startY + 1, x - 4, startY - 2)
        ..quadraticBezierTo(x - 2, startY, x + 3, startY);

      canvas.drawPath(hookPath, paint);
    }
  }

  void _drawTriplet(
    Canvas canvas,
    double startX,
    double midY,
    double spacing,
    List<String> notes,
    bool isActive,
    int? activeTripletIndex,
  ) {
    final double x0 = startX - 16;
    final double x1 = startX;
    final double x2 = startX + 16;

    final double y0 = geometry.noteY(notes[0], midY, spacing);
    final double y1 = geometry.noteY(notes[1], midY, spacing);
    final double y2 = geometry.noteY(notes[2], midY, spacing);

    final double stemLen = spacing * 2.8;

    final double sy0 = y0 - stemLen;
    final double sy1 = y1 - stemLen;
    final double sy2 = y2 - stemLen;

    for (int i = 0; i < 3; i++) {
      final double noteX = (i == 0) ? x0 : ((i == 1) ? x1 : x2);
      final double noteY = (i == 0) ? y0 : ((i == 1) ? y1 : y2);
      final bool isThisNoteActive = isActive && activeTripletIndex == i;

      final notePaint = Paint()
        ..color = isThisNoteActive ? AppColors.primary : AppColors.textPrimary
        ..style = PaintingStyle.fill;

      final stemPaint = Paint()
        ..color = isThisNoteActive
            ? AppColors.primary
            : (isActive ? AppColors.primary.withValues(alpha: 0.5) : AppColors.textPrimary)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;

      _drawNoteHead(canvas, noteX, noteY, notePaint);

      canvas.drawLine(
        Offset(noteX + noteWidth / 2 - 1, noteY),
        Offset(noteX + noteWidth / 2 - 1, noteY - stemLen),
        stemPaint,
      );
    }

    final beamPaint = Paint()
      ..color = isActive ? AppColors.primary : AppColors.textPrimary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(x0 + noteWidth / 2 - 1, sy0),
      Offset(x2 + noteWidth / 2 - 1, sy2),
      beamPaint,
    );

    final bracketPaint = Paint()
      ..color = isActive ? AppColors.primary : AppColors.textSecondary
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double bracketY = math.min(math.min(sy0, sy1), sy2) - 8.0;

    canvas.drawLine(Offset(x0 - 4, bracketY), Offset(x2 + 8, bracketY), bracketPaint);
    canvas.drawLine(Offset(x0 - 4, bracketY), Offset(x0 - 4, bracketY + 4), bracketPaint);
    canvas.drawLine(Offset(x2 + 8, bracketY), Offset(x2 + 8, bracketY + 4), bracketPaint);

    final textStyle = TextStyle(
      color: isActive ? AppColors.primary : AppColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: '3', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Matches the actual staff-card surface behind the canvas — this box
    // exists to blot out the beam/bracket lines passing behind the "3", not
    // to stand out as its own chip, so it must blend with the real
    // background rather than the off-palette dark navy it used to be
    // (which also left the text nearly illegible against it).
    final bgPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(startX + noteWidth / 2 - 1, bracketY),
        width: 10.0,
        height: 10.0,
      ),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(
        startX + noteWidth / 2 - 1 - textPainter.width / 2,
        bracketY - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant MusicStaffPainter oldDelegate) {
    return oldDelegate.activeMeasureIndex != activeMeasureIndex ||
        oldDelegate.activeElementIndex != activeElementIndex ||
        oldDelegate.activeTripletIndex != activeTripletIndex ||
        oldDelegate.measures != measures;
  }
}
