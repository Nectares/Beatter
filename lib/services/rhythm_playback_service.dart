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

  // Getters
  int get bpm => _bpm;
  bool get isMetronomeEnabled => _isMetronomeEnabled;
  String get soundInstrument => _soundInstrument;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
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

  /// Avvia la riproduzione.
  void play() {
    if (_timeline.isEmpty) return;
    
    if (_isPaused) {
      _isPaused = false;
      _isPlaying = true;
      _stopwatch.start();
      _startSchedulerLoop();
      notifyListeners();
      return;
    }

    _isPlaying = true;
    _isPaused = false;
    _nextEventIndex = 0;
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

  /// Ferma la riproduzione.
  void stop() {
    _isPlaying = false;
    _isPaused = false;
    _stopwatch.stop();
    _stopwatch.reset();
    _schedulerTimer?.cancel();
    _currentMeasureIndex = -1;
    _currentElementIndex = -1;
    _currentTripletIndex = null;
    _nextEventIndex = 0;
    notifyListeners();
  }

  /// Loop ad alta precisione (sub-millisecondo tramite polling a 5ms) per triggerare l'audio al tempo esatto.
  void _startSchedulerLoop() {
    _schedulerTimer?.cancel();
    
    // Intervallo di controllo a 5 millisecondi per la massima precisione possibile
    _schedulerTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      final double elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      final double secondsPerBeat = 60.0 / _bpm;
      final double currentBeatOffset = elapsedSeconds / secondsPerBeat;

      // Riproduci tutti gli eventi programmati fino al beat attuale
      while (_nextEventIndex < _timeline.length && 
             _timeline[_nextEventIndex].beatOffset <= currentBeatOffset) {
        
        final event = _timeline[_nextEventIndex];
        _executeEvent(event);
        _nextEventIndex++;
      }

      // Se abbiamo superato la fine del brano, fermiamo la riproduzione
      if (currentBeatOffset >= _totalBeats) {
        stop();
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
