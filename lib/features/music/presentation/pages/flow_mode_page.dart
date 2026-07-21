import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/figurations/flow_playback_controller.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/navigation/shell_visibility.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';

class FlowModePage extends StatefulWidget {
  const FlowModePage({super.key});

  @override
  State<FlowModePage> createState() => _FlowModePageState();
}

class _FlowModePageState extends State<FlowModePage>
    with TickerProviderStateMixin {
  // ── Engine ────────────────────────────────────────────────────────────────
  late final FlowPlaybackController _controller;

  // ── Auto-variation timer (UI-driven, seamless swaps) ──────────────────────
  bool _isAutoGenerateEnabled = false;
  double _autoGenerateSeconds = 5.0;
  Timer? _autoGenerateTimer;

  // ── UI controllers ────────────────────────────────────────────────────────
  late TextEditingController _bpmTextController;

  // Purely presentational heartbeat synced to the current BPM.
  late final AnimationController _beatPulseController = AnimationController(
    vsync: this,
  );

  // Avoids re-issuing the orientation lock when already in the right state.
  bool? _lastAppliedVisibility;

  // Signature of the last precached sequence, so tiles are only precached when
  // the sequence actually changes (not on every per-beat notification).
  String _lastPrecacheSignature = '';

  @override
  void initState() {
    super.initState();
    _controller = FlowPlaybackController();
    _controller.addListener(_onControllerChanged);
    _bpmTextController = TextEditingController(text: _controller.bpm.toString());
    _controller.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool visible = ShellVisibility.of(context);
    if (_lastAppliedVisibility == visible) return;
    _lastAppliedVisibility = visible;
    SystemChrome.setPreferredOrientations(visible
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _bpmTextController.dispose();
    _beatPulseController.dispose();
    _stopAutoGenerateTimer();
    super.dispose();
  }

  // ── Controller listener ────────────────────────────────────────────────────
  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _syncBeatPulse();
    _precacheSequenceIfChanged();
  }

  void _precacheSequenceIfChanged() {
    final items = _controller.sequence;
    final signature = items.map((p) => p.figuration.imageAsset).join('|');
    if (signature == _lastPrecacheSignature) return;
    _lastPrecacheSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final item in items) {
        precacheImage(AssetImage(item.figuration.imageAsset), context);
      }
    });
  }

  // ── Beat-pulse sync ────────────────────────────────────────────────────────
  void _syncBeatPulse() {
    if (_controller.isPlaying) {
      final ms = (60000 / _controller.bpm).round().clamp(150, 2000);
      if (!_beatPulseController.isAnimating ||
          _beatPulseController.duration?.inMilliseconds != ms) {
        _beatPulseController.duration = Duration(milliseconds: ms);
        _beatPulseController.repeat(reverse: true);
      }
    } else if (_beatPulseController.isAnimating) {
      _beatPulseController
        ..stop()
        ..value = 0;
    }
  }

  // ── Generation ─────────────────────────────────────────────────────────────
  void _generateNewRhythm() {
    if (_isAutoGenerateEnabled) _startAutoGenerateTimer();
    _controller.generate();
  }

  // ── BPM helpers ────────────────────────────────────────────────────────────
  void _onBpmChanged(String val) {
    final p = int.tryParse(val);
    if (p != null && p >= 40 && p <= 180) {
      _controller.bpm = p;
    }
  }

  void _onBpmSlider(double val) {
    _controller.bpm = val.toInt();
    _bpmTextController.text = _controller.bpm.toString();
  }

  // ── Playback controls ──────────────────────────────────────────────────────
  void _togglePlay() {
    if (!_controller.hasSequence) return;
    _controller.togglePlay();
  }

  // ── Auto-variation timer ───────────────────────────────────────────────────
  void _startAutoGenerateTimer() {
    _autoGenerateTimer?.cancel();
    _autoGenerateTimer = Timer.periodic(
      Duration(milliseconds: (_autoGenerateSeconds * 1000).toInt()),
      (_) => _controller.autoVary(),
    );
  }

  void _stopAutoGenerateTimer() {
    _autoGenerateTimer?.cancel();
    _autoGenerateTimer = null;
  }

  void _onAutoGenerateToggled(bool value) {
    setState(() => _isAutoGenerateEnabled = value);
    if (value) {
      _startAutoGenerateTimer();
    } else {
      _stopAutoGenerateTimer();
    }
  }

  void _onAutoGenerateSpeedChanged(double seconds) {
    setState(() => _autoGenerateSeconds = seconds);
    if (_isAutoGenerateEnabled) _startAutoGenerateTimer();
  }

  String _getSpeedLabel(double seconds) {
    if (seconds <= 3.0) return 'Molto veloce';
    if (seconds <= 5.0) return 'Veloce';
    if (seconds <= 8.0) return 'Media';
    if (seconds <= 11.0) return 'Lenta';
    return 'Molto lenta';
  }

  int get _currentMovimentoNumber {
    final idx = _controller.activeIndex;
    if (idx < 0 || idx >= _controller.sequence.length) return 1;
    return idx + 1;
  }

  String get _countLabel => 'MOVIMENTI';

  // ── Tile-size helper for the wrap layout ───────────────────────────────────
  double _calcTileSize(double availableWidth, int perRow) {
    const double outerPadding = 12.0;
    const double gap = 10.0;
    return ((availableWidth - 2 * outerPadding - (perRow - 1) * gap) / perRow)
        .clamp(48.0, 150.0);
  }

  // ── Settings bottom sheet ──────────────────────────────────────────────────
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                color: AppColors.primary, size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'Rhythm Settings',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Ottave mode ──────────────────────────────
                              Row(
                                children: [
                                  _buildSectionTitle('MODALITÀ OTTAVE'),
                                  const Spacer(),
                                  Switch(
                                    value: _controller.ottaveMode,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      _controller.setOttaveMode(val);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                _controller.ottaveMode
                                    ? 'Movimenti dal set di ottave (3/8).'
                                    : 'Movimenti dal set di quarti (1/4).',
                                style: TextStyle(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Sound selector ───────────────────────────
                              _buildSectionTitle('SUONO'),
                              const SizedBox(height: 8),
                              _buildSoundSelector(onChanged: () {
                                setSheetState(() {});
                              }),
                              const SizedBox(height: 24),

                              // ── Metronome ────────────────────────────────
                              Row(
                                children: [
                                  _buildSectionTitle('METRONOMO'),
                                  const Spacer(),
                                  Switch(
                                    value: _controller.metronomeEnabled,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      _controller.setMetronomeEnabled(val);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── BPM slider ───────────────────────────────
                              _buildSectionTitle('TEMPO (BPM)'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _controller.bpm.toDouble(),
                                      min: 40,
                                      max: 180,
                                      activeColor: AppColors.primary,
                                      inactiveColor: AppColors.inactiveTrack,
                                      onChanged: (v) {
                                        _onBpmSlider(v);
                                        setSheetState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 60,
                                    height: 38,
                                    child: TextField(
                                      controller: _bpmTextController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 4),
                                        fillColor: Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: AppColors.surfaceBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        _onBpmChanged(v);
                                        setSheetState(() {});
                                      },
                                      onSubmitted: (v) {
                                        final p = int.tryParse(v) ??
                                            _controller.bpm;
                                        final clamped = p.clamp(40, 180);
                                        _bpmTextController.text =
                                            clamped.toString();
                                        _onBpmChanged(clamped.toString());
                                        setSheetState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'I WAV sono resi a 70 BPM: a 70 la sequenza è '
                                'perfettamente continua.',
                                style: TextStyle(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Count (measures / cells) ─────────────────
                              _buildSectionTitle(_countLabel),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCounterButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: _controller.count > 1
                                        ? () {
                                            _controller
                                                .setCount(_controller.count - 1);
                                            setSheetState(() {});
                                          }
                                        : null,
                                  ),
                                  Container(
                                    width: 70,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${_controller.count}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _buildCounterButton(
                                    icon: Icons.add_rounded,
                                    onPressed: _controller.count < 12
                                        ? () {
                                            _controller
                                                .setCount(_controller.count + 1);
                                            setSheetState(() {});
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Figuration picker (switches with Ottave) ─
                              _buildFigurationPicker(setSheetState),
                              const SizedBox(height: 24),

                              // ── Auto-variation ───────────────────────────
                              Row(
                                children: [
                                  _buildSectionTitle('GENERAZIONE AUTOMATICA'),
                                  const Spacer(),
                                  Switch(
                                    value: _isAutoGenerateEnabled,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      setSheetState(
                                          () => _isAutoGenerateEnabled = val);
                                      _onAutoGenerateToggled(val);
                                    },
                                  ),
                                ],
                              ),
                              if (_isAutoGenerateEnabled) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: _autoGenerateSeconds,
                                        min: 2.0,
                                        max: 15.0,
                                        divisions: 13,
                                        activeColor: AppColors.primary,
                                        inactiveColor: AppColors.inactiveTrack,
                                        onChanged: (v) {
                                          setSheetState(
                                              () => _autoGenerateSeconds = v);
                                          _onAutoGenerateSpeedChanged(v);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_autoGenerateSeconds.toInt()}s',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                Center(
                                  child: Text(
                                    _getSpeedLabel(_autoGenerateSeconds),
                                    style: TextStyle(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _generateNewRhythm();
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shuffle_rounded,
                                          color: Colors.white),
                                      SizedBox(width: 10),
                                      Text(
                                        'GENERA RITMO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onPressed,
    double size = 44,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed();
              },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onPressed != null
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: onPressed != null
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.surfaceBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: onPressed != null ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Sound selector (Beatter / Silenzio) ────────────────────────────────────
  Widget _buildSoundSelector({VoidCallback? onChanged, bool compact = false}) {
    Widget option(FlowSoundMode mode, IconData icon, String label) {
      final bool selected = _controller.soundMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _controller.setSoundMode(mode);
            onChanged?.call();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? 15 : 18,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(FlowSoundMode.beatter, Icons.graphic_eq_rounded, 'Beatter'),
        const SizedBox(width: 10),
        option(FlowSoundMode.silence, Icons.volume_off_rounded, 'Silenzio'),
      ],
    );
  }

  // ── Figuration picker (list switches with the Ottave set) ──────────────────
  Widget _buildFigurationPicker(StateSetter setSheetState) {
    final figs = _controller.pickerFigurations;
    final title = _controller.ottaveMode
        ? 'FIGURAZIONI OTTAVE (3/8)'
        : 'FIGURAZIONI QUARTI (1/4)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionTitle(title)),
            TextButton(
              onPressed: figs.isEmpty
                  ? null
                  : () {
                      final allOn = figs.every(_controller.isEnabled);
                      _controller.setAllEnabled(!allOn);
                      setSheetState(() {});
                    },
              child: const Text(
                'Tutte / Nessuna',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (figs.isEmpty)
          Text(
            'Nessuna figurazione disponibile.',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: figs.length,
            itemBuilder: (context, idx) {
              final fig = figs[idx];
              final isEnabled = _controller.isEnabled(fig);

              return GestureDetector(
                onTap: () {
                  _controller.toggleEnabled(fig);
                  setSheetState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnabled
                          ? AppColors.primary
                          : AppColors.surfaceBorder,
                      width: isEnabled ? 2.5 : 1.0,
                    ),
                    boxShadow: isEnabled
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : 0.4,
                            child: Image.asset(
                              fig.imageAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stack) => Icon(
                                Icons.music_note_rounded,
                                color: AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isEnabled)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── On-screen quick toggles (Ottave + sound) ───────────────────────────────
  Widget _buildTogglesRow() {
    // Two compact rows keep every control fully labelled without ever
    // overflowing on narrow phones: the Ottave + Metronome toggles on top,
    // the Beatter/Silenzio selector below.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildOttavePill()),
              const SizedBox(width: 8),
              Expanded(child: _buildMetronomePill()),
            ],
          ),
          const SizedBox(height: 6),
          _buildSoundSelector(compact: true),
        ],
      ),
    );
  }

  Widget _buildMetronomePill() {
    final bool on = _controller.metronomeEnabled;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _controller.setMetronomeEnabled(!on);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? AppColors.primary : AppColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timelapse_rounded,
              size: 16,
              color: on ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Metronomo',
              style: TextStyle(
                color: on ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOttavePill() {
    final bool on = _controller.ottaveMode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _controller.setOttaveMode(!on);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? AppColors.primary : AppColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 15,
              color: on ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Ottave',
              style: TextStyle(
                color: on ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main-screen count stepper ──────────────────────────────────────────────
  Widget _buildSlotCountControl({
    bool isCompact = false,
    bool isVertical = false,
    double scale = 1.0,
  }) {
    final double buttonSize = (isCompact ? 36.0 : 38.0) * scale;
    final minusButton = _buildCounterButton(
      icon: Icons.remove_rounded,
      size: buttonSize,
      onPressed: _controller.count > 1
          ? () => _controller.setCount(_controller.count - 1)
          : null,
    );
    final plusButton = _buildCounterButton(
      icon: Icons.add_rounded,
      size: buttonSize,
      onPressed: _controller.count < 12
          ? () => _controller.setCount(_controller.count + 1)
          : null,
    );
    final countLabel = Text(
      '${_controller.count}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: (isCompact ? 13.0 : 16.0) * scale,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          plusButton,
          const SizedBox(height: 2),
          countLabel,
          const SizedBox(height: 2),
          minusButton,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        minusButton,
        SizedBox(width: isCompact ? 26 : 34, child: countLabel),
        plusButton,
      ],
    );
  }

  // ── Main-screen speed (BPM) slider ─────────────────────────────────────────
  Widget _buildSpeedSlider({
    bool isVertical = false,
    double verticalHeight = 110,
    double scale = 1.0,
  }) {
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3 * scale,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7 * scale),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14 * scale),
      ),
      child: Slider(
        value: _controller.bpm.toDouble().clamp(40, 180),
        min: 40,
        max: 180,
        activeColor: AppColors.primary,
        inactiveColor: AppColors.inactiveTrack,
        onChanged: _onBpmSlider,
      ),
    );

    if (isVertical) {
      return SizedBox(
        height: verticalHeight,
        width: 28 * scale,
        child: RotatedBox(quarterTurns: 3, child: slider),
      );
    }
    return slider;
  }

  Widget _buildSpeedControl({
    bool isCompact = false,
    double sliderHeight = 110,
    double scale = 1.0,
  }) {
    if (isCompact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded,
              color: AppColors.textSecondary, size: 16 * scale),
          _buildSpeedSlider(
              isVertical: true, verticalHeight: sliderHeight, scale: scale),
          Text(
            '${_controller.bpm}',
            style: TextStyle(
              fontSize: 11 * scale,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.speed_rounded,
            color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 6),
        Expanded(child: _buildSpeedSlider()),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          child: Text(
            '${_controller.bpm}',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.music_note_rounded,
      title: 'Genera un ritmo per iniziare',
    );
  }

  // ── Figuration tiles ────────────────────────────────────────────────────────
  Widget _buildSlotsGrid() {
    final items = _controller.sequence;
    final int n = items.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int perRow = n <= 4 ? math.max(n, 1) : (n <= 8 ? 4 : 5);
        final double tileSize = _calcTileSize(constraints.maxWidth, perRow);
        final double imagePadding = (tileSize * 0.12).clamp(4.0, 16.0);
        final double radius = (tileSize * 0.14).clamp(8.0, AppRadius.lg);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int index = 0; index < n; index++)
                  _buildSlotTile(
                    index: index,
                    tileSize: tileSize,
                    imagePadding: imagePadding,
                    radius: radius,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotTile({
    required int index,
    required double tileSize,
    required double imagePadding,
    required double radius,
  }) {
    final item = _controller.sequence[index];
    final bool isActive =
        _controller.isPlaying && _controller.activeIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: tileSize,
      height: tileSize,
      transform: Matrix4.identity()
        ..translateByDouble(tileSize / 2, tileSize / 2, 0, 1)
        ..scaleByDouble(isActive ? 1.06 : 1.0, isActive ? 1.06 : 1.0, 1, 1)
        ..translateByDouble(-tileSize / 2, -tileSize / 2, 0, 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.surfaceBorder,
          width: isActive ? 3.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isActive ? 16 : 6,
            spreadRadius: isActive ? 2 : 0,
            offset: isActive ? const Offset(0, 4) : const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(imagePadding),
            child: Image.asset(
              item.figuration.imageAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.music_note_rounded,
                color: AppColors.textMuted,
                size: tileSize * 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Metronome / beat indicator ──────────────────────────────────────────────
  Widget _buildMetronomeIndicator() {
    final textTheme = Theme.of(context).textTheme;

    if (!_controller.isPlaying) {
      return const SizedBox(height: 52);
    }

    final beatNum = _currentMovimentoNumber;

    return AnimatedBuilder(
      animation: _beatPulseController,
      builder: (context, child) {
        final double t = _beatPulseController.value;
        return Transform.scale(
          scale: 1.0 + t * 0.05,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1 + t * 0.06),
              borderRadius: BorderRadius.circular(AppRadius.xl - 4),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2 + t * 0.15)),
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'MOVIMENTO: ',
            style: textTheme.labelMedium
                ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.1),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$beatNum',
              key: ValueKey<int>(beatNum),
              style: textTheme.displaySmall
                  ?.copyWith(color: AppColors.primary, fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isLandscape = context.isLandscape;

    return BeatterScaffold(
      backgroundColor: Colors.transparent,
      appBar: BeatterAppBar(
        title: 'Beatter Flow Mode',
        leading: ShellMenuButton.maybe(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            onPressed: _showSettingsBottomSheet,
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: TwoPaneLayout(
            portrait: (context) => Column(
              children: [
                _buildTogglesRow(),
                _buildMetronomeIndicator(),
                Expanded(child: _buildGridArea()),
                _buildControlsBar(isLandscape),
              ],
            ),
            landscapePrimary: (context) => Column(
              children: [
                _buildTogglesRow(),
                _buildMetronomeIndicator(),
                Expanded(child: _buildGridArea()),
              ],
            ),
            landscapeSecondary: (context) => _buildControlsBar(isLandscape),
            primaryFlex: 0.84,
            secondaryFlex: 0.16,
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    if (!_controller.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_controller.hasSequence) {
      return _buildEmptyState();
    }
    return _buildSlotsGrid();
  }

  double _landscapePanelScale(double width, double height) {
    final double widthT = ((width - 110.0) / 140.0).clamp(0.0, 1.0);
    final double heightT = ((height - 320.0) / 380.0).clamp(0.0, 1.0);
    final double t = math.min(widthT, heightT);
    return 1.0 + t * 0.5;
  }

  Widget _buildLandscapeControlsColumn(bool isPlaying) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;
        final double scale =
            _landscapePanelScale(constraints.maxWidth, availableHeight);
        final double sliderHeight = (availableHeight < 260
                ? 55.0
                : availableHeight < 340
                    ? 80.0
                    : 110.0) *
            scale;
        final double gap = (availableHeight < 260 ? 6.0 : 12.0) * scale;

        final Widget autoButton = _buildControlButton(
          icon: Icons.auto_awesome_rounded,
          color: _isAutoGenerateEnabled
              ? AppColors.primary
              : AppColors.textSecondary,
          onTap: () => _onAutoGenerateToggled(!_isAutoGenerateEnabled),
          label: 'AutoMix',
          isCompact: true,
          scale: scale,
        );

        final Widget generateButton = _buildControlButton(
          icon: Icons.shuffle_rounded,
          color: AppColors.primary,
          onTap: _generateNewRhythm,
          label: 'Generate',
          isCompact: true,
          scale: scale,
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: constraints.copyWith(
              minHeight: availableHeight,
              maxHeight: double.infinity,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                autoButton,
                SizedBox(height: gap),
                _buildSlotCountControl(
                    isCompact: true, isVertical: true, scale: scale),
                SizedBox(height: gap),
                _buildPlayButton(isPlaying, isCompact: true, scale: scale),
                SizedBox(height: gap),
                _buildSpeedControl(
                    isCompact: true, sliderHeight: sliderHeight, scale: scale),
                SizedBox(height: gap),
                generateButton,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsBar(bool isLandscape) {
    final bool isPlaying = _controller.isPlaying;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(
          top: isLandscape
              ? BorderSide.none
              : const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
          left: isLandscape
              ? const BorderSide(color: AppColors.surfaceBorder, width: 1.0)
              : BorderSide.none,
        ),
      ),
      child: isLandscape
          ? _buildLandscapeControlsColumn(isPlaying)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildSlotCountControl(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildSpeedControl()),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.auto_awesome_rounded,
                      color: _isAutoGenerateEnabled
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      onTap: () =>
                          _onAutoGenerateToggled(!_isAutoGenerateEnabled),
                      label: 'AutoMix',
                    ),
                    _buildPlayButton(isPlaying),
                    _buildControlButton(
                      icon: Icons.shuffle_rounded,
                      color: AppColors.primary,
                      onTap: _generateNewRhythm,
                      label: 'Generate',
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPlayButton(
    bool isPlaying, {
    bool isCompact = false,
    double scale = 1.0,
  }) {
    final isDisabled = !_controller.hasSequence;
    final double size = (isCompact ? 44.0 : 56.0) * scale;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isDisabled
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _togglePlay();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isDisabled
                  ? [
                      AppColors.surfaceBorder,
                      AppColors.surfaceBorder.withValues(alpha: 0.5)
                    ]
                  : isPlaying
                      ? [AppColors.tertiary, AppColors.primary]
                      : [AppColors.primary, AppColors.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: isDisabled ? Colors.white54 : Colors.white,
            size: (isCompact ? 24.0 : 32.0) * scale,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    bool isCompact = false,
    double scale = 1.0,
  }) {
    final double size = (isCompact ? 40.0 : 44.0) * scale;
    final BorderRadius radius =
        BorderRadius.circular(isCompact ? AppRadius.sm + 2 : AppRadius.md);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: radius,
                  border: Border.all(
                      color: color.withValues(alpha: 0.2), width: 1.2),
                ),
                child: Icon(icon,
                    color: color, size: (isCompact ? 18.0 : 22.0) * scale),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: (isCompact ? 9.0 : 10.0) * scale,
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
