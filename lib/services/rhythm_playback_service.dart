import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/rhythm_element.dart';

/// Evento di riproduzione convertito in millisecondi per lo scheduler.
class PlaybackEvent {
  final double beatOffset;      // Offset in battiti dall'inizio
  final int measureIndex;
  final int elementIndex;
  final int? tripletIndex;      // null se non terzina, 0, 1, 2 se terzina
  final bool isMetronome;       // true se è un click del metronomo
  final bool isAccent;          // true se è il primo movimento (forte)
  final bool isRest;            // true se è una pausa
  final RhythmElementType noteType;
  final String? noteName;       // pitch (es. 'C4'), per la riproduzione melodica

  PlaybackEvent({
    required this.beatOffset,
    required this.measureIndex,
    required this.elementIndex,
    this.tripletIndex,
    this.isMetronome = false,
    this.isAccent = false,
    this.isRest = false,
    required this.noteType,
    this.noteName,
  });
}

/// Gestore del pool di player audio per evitare tagli di campioni in decadimento.
class AudioPlayerPool {
  final String assetPath;
  final int size;
  final List<AudioPlayer> _pool = [];
  int _nextIndex = 0;
  double _volume = 1.0;

  AudioPlayerPool({required this.assetPath, this.size = 3}) {
    for (int i = 0; i < size; i++) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      // Pre-imposta la sorgente per eliminare la latenza di caricamento iniziale
      player.setSource(AssetSource(assetPath));
      _pool.add(player);
    }
  }

  void play() {
    if (_pool.isEmpty) return;
    final player = _pool[_nextIndex];
    // Riavvia immediatamente il file WAV
    player.stop();
    player.resume();
    _nextIndex = (_nextIndex + 1) % size;
  }

  /// Sets playback volume (0.0-1.0) applied to every pooled player —
  /// used by callers that expose a master-volume control (e.g. Polyrhythm
  /// Lab's [AudioScheduler]). No-op for pools that never call it.
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    for (final player in _pool) {
      player.setVolume(_volume);
    }
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
  }
}

class RhythmPlaybackService extends ChangeNotifier {
  // Configurazione riproduzione
  int _bpm = 120;
  bool _isMetronomeEnabled = true;
  String _soundInstrument = 'silent'; // 'silent', 'snare', 'stick' o 'melodic'

  // Stato riproduzione
  bool _isPlaying = false;
  bool _isPaused = false;
  int _currentMeasureIndex = -1;
  int _currentElementIndex = -1;
  int? _currentTripletIndex;

  // Servizio Audio Pools
  AudioPlayerPool? _accentPool;
  AudioPlayerPool? _clickPool;
  AudioPlayerPool? _stickPool;
  AudioPlayerPool? _snarePool;
  final Map<String, AudioPlayerPool> _notePools = {};
  final bool _enableMelodicPlayback;

  /// Natural notes C3–C6 — matches the WAV set pre-baked by
  /// `generate_note_assets.dart` and the staff's letter-only pitch range.
  static const List<String> _melodicNoteNames = [
    'C3', 'D3', 'E3', 'F3', 'G3', 'A3', 'B3',
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4',
    'C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'B5',
    'C6',
  ];

  // Scheduler interni
  final List<PlaybackEvent> _timeline = [];
  int _nextEventIndex = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _schedulerTimer;
  double _totalBeats = 0.0;

  // Loop infinito
  bool _isLooping = false;
  /// Timestamp (in ms dallo stopwatch) dell'inizio del ciclo corrente.
  /// Usato per calcolare il beat offset relativo senza resettare lo stopwatch
  /// (evita drift tra un loop e il successivo).
  double _loopStartMs = 0.0;

  // Getters
  int get bpm => _bpm;
  bool get isMetronomeEnabled => _isMetronomeEnabled;
  String get soundInstrument => _soundInstrument;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isLooping => _isLooping;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentElementIndex => _currentElementIndex;
  int? get currentTripletIndex => _currentTripletIndex;

  /// [enableMelodicPlayback] builds one small audio pool per pitched note
  /// (used by Composer Mode) — left off elsewhere so Flow Mode/Sheet Mode
  /// don't pay for two dozen unused audio players.
  RhythmPlaybackService({bool enableMelodicPlayback = false})
      : _enableMelodicPlayback = enableMelodicPlayback {
    _initAudioPools();
  }

  void _initAudioPools() {
    _accentPool = AudioPlayerPool(assetPath: 'audio/metronome_accent.wav', size: 2);
    _clickPool = AudioPlayerPool(assetPath: 'audio/metronome_click.wav', size: 3);
    _stickPool = AudioPlayerPool(assetPath: 'audio/stick.wav', size: 3);
    _snarePool = AudioPlayerPool(assetPath: 'audio/snare.wav', size: 4);

    if (_enableMelodicPlayback) {
      for (final noteName in _melodicNoteNames) {
        _notePools[noteName] = AudioPlayerPool(assetPath: 'audio/notes/$noteName.wav', size: 2);
      }
    }
  }

