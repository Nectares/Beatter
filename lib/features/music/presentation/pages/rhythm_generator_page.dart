import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_pattern.dart';
import '../../../../services/pattern_repository.dart';

class RhythmGeneratorPage extends StatefulWidget {
  const RhythmGeneratorPage({super.key});

  @override
  State<RhythmGeneratorPage> createState() => _RhythmGeneratorPageState();
}

class _RhythmGeneratorPageState extends State<RhythmGeneratorPage> with SingleTickerProviderStateMixin {
  final List<RhythmPattern> _availablePatterns = PatternRepository().patterns;
  RhythmPattern? _selectedPattern;

  // Sequencer State
  late List<bool> _beats;
  late List<String> _notes;
  int _bpm = 120;
  double _baseFrequency = 440.0;
  
  bool _isPlaying = false;
  int _currentStep = -1;
  Timer? _sequencerTimer;

  // Wave Visualizer Animation
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // Default to the first pattern
    if (_availablePatterns.isNotEmpty) {
      _selectedPattern = _availablePatterns.first;
      _loadPattern(_selectedPattern!);
    } else {
      _beats = List.generate(16, (_) => false);
      _notes = List.generate(16, (_) => 'C4');
    }

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _sequencerTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _loadPattern(RhythmPattern pattern) {
    setState(() {
      _beats = List<bool>.from(pattern.beats);
      _notes = List<String>.from(pattern.notes);
      _bpm = pattern.bpm;
      _baseFrequency = pattern.baseFrequency;
      if (_isPlaying) {
        _stopSequencer();
        _startSequencer();
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startSequencer();
        _waveController.repeat();
      } else {
        _stopSequencer();
        _waveController.stop();
      }
    });
  }

