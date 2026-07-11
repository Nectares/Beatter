import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/layout/responsive_context.dart';
import '../../../../../models/polyrhythm/visualization_mode.dart';
import '../../../../../services/polyrhythm/polyrhythm_controller.dart';
import '../../../../../theme/app_theme.dart';
import 'polyrhythm_dark_style.dart';

/// The floating glass control panel — Polyrhythm Lab's only always-visible
/// chrome. A single [ListenableBuilder] scoped to [controller] means this
/// entire subtree only rebuilds on genuine setting changes (play/pause,
/// tempo, volume, mode, toggles), never at animation frame rate — the
/// canvas repaints independently via the engine's own `Listenable`.
///
/// Everything scales up on tablets (`context.isTablet`) — a touch target
/// sized for a phone reads as fussy and small on a 12" screen, so every
/// sub-control takes a [scale] factor rather than a fixed size.
class PolyrhythmControlPanel extends StatelessWidget {
  final PolyrhythmController controller;
  final bool isLandscape;

  const PolyrhythmControlPanel({
    super.key,
    required this.controller,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = context.isTablet ? 1.4 : 1.0;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Align(
          alignment: isLandscape
              ? Alignment.centerRight
              : Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isLandscape
                      ? const Offset(0.15, 0)
                      : const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: controller.controlsHidden
                ? _RevealHandle(
                    key: const ValueKey('hidden'),
                    isLandscape: isLandscape,
                    scale: scale,
                    onTap: () =>
                        controller.setToggle(controlsHiddenValue: false),
                  )
                : Padding(
                    key: const ValueKey('shown'),
                    padding: EdgeInsets.all(isLandscape ? 12 : 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 340 * scale : 520 * scale,
                      ),
                      child: _GlassPanel(
                        child: isLandscape
                            ? _LandscapeControls(
                                controller: controller,
                                scale: scale,
                              )
                            : _PortraitControls(
                                controller: controller,
                                scale: scale,
                              ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: PolyrhythmDarkStyle.glassPanelDecoration(),
          child: child,
        ),
      ),
    );
  }
}

class _RevealHandle extends StatelessWidget {
  final bool isLandscape;
  final double scale;
  final VoidCallback onTap;
  const _RevealHandle({
    super.key,
    required this.isLandscape,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: _GlassPanel(
          child: Padding(
            padding: EdgeInsets.all(10 * scale),
            child: Icon(
              isLandscape
                  ? Icons.chevron_left_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: PolyrhythmDarkStyle.textOnDark,
              size: 20 * scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitControls extends StatelessWidget {
  final PolyrhythmController controller;
  final double scale;
  const _PortraitControls({required this.controller, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        14 * scale,
        18 * scale,
        16 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PlayButton(controller: controller, scale: scale),
              SizedBox(width: 16 * scale),
              Expanded(
                child: _TempoSlider(controller: controller, scale: scale),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              _ModeSelector(controller: controller, scale: scale),
              const Spacer(),
              _MiniButton(
                icon: Icons.visibility_off_rounded,
                label: 'Hide',
                onTap: () => controller.setToggle(controlsHiddenValue: true),
                scale: scale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LandscapeControls extends StatelessWidget {
  final PolyrhythmController controller;
  final double scale;
  const _LandscapeControls({required this.controller, required this.scale});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: 18 * scale,
        horizontal: 12 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayButton(controller: controller, scale: scale),
          SizedBox(height: 18 * scale),
          SizedBox(
            height: 110 * scale,
            width: 32 * scale,
            child: RotatedBox(
              quarterTurns: 3,
              child: _TempoSlider(
                controller: controller,
                compact: true,
                scale: scale,
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          _ModeSelector(controller: controller, vertical: true, scale: scale),
          SizedBox(height: 18 * scale),
          _MiniButton(
            icon: Icons.visibility_off_rounded,
            label: 'Hide',
            onTap: () => controller.setToggle(controlsHiddenValue: true),
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final PolyrhythmController controller;
  final double scale;
  const _PlayButton({required this.controller, required this.scale});

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = controller.isPlaying;
    final double size = 54 * scale;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.mediumImpact();
          controller.togglePlayback();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPlaying
                  ? [AppColors.secondary, AppColors.primary]
                  : [AppColors.primary, AppColors.primaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28 * scale,
          ),
        ),
      ),
    );
  }
}

class _TempoSlider extends StatelessWidget {
  final PolyrhythmController controller;
  final bool compact;
  final double scale;
  const _TempoSlider({
    required this.controller,
    this.compact = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.speed_rounded,
          color: PolyrhythmDarkStyle.textOnDarkMuted,
          size: (compact ? 15 : 17) * scale,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 2.5 * scale,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 6.5 * scale,
              ),
            ),
            child: Slider(
              value: controller.bpm.clamp(40, 220),
              min: 40,
              max: 220,
              onChanged: controller.setBpm,
            ),
          ),
        ),
        SizedBox(
          width: 34 * scale,
          child: Text(
            '${controller.bpm.round()}',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: PolyrhythmDarkStyle.textOnDark,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final PolyrhythmController controller;
  final bool vertical;
  final double scale;
  const _ModeSelector({
    required this.controller,
    this.vertical = false,
    required this.scale,
  });

  static const Map<VisualizationMode, IconData> _icons = {
    VisualizationMode.nested: Icons.change_history_rounded,
    VisualizationMode.circular: Icons.donut_large_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final buttons = VisualizationMode.values.map((mode) {
      final bool selected = controller.mode == mode;
      return Padding(
        padding: EdgeInsets.all((vertical ? 3 : 2) * scale),
        child: Tooltip(
          message: mode.label,
          child: Material(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                controller.setMode(mode);
              },
              child: Padding(
                padding: EdgeInsets.all(7 * scale),
                child: Icon(
                  _icons[mode],
                  size: 17 * scale,
                  color: selected
                      ? AppColors.primary
                      : PolyrhythmDarkStyle.textOnDarkMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Container(
      padding: EdgeInsets.all(2 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
          : Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double scale;
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * scale,
            vertical: 6 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16 * scale,
                color: PolyrhythmDarkStyle.textOnDarkMuted,
              ),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  color: PolyrhythmDarkStyle.textOnDarkMuted,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
