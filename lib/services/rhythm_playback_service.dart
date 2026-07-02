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

  PlaybackEvent({
    required this.beatOffset,
    required this.measureIndex,
    required this.elementIndex,
    this.tripletIndex,
    this.isMetronome = false,
    this.isAccent = false,
    this.isRest = false,
    required this.noteType,
  });
}

/// Gestore del pool di player audio per evitare tagli di campioni in decadimento.
class AudioPlayerPool {
  final String assetPath;
  final int size;
  final List<AudioPlayer> _pool = [];
  int _nextIndex = 0;

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
  String _soundInstrument = 'snare'; // 'snare' o 'stick'

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

  RhythmPlaybackService() {
    _initAudioPools();
  }

  void _initAudioPools() {
    _accentPool = AudioPlayerPool(assetPath: 'audio/metronome_accent.wav', size: 2);
    _clickPool = AudioPlayerPool(assetPath: 'audio/metronome_click.wav', size: 3);
    _stickPool = AudioPlayerPool(assetPath: 'audio/stick.wav', size: 3);
    _snarePool = AudioPlayerPool(assetPath: 'audio/snare.wav', size: 4);
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
      if (timeSig == '4/4') {
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
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, tripletIndex: 0, noteType: element.type));
          _timeline.add(PlaybackEvent(beatOffset: currentBeat + 1.0 / 3.0, measureIndex: m, elementIndex: e, tripletIndex: 1, noteType: element.type));
          _timeline.add(PlaybackEvent(beatOffset: currentBeat + 2.0 / 3.0, measureIndex: m, elementIndex: e, tripletIndex: 2, noteType: element.type));
        } else if (element.isRest) {
          // Evento silenzioso solo per notificare l'interfaccia dell'evidenziazione
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, isRest: true, noteType: element.type));
        } else {
          // Nota singola (quarter, eighth, sixteenth)
          _timeline.add(PlaybackEvent(beatOffset: currentBeat, measureIndex: m, elementIndex: e, noteType: element.type));
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
  void prepareSlotPlayback(List<RhythmSlot> slots, String timeSignature) {
    _timeline.clear();
    
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final double slotBeatOffset = i.toDouble();

      // 1. Aggiungi i click del metronomo su ciascun movimento
      final bool isAccent = (timeSignature == '4/4' && i % 4 == 0) ||
                            (timeSignature == '3/4' && i % 3 == 0) ||
                            (timeSignature == '6/8' && i % 6 == 0);

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
      if (!event.isRest) {
        if (_soundInstrument == 'snare') {
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
    super.dispose();
  }
}
