import 'package:flutter/material.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_pattern.dart';
import '../../../../services/pattern_repository.dart';
import '../../../../services/composition_repository.dart';
import '../widgets/app_drawer.dart';
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
      drawer: const AppDrawer(activeLabel: 'Sheet Mode'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Sheet Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryPurple,
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
      return _buildEmptyState(
        icon: Icons.library_music_outlined,
        message: 'Nessun pattern disponibile.',
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
      padding: const EdgeInsets.all(20),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        final bool isSelected = selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: AppTheme.glassCardDecoration(borderRadius: 16).copyWith(
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryPurple : AppTheme.cardBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note_rounded, color: AppTheme.primaryPurple),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pattern.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pattern.bpm} BPM',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
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
      return _buildEmptyState(
        icon: Icons.edit_note_rounded,
        message: 'Nessuna composizione ancora. Apri Composer Mode dal menu per iniziare.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
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

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.responsive(portrait: 40, landscape: 80)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