  void updateSettings({int? bpm, bool? isMetronomeEnabled, String? soundInstrument}) {
    if (bpm != null) _bpm = bpm;
    if (isMetronomeEnabled != null) _isMetronomeEnabled = isMetronomeEnabled;
    if (soundInstrument != null) _soundInstrument = soundInstrument;
    notifyListeners();
  }

  /// Costruisce la timeline esatta degli eventi in base al ritmo generato.
  void preparePlayback(List<RhythmMeasure> measures) {
    _timeline.clear();
    double currentBeat = 0.0;

    for (int m = 0; m < measures.length; m++) {
      final measure = measures[m];
      final timeSig = measure.timeSignature;

      // 1. Aggiungi i click del metronomo
      if (timeSig == '2/4') {
        _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: -1, isMetronome: true, isAccent: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
      } else if (timeSig == '4/4') {
        _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: -1, isMetronome: true, isAccent: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 2.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 3.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
      } else if (timeSig == '3/4') {
        _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: -1, isMetronome: true, isAccent: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 2.0, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
      } else if (timeSig == '6/8') {
        // Metronomo in 6/8: due movimenti principali (da croma puntata = 1.5 quarti ciascuno)
        _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: -1, isMetronome: true, isAccent: true, noteType: RhythmElementType.quarter));
        _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.5, measureIndex: m, elementIndex: -1, isMetronome: true, noteType: RhythmElementType.quarter));
      }

      // 2. Aggiungi le note/pause del ritmo
      for (int e = 0; e < measure.elements.length; e++) {
        final element = measure.elements[e];

        if (element.type == RhythmElementType.triplet) {
          // Terzina: 3 note equidistanti che riempiono 1 battito
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, tripletIndex: 0, noteType: element.type, noteName: element.tripletNotes[0]));
          _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.0 / 3.0, measureIndex: m, elementIndex: e, tripletIndex: 1, noteType: element.type, noteName: element.tripletNotes[1]));
          _timeline.add(PlaybackEvent(beatOffset: currentBeat + 2.0 / 3.0, measureIndex: m, elementIndex: e, tripletIndex: 2, noteType: element.type, noteName: element.tripletNotes[2]));
        } else if (element.isRest) {
          // Evento silenzioso solo per notificare l'interfaccia dell'evidenziazione
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, isRest: true, noteType: element.type));
        } else {
          // Nota singola (quarter, eighth, sixteenth)
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, noteType: element.type, noteName: element.noteName));
        }

        currentBeat += element.duration;
      }
    }

    _totalBeats = currentBeat;
    
    // Ordina la timeline in base al beatOffset
    _timeline.sort((a, b) => a.beatOffset.compareTo(b.beatOffset));
    
    // Resetta l'indice del prossimo evento
    _nextEventIndex = 0;
  }

  /// Costruisce la timeline esatta degli eventi in base alle tessere del Flow Mode.
  /// Flow Mode usa sempre un tempo fisso di 4/4.
  void prepareSlotPlayback(List<RhythmSlot> slots) {
    _timeline.clear();

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final double slotBeatOffset = i.toDouble();

      // 1. Aggiungi i click del metronomo su ciascun movimento
      final bool isAccent = i % 4 == 0;

      _timeline.add(PlaybackEvent(
        beatOffset: slotBeatOffset,
        measureIndex: 0,
        elementIndex: -1,
        isMetronome: true,
        isAccent: isAccent,
        noteType: RhythmElementType.quarter,
      ));

      // 2. Aggiungi le note all'interno del movimento
      double subBeatOffset = 0.0;
      for (int noteIdx = 0; noteIdx < slot.noteDurations.length; noteIdx++) {
        final double noteDuration = slot.noteDurations[noteIdx];
        final bool isRest = slot.isRestList[noteIdx];

        _timeline.add(PlaybackEvent(
          beatOffset: slotBeatOffset + subBeatOffset,
          measureIndex: 0,
          elementIndex: i, // L'indice della tessera
          isRest: isRest,
          noteType: RhythmElementType.quarter,
        ));

        subBeatOffset += noteDuration;
      }
    }

    _totalBeats = slots.length.toDouble();
    _timeline.sort((a, b) => a.beatOffset.compareTo(b.beatOffset));
    _nextEventIndex = 0;
  }

  /// Aggiorna le tessere del Flow Mode in modo fluido senza interrompere il loop.
  void updateSlotsSeamlessly(List<RhythmSlot> slots) {
    prepareSlotPlayback(slots);
    
    if (_isPlaying && !_isPaused) {
      final double msPerBeat = 60000.0 / _bpm;
      final double elapsedMs = _stopwatch.elapsedMilliseconds.toDouble();
      final double currentBeatOffset = (elapsedMs - _loopStartMs) / msPerBeat;

      _nextEventIndex = 0;
      while (_nextEventIndex < _timeline.length &&
             _timeline[_nextEventIndex].beatOffset <= currentBeatOffset) {
        _nextEventIndex++;
      }
    }
  }

  /// Avvia la riproduzione in loop infinito.
  void play() {
    if (_timeline.isEmpty) return;

    // Evita doppio play: se già in esecuzione non fare nulla
    if (_isPlaying && !_isPaused) return;

    if (_isPaused) {
      // Resume dalla pausa: riprende dallo stesso punto
      _isPaused = false;
      _isPlaying = true;
      _isLooping = true;
      _stopwatch.start();
      _startSchedulerLoop();
      notifyListeners();
      return;
    }

    // Avvio da zero
    _isPlaying = true;
    _isPaused = false;
    _isLooping = true;
    _nextEventIndex = 0;
    _loopStartMs = 0.0;
    _stopwatch.reset();
    _stopwatch.start();
    _startSchedulerLoop();
    notifyListeners();
  }

  /// Mette in pausa la riproduzione.
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _isPaused = true;
    _stopwatch.stop();
    _schedulerTimer?.cancel();
    notifyListeners();
  }

  /// Ferma il loop e resetta tutto allo stato idle.
  void stopLoop() {
    _isLooping = false;
    stop();
  }

  /// Ferma la riproduzione e resetta lo stato a idle.
  void stop() {
    _isPlaying = false;
    _isPaused = false;
    _isLooping = false;
    _stopwatch.stop();
    _stopwatch.reset();
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _currentMeasureIndex = -1;
    _currentElementIndex = -1;
    _currentTripletIndex = null;
    _nextEventIndex = 0;
    _loopStartMs = 0.0;
    notifyListeners();
  }

  /// Loop ad alta precisione (polling a 5 ms) per triggerare l'audio al tempo esatto.
  /// In modalità loop infinito, al termine di ogni ciclo avanza _loopStartMs di
  /// esattamente una durata-ciclo in millisecondi, azzerando _nextEventIndex.
  /// Questo evita qualsiasi drift tra un loop e il successivo.
  void _startSchedulerLoop() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;

    // Intervallo di polling a 5 ms per la massima precisione possibile
    _schedulerTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      final double msPerBeat = 60000.0 / _bpm;
      final double elapsedMs = _stopwatch.elapsedMilliseconds.toDouble();
      // Beat offset relativo all'inizio del ciclo corrente
      final double currentBeatOffset = (elapsedMs - _loopStartMs) / msPerBeat;

      // Riproduci tutti gli eventi programmati fino al beat attuale
      while (_nextEventIndex < _timeline.length &&
             _timeline[_nextEventIndex].beatOffset <= currentBeatOffset) {
        _executeEvent(_timeline[_nextEventIndex]);
        _nextEventIndex++;
      }

      // Fine del ciclo corrente
      if (currentBeatOffset >= _totalBeats) {
        if (_isLooping) {
          // Avanza l'ancoraggio del loop di esattamente una durata-ciclo.
          // NON resettiamo lo stopwatch: evitiamo così qualsiasi jitter/drift.
          _loopStartMs += _totalBeats * msPerBeat;
          _nextEventIndex = 0;
        } else {
          // Singolo ciclo: stop pulito
          timer.cancel();
          stop();
        }
      }
    });
  }

  /// Esegue un singolo evento di riproduzione: suona l'audio e notifica la UI per l'highlight.
  void _executeEvent(PlaybackEvent event) {
    if (event.isMetronome) {
      if (_isMetronomeEnabled) {
        if (event.isAccent) {
          _accentPool?.play();
        } else {
          _clickPool?.play();
        }
      }
    } else {
      // È una nota reale o una pausa
      if (!event.isRest && _soundInstrument != 'silent') {
        if (_soundInstrument == 'melodic') {
          _notePools[event.noteName]?.play();
        } else if (_soundInstrument == 'snare') {
          _snarePool?.play();
        } else {
          _stickPool?.play();
        }
      }
      
      // Aggiorna gli indici per l'evidenziazione grafica
      _currentMeasureIndex = event.measureIndex;
      _currentElementIndex = event.elementIndex;
      _currentTripletIndex = event.tripletIndex;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    _accentPool?.dispose();
    _clickPool?.dispose();
    _stickPool?.dispose();
    _snarePool?.dispose();
    for (final pool in _notePools.values) {
      pool.dispose();
    }
    super.dispose();
  }
}
