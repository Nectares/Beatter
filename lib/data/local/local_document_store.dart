import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/value_stream.dart';
import '../../domain/repositories/document_store.dart';

/// shared_preferences-backed [DocumentStore] — the pre-Firebase persistence
/// strategy, preserved as the local-mode fallback and as a lightweight fake
/// for widget tests.
class LocalDocumentStore<T> implements DocumentStore<T> {
  final String _storageKey;
  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T value) _toJson;
  final String Function(T value) _idOf;
  final int Function(T a, T b)? _sort;

  final _controller = StreamController<List<T>>.broadcast();
  List<T> _items = [];
  bool _loaded = false;

  LocalDocumentStore({
    required String storageKey,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
    required String Function(T value) idOf,
    int Function(T a, T b)? sort,
  })  : _storageKey = storageKey,
        _fromJson = fromJson,
        _toJson = toJson,
        _idOf = idOf,
        _sort = sort;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _items = (decoded['items'] as List? ?? [])
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
      _applySort();
    } catch (_) {
      _items = []; // corrupt data: start fresh rather than crash
    }
  }

  void _applySort() {
    final sort = _sort;
    if (sort != null) _items.sort(sort);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'schemaVersion': 1,
        'items': _items.map(_toJson).toList(),
      }),
    );
  }

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Stream<List<T>> watchAll() => valueThenUpdates(
        ensureLoaded: _ensureLoaded,
        snapshot: () => List.unmodifiable(_items),
        updates: _controller.stream,
      );

  @override
  Future<List<T>> loadAll() async {
    await _ensureLoaded();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> upsert(T document) async {
    await _ensureLoaded();
    final id = _idOf(document);
    final index = _items.indexWhere((e) => _idOf(e) == id);
    if (index == -1) {
      _items.add(document);
    } else {
      _items[index] = document;
    }
    _applySort();
    _emit();
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    await _ensureLoaded();
    _items.removeWhere((e) => _idOf(e) == id);
    _emit();
    await _persist();
  }

  @override
  Future<void> dispose() => _controller.close();
}
