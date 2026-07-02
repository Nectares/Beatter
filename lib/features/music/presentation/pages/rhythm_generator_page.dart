import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../services/rhythm_generator_service.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../widgets/rhythm_staff_painter.dart';
import '../widgets/app_drawer.dart';

class RhythmGeneratorPage extends StatefulWidget {
  const RhythmGeneratorPage({super.key});

  @override
  State<RhythmGeneratorPage> createState() => _RhythmGeneratorPageState();
}

class _RhythmGeneratorPageState extends State<RhythmGeneratorPage> {
  // Servizi
  late RhythmPlaybackService _playbackService;
  List<RhythmMeasure> _generatedMeasures = [];

  // Controlli Configurazione
  int _bpm = 120;
  String _selectedTimeSignature = '4/4';
  int _measuresCount = 4;
  
  // Abilitazione Figure Ritmiche
  final Map<RhythmElementType, bool> _enabledFigures = {
    RhythmElementType.quarter: true,
    RhythmElementType.eighth: true,
    RhythmElementType.sixteenth: false,
    RhythmElementType.quarterRest: true,
    RhythmElementType.eighthRest: false,
    RhythmElementType.sixteenthRest: false,
    RhythmElementType.triplet: false,
  };

  // Controller UI e Scroll
  late TextEditingController _bpmTextController;
  final ScrollController _staffScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _playbackService = RhythmPlaybackService();
    _playbackService.updateSettings(bpm: _bpm);
    
    _bpmTextController = TextEditingController(text: _bpm.toString());

    // Ascolta gli aggiornamenti di riproduzione (highlight note e scroll automatico)
    _playbackService.addListener(_onPlaybackStateChanged);

