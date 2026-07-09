import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The "staff on a glass card" frame shared by Composer Mode's editable
/// staff and the read-only staff/playback panel — previously duplicated
/// inline at both call sites.
class FramedStaffCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry outerPadding;
  final EdgeInsetsGeometry innerPadding;

  const FramedStaffCard({
    super.key,
    required this.child,
    this.outerPadding = const EdgeInsets.all(AppSpacing.sm),
    this.innerPadding = const EdgeInsets.all(AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: outerPadding,
      child: Container(
        padding: innerPadding,
        decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
        child: child,
      ),
    );
  }
}
