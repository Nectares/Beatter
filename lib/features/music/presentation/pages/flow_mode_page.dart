import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/navigation/shell_menu_button.dart';
import '../../../../core/navigation/shell_visibility.dart';
import '../../../../core/widgets/beatter_app_bar.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../widgets/metronome_sound_dropdown.dart';

class FlowModePage extends StatefulWidget {
  const FlowModePage({super.key});

  /// Identifies the controls bar (steppers, speed slider and transport
  /// buttons) so tests can assert its height stays put when a value or the
  /// system text scale changes — a taller bar shrinks the tile grid above it.
  static const Key controlsBarKey = ValueKey('flowModeControlsBar');

  /// Identifies the tile of beat [index] — the thing you tap to accent that
  /// beat, and the handle tests use to address one beat in particular.
  static Key slotKey(int index) => ValueKey('flowModeSlot$index');

  @override
  State<FlowModePage> createState() => _FlowModePageState();
}

class _FlowModePageState extends State<FlowModePage>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  late RhythmPlaybackService _playbackService;

  // ── Settings ─────────────────────────────────────────────────────────────
  int _bpm = 120;
  int _slotsCount = 4;

  // ── Assets & State ────────────────────────────────────────────────────────
  List<String> _rhythmAssets = [];
  final Map<String, bool> _enabledAssets = {};
  List<RhythmSlot> _generatedSlots = [];
  bool _isLoading = true;

  // ── Slot keys — used for widget identity in the single-row tile layout ────
  List<GlobalKey> _slotKeys = [];

  // ── Accents ──────────────────────────────────────────────────────────────
  // Quali movimenti sono accentati, per posizione nel giro: l'accento resta
  // dov'è quando il ritmo si rigenera, esattamente come su uno spartito
  // (si accenta il tempo, non la figurazione che ci capita sopra).
  //
  // Il default riproduce l'accento che il motore metteva fisso ogni quattro
  // movimenti; l'indice 4 resta nell'insieme anche con poche tessere, così
  // torna se il giro si allunga di nuovo.
  final Set<int> _accentedSlots = {0, 4};

  // ── Auto-Generation Timer ────────────────────────────────────────────────
  bool _isAutoGenerateEnabled = false;
  double _autoGenerateSeconds = 5.0; // Default 5 seconds
  Timer? _autoGenerateTimer;

  // ── UI Controllers ────────────────────────────────────────────────────────
  late TextEditingController _bpmTextController;

  // Purely presentational: a free-running pulse synced to the current BPM,
  // used to give the metronome indicator a visible "heartbeat" while
  // playing. Not sample-accurate against the audio clock (the service only
  // notifies listeners on note/rest events, not on every metronome click),
  // but imperceptible for a glance-at visual cue.
  late final AnimationController _beatPulseController = AnimationController(
    vsync: this,
  );

  // Whether the orientation lock below was last set for "visible" (true)
  // or "hidden" (false) — avoids re-issuing the platform channel call on
  // every dependency change once it's already in the right state.
  bool? _lastAppliedVisibility;

  @override
  void initState() {
    super.initState();

    _playbackService = RhythmPlaybackService();
    _playbackService.updateSettings(bpm: _bpm);
    _playbackService.addListener(_onPlaybackChanged);

    _bpmTextController = TextEditingController(text: _bpm.toString());

    // Load assets dynamically
    _loadAssets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This page now stays mounted inside the shell's IndexedStack even
    // while the Home tab is showing (that's what fixes state loss on tab
    // switch — see NavigationShell), so the landscape rotation this page
    // wants can't be tied to initState/dispose anymore: those only fire
    // once, when the shell itself is created/torn down, not on every tab
    // switch. ShellVisibility reports the actual on-screen state instead.
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
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    _bpmTextController.dispose();
    _beatPulseController.dispose();
    _stopAutoGenerateTimer();
    super.dispose();
  }

  // ── Beat-pulse sync ──────────────────────────────────────────────────────
  void _syncBeatPulse() {
    if (_playbackService.isPlaying) {
      final ms = (60000 / _playbackService.bpm).round().clamp(150, 2000);
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

  // ── Load Assets Dynamically ────────────────────────────────────────────────
  Future<void> _loadAssets() async {
    List<String> paths = [];
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      paths = manifest
          .listAssets()
          .where(
            (key) =>
                (key.startsWith('assets/icon/') ||
                    key.startsWith('assets/icons/')) &&
                key.endsWith('.png'),
          )
          .toList();
    } catch (_) {}

    if (paths.isEmpty) {
      try {
        final manifestContent = await rootBundle.loadString(
          'AssetManifest.json',
        );
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        paths = manifestMap.keys
            .where(
              (key) =>
                  (key.startsWith('assets/icon/') ||
                      key.startsWith('assets/icons/')) &&
                  key.endsWith('.png'),
            )
            .toList();
      } catch (_) {}
    }

    // Fallback static list in case manifest reading fails in certain environments
    if (paths.isEmpty) {
      paths = const [
        'assets/icon/Screenshot 2026-05-07 alle 15.39.51.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.40.22.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.40.59.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.41.33.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.43.32.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.43.59.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.44.26.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.45.34.png', // This will be filtered out!
        'assets/icon/Screenshot 2026-05-07 alle 15.45.42.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.45.48.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.45.55.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.46.35.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.46.58.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.47.06.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.47.14.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.47.35.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.47.53.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.14.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.21.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.27.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.35.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.40.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.45.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.51.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.48.57.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.50.31.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.50.38.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.50.48.png',
        'assets/icon/Screenshot 2026-05-07 alle 15.51.02.png',
      ];
    }

    paths.sort();

    if (mounted) {
      setState(() {
        // Exclude single eighth note (Screenshot 2026-05-07 alle 15.45.34.png)
        _rhythmAssets = paths.where((p) => !p.contains('15.45.34')).toList();

        for (var path in _rhythmAssets) {
          _enabledAssets[path] = true;
        }
        _isLoading = false;
      });

      // Precache images in Flutter image cache. Deferred to a post-frame
      // callback: this resumes from an `await` above, and calling
      // precacheImage's underlying MediaQuery lookup on `context` too soon
      // after initState (before this element's first build has been
      // registered with the framework) throws
      // "dependOnInheritedWidgetOfExactType<MediaQuery>() ... called before
      // initState() completed" — reliably reproducible when this page is
      // reached via a pushReplacement (e.g. the drawer's Flow Mode entry)
      // rather than as the app's very first route, where scheduling happens
      // to land on the safe side of the race.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (var path in _rhythmAssets) {
          precacheImage(AssetImage(path), context);
        }
      });

      _generateNewRhythm();
    }
  }

  // ── Rhythm Generation ────────────────────────────────────────────────────
  void _generateNewRhythm({bool fromTimer = false}) {
    if (!fromTimer && _isAutoGenerateEnabled) {
      _startAutoGenerateTimer(); // Reset timer on manual action
    }

    final activeAssets = _rhythmAssets
        .where((p) => _enabledAssets[p] == true)
        .toList();
    if (activeAssets.isEmpty) {
      activeAssets.addAll(_rhythmAssets);
    }

    final List<RhythmSlot> slots = [];
    final rand = math.Random();

    if (fromTimer && _generatedSlots.isNotEmpty) {
      // Auto-generazione: cambia solo 1 singola tessera random
      slots.addAll(_generatedSlots);
      final randIndex = rand.nextInt(_slotsCount);
      slots[randIndex] = RhythmSlot.fromAsset(
        activeAssets[rand.nextInt(activeAssets.length)],
        isAccented: _accentedSlots.contains(randIndex),
      );
    } else {
      // Generazione manuale o prima generazione: cambia tutte le tessere
      for (int i = 0; i < _slotsCount; i++) {
        final randomAsset = activeAssets[rand.nextInt(activeAssets.length)];
        slots.add(RhythmSlot.fromAsset(
          randomAsset,
          isAccented: _accentedSlots.contains(i),
        ));
      }
    }

    if (_slotKeys.length != slots.length) {
      _slotKeys = List.generate(slots.length, (_) => GlobalKey());
    }

    setState(() {
      _generatedSlots = slots;
    });

    if (fromTimer && _playbackService.isPlaying) {
      // Se generato dal timer e in play, aggiorna in modo fluido per non perdere il timing
      _playbackService.updateSlotsSeamlessly(slots);
    } else {
      // Altrimenti fermati e ricomincia per un reset manuale pulito
      final wasPlaying = _playbackService.isPlaying;
      _playbackService.stop();
      _playbackService.prepareSlotPlayback(slots);
      if (wasPlaying) {
        _playbackService.play();
      }
    }
  }

  // ── Playback Listener ────────────────────────────────────────────────────
  void _onPlaybackChanged() {
    if (!mounted) return;
    setState(() {});
    _syncBeatPulse();
    _scrollActiveSlotIntoView();
  }

  // ── All tiles are always fully visible in the single-row layout ───────────
  // No scrolling needed; this is kept as a no-op so _onPlaybackChanged can
  // call it unconditionally without any refactor of the listener.
  void _scrollActiveSlotIntoView() {}

  // ── BPM Helpers ──────────────────────────────────────────────────────────
  void _onBpmChanged(String val) {
    final p = int.tryParse(val);
    if (p != null && p >= 40 && p <= 240) {
      setState(() => _bpm = p);
      _playbackService.updateSettings(bpm: p);
      _syncBeatPulse();
    }
  }

  void _onBpmSlider(double val) {
    setState(() {
      _bpm = val.toInt();
      _bpmTextController.text = _bpm.toString();
    });
    _playbackService.updateSettings(bpm: _bpm);
    _syncBeatPulse();
  }

  // ── Playback Controls ────────────────────────────────────────────────────
  /// Toggle Play/Pause del loop infinito.
  void _togglePlay() {
    if (_generatedSlots.isEmpty) return;
    if (_playbackService.isPlaying) {
      _playbackService.pause();
    } else {
      // Sia da pausa che da stop, play() gestisce entrambi i casi
      _playbackService.play();
    }
  }

  // ── Auto-Generation Timers ────────────────────────────────────────────────
  void _startAutoGenerateTimer() {
    _autoGenerateTimer?.cancel();
    _autoGenerateTimer = Timer.periodic(
      Duration(milliseconds: (_autoGenerateSeconds * 1000).toInt()),
      (timer) {
        _generateNewRhythm(fromTimer: true);
      },
    );
  }

  void _stopAutoGenerateTimer() {
    _autoGenerateTimer?.cancel();
    _autoGenerateTimer = null;
  }

  void _onAutoGenerateToggled(bool value) {
    setState(() {
      _isAutoGenerateEnabled = value;
    });
    if (value) {
      _startAutoGenerateTimer();
    } else {
      _stopAutoGenerateTimer();
    }
  }

  void _onAutoGenerateSpeedChanged(double seconds) {
    setState(() {
      _autoGenerateSeconds = seconds;
    });
    if (_isAutoGenerateEnabled) {
      _startAutoGenerateTimer();
    }
  }

  String _getSpeedLabel(double seconds) {
    if (seconds <= 3.0) return 'Molto veloce';
    if (seconds <= 5.0) return 'Veloce';
    if (seconds <= 8.0) return 'Media';
    if (seconds <= 11.0) return 'Lenta';
    return 'Molto lenta';
  }

  int get _currentBeatNumber {
    final idx = _playbackService.currentElementIndex;
    if (idx < 0) return 1;
    return (idx % _slotsCount) + 1;
  }

  // ── Tile-size helper ─────────────────────────────────────────────────────
  // Returns the side length (px) each square tile must have so that all N
  // slots fit in one row within [availableWidth], respecting the outer
  // horizontal padding and inter-tile gap.  Clamped to a readable minimum.
  double _calcTileSize(double availableWidth, int n) {
    const double outerPadding = 12.0; // each side
    final double gap = n <= 3 ? 12.0 : n <= 5 ? 10.0 : 8.0;
    return ((availableWidth - 2 * outerPadding - (n - 1) * gap) / n)
        .clamp(36.0, 180.0);
  }

  // ── Show Settings Bottom Sheet ───────────────────────────────────────────
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Title Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
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
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.surfaceBorder),

                      // Scrollable Controls
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── BPM Slider ───────────────────────────────
                              _buildSectionTitle('TEMPO (BPM)'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _bpm.toDouble(),
                                      min: 40,
                                      max: 240,
                                      activeColor: AppColors.primary,
                                      inactiveColor: AppColors.inactiveTrack,
                                      onChanged: (v) {
                                        setSheetState(() => _bpm = v.toInt());
                                        _onBpmSlider(v);
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
                                              vertical: 4,
                                            ),
                                        fillColor: Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.surfaceBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        _onBpmChanged(v);
                                        final p = int.tryParse(v);
                                        if (p != null && p >= 40 && p <= 240) {
                                          setSheetState(() => _bpm = p);
                                        }
                                      },
                                      onSubmitted: (v) {
                                        final p = int.tryParse(v) ?? _bpm;
                                        final clamped = p.clamp(40, 240);
                                        _bpmTextController.text = clamped
                                            .toString();
                                        _onBpmChanged(clamped.toString());
                                        setSheetState(() => _bpm = clamped);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Slot Count (+ / -) ───────────────────────
                              _buildSectionTitle('NUMERO DI MOVIMENTI'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCounterButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: _slotsCount > 2
                                        ? () {
                                            _slotsCount--;
                                            setState(() => _slotsCount);
                                            setSheetState(() => _slotsCount);
                                            _generateNewRhythm();
                                          }
                                        : null,
                                  ),
                                  Container(
                                    width: 70,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$_slotsCount',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _buildCounterButton(
                                    icon: Icons.add_rounded,
                                    onPressed: _slotsCount < 7
                                        ? () {
                                            _slotsCount++;
                                            setState(() => _slotsCount);
                                            setSheetState(() => _slotsCount);
                                            _generateNewRhythm();
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Auto-Generation & Random Speed Slider ─────
                              Row(
                                children: [
                                  _buildSectionTitle('GENERAZIONE AUTOMATICA'),
                                  const Spacer(),
                                  Switch(
                                    value: _isAutoGenerateEnabled,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      setSheetState(
                                        () => _isAutoGenerateEnabled = val,
                                      );
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
                                            () => _autoGenerateSeconds = v,
                                          );
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
                                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // ── Figuration Grid Selector ───────────────────
                              Row(
                                children: [
                                  _buildSectionTitle('FIGURAZIONI RITMICHE'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setSheetState(() {
                                        final allOn = _enabledAssets.values
                                            .contains(false);
                                        for (var k in _enabledAssets.keys) {
                                          _enabledAssets[k] = allOn;
                                        }
                                      });
                                      setState(() {});
                                      _generateNewRhythm();
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
                                itemCount: _rhythmAssets.length,
                                itemBuilder: (context, idx) {
                                  final path = _rhythmAssets[idx];
                                  final isEnabled =
                                      _enabledAssets[path] ?? false;

                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        _enabledAssets[path] = !isEnabled;
                                      });
                                      setState(() {});
                                      _generateNewRhythm();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
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
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.15),
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
                                              padding: const EdgeInsets.all(
                                                6.0,
                                              ),
                                              child: Opacity(
                                                opacity: isEnabled ? 1.0 : 0.4,
                                                child: Image.asset(
                                                  path,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isEnabled)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
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
                              const SizedBox(height: 24),

                              // ── Metronome & Instrument ───────────────────
                              _buildSectionTitle('AUDIO CONTROLS'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        final newVal = !_playbackService
                                            .isMetronomeEnabled;
                                        setSheetState(() {});
                                        _playbackService.updateSettings(
                                          isMetronomeEnabled: newVal,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _playbackService
                                                  .isMetronomeEnabled
                                              ? AppColors.primary
                                                    .withValues(alpha: 0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                _playbackService
                                                    .isMetronomeEnabled
                                                ? AppColors.primary
                                                : AppColors.surfaceBorder,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _playbackService
                                                      .isMetronomeEnabled
                                                  ? Icons.graphic_eq_rounded
                                                  : Icons.volume_off_rounded,
                                              color:
                                                  _playbackService
                                                      .isMetronomeEnabled
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Metronomo',
                                              style: TextStyle(
                                                color:
                                                    _playbackService
                                                        .isMetronomeEnabled
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.surfaceBorder,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _playbackService.soundInstrument,
                                      dropdownColor: Colors.white,
                                      underline: const SizedBox(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'silent',
                                          child: Text('🔇 Silent'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'snare',
                                          child: Text('🥁 Snare'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'stick',
                                          child: Text('🥢 Stick'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setSheetState(() {});
                                          _playbackService.updateSettings(
                                            soundInstrument: v,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Suono metronomo',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  MetronomeSoundDropdown(
                                    playbackService: _playbackService,
                                    onChanged: () => setSheetState(() {}),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── Accents ──────────────────────────────────
                              _buildSectionTitle('ACCENTI'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Tocca una tessera per mettere o togliere l\'accento.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _hasAccents
                                        ? () {
                                            _clearAccents();
                                            setSheetState(() {});
                                          }
                                        : null,
                                    child: const Text('Azzera'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── Buttons ──────────────────────────────────
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
                                      Icon(
                                        Icons.shuffle_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'GENERATE RHYTHM',
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

  // ── Accents ──────────────────────────────────────────────────────────────
  /// Manda le tessere correnti al motore: in riproduzione l'aggiornamento è
  /// fluido (il giro non si interrompe), da fermi basta riarmare la timeline.
  void _pushSlotsToPlayback() {
    if (_playbackService.isPlaying) {
      _playbackService.updateSlotsSeamlessly(_generatedSlots);
    } else {
      _playbackService.prepareSlotPlayback(_generatedSlots);
    }
  }

  void _toggleSlotAccent(int index) {
    if (index >= _generatedSlots.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final bool accented = !_accentedSlots.remove(index);
      if (accented) _accentedSlots.add(index);
      _generatedSlots[index] =
          _generatedSlots[index].copyWith(isAccented: accented);
    });
    _pushSlotsToPlayback();
  }

  bool get _hasAccents => _generatedSlots.any((slot) => slot.isAccented);

  void _clearAccents() {
    if (!_hasAccents && _accentedSlots.isEmpty) return;
    setState(() {
      _accentedSlots.clear();
      _generatedSlots = [
        for (final slot in _generatedSlots) slot.copyWith(isAccented: false),
      ];
    });
    _pushSlotsToPlayback();
  }

  // ── Quick slot-count stepper (main screen, outside the settings sheet) ───
  void _incrementSlotCount() {
    if (_slotsCount >= 7) return;
    setState(() => _slotsCount++);
    _generateNewRhythm();
  }

  void _decrementSlotCount() {
    if (_slotsCount <= 2) return;
    setState(() => _slotsCount--);
    _generateNewRhythm();
  }

  // Width of a fixed-width stepper value label. The base widths were sized
  // for the default text scale; at accessibility text scales the digits grow
  // past them, and a label that doesn't fit its box wraps to a second line,
  // making the stepper (and the whole controls bar) taller. Scaling the box
  // with the ambient text scaler — never below the original width, so the
  // default-scale layout is untouched — keeps that from happening for
  // realistic values, and the labels' own maxLines: 1 keeps the height
  // stable even when it does.
  double _valueLabelWidth({
    required double base,
    required double fontSize,
    required double emCount,
  }) {
    final double scaled =
        MediaQuery.textScalerOf(context).scale(fontSize) * emCount;
    return math.max(base, scaled);
  }

  Widget _buildSlotCountControl({
    bool isCompact = false,
    bool isVertical = false,
    double scale = 1.0,
  }) {
    // Compact floor raised from 28 to 36 — the original shrank below common
    // 44dp touch-target guidance on small landscape screens, a real problem
    // for a control meant to be used hands-on-instrument.
    final double buttonSize = (isCompact ? 36.0 : 38.0) * scale;
    final minusButton = _buildCounterButton(
      icon: Icons.remove_rounded,
      size: buttonSize,
      onPressed: _slotsCount > 2 ? _decrementSlotCount : null,
    );
    final plusButton = _buildCounterButton(
      icon: Icons.add_rounded,
      size: buttonSize,
      onPressed: _slotsCount < 7 ? _incrementSlotCount : null,
    );
    final double countFontSize = (isCompact ? 13.0 : 16.0) * scale;
    final countLabel = Text(
      '$_slotsCount',
      textAlign: TextAlign.center,
      // Single line, always: inside the fixed-width box below a value that
      // doesn't fit would otherwise wrap onto a second line, growing the
      // stepper — and with it the whole controls bar, which pushes the
      // Expanded tile grid up and forces it to relayout. See
      // _valueLabelWidth for the other half of the guard.
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: TextStyle(
        fontSize: countFontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );

    // Vertical (narrow landscape side panel): stacked so the control never
    // needs more width than a single button. Order is + on top, - on the
    // bottom (mirrored from the portrait row) so the raise action sits
    // closer to the top of the panel.
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
        SizedBox(
          width: _valueLabelWidth(
            base: isCompact ? 26 : 34,
            fontSize: countFontSize,
            emCount: 1.0,
          ),
          child: countLabel,
        ),
        plusButton,
      ],
    );
  }

  // ── Quick speed (BPM) slider (main screen, outside the settings sheet) ──
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
        value: _bpm.toDouble().clamp(40, 240),
        min: 40,
        max: 240,
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
          Icon(
            Icons.speed_rounded,
            color: AppColors.textSecondary,
            size: 16 * scale,
          ),
          _buildSpeedSlider(
            isVertical: true,
            verticalHeight: sliderHeight,
            scale: scale,
          ),
          Text(
            '$_bpm',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
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
        const Icon(
          Icons.speed_rounded,
          color: AppColors.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(child: _buildSpeedSlider()),
        const SizedBox(width: 6),
        SizedBox(
          width: _valueLabelWidth(base: 36, fontSize: 13, emCount: 2.0),
          child: Text(
            '$_bpm',
            textAlign: TextAlign.end,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
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

  // ── Empty State ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.music_note_rounded,
      title: 'Genera un ritmo per iniziare',
    );
  }

  // ── Rhythm Slots Grid Widget ──────────────────────────────────────────────
  // All N slots are placed in a single responsive row.  Each tile's side
  // length is calculated dynamically via _calcTileSize so they always fit
  // within the available width — no horizontal overflow, ever.
  Widget _buildSlotsGrid(bool isLandscape) {
    final int n = _generatedSlots.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double outerPadding = 12.0;
        final double gap = n <= 3 ? 12.0 : n <= 5 ? 10.0 : 8.0;
        final double tileSize = _calcTileSize(constraints.maxWidth, n);
        final double imagePadding = (tileSize * 0.10).clamp(4.0, 14.0);
        final double radius = (tileSize * 0.14).clamp(8.0, AppRadius.lg);

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: outerPadding,
              vertical: 20.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (int index = 0; index < n; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  KeyedSubtree(
                    key: index < _slotKeys.length ? _slotKeys[index] : null,
                    child: _buildSlotTile(
                      index: index,
                      tileSize: tileSize,
                      imagePadding: imagePadding,
                      radius: radius,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Single Slot Tile ─────────────────────────────────────────────────────
  Widget _buildSlotTile({
    required int index,
    required double tileSize,
    required double imagePadding,
    required double radius,
  }) {
    final slot = _generatedSlots[index];
    final bool isActive = _playbackService.isPlaying &&
        _playbackService.currentElementIndex == index;
    final bool isAccented = slot.isAccented;

    return GestureDetector(
      key: FlowModePage.slotKey(index),
      // Tocca una tessera per accentare il suo movimento (e ritocca per
      // togliere l'accento): è l'unico gesto sulla griglia, quindi non
      // ruba niente ad altre interazioni.
      onTap: () => _toggleSlotAccent(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        // width/height animate when tileSize changes (slot-count change)
        width: tileSize,
        height: tileSize,
        // scale animates for the active-beat highlight
        transform: Matrix4.identity()
          ..translateByDouble(tileSize / 2, tileSize / 2, 0, 1)
          ..scaleByDouble(isActive ? 1.06 : 1.0, isActive ? 1.06 : 1.0, 1, 1)
          ..translateByDouble(-tileSize / 2, -tileSize / 2, 0, 1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : isAccented
                ? AppColors.tertiary
                : AppColors.surfaceBorder,
            width: isActive
                ? 3.5
                : isAccented
                ? 2.5
                : 1.5,
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
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(imagePadding),
                  child: Image.asset(
                    slot.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (isAccented)
                Positioned(
                  top: tileSize * 0.04,
                  left: tileSize * 0.08,
                  // Il segno di accento della notazione, ">".
                  child: Text(
                    '>',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: tileSize * 0.26,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Metronome Beat Pulsing Indicator ──────────────────────────────────────
  Widget _buildMetronomeIndicator() {
    final textTheme = Theme.of(context).textTheme;

    if (!_playbackService.isPlaying) {
      return const SizedBox(height: 52);
    }

    final beatNum = _currentBeatNumber;

    return AnimatedBuilder(
      animation: _beatPulseController,
      builder: (context, child) {
        final double t = _beatPulseController.value;
        return Transform.scale(
          scale: 1.0 + t * 0.05,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1 + t * 0.06),
              borderRadius: BorderRadius.circular(AppRadius.xl - 4),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2 + t * 0.15)),
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'MOVIMENTO: ',
            style: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.1),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Text(
              '$beatNum',
              key: ValueKey<int>(beatNum),
              style: textTheme.displaySmall?.copyWith(color: AppColors.primary, fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
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
                _buildMetronomeIndicator(),
                Expanded(child: _buildGridArea(isLandscape)),
                _buildControlsBar(isLandscape),
              ],
            ),
            landscapePrimary: (context) => Column(
              children: [
                _buildMetronomeIndicator(),
                Expanded(child: _buildGridArea(isLandscape)),
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

  Widget _buildGridArea(bool isLandscape) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _generatedSlots.isEmpty
        ? _buildEmptyState()
        : _buildSlotsGrid(isLandscape);
  }

  // Landscape side panel content: adapts its spacing/slider/button size to
  // the available width and height, so it stays tiny (but overflow-safe) on
  // very small phones and grows comfortably on tablets/large screens instead
  // of staying pinned to phone-sized buttons. Wrapped in a scroll view as a
  // safety net so it can never hard-overflow, even on very short screens.
  double _landscapePanelScale(double width, double height) {
    final double widthT = ((width - 110.0) / 140.0).clamp(0.0, 1.0);
    final double heightT = ((height - 320.0) / 380.0).clamp(0.0, 1.0);
    final double t = math.min(widthT, heightT);
    return 1.0 + t * 0.5; // 1.0 (small screens) .. 1.5 (large screens)
  }

  Widget _buildLandscapeControlsColumn(bool isPlaying) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;
        final double scale = _landscapePanelScale(
          constraints.maxWidth,
          availableHeight,
        );
        final double sliderHeight =
            (availableHeight < 260
                ? 55.0
                : availableHeight < 340
                ? 80.0
                : 110.0) *
            scale;
        final double gap = (availableHeight < 260 ? 6.0 : 12.0) * scale;

        final Widget autoButton = _buildControlButton(
          icon: Icons.autorenew_rounded,
          color: _isAutoGenerateEnabled ? AppColors.primary : AppColors.textSecondary,
          onTap: () {
            setState(() {
              _onAutoGenerateToggled(!_isAutoGenerateEnabled);
            });
          },
          label: 'Auto',
          isCompact: true,
          scale: scale,
        );

        final Widget generateButton = _buildControlButton(
          icon: Icons.shuffle_rounded,
          color: AppColors.primary,
          onTap: () => _generateNewRhythm(),
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
                  isCompact: true,
                  isVertical: true,
                  scale: scale,
                ),
                SizedBox(height: gap),
                _buildPlayButton(isPlaying, isCompact: true, scale: scale),
                SizedBox(height: gap),
                _buildSpeedControl(
                  isCompact: true,
                  sliderHeight: sliderHeight,
                  scale: scale,
                ),
                SizedBox(height: gap),
                generateButton,
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Controls Bar ─────────────────────────────────────────────────────────
  // Portrait: a bottom bar with buttons in a row (plus a quick slot-count
  // stepper and speed slider above it). Landscape: a side panel with
  // everything stacked in a column, so the notation grid keeps full height.
  Widget _buildControlsBar(bool isLandscape) {
    final bool isPlaying = _playbackService.isPlaying;

    return Container(
      key: FlowModePage.controlsBarKey,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 24,
        vertical: isLandscape ? 16 : 16,
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
                    // Flexible: at large system text scales the labels are
                    // what set these buttons' width, and on a narrow phone
                    // 'Generate' alone could push the row past the screen.
                    // Loose flex caps them and the labels ellipsize instead.
                    Flexible(
                      child: _buildControlButton(
                        icon: Icons.autorenew_rounded,
                        color: _isAutoGenerateEnabled ? AppColors.primary : AppColors.textSecondary,
                        onTap: () {
                          setState(() {
                            _onAutoGenerateToggled(!_isAutoGenerateEnabled);
                          });
                        },
                        label: 'Auto',
                      ),
                    ),
                    _buildPlayButton(isPlaying),
                    Flexible(
                      child: _buildControlButton(
                        icon: Icons.shuffle_rounded,
                        color: AppColors.primary,
                        onTap: () => _generateNewRhythm(),
                        label: 'Generate',
                      ),
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
    final isDisabled = _generatedSlots.isEmpty;
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
                  ? [AppColors.surfaceBorder, AppColors.surfaceBorder.withValues(alpha: 0.5)]
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
    // Compact floor raised from 34 to 40 for the same touch-target reason
    // as the slot-count stepper above.
    final double size = (isCompact ? 40.0 : 44.0) * scale;
    final BorderRadius radius = BorderRadius.circular(isCompact ? AppRadius.sm + 2 : AppRadius.md);

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
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
                ),
                child: Icon(icon, color: color, size: (isCompact ? 18.0 : 22.0) * scale),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