  void _startSequencer() {
    final intervalMs = (60000 / _bpm / 4).round(); // 16th notes
    _sequencerTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      setState(() {
        _currentStep = (_currentStep + 1) % 16;
        // Trigger sound simulation or pulse animation
      });
    });
  }

  void _stopSequencer() {
    _sequencerTimer?.cancel();
    setState(() {
      _currentStep = -1;
    });
  }

  void _updateBpm(int newBpm) {
    setState(() {
      _bpm = newBpm;
      if (_isPlaying) {
        _stopSequencer();
        _startSequencer();
      }
    });
  }

  void _randomizeNotes() {
    final scale = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'G5', 'A5'];
    final rand = math.Random();
    setState(() {
      for (int i = 0; i < 16; i++) {
        _notes[i] = scale[rand.nextInt(scale.length)];
      }
    });
  }

  void _randomizeRhythm() {
    final rand = math.Random();
    setState(() {
      for (int i = 0; i < 16; i++) {
        _beats[i] = rand.nextBool();
      }
    });
  }

  void _toggleStep(int index) {
    setState(() {
      _beats[index] = !_beats[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Generatore Automatico', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pattern Selector Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scegli o Carica Ritmica',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<RhythmPattern>(
                            value: _selectedPattern,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              fillColor: Colors.black.withOpacity(0.2),
                            ),
                            items: _availablePatterns.map((pat) {
                              return DropdownMenuItem<RhythmPattern>(
                                value: pat,
                                child: Text(pat.name),
                              );
                            }).toList(),
                            onChanged: (pat) {
                              if (pat != null) {
                                setState(() {
                                  _selectedPattern = pat;
                                });
                                _loadPattern(pat);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Oscilloscope Wave Visualizer
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: WavePainter(
                            animationValue: _waveController.value,
                            isPlaying: _isPlaying,
                            bpm: _bpm,
                            frequency: _baseFrequency,
                            currentStep: _currentStep,
                            beats: _beats,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Playback and Speed Controls
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Play Pause Button
                              ElevatedButton.icon(
                                onPressed: _togglePlay,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPlaying ? AppTheme.accentPink : AppTheme.secondaryCyan,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                label: Text(_isPlaying ? 'PAUSA' : 'RIPRODUCI'),
                              ),
                            ],
                          ),
                          const Divider(height: 30, color: AppTheme.cardBorder),
                          // BPM Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tempo (BPM)', style: TextStyle(color: AppTheme.textSecondary)),
                              Text('$_bpm BPM', style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _bpm.toDouble(),
                            min: 60,
                            max: 200,
                            activeColor: AppTheme.primaryPurple,
                            inactiveColor: AppTheme.cardBorder,
                            onChanged: (val) => _updateBpm(val.toInt()),
                          ),
                          // Frequency Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Frequenza Base', style: TextStyle(color: AppTheme.textSecondary)),
                              Text('${_baseFrequency.toStringAsFixed(1)} Hz', style: const TextStyle(color: AppTheme.secondaryCyan, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _baseFrequency,
                            min: 100,
                            max: 1000,
                            activeColor: AppTheme.secondaryCyan,
                            inactiveColor: AppTheme.cardBorder,
                            onChanged: (val) {
                              setState(() {
                                _baseFrequency = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Randomizers & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sequencer Ritmico',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _randomizeRhythm,
                          icon: const Icon(Icons.shuffle_rounded, size: 16, color: AppTheme.secondaryCyan),
                          label: const Text('Ritmica', style: TextStyle(color: AppTheme.secondaryCyan, fontSize: 12)),
                        ),
                        TextButton.icon(
                          onPressed: _randomizeNotes,
                          icon: const Icon(Icons.music_note_rounded, size: 16, color: AppTheme.primaryPurple),
                          label: const Text('Note', style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Interactive 16-Step Sequencer
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    final isActive = _beats[index];
                    final isCurrent = _currentStep == index;
                    final note = _notes[index];

                    return GestureDetector(
                      onTap: () => _toggleStep(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          color: isCurrent 
                              ? (isActive ? AppTheme.accentPink : AppTheme.secondaryCyan.withOpacity(0.3))
                              : (isActive ? AppTheme.primaryPurple : Colors.black.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent 
                                ? Colors.white 
                                : (isActive ? AppTheme.primaryPurple : AppTheme.cardBorder),
                            width: 1.5,
                          ),
                          boxShadow: isCurrent || isActive
                              ? [
                                  BoxShadow(
                                    color: (isCurrent ? AppTheme.accentPink : AppTheme.primaryPurple).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent || isActive ? Colors.white : AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              note,
                              style: TextStyle(
                                color: isCurrent || isActive ? Colors.white : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter to draw a premium glowing synthesizer/oscilloscope wave
class WavePainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final int bpm;
  final double frequency;
  final int currentStep;
  final List<bool> beats;

  WavePainter({
    required this.animationValue,
    required this.isPlaying,
    required this.bpm,
    required this.frequency,
    required this.currentStep,
    required this.beats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.secondaryCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final glowPaint = Paint()
      ..color = AppTheme.secondaryCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final midY = size.height / 2;

    // Check if the current sequencer step is active to add a "spike/pulse" to the wave
    bool currentStepIsActive = false;
    if (isPlaying && currentStep >= 0 && currentStep < beats.length) {
      currentStepIsActive = beats[currentStep];
    }

    final waveWidth = size.width;
    final waveAmplitude = currentStepIsActive ? 35.0 : (isPlaying ? 15.0 : 3.0);
    final waveFreqScale = (frequency / 250.0);

    path.moveTo(0, midY);

    for (double x = 0; x <= waveWidth; x++) {
      // Calculate sine wave coordinates
      final phase = animationValue * 2 * math.pi * (isPlaying ? 2.5 : 0.5);
      final angle = (x / waveWidth) * 4 * math.pi * waveFreqScale - phase;
      
      // Add small high frequency harmonics if active step
      double yOffset = math.sin(angle) * waveAmplitude;
      if (currentStepIsActive) {
        yOffset += math.sin(angle * 3) * (waveAmplitude * 0.3);
      }

      path.lineTo(x, midY + yOffset);
    }

    // Draw the glow first, then the core line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw step pulse markers (flashing lights at bottom)
    if (isPlaying) {
      final stepMarkerPaint = Paint()
        ..color = currentStepIsActive ? AppTheme.accentPink : AppTheme.primaryPurple
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width - 20, 20), 
        currentStepIsActive ? 6.0 : 4.0, 
        stepMarkerPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true; // Animates continuously
  }
}
