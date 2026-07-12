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

  /// True per gli eventi della finestra di eco del Reading Mode: l'app non
  /// suona la nota (deve rifarla l'utente) ma l'evidenziazione avanza per
  /// fare da guida visiva.
  final bool isEcho;
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
    this.isEcho = false,
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

  /// True mentre scorre una finestra di eco del Reading Mode (l'utente sta
  /// ripetendo il ritmo). La UI la usa per cambiare colore alla guida.
  bool _isEchoPhase = false;

  /// Se false, durante l'eco l'evidenziazione-guida resta spenta (modalità
  /// "da solo": l'utente ripete a memoria senza aiuti visivi).
  bool _echoGuideEnabled = true;

  // ── Punteggio Reading Mode ────────────────────────────────────────────
  // Ogni onset di nota nelle finestre di eco è un bersaglio: un tap entro
  // ±[_tapWindowMs] lo colpisce ("good", una volta sola); i tap a vuoto
  // durante l'eco e i bersagli scaduti senza tap sono "miss" e azzerano la
  // strike (serie di good consecutivi).
  static const double _tapWindowMs = 160.0;

  List<double> _echoTargetBeats = [];
  List<bool> _echoTargetDone = [];
  int _echoExpiryIndex = 0;
  int _echoGood = 0;
  int _echoMiss = 0;
  int _echoStreak = 0;
  int _echoBestStreak = 0;

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
  bool get isEchoPhase => _isEchoPhase;
  bool get echoGuideEnabled => _echoGuideEnabled;

  // Punteggio Reading Mode della sessione corrente.
  int get echoGood => _echoGood;
  int get echoMiss => _echoMiss;
  int get echoStreak => _echoStreak;
  int get echoBestStreak => _echoBestStreak;
  int get echoScore => _echoGood * 10;
  bool get hasEchoTargets => _echoTargetBeats.isNotEmpty;

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

  void updateSettings({
    int? bpm,
    bool? isMetronomeEnabled,
    String? soundInstrument,
    bool? echoGuideEnabled,
  }) {
    if (bpm != null) _bpm = bpm;
    if (isMetronomeEnabled != null) _isMetronomeEnabled = isMetronomeEnabled;
    if (soundInstrument != null) _soundInstrument = soundInstrument;
    if (echoGuideEnabled != null) _echoGuideEnabled = echoGuideEnabled;
    notifyListeners();
  }

  /// Feedback sonoro del tap dell'utente durante la finestra di eco del
  /// Reading Mode (bacchetta, indipendente dallo strumento delle note).
  void playTap() => _stickPool?.play();

  /// Costruisce la timeline esatta degli eventi in base al ritmo generato.
  ///
  /// Con [echoEveryMeasures] attivo (Reading Mode) l'esecuzione si ferma
  /// ogni N battute: dopo ogni gruppo viene inserita una finestra di eco
  /// della stessa durata in cui l'app tace le note (le rifà l'utente) ma il
  /// metronomo continua e gli eventi-guida evidenziano le figurazioni al
  /// momento giusto.
  void preparePlayback(List<RhythmMeasure> measures, {int? echoEveryMeasures}) {
    final (events, totalBeats) =
        buildTimeline(measures, echoEveryMeasures: echoEveryMeasures);
    _timeline
      ..clear()
      ..addAll(events);
    _totalBeats = totalBeats;
    _nextEventIndex = 0;

    _echoTargetBeats = echoTapTargets(events);
    _echoTargetDone = List<bool>.filled(_echoTargetBeats.length, false);
    _echoExpiryIndex = 0;
    _echoGood = 0;
    _echoMiss = 0;
    _echoStreak = 0;
    _echoBestStreak = 0;
  }

  /// I bersagli del punteggio Reading Mode: gli onset delle note (non
  /// pause, non metronomo) delle finestre di eco. Pura, per i test.
  static List<double> echoTapTargets(List<PlaybackEvent> events) => [
        for (final e in events)
          if (e.isEcho && !e.isMetronome && !e.isRest) e.beatOffset,
      ];

  /// Giudica un tap dell'utente contro i bersagli di eco: true se ha
  /// colpito un onset entro la finestra (good), false se è un miss o un
  /// tap fuori dalle finestre di eco (ignorato, nessuna penalità).
  bool registerEchoTap() {
    if (!_isPlaying || _echoTargetBeats.isEmpty) return false;

    final double msPerBeat = 60000.0 / _bpm;
    final double now =
        (_stopwatch.elapsedMilliseconds - _loopStartMs) / msPerBeat;
    final double windowBeats = _tapWindowMs / msPerBeat;

    // Bersaglio libero più vicino entro la finestra.
    int best = -1;
    double bestDelta = double.infinity;
    for (int i = _echoExpiryIndex; i < _echoTargetBeats.length; i++) {
      if (_echoTargetBeats[i] - now > windowBeats) break;
      final double delta = (_echoTargetBeats[i] - now).abs();
      if (!_echoTargetDone[i] && delta <= windowBeats && delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }

    if (best != -1) {
      _echoTargetDone[best] = true;
      _echoGood++;
      _echoStreak++;
      if (_echoStreak > _echoBestStreak) _echoBestStreak = _echoStreak;
      notifyListeners();
      return true;
    }

    if (_isEchoPhase) {
      // Tap a vuoto mentre toccava all'utente: penalizza.
      _echoMiss++;
      _echoStreak = 0;
      notifyListeners();
    }
    return false;
  }

  /// Marca come miss i bersagli scaduti senza tap (chiamato dallo
  /// scheduler man mano che il tempo avanza).
  void _expireEchoTargets(double currentBeatOffset) {
    if (_echoExpiryIndex >= _echoTargetBeats.length) return;
    final double windowBeats = _tapWindowMs / (60000.0 / _bpm);
    bool changed = false;
    while (_echoExpiryIndex < _echoTargetBeats.length &&
        _echoTargetBeats[_echoExpiryIndex] + windowBeats < currentBeatOffset) {
      if (!_echoTargetDone[_echoExpiryIndex]) {
        _echoMiss++;
        _echoStreak = 0;
        changed = true;
      }
      _echoExpiryIndex++;
    }
    if (changed) notifyListeners();
  }

  /// Costruzione pura della timeline (statica e senza audio: testabile
  /// senza istanziare i pool di player).
  static (List<PlaybackEvent>, double) buildTimeline(
    List<RhythmMeasure> measures, {
    int? echoEveryMeasures,
  }) {
    final events = <PlaybackEvent>[];
    double currentBeat = 0.0;

    if (echoEveryMeasures == null) {
      for (int m = 0; m < measures.length; m++) {
        _addMeasureEvents(events, m, measures[m], currentBeat, isEcho: false);
        currentBeat += measures[m].totalDuration;
      }
    } else {
      final int n = echoEveryMeasures < 1 ? 1 : echoEveryMeasures;
      int start = 0;
      while (start < measures.length) {
        final int end =
            (start + n < measures.length) ? start + n : measures.length;
        for (int m = start; m < end; m++) {
          final measure = measures[m];
          _addMeasureEvents(events, m, measure, currentBeat, isEcho: false);
          currentBeat += measure.totalDuration;
        }
        for (int m = start; m < end; m++) {
          final measure = measures[m];
          _addMeasureEvents(events, m, measure, currentBeat, isEcho: true);
          currentBeat += measure.totalDuration;
        }
        start = end;
      }
    }

    events.sort((a, b) => a.beatOffset.compareTo(b.beatOffset));
    return (events, currentBeat);
  }

  /// Emette metronomo + note/pause di [measure] a partire da [startBeat].
  /// Con [isEcho] le note diventano eventi-guida silenziosi (il metronomo
  /// resta udibile, soggetto al toggle del metronomo).
  static void _addMeasureEvents(
    List<PlaybackEvent> events,
    int m,
    RhythmMeasure measure,
    double startBeat, {
    required bool isEcho,
  }) {
    final timeSig = measure.timeSignature;

    // 1. Click del metronomo: uno per movimento del metro.
    final List<double> clickOffsets = switch (timeSig) {
      '2/4' => const [0.0, 1.0],
      '3/4' => const [0.0, 1.0, 2.0],
      // Metronomo in 6/8: due movimenti principali (croma puntata = 1.5).
      '6/8' => const [0.0, 1.5],
      _ => const [0.0, 1.0, 2.0, 3.0],
    };
    for (int c = 0; c < clickOffsets.length; c++) {
      events.add(PlaybackEvent(
        beatOffset: startBeat + clickOffsets[c],
        measureIndex: m,
        elementIndex: -1,
        isMetronome: true,
        isAccent: c == 0,
        noteType: RhythmElementType.quarter,
      ));
    }

    // 2. Note/pause del ritmo.
    double currentBeat = startBeat;
    for (int e = 0; e < measure.elements.length; e++) {
      final element = measure.elements[e];

      if (element.type == RhythmElementType.triplet) {
        // Terzina: 3 note equidistanti che riempiono 1 battito
        for (int t = 0; t < 3; t++) {
          events.add(PlaybackEvent(
            beatOffset: currentBeat + t / 3.0,
            measureIndex: m,
            elementIndex: e,
            tripletIndex: t,
            isEcho: isEcho,
            noteType: element.type,
            noteName: element.tripletNotes[t],
          ));
        }
      } else if (element.type == RhythmElementType.beatGroup) {
        // Gruppo da 1 battito (terzine variate, quintine, sestine,
        // biscrome…): un evento per membro al suo offset esatto; i membri
        // di pausa restano eventi silenziosi per l'highlight.
        double memberOffset = 0.0;
        for (int g = 0; g < element.groupDurations.length; g++) {
          events.add(PlaybackEvent(
            beatOffset: currentBeat + memberOffset,
            measureIndex: m,
            elementIndex: e,
            tripletIndex: g,
            isRest: element.groupRests[g],
            isEcho: isEcho,
            noteType: element.type,
            noteName: element.noteName,
          ));
          memberOffset += element.groupDurations[g];
        }
      } else if (element.isRest) {
        // Evento silenzioso solo per notificare l'interfaccia dell'evidenziazione
        events.add(PlaybackEvent(
          beatOffset: currentBeat,
          measureIndex: m,
          elementIndex: e,
          isRest: true,
          isEcho: isEcho,
          noteType: element.type,
        ));
      } else {
        // Nota singola (quarter, eighth, sixteenth…)
        events.add(PlaybackEvent(
          beatOffset: currentBeat,
          measureIndex: m,
          elementIndex: e,
          isEcho: isEcho,
          noteType: element.type,
          noteName: element.noteName,
        ));
      }

      currentBeat += element.duration;
    }
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

  /// Avvia la riproduzione. Con [loop] attivo (default) ripete all'infinito;
  /// con [loop] disattivo esegue un singolo passaggio e si ferma da sola
  /// alla fine (usato dagli esercizi di lettura di Sheet Mode).
  void play({bool loop = true}) {
    if (_timeline.isEmpty) return;

    // Evita doppio play: se già in esecuzione non fare nulla
    if (_isPlaying && !_isPaused) return;

    if (_isPaused) {
      // Resume dalla pausa: riprende dallo stesso punto
      _isPaused = false;
      _isPlaying = true;
      _isLooping = loop;
      _stopwatch.start();
      _startSchedulerLoop();
      notifyListeners();
      return;
    }

    // Avvio da zero
    _isPlaying = true;
    _isPaused = false;
    _isLooping = loop;
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
    _isEchoPhase = false;
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

      // Punteggio Reading Mode: i bersagli non tappati in tempo scadono.
      _expireEchoTargets(currentBeatOffset);

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
      // È una nota reale, una pausa, o un evento-guida di eco (silenzioso:
      // il ritmo in quella finestra lo rifà l'utente).
      if (!event.isRest && !event.isEcho && _soundInstrument != 'silent') {
        if (_soundInstrument == 'melodic') {
          _notePools[event.noteName]?.play();
        } else if (_soundInstrument == 'snare') {
          _snarePool?.play();
        } else {
          _stickPool?.play();
        }
      }

      _isEchoPhase = event.isEcho;

      // Aggiorna gli indici per l'evidenziazione grafica. In eco la guida
      // si accende solo se l'utente ripete col tap sullo schermo; in
      // modalità "da solo" resta spenta.
      if (event.isEcho && !_echoGuideEnabled) {
        _currentMeasureIndex = -1;
        _currentElementIndex = -1;
        _currentTripletIndex = null;
      } else {
        _currentMeasureIndex = event.measureIndex;
        _currentElementIndex = event.elementIndex;
        _currentTripletIndex = event.tripletIndex;
      }
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
