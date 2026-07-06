import 'package:flutter/material.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
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
    final controller = TextEditingController(text: composition.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rinomina composizione'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Rinomina'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await _repository.rename(composition.id, newTitle.trim());
    }
  }

  Future<void> _confirmDelete(Composition composition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare la composizione?'),
        content: Text('"${composition.title}" verrà eliminata definitivamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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
        backgroundColor: AppTheme.primaryPurple,
        tooltip: 'Nuova composizione',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
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
          'Composer Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        actions: [
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort_rounded, color: AppTheme.textPrimary),
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SortOption.recentlyModified,
                child: Text('Modificate di recente'),
              ),
              PopupMenuItem(value: _SortOption.name, child: Text('Nome')),
              PopupMenuItem(value: _SortOption.dateCreated, child: Text('Data di creazione')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Cerca composizioni...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    Expanded(
                      child: compositions.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                              itemCount: compositions.length,
                              itemBuilder: (context, index) {
                                final composition = compositions[index];
                                return CompositionListTile(
                                  title: composition.title,
                                  subtitle: _subtitleFor(composition),
                                  onTap: () => _openComposer(composition),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
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
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool searching = _searchQuery.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.piano_off_outlined,
              size: 56,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'Nessun risultato' : 'Nessuna composizione ancora',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Prova con un altro titolo.'
                  : 'Tocca + per iniziare a comporre la tua prima melodia.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
