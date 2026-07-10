// Regression test for the tablet nav rail overflowing — the counterpart to
// shell_nav_drawer_overflow_test.dart. The rail's expanded state was
// rebuilt to match ShellNavDrawer's exact measurements (see
// collapsible_nav_rail.dart), including several width/padding values that
// now animate together; this exercises both steady states plus mid-
// animation frames across a spread of realistic tablet sizes and text
// scales to make sure that never overflows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/core/navigation/collapsible_nav_rail.dart';
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

class _ToggleableRailHarness extends StatefulWidget {
  const _ToggleableRailHarness();

  @override
  State<_ToggleableRailHarness> createState() => _ToggleableRailHarnessState();
}

class _ToggleableRailHarnessState extends State<_ToggleableRailHarness> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleNavRail(
            navItems: _navItems,
            selectedIndex: 1,
            onSelect: (_) {},
            expanded: expanded,
            onToggle: () => setState(() => expanded = !expanded),
            onLogout: () {},
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

Future<void> _pumpRailAt(WidgetTester tester, Size size, {double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const _ToggleableRailHarness(),
    ),
  );
}

void main() {
  final sizes = <String, Size>{
    '600x800 (small tablet portrait)': const Size(600, 800),
    '800x1280 (tablet portrait)': const Size(800, 1280),
    '1024x768 (tablet landscape)': const Size(1024, 768),
    '900x500 (short tablet landscape)': const Size(900, 500),
  };

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('rail steady states at ${entry.key}, textScale $scale', (tester) async {
        await _pumpRailAt(tester, entry.value, textScale: scale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'expanded, ${entry.key}, scale $scale');

        await tester.tap(find.byTooltip('Comprimi menu'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'collapsed, ${entry.key}, scale $scale');
      });

      testWidgets('rail mid-animation frames at ${entry.key}, textScale $scale', (tester) async {
        await _pumpRailAt(tester, entry.value, textScale: scale);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Comprimi menu'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.takeException(), isNull, reason: 'mid-collapse frame $i, ${entry.key}, scale $scale');
        }
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Espandi menu'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.takeException(), isNull, reason: 'mid-expand frame $i, ${entry.key}, scale $scale');
        }
        await tester.pumpAndSettle();
      });
    }
  }
}
