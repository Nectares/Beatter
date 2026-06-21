import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';

class RhythmStaffPainter extends CustomPainter {
  final List<RhythmMeasure> measures;
  final int activeMeasureIndex;
  final int activeElementIndex;
  final int? activeTripletIndex;
  final double horizontalScrollOffset;

  static const double lineSpacing = 10.0;
  static const double noteWidth = 12.0;
  static const double noteHeight = 8.0;

  RhythmStaffPainter({
    required this.measures,
    required this.activeMeasureIndex,
    required this.activeElementIndex,
    this.activeTripletIndex,
    this.horizontalScrollOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    
    // Stili linee pentagramma
    final linePaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final barPaint = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Disegna le 5 linee del pentagramma
    for (int i = -2; i <= 2; i++) {
      final y = midY + i * lineSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Se non ci sono battute da disegnare, ci fermiamo qui
    if (measures.isEmpty) return;

    double currentX = 20.0;

    // 1. Chiave di Violino (Treble Clef) all'inizio del pentagramma (solo sulla prima battuta se visibile)
    _drawTrebleClef(canvas, currentX, midY, lineSpacing);
    currentX += 45.0;

    // 2. Indicazione di Tempo (Time Signature)
    final String timeSig = measures.first.timeSignature;
    _drawTimeSignature(canvas, currentX, midY, timeSig);
    currentX += 35.0;

    // Disegna ciascuna battuta
    for (int m = 0; m < measures.length; m++) {
      final measure = measures[m];
      final double measureWidth = _getMeasureWidth(measure.timeSignature);
      final double endX = currentX + measureWidth;

      // Disegna le note all'interno della battuta
      double elapsedBeats = 0.0;
      final double beatsPerMeasure = _getTargetBeats(measure.timeSignature);

      for (int e = 0; e < measure.elements.length; e++) {
        final element = measure.elements[e];
        
        // Calcola la coordinata X dell'elemento
        final double elementX = currentX + (elapsedBeats / beatsPerMeasure) * (measureWidth - 30.0) + 15.0;
        final bool isActive = (m == activeMeasureIndex && e == activeElementIndex);

        _drawRhythmElement(
          canvas: canvas,
          element: element,
          x: elementX,
          midY: midY,
          spacing: lineSpacing,
          isActive: isActive,
          activeTripletIndex: activeTripletIndex,
        );

        elapsedBeats += element.duration;
      }

      // Disegna la stanghetta di battuta finale (verticale)
      canvas.drawLine(
        Offset(endX, midY - 2 * lineSpacing),
        Offset(endX, midY + 2 * lineSpacing),
        barPaint,
      );

      currentX = endX;
    }
  }

  double _getMeasureWidth(String timeSig) {
    if (timeSig == '4/4') return 240.0;
    if (timeSig == '3/4') return 180.0;
    if (timeSig == '6/8') return 200.0;
    return 240.0;
  }

  double _getTargetBeats(String timeSig) {
    if (timeSig == '4/4') return 4.0;
    if (timeSig == '3/4') return 3.0;
    if (timeSig == '6/8') return 3.0;
    return 4.0;
  }

  void _drawTrebleClef(Canvas canvas, double x, double y, double s) {
    final clefPaint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Disegno vettoriale semplificato ma elegante della chiave di violino
    // Inizia dal basso con un piccolo cerchio/ricciolo
    path.moveTo(x + 10, y + 2.5 * s);
    path.cubicTo(
      x + 18, y + 2.5 * s,
      x + 22, y + 1.5 * s,
      x + 22, y + 0.8 * s,
    );
    path.cubicTo(
      x + 22, y + 0.1 * s,
      x + 15, y - 0.4 * s,
      x + 8, y + 0.2 * s,
    );
    path.cubicTo(
      x + 2, y + 0.8 * s,
      x + 5, y + 1.6 * s,
      x + 12, y + 1.6 * s,
    );
    path.cubicTo(
      x + 18, y + 1.6 * s,
      x + 20, y + 1.0 * s,
      x + 14, y + 0.6 * s,
    );

    // Loop verso l'alto superando il pentagramma
    path.moveTo(x + 8, y + 0.2 * s);
    path.cubicTo(
      x - 5, y - 1.0 * s,
      x + 5, y - 3.2 * s,
      x + 12, y - 3.8 * s,
    );
    path.cubicTo(
      x + 15, y - 4.1 * s,
      x + 18, y - 4.0 * s,
      x + 16, y - 3.2 * s,
    );

    // Linea verticale che scende fino in fondo
    path.lineTo(x + 12, y + 3.2 * s);
    path.cubicTo(
      x + 10, y + 3.8 * s,
      x + 4, y + 4.0 * s,
      x + 2, y + 3.6 * s,
    );

    canvas.drawPath(path, clefPaint);
  }

  void _drawTimeSignature(Canvas canvas, double x, double y, String timeSig) {
    String topNum = '4';
    String bottomNum = '4';
    if (timeSig == '3/4') {
      topNum = '3';
      bottomNum = '4';
    } else if (timeSig == '6/8') {
      topNum = '6';
      bottomNum = '8';
    }

    final textStyle = const TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      fontFamily: 'serif',
      height: 0.9,
    );

    // Disegna il numero superiore
    final topPainter = TextPainter(
      text: TextSpan(text: topNum, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    topPainter.paint(canvas, Offset(x, y - 2.0 * lineSpacing - 2));

    // Disegna il numero inferiore
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
      ..color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final restPaint = Paint()
      ..color = isActive ? AppTheme.accentPink : AppTheme.textSecondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Effetto alone luminoso neon se la nota è attiva
    if (isActive) {
      final glowPaint = Paint()
        ..color = (element.isRest ? AppTheme.accentPink : AppTheme.secondaryCyan).withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, midY), 22, glowPaint);
    }

    switch (element.type) {
      case RhythmElementType.quarter:
        _drawNoteHead(canvas, x, getNoteY(element.noteName, midY, spacing), notePaint);
        _drawStem(canvas, x, getNoteY(element.noteName, midY, spacing), spacing, true, stemPaint);
        break;

      case RhythmElementType.eighth:
        final y = getNoteY(element.noteName, midY, spacing);
        _drawNoteHead(canvas, x, y, notePaint);
        final stemEnd = _drawStem(canvas, x, y, spacing, true, stemPaint);
        _drawFlag(canvas, x, stemEnd, true, 1, stemPaint);
        break;

      case RhythmElementType.sixteenth:
        final y = getNoteY(element.noteName, midY, spacing);
        _drawNoteHead(canvas, x, y, notePaint);
        final stemEnd = _drawStem(canvas, x, y, spacing, true, stemPaint);
        _drawFlag(canvas, x, stemEnd, true, 2, stemPaint);
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
        // Una terzina è disegnata come tre note da 1/8 unite da una sbarra spessa in alto o in basso
        _drawTriplet(canvas, x, midY, spacing, element.tripletNotes, isActive, activeTripletIndex);
        break;
    }
  }

  double getNoteY(String noteName, double centerLineY, double spacing) {
    // La linea centrale (3ª linea dal basso) è il B4
    final notes = ['F5', 'E5', 'D5', 'C5', 'B4', 'A4', 'G4', 'F4', 'E4'];
    final index = notes.indexOf(noteName);
    if (index == -1) return centerLineY;
    return centerLineY + (index - 4) * 0.5 * spacing;
  }

  void _drawNoteHead(Canvas canvas, double x, double y, Paint paint) {
    // Le note sono ellissi inclinate di circa -20 gradi
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-20 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: noteWidth, height: noteHeight),
      paint,
    );
    
