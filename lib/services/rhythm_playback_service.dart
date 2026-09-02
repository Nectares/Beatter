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

  /// I suoni di metronomo selezionabili, ognuno con la sua coppia di
  /// campioni: accento (primo movimento) e click (movimenti deboli). Il
  /// motore non sa nient'altro dei due suoni, quindi aggiungerne un terzo è
  /// solo questione di generare i WAV (`generate_audio_assets.dart`),
  /// dichiararli in pubspec.yaml e aggiungere una voce qui.
  static const Map<String, ({String accent, String click})> metronomeSounds = {
    'classic': (
      accent: 'audio/metronome_accent.wav',
      click: 'audio/metronome_click.wav',
    ),
    'beatter': (
      accent: 'audio/beatter_beep_accent.wav',
      click: 'audio/beatter_beep_click.wav',
    ),
  };

  static const String defaultMetronomeSound = 'classic';

  String _metronomeSound = defaultMetronomeSound;

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
  //
  // Il metronomo ha una coppia di pool per ogni suono di
  // [metronomeSounds], creata alla prima selezione e poi tenuta in cache:
  // pre-caricare il suono al cambio di impostazione (e non al primo tick)
  // evita che il primo click arrivi in ritardo.
  final Map<String, ({AudioPlayerPool accent, AudioPlayerPool click})>
      _metronomePools = {};
  AudioPlayerPool? _stickPool;
  AudioPlayerPool? _snarePool;

  // Gemelli a volume pieno di stick/snare, usati per le note accentate. I
  // campioni sono già quasi a fondo scala: un accento non può suonare "più
  // forte", quindi è il resto a farsi più piano (vedi _applyVolumes),
  // e servono due pool perché cambiare volume sul singolo colpo vorrebbe
  // dire una chiamata di piattaforma asincrona proprio sull'attacco.
  AudioPlayerPool? _stickAccentPool;
  AudioPlayerPool? _snareAccentPool;

  /// Quanto scendono le note non accentate quando il pattern ha almeno un
  /// accento. Senza accenti il fattore è 1.0 e non cambia nulla.
  static const double _unaccentedFactor = 0.62;

  // Volumi impostabili dall'utente (1.0 = massimo, il default).
  double _metronomeVolume = 1.0;
  double _noteVolume = 1.0;

  /// Se il pattern preparato ha almeno un accento: decide se attenuare le
  /// note normali rispetto a quelle accentate.
  bool _patternHasAccents = false;

  /// Ultimo stato applicato ai player, per non ripetere le chiamate di
  /// piattaforma a ogni `prepare` (con l'auto-generazione attiva il Flow
  /// Mode ne fa una a ogni giro).
  (double, double, bool)? _appliedVolumes;
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
  String get metronomeSound => _metronomeSound;
  double get metronomeVolume => _metronomeVolume;
  double get noteVolume => _noteVolume;
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
    _ensureMetronomePools(_metronomeSound);
    _stickPool = AudioPlayerPool(assetPath: 'audio/stick.wav', size: 3);
    _snarePool = AudioPlayerPool(assetPath: 'audio/snare.wav', size: 4);
    // Gli accenti sono radi: due player a testa bastano.
    _stickAccentPool = AudioPlayerPool(assetPath: 'audio/stick.wav', size: 2);
    _snareAccentPool = AudioPlayerPool(assetPath: 'audio/snare.wav', size: 2);

    if (_enableMelodicPlayback) {
      for (final noteName in _melodicNoteNames) {
        _notePools[noteName] = AudioPlayerPool(assetPath: 'audio/notes/$noteName.wav', size: 2);
      }
    }

    _appliedVolumes = null;
    _applyVolumes();
  }

  void _ensureMetronomePools(String sound) {
    final samples = metronomeSounds[sound];
    if (samples == null) return;
    final int before = _metronomePools.length;
    _metronomePools.putIfAbsent(
      sound,
      () => (
        accent: AudioPlayerPool(assetPath: samples.accent, size: 2),
        click: AudioPlayerPool(assetPath: samples.click, size: 3),
      ),
    );
    // I pool nuovi nascono a volume pieno: allineali all'impostazione
    // corrente, altrimenti cambiare suono rialzerebbe il metronomo.
    if (_metronomePools.length != before) {
      _appliedVolumes = null;
      _applyVolumes();
    }
  }

  /// Porta i volumi impostati (e il rapporto fra note accentate e non) sui
  /// player. Chiamata al `prepare` e al cambio di impostazione, mai sul
  /// singolo colpo: `setVolume` è una chiamata di piattaforma e non deve
  /// capitare sull'attacco della nota.
  void _applyVolumes() {
    final state = (_metronomeVolume, _noteVolume, _patternHasAccents);
    if (_appliedVolumes == state) return;
    _appliedVolumes = state;

    for (final pools in _metronomePools.values) {
      pools.accent.setVolume(_metronomeVolume);
      pools.click.setVolume(_metronomeVolume);
    }

    // L'accento non può salire sopra il volume impostato (i campioni sono
    // già quasi a fondo scala): sono le note normali a scendere.
    final double unaccented =
        _noteVolume * (_patternHasAccents ? _unaccentedFactor : 1.0);
    _stickPool?.setVolume(unaccented);
    _snarePool?.setVolume(unaccented);
    _stickAccentPool?.setVolume(_noteVolume);
    _snareAccentPool?.setVolume(_noteVolume);
    for (final pool in _notePools.values) {
      pool.setVolume(_noteVolume);
    }
  }

  void _setPatternHasAccents(bool hasAccents) {
    _patternHasAccents = hasAccents;
    _applyVolumes();
  }

  void updateSettings({
    int? bpm,
    bool? isMetronomeEnabled,
    String? metronomeSound,
    double? metronomeVolume,
    double? noteVolume,
    String? soundInstrument,
    bool? echoGuideEnabled,
  }) {
    if (bpm != null) _bpm = bpm;
    if (isMetronomeEnabled != null) _isMetronomeEnabled = isMetronomeEnabled;
    // Un id sconosciuto (impostazione vecchia o salvata da una versione
    // futura) viene ignorato: meglio restare sul suono corrente che
    // ritrovarsi il metronomo muto.
    if (metronomeSound != null && metronomeSounds.containsKey(metronomeSound)) {
      _metronomeSound = metronomeSound;
      _ensureMetronomePools(metronomeSound);
    }
    if (metronomeVolume != null) {
      _metronomeVolume = metronomeVolume.clamp(0.0, 1.0);
    }
    if (noteVolume != null) _noteVolume = noteVolume.clamp(0.0, 1.0);
    if (metronomeVolume != null || noteVolume != null) _applyVolumes();
    if (soundInstrument != null) _soundInstrument = soundInstrument;
    if (echoGuideEnabled != null) _echoGuideEnabled = echoGuideEnabled;
    notifyListeners();
  }

  /// Feedback sonoro del tap dell'utente durante la finestra di eco del
  /// Reading Mode (bacchetta, indipendente dallo strumento delle note).
  void playTap() => _stickPool?.play();

  /// Fa sentire l'accento del metronomo selezionato: sceglierne uno dalle
  /// impostazioni senza poterlo ascoltare sarebbe alla cieca.
  void previewMetronomeSound() =>
      _metronomePools[_metronomeSound]?.accent.play();

  /// Costruisce la timeline esatta degli eventi in base al ritmo generato.
  ///
  /// Con [echoEveryMeasures] attivo (Reading Mode) l'esecuzione si ferma
  /// ogni N battute: dopo ogni gruppo viene inserita una finestra di eco
  /// della stessa durata in cui l'app tace le note (le rifà l'utente) ma il
  /// metronomo continua e gli eventi-guida evidenziano le figurazioni al
  /// momento giusto.
  void preparePlayback(List<RhythmMeasure> measures, {int? echoEveryMeasures}) {
    // Gli accenti sulle note esistono solo nelle tessere del Flow Mode: qui
    // le note tornano tutte allo stesso volume.
    _setPatternHasAccents(false);
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
  /// Costruzione pura della timeline del Flow Mode: una tessera per
  /// movimento, col click del metronomo e le note (o pause) interne.
  ///
  /// Una tessera accentata marca `isAccent` sul click — che così usa il
  /// campione accentato del metronomo — e sulla nota del tempo forte, che
  /// suona a volume pieno mentre le altre restano attenuate. Se il tempo
  /// forte è una pausa non c'è niente da accentare e resta accentato solo
  /// il click.
  static (List<PlaybackEvent>, double) buildSlotTimeline(
    List<RhythmSlot> slots,
  ) {
    final events = <PlaybackEvent>[];

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final double slotBeatOffset = i.toDouble();

      // 1. Click del metronomo sul movimento.
      events.add(PlaybackEvent(
        beatOffset: slotBeatOffset,
        measureIndex: 0,
        elementIndex: -1,
        isMetronome: true,
        isAccent: slot.isAccented,
        noteType: RhythmElementType.quarter,
      ));

      // 2. Note all'interno del movimento.
      double subBeatOffset = 0.0;
      for (int noteIdx = 0; noteIdx < slot.noteDurations.length; noteIdx++) {
        final double noteDuration = slot.noteDurations[noteIdx];
        final bool isRest = slot.isRestList[noteIdx];

        events.add(PlaybackEvent(
          beatOffset: slotBeatOffset + subBeatOffset,
          measureIndex: 0,
          elementIndex: i, // L'indice della tessera
          isRest: isRest,
          isAccent: slot.isAccented && noteIdx == 0 && !isRest,
          noteType: RhythmElementType.quarter,
        ));

        subBeatOffset += noteDuration;
      }
    }

    events.sort((a, b) => a.beatOffset.compareTo(b.beatOffset));
    return (events, slots.length.toDouble());
  }

  void prepareSlotPlayback(List<RhythmSlot> slots) {
    final (events, totalBeats) = buildSlotTimeline(slots);
    _timeline
      ..clear()
      ..addAll(events);
    _totalBeats = totalBeats;
    _nextEventIndex = 0;
    _setPatternHasAccents(slots.any((slot) => slot.isAccented));
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

          // Ricalcola subito il beat offset nel nuovo frame di riferimento
          // e spara immediatamente gli eventi già scaduti nel nuovo ciclo.
          // Senza questo secondo pass, il primo evento del ciclo N+1 verrebbe
          // ritardato fino al prossimo tick del timer (~5 ms), creando un
          // micro-stutter percepibile — specialmente con 5+ slot dove la
          // durata del ciclo non è un multiplo esatto dell'intervallo di polling.
          final double newBeatOffset = (elapsedMs - _loopStartMs) / msPerBeat;
          while (_nextEventIndex < _timeline.length &&
                 _timeline[_nextEventIndex].beatOffset <= newBeatOffset) {
            _executeEvent(_timeline[_nextEventIndex]);
            _nextEventIndex++;
          }
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
        final pools = _metronomePools[_metronomeSound];
        if (event.isAccent) {
          pools?.accent.play();
        } else {
          pools?.click.play();
        }
      }
    } else {
      // È una nota reale, una pausa, o un evento-guida di eco (silenzioso:
      // il ritmo in quella finestra lo rifà l'utente).
      if (!event.isRest && !event.isEcho && _soundInstrument != 'silent') {
        if (_soundInstrument == 'melodic') {
          _notePools[event.noteName]?.play();
        } else if (_soundInstrument == 'snare') {
          (event.isAccent ? _snareAccentPool : _snarePool)?.play();
        } else {
          (event.isAccent ? _stickAccentPool : _stickPool)?.play();
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
    for (final pools in _metronomePools.values) {
      pools.accent.dispose();
      pools.click.dispose();
    }
    _stickPool?.dispose();
    _snarePool?.dispose();
    _stickAccentPool?.dispose();
    _snareAccentPool?.dispose();
    for (final pool in _notePools.values) {
      pool.dispose();
    }
    super.dispose();
  }
}
