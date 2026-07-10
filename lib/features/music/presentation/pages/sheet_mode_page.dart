import 'package:flutter/material.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_pattern.dart';
import '../../../../services/pattern_repository.dart';
import '../../../../services/composition_repository.dart';
import '../widgets/composition_list_tile.dart';
import 'sheet_music_viewer_page.dart';

class SheetModePage extends StatefulWidget {
  const SheetModePage({super.key});

  @override
  State<SheetModePage> createState() => _SheetModePageState();
}

class _SheetModePageState extends State<SheetModePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedPatternIndex = 0;

  final CompositionRepository _compositionRepository = CompositionRepository();
  bool _compositionsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _compositionRepository.addListener(_onCompositionsChanged);
    _loadCompositions();
  }

  Future<void> _loadCompositions() async {
    await _compositionRepository.init();
    if (mounted) setState(() => _compositionsLoading = false);
  }

  void _onCompositionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _compositionRepository.removeListener(_onCompositionsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patterns = PatternRepository().patterns;

    return BeatterScaffold(
      appBar: BeatterAppBar(
        title: 'Sheet Mode',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Libreria'),
            Tab(text: 'Le Mie Composizioni'),
          ],
        ),
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLibraryTab(patterns),
              _buildCompositionsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryTab(List<RhythmPattern> patterns) {
    if (patterns.isEmpty) {
      return const EmptyState(
        icon: Icons.library_music_outlined,
        title: 'Nessun pattern disponibile.',
      );
    }

    return TwoPaneLayout(
      portrait: (context) => _buildPatternList(patterns, onTap: (index) {
        final pattern = patterns[index];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SheetMusicViewerPage(
              title: pattern.name,
              measures: pattern.toRhythmMeasures(),
              bpm: pattern.bpm,
            ),
          ),
        );
      }),
      landscapePrimary: (context) => _buildPatternList(
        patterns,
        selectedIndex: _selectedPatternIndex,
        onTap: (index) => setState(() => _selectedPatternIndex = index),
      ),
      landscapeSecondary: (context) {
        final pattern = patterns[_selectedPatternIndex.clamp(0, patterns.length - 1)];
        return StaffPlaybackPanel(
          title: pattern.name,
          measures: pattern.toRhythmMeasures(),
          bpm: pattern.bpm,
        );
      },
      primaryFlex: 0.35,
      secondaryFlex: 0.65,
    );
  }

  Widget _buildPatternList(
    List<RhythmPattern> patterns, {
    int? selectedIndex,
    required void Function(int index) onTap,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        return CompositionListTile(
          title: pattern.name,
          subtitle: '${pattern.bpm} BPM',
          icon: Icons.music_note_rounded,
          isSelected: selectedIndex == index,
          onTap: () => onTap(index),
        );
      },
    );
  }

  Widget _buildCompositionsTab() {
    if (_compositionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final compositions = _compositionRepository.compositions;
    if (compositions.isEmpty) {
      return const EmptyState(
        icon: Icons.edit_note_rounded,
        title: 'Nessuna composizione ancora',
        message: 'Apri Composer Mode dal menu per iniziare.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: compositions.length,
      itemBuilder: (context, index) {
        final composition = compositions[index];
        return CompositionListTile(
          title: composition.title,
          subtitle: '${composition.bpm} BPM',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SheetMusicViewerPage(
                title: composition.title,
                measures: composition.toRhythmMeasures(),
                bpm: composition.bpm,
              ),
            ),
          ),
        );
      },
    );
  }
}
