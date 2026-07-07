import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_pattern.dart';
import '../../../../services/pattern_repository.dart';

class RhythmCreatorPage extends StatefulWidget {
  const RhythmCreatorPage({super.key});

  @override
  State<RhythmCreatorPage> createState() => _RhythmCreatorPageState();
}

class _RhythmCreatorPageState extends State<RhythmCreatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  int _bpm = 120;
  double _baseFrequency = 440.0; // A4
  
  final List<bool> _beats = List.generate(16, (index) => false);
  final List<String> _notes = List.generate(16, (index) {
    // Prepopulate with a nice basic scale sequence
    final scale = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];
    return scale[index % scale.length];
  });

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _savePattern() {
    if (!_formKey.currentState!.validate()) return;

    final hasAtLeastOneBeat = _beats.contains(true);
    if (!hasAtLeastOneBeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno una nota/battuta nella griglia!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newPattern = RhythmPattern(
      name: _nameController.text.trim(),
      bpm: _bpm,
      baseFrequency: _baseFrequency,
      beats: _beats,
      notes: _notes,
    );

    PatternRepository().addPattern(newPattern);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pattern "${newPattern.name}" salvato con successo!'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );

    Navigator.pop(context, true);
  }

  void _toggleBeat(int index) {
    setState(() {
      _beats[index] = !_beats[index];
    });
  }

  void _editStepNote(int index) {
    final noteController = TextEditingController(text: _notes[index]);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Text('Modifica Nota Step ${index + 1}', style: const TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: noteController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Es: C4, E4, G5, A#4',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (noteController.text.trim().isNotEmpty) {
                  setState(() {
                    _notes[index] = noteController.text.trim().toUpperCase();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Salva', style: TextStyle(color: AppTheme.secondaryCyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Crea Pattern Ritmico', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pattern Name Box
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nome del Pattern',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Es. Techno Kick Pro, Cosmic Arp...',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Inserisci un nome per il pattern';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sequencer Controls
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Impostazioni Tempo e Frequenza',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 18),
                            
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
                              max: 220,
                              activeColor: AppTheme.primaryPurple,
                              inactiveColor: AppTheme.cardBorder,
                              onChanged: (val) {
                                setState(() {
                                  _bpm = val.toInt();
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Freq Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Frequenza Base (Hz)', style: TextStyle(color: AppTheme.textSecondary)),
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

                  // The Grid Step Sequencer (16 steps)
                  const Text(
                    'Sequencer (16 Step)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tocca un quadrato per attivarlo/disattivarlo, tieni premuto per modificare la nota.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, index) {
                      final isActive = _beats[index];
                      final note = _notes[index];
                      return GestureDetector(
                        onTap: () => _toggleBeat(index),
                        onLongPress: () => _editStepNote(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? const LinearGradient(
                                    colors: [AppTheme.primaryPurple, AppTheme.accentPink],
                                  )
                                : null,
                            color: isActive ? null : const Color(0xFFFFEAD6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive 
                                  ? AppTheme.accentPink 
                                  : AppTheme.cardBorder,
                              width: 1.5,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                                      blurRadius: 10,
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
                                  color: isActive ? Colors.white : AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note,
                                style: TextStyle(
                                  color: isActive ? Colors.white : AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Save Button
                  ElevatedButton(
                    onPressed: _savePattern,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('SALVA E PUBBLICA PATTERN'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
