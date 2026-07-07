import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// A small circular icon button used for playback controls (play/pause/
/// stop), shared by the read-only Sheet Mode viewer and Composer Mode.
class PlaybackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const PlaybackButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1.0 : 0.5,
      child: Material(
        color: primary ? AppTheme.primaryPurple : AppTheme.cardBorder.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              icon,
              color: primary ? Colors.white : AppTheme.textSecondary,
              size: primary ? 28 : 22,
            ),
          ),
        ),
      ),
    );
  }
}
