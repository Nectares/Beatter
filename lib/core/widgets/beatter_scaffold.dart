import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Drop-in replacement for [Scaffold] that keeps the system status bar and
/// navigation bar in sync with Beatter's theme via [AnnotatedRegion], instead
/// of every screen having to remember to wrap itself.
///
/// Root-level navigation (bottom bar on phones, collapsible rail on
/// tablets) lives in [NavigationShell], one level up — pages reached
/// through it should not pass [drawer] here. This still accepts one for
/// screens that want a genuine modal drawer of their own, but no longer
/// tries to reinterpret it as a permanent side panel on wide screens: that
/// silently turned `Navigator.pop` (used to close the drawer) into a pop of
/// the current page whenever the drawer wasn't actually a modal route,
/// which was the root cause of a white-screen bug on tablet widths.
class BeatterScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget body;
  final Color backgroundColor;
  final SystemUiOverlayStyle? overlayStyle;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  const BeatterScaffold({
    super.key,
    this.appBar,
    this.drawer,
    required this.body,
    this.backgroundColor = Colors.transparent,
    this.overlayStyle,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
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
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
