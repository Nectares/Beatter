import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Slider di volume delle impostazioni audio: etichetta e percentuale
/// sopra, slider sotto a tutta larghezza — così etichetta e slider non si
/// contendono lo spazio nemmeno coi caratteri di sistema ingranditi.
///
/// Condiviso dalle modalità che espongono i volumi del motore
/// (`RhythmPlaybackService.metronomeVolume` / `noteVolume`), per non
/// duplicare la riga in ogni schermata.
class VolumeSliderRow extends StatelessWidget {
  const VolumeSliderRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(value * 100).round()}%',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3),
          child: Slider(
            value: value,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.inactiveTrack,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
