import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/layout/responsive_context.dart';
import '../../../../../models/polyrhythm/subdivision_model.dart';
import '../../../../../services/polyrhythm/polyrhythm_controller.dart';
import '../../../../../theme/app_theme.dart';
import 'polyrhythm_dark_style.dart';

/// Secondary settings — rhythm selection (Primary/Secondary/optional Third
/// voice + quick presets) and the visual/mode toggles — reached from the
/// control panel's "Settings" button. Same `showModalBottomSheet` +
/// `BackdropFilter` pattern Flow Mode's settings sheet uses, restyled
/// dark. Reads/writes [PolyrhythmController] directly and rebuilds via a
/// single [ListenableBuilder] — no separate sheet-local state to keep in
/// sync.
class PolyrhythmSettingsSheet {
  const PolyrhythmSettingsSheet._();

  static void show(BuildContext context, PolyrhythmController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _SheetBody(controller: controller),
    );
  }
}

class _SheetBody extends StatelessWidget {
  final PolyrhythmController controller;
  const _SheetBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final double scale = context.isTablet ? 1.2 : 1.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.isTablet ? 560 : double.infinity,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              decoration: BoxDecoration(
                color: PolyrhythmDarkStyle.panelSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: PolyrhythmDarkStyle.panelBorder,
                    width: 1.2,
                  ),
                ),
              ),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        top: 12 * scale,
                        bottom: 8 * scale,
                      ),
                      width: 40 * scale,
                      height: 4 * scale,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24 * scale,
                        vertical: 8 * scale,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                            size: 22 * scale,
                          ),
                          SizedBox(width: 10 * scale),
                          Text(
                            'Polyrhythm Settings',
                            style: TextStyle(
                              color: PolyrhythmDarkStyle.textOnDark,
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: PolyrhythmDarkStyle.textOnDarkMuted,
                              size: 22 * scale,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24 * scale,
                          16 * scale,
                          24 * scale,
                          28 * scale,
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('RHYTHM COMBINATION'),
                            const SizedBox(height: 10),
                            _presetChips(),
                            const SizedBox(height: 20),
                            _rhythmStepper('PRIMARY', 0),
                            const SizedBox(height: 14),
                            _rhythmStepper('SECONDARY', 1),
                            const SizedBox(height: 14),
                            _thirdRhythmRow(),
                            const SizedBox(height: 26),
                            _sectionTitle('VISUALS'),
                            const SizedBox(height: 6),
                            _toggleRow(
                              Icons.blur_on_rounded,
                              'Enable Glow',
                              controller.enableGlow,
                              (v) => controller.setToggle(glow: v),
                            ),
                            _toggleRow(
                              Icons.gesture_rounded,
                              'Enable Trails',
                              controller.enableTrails,
                              (v) => controller.setToggle(trails: v),
                            ),
                            _toggleRow(
                              Icons.bolt_rounded,
                              'Enable Pulse',
                              controller.enablePulse,
                              (v) => controller.setToggle(pulse: v),
                            ),
                            _toggleRow(
                              Icons.dark_mode_rounded,
                              'Dark Background',
                              controller.graphiteBackground,
                              (v) => controller.setToggle(graphiteBg: v),
                            ),
                            const SizedBox(height: 20),
                            _sectionTitle('TRAINING'),
                            const SizedBox(height: 6),
                            _toggleRow(
                              Icons.school_rounded,
                              'Learning Mode',
                              controller.learningMode,
                              (v) => controller.setToggle(learning: v),
                            ),
                            _toggleRow(
                              Icons.adjust_rounded,
                              'Practice Mode',
                              controller.practiceMode,
                              (v) => controller.setToggle(practice: v),
                            ),
                            if (controller.practiceMode) ...[
                              const SizedBox(height: 10),
                              _practiceStats(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: PolyrhythmDarkStyle.textOnDarkMuted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    ),
  );

  Widget _presetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PolyrhythmPreset.all.map((preset) {
        final bool selected = _matchesPreset(preset);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            controller.setSubdivisions(preset.subdivisions);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              preset.name,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : PolyrhythmDarkStyle.textOnDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _matchesPreset(PolyrhythmPreset preset) {
    final current = controller.activePolygons
        .map((p) => p.subdivisions)
        .toList();
    if (current.length != preset.subdivisions.length) return false;
    for (int i = 0; i < current.length; i++) {
      if (current[i] != preset.subdivisions[i]) return false;
    }
    return true;
  }

  Widget _rhythmStepper(String label, int index) {
    final polygons = controller.activePolygons;
    if (index >= polygons.length) return const SizedBox.shrink();
    final polygon = polygons[index];

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: PolyrhythmDarkStyle.textOnDarkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _stepperButton(
          Icons.remove_rounded,
          polygon.subdivisions > SubdivisionModel.minSubdivisions
              ? () => _changeSubdivision(index, -1)
              : null,
        ),
        SizedBox(
          width: 96,
          child: Column(
            children: [
              Text(
                '${polygon.subdivisions}',
                style: TextStyle(
                  color: polygon.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                SubdivisionModel.shapeName(polygon.subdivisions),
                style: const TextStyle(
                  color: PolyrhythmDarkStyle.textOnDarkMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        _stepperButton(
          Icons.add_rounded,
          polygon.subdivisions < SubdivisionModel.maxSubdivisions
              ? () => _changeSubdivision(index, 1)
              : null,
        ),
      ],
    );
  }

  Widget _thirdRhythmRow() {
    final bool hasThird = controller.activePolygons.length >= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'THIRD RHYTHM (OPTIONAL)',
                style: TextStyle(
                  color: PolyrhythmDarkStyle.textOnDarkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Switch(
              value: hasThird,
              activeThumbColor: AppColors.primary,
              onChanged: _toggleThirdRhythm,
            ),
          ],
        ),
        if (hasThird) ...[
          const SizedBox(height: 10),
          _rhythmStepper('THIRD', 2),
        ],
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed();
              },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: onPressed == null ? 0.02 : 0.06,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onPressed == null
                ? Colors.white24
                : PolyrhythmDarkStyle.textOnDark,
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PolyrhythmDarkStyle.textOnDarkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: PolyrhythmDarkStyle.textOnDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _practiceStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statColumn('${controller.practiceHits}', 'Hits', AppColors.success),
          _statColumn(
            '${controller.practiceMisses}',
            'Misses',
            AppColors.error,
          ),
          _statColumn(
            '${controller.practiceStreak}',
            'Streak',
            AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: PolyrhythmDarkStyle.textOnDarkMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _changeSubdivision(int index, int delta) {
    final subdivisions = controller.activePolygons
        .map((p) => p.subdivisions)
        .toList();
    final int next = (subdivisions[index] + delta).clamp(
      SubdivisionModel.minSubdivisions,
      SubdivisionModel.maxSubdivisions,
    );
    subdivisions[index] = next;
    controller.setSubdivisions(subdivisions);
  }

  void _toggleThirdRhythm(bool enabled) {
    final subdivisions = controller.activePolygons
        .map((p) => p.subdivisions)
        .toList();
    if (enabled) {
      final used = subdivisions.toSet();
      int third = SubdivisionModel.supportedRange.firstWhere(
        (n) => !used.contains(n),
        orElse: () => SubdivisionModel.maxSubdivisions,
      );
      subdivisions.add(third);
    } else if (subdivisions.length >= 3) {
      subdivisions.removeLast();
    }
    HapticFeedback.selectionClick();
    controller.setSubdivisions(subdivisions);
  }
}
