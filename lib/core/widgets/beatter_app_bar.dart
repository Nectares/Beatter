import 'package:flutter/material.dart';

/// The app's one AppBar shape, replacing the two inconsistent hand-rolled
/// "flavors" (centered-bold-title-with-drawer vs. left-aligned-plain-title)
/// that had drifted apart across screens. Styling itself comes from
/// `AppTheme.lightTheme.appBarTheme` — this just fixes the shared shell
/// (centered title by default, consistent action spacing).
///
/// Flutter's [Scaffold] already supplies the drawer hamburger automatically
/// when `drawer:` is set and no [leading] is given, so there's no separate
/// "drawer flavor" to model — pass an explicit `leading: BackButton()` for
/// pushed pages instead.
class BeatterAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const BeatterAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      centerTitle: centerTitle,
      title: Text(title),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}