    // Linea addizionale (taglio in testa) per note molto basse o alte (es. C4 o A5)
    canvas.restore();
    
    // Se la nota è C4 o D4, disegna il taglio addizionale
    // D4 sits at index 9, C4 sits at index 10 in extended scale
    if (y >= lineSpacing * 2.5) {
      // Disegna un piccolo taglio orizzontale
      final ledgerPaint = Paint()
        ..color = paint.color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), ledgerPaint);
    }
  }

  Offset _drawStem(Canvas canvas, double x, double y, double spacing, bool isUp, Paint paint) {
    // Lunghezza del gambo della nota (in genere 3 volte lo spazio tra le linee)
    final double stemLen = spacing * 3.0;
    final double stemX = isUp ? x + noteWidth / 2 - 1 : x - noteWidth / 2 + 1;
    final double stemYEnd = isUp ? y - stemLen : y + stemLen;

    canvas.drawLine(
      Offset(stemX, y),
      Offset(stemX, stemYEnd),
      paint,
    );
    
    return Offset(stemX, stemYEnd);
  }

  void _drawFlag(Canvas canvas, double x, Offset stemEnd, bool isUp, int flagsCount, Paint paint) {
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
        path.cubicTo(
          4, yOffset + 5,
          10, yOffset + 10,
          8, yOffset + 18,
        );
        path.cubicTo(
          8, yOffset + 12,
          4, yOffset + 8,
          0, yOffset + 6,
        );
      } else {
        path.moveTo(0, yOffset);
        path.cubicTo(
          4, yOffset - 5,
          10, yOffset - 10,
          8, yOffset - 18,
        );
        path.cubicTo(
          8, yOffset - 12,
          4, yOffset - 8,
          0, yOffset - 6,
        );
      }
      
      canvas.drawPath(path, flagPaint);
    }
    
    canvas.restore();
  }

  void _drawQuarterRest(Canvas canvas, double x, double y, double s, Paint paint) {
    // La pausa da 1/4 (semiminima) è disegnata come una linea a zig-zag stilizzata ma professionale
    final path = Path();
    path.moveTo(x - 3, y - 1.2 * s);
    path.lineTo(x + 4, y - 0.5 * s);
    path.lineTo(x - 4, y + 0.2 * s);
    path.lineTo(x + 4, y + 0.9 * s);
    path.quadraticBezierTo(x, y + 1.6 * s, x - 5, y + 1.2 * s);
    
    canvas.drawPath(path, paint);
  }

  void _drawEighthRest(Canvas canvas, double x, double y, double s, int restsCount, Paint paint) {
    // Le pause di croma (1/8) e semicroma (1/16)
    final restPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < restsCount; i++) {
      final double yOffset = i * 0.8 * s - 0.2 * s;
      
      // Asta diagonale
      final double startY = y - 0.7 * s + yOffset;
      final double endY = y + 0.8 * s + yOffset;
      
      canvas.drawLine(
        Offset(x + 3, startY),
        Offset(x - 3, endY),
        paint,
      );

      // Pallina/Gancio a sinistra
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
    // Una terzina è larga in tutto circa 45 pixel. Le tre note sono a:
    // x0 = startX - 16, x1 = startX, x2 = startX + 16
    final double x0 = startX - 16;
    final double x1 = startX;
    final double x2 = startX + 16;
    
    final double y0 = getNoteY(notes[0], midY, spacing);
    final double y1 = getNoteY(notes[1], midY, spacing);
    final double y2 = getNoteY(notes[2], midY, spacing);

    // Determiniamo la direzione dei gambi (tutti in su per semplicità)
    final double stemLen = spacing * 2.8;

    final double sy0 = y0 - stemLen;
    final double sy1 = y1 - stemLen;
    final double sy2 = y2 - stemLen;

    // Disegna le tre note singolarmente
    for (int i = 0; i < 3; i++) {
      final double noteX = (i == 0) ? x0 : ((i == 1) ? x1 : x2);
      final double noteY = (i == 0) ? y0 : ((i == 1) ? y1 : y2);
      final bool isThisNoteActive = isActive && activeTripletIndex == i;

      final notePaint = Paint()
        ..color = isThisNoteActive ? AppTheme.secondaryCyan : AppTheme.textPrimary
        ..style = PaintingStyle.fill;

      final stemPaint = Paint()
        ..color = isThisNoteActive ? AppTheme.secondaryCyan : (isActive ? AppTheme.secondaryCyan.withOpacity(0.5) : AppTheme.textPrimary)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;

      // Disegna testa
      _drawNoteHead(canvas, noteX, noteY, notePaint);
      
      // Disegna gambo verticale
      canvas.drawLine(
        Offset(noteX + noteWidth / 2 - 1, noteY),
        Offset(noteX + noteWidth / 2 - 1, noteY - stemLen),
        stemPaint,
      );
    }

    // Disegna la trave spessa (beam) superiore che unisce i tre gambi
    final beamPaint = Paint()
      ..color = isActive ? AppTheme.secondaryCyan : AppTheme.textPrimary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(x0 + noteWidth / 2 - 1, sy0),
      Offset(x2 + noteWidth / 2 - 1, sy2),
      beamPaint,
    );

    // Disegna la parentesi quadra con il numero "3" sopra
    final bracketPaint = Paint()
      ..color = isActive ? AppTheme.secondaryCyan : AppTheme.textSecondary
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double bracketY = math.min(math.min(sy0, sy1), sy2) - 8.0;
    
    // Staffa orizzontale
    canvas.drawLine(Offset(x0 - 4, bracketY), Offset(x2 + 8, bracketY), bracketPaint);
    // Ali verticali
    canvas.drawLine(Offset(x0 - 4, bracketY), Offset(x0 - 4, bracketY + 4), bracketPaint);
    canvas.drawLine(Offset(x2 + 8, bracketY), Offset(x2 + 8, bracketY + 4), bracketPaint);

    // Numero "3" al centro della staffa
    final textStyle = TextStyle(
      color: isActive ? AppTheme.secondaryCyan : AppTheme.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(text: '3', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    // Disegna uno sfondo scuro dietro al "3" per interrompere visivamente la linea della staffa
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
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
        bracketY - textPainter.height / 2
      )
    );
  }

  @override
  bool shouldRepaint(covariant RhythmStaffPainter oldDelegate) {
    return oldDelegate.activeMeasureIndex != activeMeasureIndex ||
        oldDelegate.activeElementIndex != activeElementIndex ||
        oldDelegate.activeTripletIndex != activeTripletIndex ||
        oldDelegate.horizontalScrollOffset != horizontalScrollOffset ||
        oldDelegate.measures != measures;
  }
}
