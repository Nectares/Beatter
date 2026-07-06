import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/composition.dart';

/// Local persistence for Composer Mode compositions, backed by
/// shared_preferences (proportionate for a handful of small JSON blobs —
/// matches this app's otherwise dependency-light approach).
class CompositionRepository extends ChangeNotifier {
  static final CompositionRepository _instance = CompositionRepository._internal();
  factory CompositionRepository() => _instance;
  CompositionRepository._internal();

  static const String _storageKey = 'composer.compositions.v1';

  final List<Composition> _compositions = [];
  bool _initialized = false;

  List<Composition> get compositions => List.unmodifiable(_compositions);
  bool get isInitialized => _initialized;

  /// Loads saved compositions. Safe to call more than once (e.g. from
  /// multiple screens' initState) — later calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List? ?? [])
          .map((e) => Composition.fromJson(e as Map<String, dynamic>))
          .toList();
      _compositions
        ..clear()
        ..addAll(items);
      notifyListeners();
    } catch (_) {
      // Corrupt/unreadable data — start fresh rather than crash the app.
      _compositions.clear();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'schemaVersion': 1,
      'items': _compositions.map((c) => c.toJson()).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  String _generateId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';
  }

  /// Saves [composition]. If it has no id yet, assigns one and appends it
  /// (first save); otherwise overwrites the existing entry with the same id.
  Future<Composition> save(Composition composition) async {
    final now = DateTime.now();
    Composition toSave;

    final existingIndex = _compositions.indexWhere((c) => c.id == composition.id);
    if (composition.id.isEmpty || existingIndex == -1) {
      toSave = composition.copyWith(
        id: composition.id.isEmpty ? _generateId() : composition.id,
        createdAt: composition.createdAt,
        modifiedAt: now,
      );
      _compositions.add(toSave);
    } else {
      toSave = composition.copyWith(modifiedAt: now);
      _compositions[existingIndex] = toSave;
    }

    await _persist();
    notifyListeners();
    return toSave;
  }

  Future<void> rename(String id, String newTitle) async {
    final index = _compositions.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _compositions[index] = _compositions[index].copyWith(
      title: newTitle,
      modifiedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<Composition> duplicate(String id) async {
    final source = _compositions.firstWhere((c) => c.id == id);
    final now = DateTime.now();
    final copy = source.copyWith(
      id: _generateId(),
      title: '${source.title} (copia)',
      createdAt: now,
      modifiedAt: now,
    );
    _compositions.add(copy);
    await _persist();
    notifyListeners();
    return copy;
  }

  Future<void> delete(String id) async {
    _compositions.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }
}
