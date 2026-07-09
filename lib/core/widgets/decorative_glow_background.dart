import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The soft, blurred "glow orb" ambient background used behind Login and
/// Home — previously copy-pasted at each call site with different magic
/// numbers. Sizes/positions scale off the current screen size; pass
/// [glowColors] to tint the two orbs (defaults to primary + secondary).
class DecorativeGlowBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? glowColors;

  const DecorativeGlowBackground({super.key, required this.child, this.glowColors});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colors = glowColors ?? const [AppColors.primary, AppColors.secondary];

    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.15,
          right: -size.width * 0.2,
          child: _GlowOrb(diameter: size.width * 0.8, color: colors[0].withValues(alpha: 0.15)),
        ),
        Positioned(
          bottom: -size.height * 0.2,
          left: -size.width * 0.2,
          child: _GlowOrb(
            diameter: size.width * 0.9,
            color: colors[colors.length > 1 ? 1 : 0].withValues(alpha: 0.12),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double diameter;
  final Color color;

  const _GlowOrb({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
