import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rhythm_exercise.dart';

/// Local persistence for generated rhythm reading exercises, backed by
/// shared_preferences — same proportionate, dependency-light approach as
/// [CompositionRepository], which this deliberately mirrors.
class ExerciseRepository extends ChangeNotifier {
  static final ExerciseRepository _instance = ExerciseRepository._internal();
  factory ExerciseRepository() => _instance;
  ExerciseRepository._internal();

  static const String _storageKey = 'sheet_mode.exercises.v1';

  final List<RhythmExercise> _exercises = [];
  bool _initialized = false;

  /// Saved exercises, newest first.
  List<RhythmExercise> get exercises => List.unmodifiable(_exercises);
  bool get isInitialized => _initialized;

  /// Loads saved exercises. Safe to call more than once (e.g. from multiple
  /// screens' initState) — later calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List? ?? [])
          .map((e) => RhythmExercise.fromJson(e as Map<String, dynamic>))
          .toList();
      _exercises
        ..clear()
        ..addAll(items);
      notifyListeners();
    } catch (_) {
      // Corrupt/unreadable data — start fresh rather than crash the app.
      _exercises.clear();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'schemaVersion': 1,
      'items': _exercises.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  String _generateId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';
  }

  /// Saves [exercise]. If it has no id yet, assigns one and prepends it
  /// (first save); otherwise overwrites the existing entry with the same id.
  Future<RhythmExercise> save(RhythmExercise exercise) async {
    RhythmExercise toSave;

    final existingIndex = _exercises.indexWhere((e) => e.id == exercise.id);
    if (exercise.id.isEmpty || existingIndex == -1) {
      toSave = exercise.copyWith(
        id: exercise.id.isEmpty ? _generateId() : exercise.id,
      );
      _exercises.insert(0, toSave);
    } else {
      toSave = exercise;
      _exercises[existingIndex] = toSave;
    }

    await _persist();
    notifyListeners();
    return toSave;
  }

  Future<void> rename(String id, String newTitle) async {
    final index = _exercises.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _exercises[index] = _exercises[index].copyWith(title: newTitle);
    await _persist();
    notifyListeners();
  }

  Future<RhythmExercise> duplicate(String id) async {
    final source = _exercises.firstWhere((e) => e.id == id);
    final copy = source.copyWith(
      id: _generateId(),
      title: '${source.title} (copia)',
      createdAt: DateTime.now(),
    );
    _exercises.insert(0, copy);
    await _persist();
    notifyListeners();
    return copy;
  }

  Future<void> delete(String id) async {
    _exercises.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }
}
