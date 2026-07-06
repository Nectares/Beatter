import 'package:flutter/material.dart';

/// Renders [portrait] in portrait orientation, and a side-by-side split of
/// [landscapePrimary] / [landscapeSecondary] in landscape orientation.
///
/// Used for master-detail style reorganizations (e.g. a list + detail pane,
/// or branding + form) that only make sense once there's extra horizontal
/// space to work with.
class TwoPaneLayout extends StatelessWidget {
  final WidgetBuilder portrait;
  final WidgetBuilder landscapePrimary;
  final WidgetBuilder landscapeSecondary;
  final double primaryFlex;
  final double secondaryFlex;
  final double spacing;

  const TwoPaneLayout({
    super.key,
    required this.portrait,
    required this.landscapePrimary,
    required this.landscapeSecondary,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return portrait(context);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: (primaryFlex * 100).round(),
              child: landscapePrimary(context),
            ),
            if (spacing > 0) SizedBox(width: spacing),
            Expanded(
              flex: (secondaryFlex * 100).round(),
              child: landscapeSecondary(context),
            ),
          ],
        );
      },
    );
  }
}
