import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data class for a beaming group (consecutive beamable notes in one beat group)
// ─────────────────────────────────────────────────────────────────────────────
class _BeamGroup {
  final List<int> elementIndices; // indices into measure.elements
  final List<double> xPositions;  // computed X for each note head
  final RhythmElementType beamType; // eighth or sixteenth

  _BeamGroup({
    required this.elementIndices,
    required this.xPositions,
    required this.beamType,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RhythmLinePainter – single-line rhythmic notation renderer
// Style: solfeggio rhythm book (one horizontal line, notes anchored to it)
// ─────────────────────────────────────────────────────────────────────────────
class RhythmLinePainter extends CustomPainter {
  final List<RhythmMeasure> measures;
  final int activeMeasureIndex;
  final int activeElementIndex;
  final int? activeTripletIndex;
  final double highlightScale; // animated scale for active note (1.0–1.18)
  final double noteScale;      // responsive scale factor (portrait/landscape/tablet)

  // ── Layout constants (at noteScale = 1.0) ──
  static const double _baseNoteRadius = 6.5;
  static const double _stemLen        = 32.0;
  static const double _beamThickness  = 4.0;
  static const double _beamGap        = 5.5;  // gap between double beams
  static const double _beatUnit       = 52.0; // px per quarter note at scale 1.0
  static const double _measurePad     = 18.0; // left+right padding inside measure
  static const double _barLineWidth   = 1.8;

  RhythmLinePainter({
    required this.measures,
    required this.activeMeasureIndex,
    required this.activeElementIndex,
    this.activeTripletIndex,
    this.highlightScale = 1.0,
    this.noteScale = 1.0,
  });

  // ─── Computed helpers ───────────────────────────────────────────────────────
  double get _nr   => _baseNoteRadius * noteScale;
  double get _sl   => _stemLen * noteScale;
  double get _bu   => _beatUnit * noteScale;
  double get _mpad => _measurePad * noteScale;

  /// Total canvas width needed to render all measures
  static double computeTotalWidth(
    List<RhythmMeasure> measures,
    double noteScale,
  ) {
    if (measures.isEmpty) return 200;
    double totalBeats = 0;
    for (final m in measures) {
      totalBeats += _beatsInMeasure(m.timeSignature);
    }
    // Extra space: initial left margin + barlines + right end
    return 24 * noteScale +
        totalBeats * _beatUnit * noteScale +
        measures.length * (_measurePad * 2 * noteScale) +
        16 * noteScale;
  }

  static double _beatsInMeasure(String sig) {
    if (sig == '3/4') return 3.0;
    if (sig == '6/8') return 3.0;
    return 4.0; // 4/4 default
  }

  /// Width of a single measure in pixels
  double _measureWidth(String sig) {
    return _beatsInMeasure(sig) * _bu + _mpad * 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (measures.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final double midY = size.height / 2;

    // ── 1. Draw the single central horizontal line ─────────────────────────
    final linePaint = Paint()
      ..color = AppTheme.textSecondary.withOpacity(0.45)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);

    // ── 2. Time signature at the very start ──────────────────────────────
    double currentX = 16.0 * noteScale;
    _drawTimeSignature(canvas, currentX, midY, measures.first.timeSignature);
    currentX += 30.0 * noteScale;

    // ── 3. Render each measure ────────────────────────────────────────────
    for (int m = 0; m < measures.length; m++) {
      final measure = measures[m];
      final double mw = _measureWidth(measure.timeSignature);
      final double contentWidth = mw - _mpad * 2;
      final double measureStartX = currentX;
      final double totalBeats = _beatsInMeasure(measure.timeSignature);

      // Pre-compute X positions for all elements in this measure
      final List<double> xPositions = [];
      double elapsedBeats = 0;
      for (final el in measure.elements) {
        final double noteX = measureStartX + _mpad +
            (elapsedBeats / totalBeats) * contentWidth;
        xPositions.add(noteX);
        elapsedBeats += el.duration;
      }

      // Build beam groups for this measure
      final beamGroups = _buildBeamGroups(measure.elements, xPositions);
      final beamedIndices = <int>{};
      for (final g in beamGroups) {
        beamedIndices.addAll(g.elementIndices);
      }

      // Draw individual (non-beamed) elements first, then beams on top
      for (int e = 0; e < measure.elements.length; e++) {
        final element = measure.elements[e];
        final bool isActive = (m == activeMeasureIndex && e == activeElementIndex);
        final double x = xPositions[e];

        if (element.type == RhythmElementType.triplet) {
          _drawTriplet(canvas, x, midY, element.tripletNotes, isActive, activeTripletIndex);
        } else if (beamedIndices.contains(e)) {
          // Draw note head + stem only (beam drawn separately below)
          _drawNoteHeadAndStem(canvas, x, midY, element.type, isActive, drawFlag: false);
        } else {
          _drawElement(canvas, x, midY, element, isActive);
        }
      }

      // Draw beam groups
      for (final group in beamGroups) {
        _drawBeamGroup(canvas, midY, group, m, activeMeasureIndex, activeElementIndex);
      }

      // ── Bar line at end of measure ──────────────────────────────────────
      final barX = measureStartX + mw;
      final barPaint = Paint()
        ..color = AppTheme.textSecondary.withOpacity(0.6)
        ..strokeWidth = _barLineWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(barX, midY - _sl * 0.55),
        Offset(barX, midY + _sl * 0.12),
        barPaint,
      );

      currentX += mw;
    }

    // ── 4. Final double barline ──────────────────────────────────────────
    _drawFinalBarline(canvas, currentX, midY);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Beam group builder
  // ─────────────────────────────────────────────────────────────────────────
  List<_BeamGroup> _buildBeamGroups(
    List<RhythmElement> elements,
    List<double> xPositions,
  ) {
    final groups = <_BeamGroup>[];
    int i = 0;
    while (i < elements.length) {
      final el = elements[i];
      final isBeamable = (el.type == RhythmElementType.eighth ||
          el.type == RhythmElementType.sixteenth) &&
          !el.isRest;

      if (!isBeamable) {
        i++;
        continue;
      }

      // Collect consecutive beamable notes of the same or compatible type
      final groupIndices = <int>[i];
      final groupX = <double>[xPositions[i]];
      final groupType = el.type;
      int j = i + 1;

      while (j < elements.length) {
        final next = elements[j];
        final nextBeamable = (next.type == RhythmElementType.eighth ||
            next.type == RhythmElementType.sixteenth) &&
            !next.isRest;
        if (!nextBeamable) break;
        groupIndices.add(j);
        groupX.add(xPositions[j]);
        j++;
      }

      if (groupIndices.length >= 2) {
        // Use the type of the fastest note in the group for beam count
        RhythmElementType beamType = groupType;
        for (final idx in groupIndices) {
          if (elements[idx].type == RhythmElementType.sixteenth) {
            beamType = RhythmElementType.sixteenth;
            break;
          }
        }
        groups.add(_BeamGroup(
          elementIndices: groupIndices,
          xPositions: groupX,
          beamType: beamType,
        ));
        i = j;
      } else {
        // Single note, skip (will be drawn with individual flag)
        i++;
      }
    }
    return groups;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Draw a beam group (shared beam over multiple notes)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawBeamGroup(
    Canvas canvas,
    double midY,
    _BeamGroup group,
    int measureIndex,
    int activeMeasure,
    int activeElement,
  ) {
    final bool groupActive = (measureIndex == activeMeasure &&
        group.elementIndices.contains(activeElement));
    final Color beamColor = groupActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;

    final double stemTopY = midY - _sl;
    final int beamCount = (group.beamType == RhythmElementType.sixteenth) ? 2 : 1;

    // Stem X for each note (right side of note head)
    final List<double> stemXs = group.xPositions.map((x) => x + _nr - 1).toList();

    final beamPaint = Paint()
      ..color = beamColor
      ..strokeWidth = _beamThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Draw stems first
    final stemPaint = Paint()
      ..color = beamColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < group.elementIndices.length; i++) {
      final sx = stemXs[i];
      canvas.drawLine(Offset(sx, midY - _nr * 0.6), Offset(sx, stemTopY), stemPaint);
    }

    // Draw beam(s)
    for (int b = 0; b < beamCount; b++) {
      final double beamY = stemTopY + b * (_beamThickness + _beamGap) * noteScale;
      canvas.drawLine(
        Offset(stemXs.first, beamY),
        Offset(stemXs.last, beamY),
        beamPaint,
      );
    }

    // For mixed groups: add secondary beam only over sixteenth notes
    if (group.beamType == RhythmElementType.sixteenth && beamCount == 2) {
      // Already drawn 2 beams above for the whole group — done.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Draw a single rhythmic element (non-beamed)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawElement(
    Canvas canvas,
    double x,
    double midY,
    RhythmElement element,
    bool isActive,
  ) {
    // Glow effect for active note
    if (isActive && !element.isRest) {
      _drawGlow(canvas, x, midY, AppTheme.secondaryCyan);
    }
    if (isActive && element.isRest) {
      _drawGlow(canvas, x, midY, AppTheme.accentPink);
    }

    switch (element.type) {
      case RhythmElementType.quarter:
        _drawQuarterNote(canvas, x, midY, isActive);
        break;
      case RhythmElementType.eighth:
        _drawEighthNote(canvas, x, midY, isActive, drawFlag: true);
        break;
      case RhythmElementType.sixteenth:
        _drawSixteenthNote(canvas, x, midY, isActive, drawFlag: true);
        break;
      case RhythmElementType.quarterRest:
        _drawQuarterRest(canvas, x, midY, isActive);
        break;
      case RhythmElementType.eighthRest:
        _drawEighthRestSymbol(canvas, x, midY, isActive, 1);
        break;
      case RhythmElementType.sixteenthRest:
        _drawEighthRestSymbol(canvas, x, midY, isActive, 2);
        break;
      case RhythmElementType.triplet:
        // handled separately
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Draw note head + stem (for beamed notes – no flag)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawNoteHeadAndStem(
    Canvas canvas,
    double x,
    double midY,
    RhythmElementType type,
    bool isActive, {
    required bool drawFlag,
  }) {
    final color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;
    if (isActive) _drawGlow(canvas, x, midY, color);
    _drawFilledNoteHead(canvas, x, midY, color);
    // Stem
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final stemX = x + _nr - 1;
    canvas.drawLine(
      Offset(stemX, midY - _nr * 0.6),
      Offset(stemX, midY - _sl),
      stemPaint,
    );
    if (drawFlag) {
      if (type == RhythmElementType.eighth) {
        _drawFlag(canvas, stemX, midY - _sl, 1, color);
      } else if (type == RhythmElementType.sixteenth) {
        _drawFlag(canvas, stemX, midY - _sl, 2, color);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Individual note drawers
  // ─────────────────────────────────────────────────────────────────────────

  void _drawQuarterNote(Canvas canvas, double x, double midY, bool isActive) {
    final color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;
    _drawFilledNoteHead(canvas, x, midY, color);
    // Stem up
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final stemX = x + _nr - 1;
    canvas.drawLine(
      Offset(stemX, midY - _nr * 0.6),
      Offset(stemX, midY - _sl),
      stemPaint,
    );
  }

  void _drawEighthNote(
    Canvas canvas,
    double x,
    double midY,
    bool isActive, {
    required bool drawFlag,
  }) {
    final color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;
    _drawFilledNoteHead(canvas, x, midY, color);
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final stemX = x + _nr - 1;
    final stemTop = midY - _sl;
    canvas.drawLine(Offset(stemX, midY - _nr * 0.6), Offset(stemX, stemTop), stemPaint);
    if (drawFlag) _drawFlag(canvas, stemX, stemTop, 1, color);
  }

  void _drawSixteenthNote(
    Canvas canvas,
    double x,
    double midY,
    bool isActive, {
    required bool drawFlag,
  }) {
    final color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;
    _drawFilledNoteHead(canvas, x, midY, color);
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final stemX = x + _nr - 1;
    final stemTop = midY - _sl;
    canvas.drawLine(Offset(stemX, midY - _nr * 0.6), Offset(stemX, stemTop), stemPaint);
    if (drawFlag) _drawFlag(canvas, stemX, stemTop, 2, color);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Note head (filled oval, slightly tilted like solfeggio books)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawFilledNoteHead(Canvas canvas, double x, double midY, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(x, midY);
    canvas.rotate(-18 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _nr * 2.0,
        height: _nr * 1.32,
      ),
      paint,
    );
    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Flag (for isolated 8th / 16th notes)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawFlag(Canvas canvas, double stemX, double stemTop, int count, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final yOff = i * 7.0 * noteScale;
      final path = Path();
      path.moveTo(stemX, stemTop + yOff);
      path.cubicTo(
        stemX + 10 * noteScale, stemTop + yOff + 6 * noteScale,
        stemX + 14 * noteScale, stemTop + yOff + 12 * noteScale,
        stemX + 10 * noteScale, stemTop + yOff + 20 * noteScale,
      );
      path.cubicTo(
        stemX + 10 * noteScale, stemTop + yOff + 14 * noteScale,
        stemX + 5 * noteScale,  stemTop + yOff + 9 * noteScale,
        stemX,                  stemTop + yOff + 6 * noteScale,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Quarter rest (classic zigzag)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawQuarterRest(Canvas canvas, double x, double midY, bool isActive) {
    final color = isActive ? AppTheme.accentPink : AppTheme.textSecondary;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * noteScale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final s = noteScale;
    final path = Path();
    path.moveTo(x - 4 * s, midY - 14 * s);
    path.lineTo(x + 5 * s, midY - 7 * s);
    path.lineTo(x - 5 * s, midY);
    path.lineTo(x + 5 * s, midY + 7 * s);
    path.quadraticBezierTo(x + 1 * s, midY + 15 * s, x - 6 * s, midY + 11 * s);

    canvas.drawPath(path, paint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Eighth / Sixteenth rest
  // ─────────────────────────────────────────────────────────────────────────
  void _drawEighthRestSymbol(
    Canvas canvas,
    double x,
    double midY,
    bool isActive,
    int count,
  ) {
    final color = isActive ? AppTheme.accentPink : AppTheme.textSecondary;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 * noteScale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final double yOff = i * 9.0 * noteScale - (count - 1) * 4.5 * noteScale;
      final double startY = midY - 8 * noteScale + yOff;
      final double endY   = midY + 8 * noteScale + yOff;

      // Diagonal stroke
      canvas.drawLine(
        Offset(x + 3 * noteScale,  startY),
        Offset(x - 4 * noteScale,  endY),
        strokePaint,
      );
      // Dot
      canvas.drawCircle(Offset(x - 1 * noteScale, startY + 3 * noteScale), 2.8 * noteScale, fillPaint);
      // Hook
      final hook = Path()
        ..moveTo(x - 1 * noteScale, startY + 3 * noteScale)
        ..quadraticBezierTo(
          x - 6 * noteScale, startY + 1 * noteScale,
          x - 5 * noteScale, startY - 3 * noteScale,
        )
        ..quadraticBezierTo(
          x - 2 * noteScale, startY,
          x + 3 * noteScale, startY,
        );
      canvas.drawPath(hook, strokePaint);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Triplet (3 eighth notes beamed + bracket + "3")
  // ─────────────────────────────────────────────────────────────────────────
  void _drawTriplet(
    Canvas canvas,
    double centerX,
    double midY,
    List<String> notes,
    bool isActive,
    int? activeTripletIndex,
  ) {
    // Triplet total width = 2 eighth-note spacings
    final double spread = _bu * 0.5;
    final double x0 = centerX - spread;
    final double x1 = centerX;
    final double x2 = centerX + spread;
    final List<double> xs = [x0, x1, x2];
    final double stemTopY = midY - _sl;

    // Draw 3 note heads + stems
    for (int i = 0; i < 3; i++) {
      final bool noteActive = isActive && activeTripletIndex == i;
      final color = noteActive
          ? AppTheme.secondaryCyan
          : (isActive ? AppTheme.secondaryCyan.withOpacity(0.6) : AppTheme.textPrimary);

      if (noteActive) _drawGlow(canvas, xs[i], midY, AppTheme.secondaryCyan);

      _drawFilledNoteHead(canvas, xs[i], midY, color);

      final stemPaint = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final sx = xs[i] + _nr - 1;
      canvas.drawLine(Offset(sx, midY - _nr * 0.6), Offset(sx, stemTopY), stemPaint);
    }

    // Beam over all three
    final beamColor = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary;
    final beamPaint = Paint()
      ..color = beamColor
      ..strokeWidth = _beamThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final double bx0 = x0 + _nr - 1;
    final double bx2 = x2 + _nr - 1;
    canvas.drawLine(Offset(bx0, stemTopY), Offset(bx2, stemTopY), beamPaint);

    // Triplet bracket above beam
    final bracketColor = isActive ? AppTheme.secondaryCyan : AppTheme.textSecondary;
    final bracketPaint = Paint()
      ..color = bracketColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double bY = stemTopY - 10 * noteScale;
    final double bLeft  = bx0 - 3 * noteScale;
    final double bRight = bx2 + 3 * noteScale;

    // Horizontal bracket bar
    canvas.drawLine(Offset(bLeft, bY), Offset(bRight, bY), bracketPaint);
    // Left tick
    canvas.drawLine(Offset(bLeft, bY), Offset(bLeft, bY + 4 * noteScale), bracketPaint);
    // Right tick
    canvas.drawLine(Offset(bRight, bY), Offset(bRight, bY + 4 * noteScale), bracketPaint);

    // Number "3" centered
    final ts = TextStyle(
      color: bracketColor,
      fontSize: 10 * noteScale,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final tp = TextPainter(
      text: TextSpan(text: '3', style: ts),
      textDirection: TextDirection.ltr,
    )..layout();

    // Small background to break the bracket line
    final bgPaint = Paint()
      ..color = const Color(0xFF0B0D17)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset((bLeft + bRight) / 2, bY),
        width: tp.width + 4 * noteScale,
        height: tp.height,
      ),
      bgPaint,
    );

    tp.paint(
      canvas,
      Offset((bLeft + bRight) / 2 - tp.width / 2, bY - tp.height / 2),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Time signature (top = beats, bottom = note value)
  // ─────────────────────────────────────────────────────────────────────────
  void _drawTimeSignature(Canvas canvas, double x, double midY, String sig) {
    String top = '4', bot = '4';
    if (sig == '3/4') { top = '3'; bot = '4'; }
    else if (sig == '6/8') { top = '6'; bot = '8'; }

    final ts = TextStyle(
      color: AppTheme.textPrimary.withOpacity(0.7),
      fontSize: 16 * noteScale,
      fontWeight: FontWeight.w900,
      height: 0.95,
    );

    final topP = TextPainter(text: TextSpan(text: top, style: ts), textDirection: TextDirection.ltr)..layout();
    final botP = TextPainter(text: TextSpan(text: bot, style: ts), textDirection: TextDirection.ltr)..layout();

    topP.paint(canvas, Offset(x - topP.width / 2, midY - 18 * noteScale));
    botP.paint(canvas, Offset(x - botP.width / 2, midY + 2  * noteScale));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Final double barline
  // ─────────────────────────────────────────────────────────────────────────
  void _drawFinalBarline(Canvas canvas, double x, double midY) {
    final thinPaint = Paint()
      ..color = AppTheme.textSecondary.withOpacity(0.7)
      ..strokeWidth = _barLineWidth
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = AppTheme.textSecondary.withOpacity(0.7)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final double top = midY - _sl * 0.55;
    final double bot = midY + _sl * 0.12;

    canvas.drawLine(Offset(x - 5,  top), Offset(x - 5,  bot), thinPaint);
    canvas.drawLine(Offset(x + 1,  top), Offset(x + 1,  bot), thickPaint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Glow effect for active note
  // ─────────────────────────────────────────────────────────────────────────
  void _drawGlow(Canvas canvas, double x, double midY, Color color) {
    final glowPaint = Paint()
      ..color = color.withOpacity(0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * noteScale * highlightScale);
    canvas.drawCircle(
      Offset(x, midY),
      (_nr * 2.8) * highlightScale,
      glowPaint,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Empty state placeholder
  // ─────────────────────────────────────────────────────────────────────────
  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(20, size.height / 2),
      Offset(size.width - 20, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RhythmLinePainter old) {
    return old.activeMeasureIndex  != activeMeasureIndex  ||
           old.activeElementIndex  != activeElementIndex  ||
           old.activeTripletIndex  != activeTripletIndex  ||
           old.highlightScale      != highlightScale      ||
           old.noteScale           != noteScale           ||
           old.measures            != measures;
  }
}
