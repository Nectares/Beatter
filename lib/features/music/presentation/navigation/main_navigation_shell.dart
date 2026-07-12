import 'package:flutter/material.dart';
import '../../../../core/navigation/navigation_shell.dart';
import '../../../../core/navigation/shell_destination.dart';
import '../../../../core/navigation/shell_nav_item.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../pages/flow_mode_page.dart';
import '../pages/polyrhythm_lab_page.dart';
import '../pages/reading_mode_page.dart';
import '../pages/sheet_mode_page.dart';
import '../pages/user_home_page.dart';

/// The app's root destinations, in the same order as
/// [MainNavigationShell.destinations] — used instead of raw indices so
/// callers (e.g. login routing, or a page asking the shell to switch tabs)
/// stay readable and can't drift out of sync with the destination list.
enum AppTab { home, flowMode, polyrhythmLab, sheetMode, readingMode }

/// Assembles the app's root [NavigationShell]. [destinations] are the real,
/// navigable pages backing the shell's [IndexedStack]; [navItems] is the
/// full list shown in the nav chrome (drawer on phones, rail on tablets),
/// which additionally includes "coming soon" placeholders with no
/// `destinationIndex` — shown, but not selectable.
class MainNavigationShell extends StatelessWidget {
  final AppTab initialTab;

  const MainNavigationShell({super.key, this.initialTab = AppTab.home});

  static const List<ShellDestination> destinations = [
    ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      page: UserHomePage(),
    ),
    ShellDestination(
      label: 'Flow Mode',
      icon: Icons.loop_outlined,
      selectedIcon: Icons.loop_rounded,
      page: FlowModePage(),
    ),
    ShellDestination(
      label: 'Polyrhythm Lab',
      icon: Icons.change_history_outlined,
      selectedIcon: Icons.change_history_rounded,
      page: PolyrhythmLabPage(),
    ),
    ShellDestination(
      label: 'Sheet Mode',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      page: SheetModePage(),
    ),
    ShellDestination(
      label: 'Reading Mode',
      icon: Icons.repeat_outlined,
      selectedIcon: Icons.repeat_rounded,
      page: ReadingModePage(),
    ),
  ];

  static const List<ShellNavItem> navItems = [
    ShellNavItem(
      label: 'Home',
      subtitle: 'Dashboard principale',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      destinationIndex: 0,
    ),
    ShellNavItem(
      label: 'Flow Mode',
      subtitle: 'Allenamento ritmico con loop',
      icon: Icons.loop_outlined,
      selectedIcon: Icons.loop_rounded,
      destinationIndex: 1,
    ),
    ShellNavItem(
      label: 'Sheet Mode',
      subtitle: 'Esercizi di lettura ritmica',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      destinationIndex: 3,
    ),
    ShellNavItem(
      label: 'Reading Mode',
      subtitle: 'Ascolta e ripeti gli esercizi',
      icon: Icons.repeat_outlined,
      selectedIcon: Icons.repeat_rounded,
      destinationIndex: 4,
    ),
    ShellNavItem(
      label: 'Polyrhythm Lab',
      subtitle: 'Poliritmie animate e sincronizzate',
      icon: Icons.change_history_outlined,
      selectedIcon: Icons.change_history_rounded,
      destinationIndex:
          2, // DISABLED - Temporaneamente disabilitato per future implementazioni.
    ),
    ShellNavItem(
      label: 'Composer Mode',
      subtitle: 'Componi le tue melodie',
      icon: Icons.edit_note_rounded,
    ),
    ShellNavItem(
      label: 'Ear Training',
      subtitle: 'Riconosci accordi e intervalli',
      icon: Icons.hearing_rounded,
    ),
    ShellNavItem(
      label: 'Chord Architect',
      subtitle: 'Crea progressioni armoniche',
      icon: Icons.piano_rounded,
    ),
    ShellNavItem(
      label: 'Scale Explorer',
      subtitle: 'Esplora scale e arpeggi',
      icon: Icons.music_note_rounded,
    ),
    ShellNavItem(
      label: 'Drum Sequencer',
      subtitle: 'Sequencer multitraccia',
      icon: Icons.album_rounded,
    ),
  ];

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      destinations: destinations,
      navItems: navItems,
      initialIndex: initialTab.index,
      onLogout: () => _logout(context),
    );
  }
}
