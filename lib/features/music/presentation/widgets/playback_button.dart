import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// A small circular icon button used for playback controls (play/pause/
/// stop), shared by the read-only Sheet Mode viewer and Composer Mode.
///
/// Prefer [PlaybackButtonRow] for the common primary-play + secondary-stop
/// pairing — it also gets a real play/pause morph animation for free.
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
        color: primary ? AppColors.primary : AppColors.surfaceBorder.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Icon(
              icon,
              color: primary ? Colors.white : AppColors.textSecondary,
              size: primary ? 28 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular play/pause button that actually morphs between the two glyphs
/// (via [AnimatedIcons.play_pause]) instead of hard-cutting, used as the
/// primary control inside [PlaybackButtonRow].
class _AnimatedPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _AnimatedPlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  State<_AnimatedPlayPauseButton> createState() => _AnimatedPlayPauseButtonState();
}

class _AnimatedPlayPauseButtonState extends State<_AnimatedPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.isPlaying ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _AnimatedPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.onTap != null ? 1.0 : 0.5,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _controller,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

/// The standard primary-play/pause + secondary-stop control pair, used by
/// both Composer Mode and the read-only staff viewer — previously
/// duplicated ad hoc at each call site. Omit [onStop] to show the
/// play/pause button alone (Sheet Mode's single-pass exercise player).
class PlaybackButtonRow extends StatelessWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final bool isPlaying;
  final bool isEnabled;

  const PlaybackButtonRow({
    super.key,
    required this.onPlay,
    this.onStop,
    required this.isPlaying,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AnimatedPlayPauseButton(
          isPlaying: isPlaying,
          onTap: isEnabled ? onPlay : null,
        ),
        if (onStop != null) ...[
          const SizedBox(width: AppSpacing.md),
          PlaybackButton(
            icon: Icons.stop_rounded,
            onTap: isEnabled ? onStop : null,
          ),
        ],
      ],
    );
  }
}