    // Genera un ritmo iniziale predefinito
    _generateNewRhythm();
  }

  @override
  void dispose() {
    _playbackService.removeListener(_onPlaybackStateChanged);
    _playbackService.stop();
    _playbackService.dispose();
    _bpmTextController.dispose();
    _staffScrollController.dispose();
    super.dispose();
  }

  /// Gestore dei cambiamenti dello stato di riproduzione (timer audio/notifica UI)
  void _onPlaybackStateChanged() {
    if (!mounted) return;
    
    setState(() {});

    // Gestione dello scorrimento automatico (Auto-Scroll) sul pentagramma
    if (_playbackService.isPlaying && 
        _playbackService.currentMeasureIndex >= 0 && 
        _playbackService.currentElementIndex >= 0) {
      
      final double targetX = _calculateNoteXCoordinate(
        measureIndex: _playbackService.currentMeasureIndex,
        elementIndex: _playbackService.currentElementIndex,
      );

      final double screenWidth = MediaQuery.of(context).size.width;
      
      // Calcola l'offset di scroll desiderato per centrare la nota attiva sullo schermo
      double scrollOffset = targetX - (screenWidth / 2);
      
      // Limita lo scroll all'interno dei confini validi
      if (scrollOffset < 0) scrollOffset = 0.0;
      final maxScroll = _staffScrollController.position.maxScrollExtent;
      if (scrollOffset > maxScroll) scrollOffset = maxScroll;

      // Anima lo scorrimento del pentagramma in modo fluido a 60 FPS
      _staffScrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Calcola la coordinata X esatta di una nota sul pentagramma per l'auto-scroll.
  double _calculateNoteXCoordinate({required int measureIndex, required int elementIndex}) {
    // 20 (padding) + 45 (chiave) + 35 (tempo)
    double x = 100.0;
    
    // Somma la larghezza delle battute precedenti
    for (int m = 0; m < measureIndex; m++) {
      x += _getMeasureWidth(_generatedMeasures[m].timeSignature);
    }

    // Calcola l'offset all'interno della battuta corrente
    if (measureIndex < _generatedMeasures.length) {
      final measure = _generatedMeasures[measureIndex];
      final double measureWidth = _getMeasureWidth(measure.timeSignature);
      final double beatsPerMeasure = _getTargetBeats(measure.timeSignature);

      double elapsedBeats = 0.0;
      for (int e = 0; e < elementIndex; e++) {
        elapsedBeats += measure.elements[e].duration;
      }

      // Proporzione X all'interno della battuta
      x += (elapsedBeats / beatsPerMeasure) * (measureWidth - 30.0) + 15.0;
    }

    return x;
  }

  double _getMeasureWidth(String timeSig) {
    if (timeSig == '4/4') return 240.0;
    if (timeSig == '3/4') return 180.0;
    if (timeSig == '6/8') return 200.0;
    return 240.0;
  }

  double _getTargetBeats(String timeSig) {
    if (timeSig == '4/4') return 4.0;
    if (timeSig == '3/4') return 3.0;
    if (timeSig == '6/8') return 3.0;
    return 4.0;
  }

  /// Genera un nuovo ritmo valido.
  void _generateNewRhythm() {
    _playbackService.stop();

    final measures = RhythmGeneratorService.generate(
      timeSignature: _selectedTimeSignature,
      measuresCount: _measuresCount,
      enabledFigures: _enabledFigures,
    );

    setState(() {
      _generatedMeasures = measures;
    });

    // Invia la timeline degli eventi al riproduttore ad alta precisione
    _playbackService.preparePlayback(_generatedMeasures);
    
    // Resetta lo scorrimento del pentagramma all'inizio
    if (_staffScrollController.hasClients) {
      _staffScrollController.jumpTo(0.0);
    }
  }

  /// Sincronizza il BPM quando l'utente usa il tastierino numerico.
  void _onBpmTextChanged(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 40 && parsed <= 240) {
      setState(() {
        _bpm = parsed;
      });
      _playbackService.updateSettings(bpm: _bpm);
    }
  }

  /// Sincronizza il BPM quando l'utente trascina lo Slider.
  void _onBpmSliderChanged(double val) {
    setState(() {
      _bpm = val.toInt();
      _bpmTextController.text = _bpm.toString();
    });
    _playbackService.updateSettings(bpm: _bpm);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // Calcoliamo la larghezza totale del Canvas del pentagramma per permettere lo scorrimento
    double staffTotalWidth = 100.0; // Chiave + Tempo iniziali
    for (final measure in _generatedMeasures) {
      staffTotalWidth += _getMeasureWidth(measure.timeSignature);
    }
    staffTotalWidth += 40.0; // Spazio extra finale

    return Scaffold(
      // ── Left Navigation Drawer ───────────────────────────────────────────
      drawer: const AppDrawer(activeLabel: 'Rhythm Generator'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Random Rhythm Generator',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // Area impostazioni (superiore su mobile, laterale su tablet)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: isTablet
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // CONFIGURAZIONE TEMPO & BATTUTE
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildBpmSelectorCard(),
                                    const SizedBox(height: 16),
                                    _buildSignatureAndMeasuresCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // SELEZIONE FIGURE RITMICHE
                              Expanded(
                                child: _buildRhythmFiguresCard(),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CONFIGURAZIONE TEMPO & BATTUTE
                            _buildBpmSelectorCard(),
                            const SizedBox(height: 16),
                            _buildSignatureAndMeasuresCard(),
                            const SizedBox(height: 16),
                            // SELEZIONE FIGURE RITMICHE
                            _buildRhythmFiguresCard(),
                          ],
                        ),
                ),
              ),

              // AREA PENTAGRAMMA E CONTROLLI PLAYER (Ancorati in basso)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0E0),
                  border: Border(
                    top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Il Pentagramma Scorrevole
                    Container(
                      height: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          controller: _staffScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: CustomPaint(
                            size: Size(staffTotalWidth, 120),
                            painter: RhythmStaffPainter(
                              measures: _generatedMeasures,
                              activeMeasureIndex: _playbackService.currentMeasureIndex,
                              activeElementIndex: _playbackService.currentElementIndex,
                              activeTripletIndex: _playbackService.currentTripletIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pannello di Controllo Riproduzione
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          // Dropdown Strumento
                          _buildInstrumentSelector(),
                          const Spacer(),

                          // Controlli di Riproduzione
                          _buildPlaybackControls(),
                          const Spacer(),

                          // Interruttore Metronomo
                          _buildMetronomeToggle(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pulsante Genera
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _generateNewRhythm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryCyan,
                            shadowColor: AppTheme.secondaryCyan.withOpacity(0.3),
                            elevation: 8,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shuffle_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Text('GENERATE RHYTHM'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBpmSelectorCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCardDecoration(borderRadius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Velocità (BPM)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                  ),
                  // Campo numerico per sincronizzazione diretta
                  SizedBox(
                    width: 70,
                    height: 38,
                    child: TextField(
                      controller: _bpmTextController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        fillColor: const Color(0xFFFFF8F1),
                      ),
                      onChanged: _onBpmTextChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _bpm.toDouble(),
                min: 40,
                max: 240,
                activeColor: AppTheme.secondaryCyan,
                inactiveColor: AppTheme.cardBorder,
                onChanged: _onBpmSliderChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureAndMeasuresCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCardDecoration(borderRadius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metrica & Misure',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),

              // Time Signature Radio Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['4/4', '3/4', '6/8'].map((sig) {
                  final isSelected = _selectedTimeSignature == sig;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTimeSignature = sig;
                      });
                      _generateNewRhythm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryPurple : const Color(0xFFFFEAD6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryPurple : AppTheme.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        sig,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Divider(height: 24, color: AppTheme.cardBorder),

              // Selettore numero di battute
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Numero di battute', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  DropdownButton<int>(
                    value: _measuresCount,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    items: List.generate(16, (i) => i + 1).map((m) {
                      return DropdownMenuItem<int>(
                        value: m,
                        child: Text('  $m  '),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _measuresCount = val;
                        });
                        _generateNewRhythm();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRhythmFiguresCard() {
    final Map<RhythmElementType, String> figureLabels = {
      RhythmElementType.quarter: 'Quarter Notes (Semiminime)',
      RhythmElementType.eighth: 'Eighth Notes (Crome)',
      RhythmElementType.sixteenth: 'Sixteenth Notes (Semicrome)',
      RhythmElementType.quarterRest: 'Quarter Rests (Pause 1/4)',
      RhythmElementType.eighthRest: 'Eighth Rests (Pause 1/8)',
      RhythmElementType.sixteenthRest: 'Sixteenth Rests (Pause 1/16)',
      RhythmElementType.triplet: 'Triplets (Terzine)',
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCardDecoration(borderRadius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Figure Ritmiche Abilitate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              
              ...figureLabels.keys.map((type) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    unselectedWidgetColor: AppTheme.textMuted,
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      figureLabels[type]!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    value: _enabledFigures[type],
                    activeColor: AppTheme.secondaryCyan,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _enabledFigures[type] = val;
                        });
                        _generateNewRhythm();
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstrumentSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAD6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButton<String>(
        value: _playbackService.soundInstrument,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        items: const [
          DropdownMenuItem(value: 'snare', child: Text('🥁 Rullante')),
          DropdownMenuItem(value: 'stick', child: Text('🥖 Bacchetta')),
        ],
        onChanged: (val) {
          if (val != null) {
            _playbackService.updateSettings(soundInstrument: val);
          }
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final bool isPlaying = _playbackService.isPlaying;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsante STOP
        IconButton(
          icon: const Icon(Icons.stop_rounded, color: AppTheme.textSecondary, size: 28),
          onPressed: () {
            _playbackService.stop();
          },
        ),
        const SizedBox(width: 8),

        // Pulsante PLAY / PAUSE
        GestureDetector(
          onTap: () {
            if (isPlaying) {
              _playbackService.pause();
            } else {
              _playbackService.play();
            }
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? AppTheme.accentPink : AppTheme.secondaryCyan,
              boxShadow: [
                BoxShadow(
                  color: (isPlaying ? AppTheme.accentPink : AppTheme.secondaryCyan).withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetronomeToggle() {
    final bool isMetronomeOn = _playbackService.isMetronomeEnabled;
    return GestureDetector(
      onTap: () {
        _playbackService.updateSettings(isMetronomeEnabled: !isMetronomeOn);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMetronomeOn ? AppTheme.primaryPurple.withOpacity(0.2) : const Color(0xFFFFEAD6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMetronomeOn ? AppTheme.primaryPurple : AppTheme.cardBorder,
            width: 1.5,
          ),
        ),
        child: Icon(
          isMetronomeOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: isMetronomeOn ? AppTheme.primaryPurple : AppTheme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
