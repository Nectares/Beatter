import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/toast.dart';
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
      Toast.show(ToastType.error, 'Seleziona almeno una nota/battuta nella griglia!', context);
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

    Toast.show(ToastType.success, 'Pattern "${newPattern.name}" salvato con successo!', context);

    Navigator.pop(context, true);
  }

  void _toggleBeat(int index) {
    setState(() {
      _beats[index] = !_beats[index];
    });
  }

  Future<void> _editStepNote(int index) async {
    final newNote = await showPromptDialog(
      context,
      title: 'Modifica Nota Step ${index + 1}',
      initialValue: _notes[index],
      hintText: 'Es: C4, E4, G5, A#4',
      confirmLabel: 'Salva',
    );
    if (newNote != null && newNote.trim().isNotEmpty) {
      setState(() => _notes[index] = newNote.trim().toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BeatterScaffold(
      appBar: const BeatterAppBar(title: 'Crea Pattern Ritmico', leading: BackButton()),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pattern Name Box
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nome del Pattern', style: textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _nameController,
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
                  const SizedBox(height: AppSpacing.lg),

                  // Sequencer Controls
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Impostazioni Tempo e Frequenza', style: textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.md + 2),

                            // BPM Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tempo (BPM)', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                                Text(
                                  '$_bpm BPM',
                                  style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                            Slider(
                              value: _bpm.toDouble(),
                              min: 60,
                              max: 220,
                              onChanged: (val) {
                                setState(() {
                                  _bpm = val.toInt();
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Freq Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Frequenza Base (Hz)',
                                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${_baseFrequency.toStringAsFixed(1)} Hz',
                                  style: textTheme.titleMedium?.copyWith(color: AppColors.secondary),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: Theme.of(context).sliderTheme.copyWith(
                                    activeTrackColor: AppColors.secondary,
                                    thumbColor: AppColors.secondary,
                                    overlayColor: AppColors.secondary.withValues(alpha: 0.12),
                                  ),
                              child: Slider(
                                value: _baseFrequency,
                                min: 100,
                                max: 1000,
                                onChanged: (val) {
                                  setState(() {
                                    _baseFrequency = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // The Grid Step Sequencer (16 steps)
                  Text('Sequencer (16 Step)', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Tocca un quadrato per attivarlo/disattivarlo, tieni premuto per modificare la nota.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, index) {
                      final isActive = _beats[index];
                      final note = _notes[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _toggleBeat(index),
                          onLongPress: () => _editStepNote(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? const LinearGradient(colors: [AppColors.primary, AppColors.tertiary])
                                  : null,
                              color: isActive ? null : AppColors.inactiveTrack,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isActive ? AppColors.tertiary : AppColors.surfaceBorder,
                                width: 1.5,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: isActive ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  note,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: isActive ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Save Button
                  ElevatedButton(
                    onPressed: _savePattern,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2)),
                    child: const Text('SALVA E PUBBLICA PATTERN'),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
