import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Monochrome Google "G" identity glyph, drawn locally so no brand asset or
/// network fetch is needed. Per Google's sign-in branding, the monochrome
/// variant is a single-color "G" — pass the color to blend with the button.
class GoogleLogo extends StatelessWidget {
  final double size;
  final Color color;

  const GoogleLogo({super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleGPainter(color),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  final Color color;

  _GoogleGPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Ring with a gap on the upper-right quadrant (from -45° to 0°),
    // like the "G" counter-form.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, // 3 o'clock
      1.75 * math.pi, // sweep counter-clockwise-equivalent leaving 45° gap
      false,
      paint,
    );

    // Horizontal crossbar entering from the right at mid-height.
    final barPaint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - stroke / 2,
        radius + stroke / 2,
        stroke,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => oldDelegate.color != color;
}
