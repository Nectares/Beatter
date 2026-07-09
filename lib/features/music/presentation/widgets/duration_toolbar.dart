import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/composition.dart';

/// Bottom toolbar for selecting a note duration in Composer Mode. Single
/// select, touch-friendly. Sets the duration for the next placed note when
/// nothing is selected on the staff; changes the currently selected note's
/// duration otherwise (the caller decides which — this widget just reports
/// the tapped duration).
class DurationToolbar extends StatelessWidget {
  final NoteDuration selected;
  final void Function(NoteDuration duration) onSelected;

  const DurationToolbar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static String _labelFor(NoteDuration duration) => switch (duration) {
        NoteDuration.whole => 'Semibreve',
        NoteDuration.half => 'Minima',
        NoteDuration.quarter => 'Semiminima',
        NoteDuration.eighth => 'Croma',
        NoteDuration.sixteenth => 'Semicroma',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: NoteDuration.values.map((duration) {
          final bool isSelected = duration == selected;
          return Semantics(
            label: _labelFor(duration),
            selected: isSelected,
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(duration);
                },
                child: Tooltip(
                  message: _labelFor(duration),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _DurationGlyphPainter(
                        duration: duration,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A small, self-contained note glyph (head/stem/flags) — not tied to
/// staff position, just a fixed-size icon for the toolbar button.
class _DurationGlyphPainter extends CustomPainter {
  final NoteDuration duration;
  final Color color;

  const _DurationGlyphPainter({required this.duration, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset headCenter = Offset(size.width * 0.42, size.height * 0.62);
    const double headWidth = 12.0;
    const double headHeight = 8.5;

    final bool hollow =
        duration == NoteDuration.whole || duration == NoteDuration.half;
    final bool hasStem = duration != NoteDuration.whole;
    final int flags = switch (duration) {
      NoteDuration.eighth => 1,
      NoteDuration.sixteenth => 2,
      _ => 0,
    };

    final headPaint = Paint()
      ..color = color
      ..style = hollow ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1.6;

    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(-20 * 3.14159265 / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: headWidth,
        height: headHeight,
      ),
      headPaint,
    );
    canvas.restore();

    if (hasStem) {
      final stemPaint = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final double stemX = headCenter.dx + headWidth / 2 - 1;
      final double stemTop = headCenter.dy - 20;
      canvas.drawLine(
        Offset(stemX, headCenter.dy),
        Offset(stemX, stemTop),
        stemPaint,
      );

      for (int i = 0; i < flags; i++) {
        final path = Path();
        final double y = stemTop + i * 5.0;
        path.moveTo(stemX, y);
        path.quadraticBezierTo(stemX + 7, y + 4, stemX + 5, y + 10);
        path.quadraticBezierTo(stemX + 3, y + 6, stemX, y + 4);
        path.close();
        canvas.drawPath(path, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DurationGlyphPainter oldDelegate) =>
      oldDelegate.duration != duration || oldDelegate.color != color;
}
