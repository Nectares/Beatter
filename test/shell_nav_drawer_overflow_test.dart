// Regression test for the phone nav drawer overflowing.
//
// Caught two real, reproducible `RenderFlex overflowed` errors that manual
// code review missed twice: a horizontal one in the brand header (a Text
// column with no Expanded/Flexible wrapper) and a vertical one on short
// landscape heights combined with a larger system text scale (fixed
// header/footer content around a scrollable middle section, where the
// fixed content alone could exceed the available height). Keep this test
// running across a spread of realistic phone sizes/orientations and text
// scales so a future change can't silently reintroduce either failure mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/core/navigation/shell_nav_drawer.dart';
import 'package:beatter/core/navigation/shell_nav_item.dart';
import 'package:beatter/theme/app_theme.dart';

const _navItems = [
  ShellNavItem(label: 'Home', subtitle: 'Dashboard principale', icon: Icons.home_rounded, selectedIcon: Icons.home_rounded, destinationIndex: 0),
  ShellNavItem(label: 'Flow Mode', subtitle: 'Allenamento ritmico con loop', icon: Icons.loop_rounded, selectedIcon: Icons.loop_rounded, destinationIndex: 1),
  ShellNavItem(label: 'Rhythm Generator', subtitle: 'Letture sul pentagramma', icon: Icons.music_note_rounded),
  ShellNavItem(label: 'Sheet Mode', subtitle: 'Trascrizioni e partiture', icon: Icons.menu_book_rounded),
  ShellNavItem(label: 'Composer Mode', subtitle: 'Componi le tue melodie', icon: Icons.edit_note_rounded),
  ShellNavItem(label: 'Polyrhythms', subtitle: 'Allenamento poliritmico', icon: Icons.group_work_rounded),
  ShellNavItem(label: 'Ear Training', subtitle: 'Riconosci accordi e intervalli', icon: Icons.hearing_rounded),
  ShellNavItem(label: 'Chord Architect', subtitle: 'Crea progressioni armoniche', icon: Icons.piano_rounded),
  ShellNavItem(label: 'Scale Explorer', subtitle: 'Esplora scale e arpeggi', icon: Icons.music_note_rounded),
  ShellNavItem(label: 'Drum Sequencer', subtitle: 'Sequencer multitraccia', icon: Icons.album_rounded),
];

Future<void> _pumpDrawerAt(WidgetTester tester, Size size, {double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final scaffoldKey = GlobalKey<ScaffoldState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        key: scaffoldKey,
        drawer: ShellNavDrawer(
          navItems: _navItems,
          selectedIndex: 1,
          onSelect: (_) {},
          onLogout: () {},
        ),
        body: const SizedBox(),
      ),
    ),
  );
  scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  final sizes = <String, Size>{
    '320x568 portrait (iPhone SE)': const Size(320, 568),
    '411x891 portrait (Medium Phone)': const Size(411, 891),
    '480x320 short landscape': const Size(480, 320),
    '600x400 landscape': const Size(600, 400),
  };

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('drawer renders without overflow at ${entry.key}, textScale $scale', (tester) async {
        await _pumpDrawerAt(tester, entry.value, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
