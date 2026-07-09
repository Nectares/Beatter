import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../layout/responsive_context.dart';

/// Drop-in replacement for [Scaffold] that keeps the system status bar and
/// navigation bar in sync with Beatter's theme via [AnnotatedRegion], instead
/// of every screen having to remember to wrap itself.
///
/// On expanded-width screens (tablet/desktop, [ScreenTier.expanded]), a
/// [drawer] is shown as a permanently-visible side panel instead of a
/// swipe-out modal — premium apps don't hide primary navigation behind a
/// hamburger once there's room to just show it. [AppBar]s built via
/// [BeatterAppBar] (or any `AppBar` with no explicit `leading`) already
/// auto-hide their hamburger button the moment `drawer` stops being set on
/// the underlying [Scaffold], so this needs no per-screen opt-in — the one
/// exception is a screen with its own hand-rolled hamburger button, which
/// must guard on `context.screenTier != ScreenTier.expanded` itself (see
/// UserHomePage's top bar).
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
    final bool usePersistentRail = drawer != null && context.screenTier == ScreenTier.expanded;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle ?? AppTheme.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        drawer: usePersistentRail ? null : drawer,
        body: usePersistentRail
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  drawer!,
                  Expanded(child: body),
                ],
              )
            : body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
