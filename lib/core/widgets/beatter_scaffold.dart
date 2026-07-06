import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Drop-in replacement for [Scaffold] that keeps the system status bar and
/// navigation bar in sync with Beatter's theme via [AnnotatedRegion], instead
/// of every screen having to remember to wrap itself.
class BeatterScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget body;
  final Color backgroundColor;
  final SystemUiOverlayStyle? overlayStyle;

  const BeatterScaffold({
    super.key,
    this.appBar,
    this.drawer,
    required this.body,
    this.backgroundColor = Colors.transparent,
    this.overlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle ?? AppTheme.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        drawer: drawer,
        body: body,
      ),
    );
  }
}
