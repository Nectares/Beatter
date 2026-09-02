import 'package:flutter/material.dart';

import '../../../../services/rhythm_playback_service.dart';
import '../../../../theme/app_theme.dart';

/// Sceglie il suono del metronomo fra quelli che il motore conosce
/// ([RhythmPlaybackService.metronomeSounds]) e ne fa sentire subito
/// l'accento. Condiviso da Flow Mode e dal player degli esercizi, che
/// hanno le stesse impostazioni audio.
class MetronomeSoundDropdown extends StatelessWidget {
  const MetronomeSoundDropdown({
    super.key,
    required this.playbackService,
    this.onChanged,
  });

  final RhythmPlaybackService playbackService;

  /// Chiamata dopo il cambio, per i contenitori che ridisegnano da soli
  /// (il bottom sheet di Flow Mode ha il suo `setState`).
  final VoidCallback? onChanged;

  /// Etichette dei suoni. Una voce senza etichetta ricade sul suo id, così
  /// aggiungere un suono al motore non fa sparire la voce dal menù.
  static const Map<String, String> labels = {
    'classic': '🔔 Beep metronomo',
    'beatter': '✨ Beep Beatter',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: DropdownButton<String>(
        value: playbackService.metronomeSound,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        items: [
          for (final id in RhythmPlaybackService.metronomeSounds.keys)
            DropdownMenuItem(value: id, child: Text(labels[id] ?? id)),
        ],
        onChanged: (value) {
          if (value == null) return;
          playbackService.updateSettings(metronomeSound: value);
          playbackService.previewMetronomeSound();
          onChanged?.call();
        },
      ),
    );
  }
}
