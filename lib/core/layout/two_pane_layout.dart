import 'package:flutter/material.dart';

/// Renders [portrait] in portrait orientation, and a side-by-side split of
/// [landscapePrimary] / [landscapeSecondary] in landscape orientation.
///
/// Used for master-detail style reorganizations (e.g. a list + detail pane,
/// or branding + form) that only make sense once there's extra horizontal
/// space to work with.
///
/// Branch selection uses the *device's* orientation ([MediaQuery]), not the
/// local box's aspect ratio. This has to match whatever signal callers use
/// for their own orientation-dependent layout math (most call
/// `context.isLandscape`, which is device-level) — otherwise the two can
/// disagree the moment this widget is placed somewhere narrower than the
/// full screen, e.g. next to a navigation rail. When they disagree, this
/// widget swaps its entire subtree (Column vs Row) while the caller's
/// layout math still assumes the other branch, which is what caused
/// FlowModePage to break/crash as the tablet rail's width animated.
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
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
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
  }
}
