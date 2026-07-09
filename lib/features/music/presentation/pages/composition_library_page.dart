import 'package:flutter/material.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/composition.dart';
import '../../../../services/composition_repository.dart';
import '../widgets/app_drawer.dart';
import '../widgets/composition_list_tile.dart';
import 'composer_page.dart';

enum _SortOption { recentlyModified, name, dateCreated }

/// Management screen for saved Composer Mode compositions: search, sort,
/// rename/duplicate/delete, and the entry point for creating/editing.
class CompositionLibraryPage extends StatefulWidget {
  const CompositionLibraryPage({super.key});

  @override
  State<CompositionLibraryPage> createState() => _CompositionLibraryPageState();
}

class _CompositionLibraryPageState extends State<CompositionLibraryPage> {
  final CompositionRepository _repository = CompositionRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortOption _sortOption = _SortOption.recentlyModified;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChanged);
    _init();
  }

  Future<void> _init() async {
    await _repository.init();
    if (mounted) setState(() => _loading = false);
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Composition> get _filteredSorted {
    final query = _searchQuery.trim().toLowerCase();
    final list = _repository.compositions
        .where((c) => query.isEmpty || c.title.toLowerCase().contains(query))
        .toList();

    switch (_sortOption) {
      case _SortOption.name:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortOption.dateCreated:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.recentlyModified:
        list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
    }
    return list;
  }

  void _openComposer([Composition? existing]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComposerPage(existing: existing)));
  }

  Future<void> _renameComposition(Composition composition) async {
    final newTitle = await showPromptDialog(
      context,
      title: 'Rinomina composizione',
      initialValue: composition.title,
      confirmLabel: 'Rinomina',
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await _repository.rename(composition.id, newTitle.trim());
    }
  }

  Future<bool> _confirmDeleteDialog(Composition composition) {
    return showConfirmDialog(
      context,
      title: 'Eliminare la composizione?',
      message: '"${composition.title}" verrà eliminata definitivamente.',
      confirmLabel: 'Elimina',
      isDestructive: true,
    );
  }

  Future<void> _confirmDelete(Composition composition) async {
    if (await _confirmDeleteDialog(composition)) {
      await _repository.delete(composition.id);
    }
  }

  String _subtitleFor(Composition composition) {
    final minutes = composition.totalDuration.inSeconds ~/ 60;
    final seconds = composition.totalDuration.inSeconds % 60;
    final durationLabel = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return '${composition.bpm} BPM · $durationLabel';
  }

  @override
  Widget build(BuildContext context) {
    final compositions = _filteredSorted;

    return BeatterScaffold(
      drawer: const AppDrawer(activeLabel: 'Composer Mode'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openComposer(),
        backgroundColor: AppColors.primary,
        tooltip: 'Nuova composizione',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      appBar: BeatterAppBar(
        title: 'Composer Mode',
        actions: [
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _SortOption.recentlyModified, child: Text('Modificate di recente')),
              PopupMenuItem(value: _SortOption.name, child: Text('Nome')),
              PopupMenuItem(value: _SortOption.dateCreated, child: Text('Data di creazione')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.xxs,
                          ),
                          child: Container(
                            decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.md),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _searchQuery = value),
                              decoration: const InputDecoration(
                                hintText: 'Cerca composizioni...',
                                prefixIcon: Icon(Icons.search_rounded),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: compositions.isEmpty
                              ? _buildEmptyState()
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: ListView.builder(
                                    key: ValueKey(compositions.map((c) => c.id).join(',')),
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      AppSpacing.xs,
                                      AppSpacing.lg,
                                      88,
                                    ),
                                    itemCount: compositions.length,
                                    itemBuilder: (context, index) {
                                      final composition = compositions[index];
                                      return Dismissible(
                                        key: ValueKey(composition.id),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss: (_) => _confirmDeleteDialog(composition),
                                        onDismissed: (_) => _repository.delete(composition.id),
                                        background: Container(
                                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                          alignment: Alignment.centerRight,
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                          ),
                                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                                        ),
                                        child: CompositionListTile(
                                          title: composition.title,
                                          subtitle: _subtitleFor(composition),
                                          onTap: () => _openComposer(composition),
                                          trailing: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                                            onSelected: (action) {
                                              switch (action) {
                                                case 'rename':
                                                  _renameComposition(composition);
                                                  break;
                                                case 'duplicate':
                                                  _repository.duplicate(composition.id);
                                                  break;
                                                case 'delete':
                                                  _confirmDelete(composition);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                                              PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                                              PopupMenuItem(value: 'delete', child: Text('Elimina')),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool searching = _searchQuery.trim().isNotEmpty;
    return EmptyState(
      icon: searching ? Icons.search_off_rounded : Icons.piano_off_outlined,
      title: searching ? 'Nessun risultato' : 'Nessuna composizione ancora',
      message: searching
          ? 'Prova con un altro titolo.'
          : 'Tocca + per iniziare a comporre la tua prima melodia.',
    );
  }
}
