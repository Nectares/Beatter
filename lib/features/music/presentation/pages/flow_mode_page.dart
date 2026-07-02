import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../../../auth/presentation/pages/login_page.dart';

class FlowModePage extends StatefulWidget {
  const FlowModePage({super.key});

  @override
  State<FlowModePage> createState() => _FlowModePageState();
}

class _FlowModePageState extends State<FlowModePage> with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  late RhythmPlaybackService _playbackService;
  
  // ── Settings ─────────────────────────────────────────────────────────────
  int _bpm = 120;
  String _selectedTimeSignature = '4/4';
  int _slotsCount = 4;
  
  // ── Assets & State ────────────────────────────────────────────────────────
  List<String> _rhythmAssets = [];
  final Map<String, bool> _enabledAssets = {};
  List<RhythmSlot> _generatedSlots = [];
  bool _isLoading = true;

  // ── Auto-Generation Timer ────────────────────────────────────────────────
  bool _isAutoGenerateEnabled = false;
  double _autoGenerateSeconds = 5.0; // Default 5 seconds
  Timer? _autoGenerateTimer;

  // ── UI Controllers ────────────────────────────────────────────────────────
  late TextEditingController _bpmTextController;

  @override
  void initState() {
    super.initState();

    // Enable rotation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _playbackService = RhythmPlaybackService();
    _playbackService.updateSettings(bpm: _bpm);
    _playbackService.addListener(_onPlaybackChanged);

    _bpmTextController = TextEditingController(text: _bpm.toString());

    // Load assets dynamically
    _loadAssets();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    _bpmTextController.dispose();
    _stopAutoGenerateTimer();
    super.dispose();
  }

  // ── Load Assets Dynamically ────────────────────────────────────────────────
  Future<void> _loadAssets() async {
    List<String> paths = [];
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      paths = manifest.listAssets()
          .where((key) => (key.startsWith('assets/icon/') || key.startsWith('assets/icons/')) && key.endsWith('.png'))
          .toList();
    } catch (_) {}

    if (paths.isEmpty) {
      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        paths = manifestMap.keys
            .where((key) => (key.startsWith('assets/icon/') || key.startsWith('assets/icons/')) && key.endsWith('.png'))
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

      // Precache images in Flutter image cache
      for (var path in _rhythmAssets) {
        precacheImage(AssetImage(path), context);
      }

      _generateNewRhythm();
    }
  }

  // ── Rhythm Generation ────────────────────────────────────────────────────
  void _generateNewRhythm({bool fromTimer = false}) {
    if (!fromTimer && _isAutoGenerateEnabled) {
      _startAutoGenerateTimer(); // Reset timer on manual action
    }

    final activeAssets = _rhythmAssets.where((p) => _enabledAssets[p] == true).toList();
    if (activeAssets.isEmpty) {
      activeAssets.addAll(_rhythmAssets);
    }

    final List<RhythmSlot> slots = [];
    final rand = math.Random();
    for (int i = 0; i < _slotsCount; i++) {
      final randomAsset = activeAssets[rand.nextInt(activeAssets.length)];
      slots.add(RhythmSlot.fromAsset(randomAsset));
    }

    final wasPlaying = _playbackService.isPlaying;
    _playbackService.stop();

    setState(() {
      _generatedSlots = slots;
    });

    _playbackService.prepareSlotPlayback(slots, _selectedTimeSignature);

    if (wasPlaying) {
      _playbackService.play();
    }
  }

  // ── Playback Listener ────────────────────────────────────────────────────
  void _onPlaybackChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ── BPM Helpers ──────────────────────────────────────────────────────────
  void _onBpmChanged(String val) {
    final p = int.tryParse(val);
    if (p != null && p >= 40 && p <= 240) {
      setState(() => _bpm = p);
      _playbackService.updateSettings(bpm: p);
    }
  }

  void _onBpmSlider(double val) {
    setState(() {
      _bpm = val.toInt();
      _bpmTextController.text = _bpm.toString();
    });
    _playbackService.updateSettings(bpm: _bpm);
  }

  // ── Playback Controls ────────────────────────────────────────────────────
  /// Toggle Play/Pause del loop infinito.
  void _togglePlay() {
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

  // ── Metronome Count Helper ────────────────────────────────────────────────
  int get _beatsPerMeasure {
    if (_selectedTimeSignature == '3/4') return 3;
    if (_selectedTimeSignature == '6/8') return 6;
    return 4; // 4/4 default
  }

  int get _currentBeatNumber {
    final idx = _playbackService.currentElementIndex;
    if (idx < 0) return 1;
    return (idx % _beatsPerMeasure) + 1;
  }

  // ── Grid Helper ──────────────────────────────────────────────────────────
  int _getGridColumns(int slotCount, bool isLandscape) {
    if (isLandscape) {
      if (slotCount <= 4) return slotCount;
      if (slotCount <= 6) return 3;
      if (slotCount <= 8) return 4;
      return 6;
    } else {
      if (slotCount <= 3) return slotCount;
      if (slotCount <= 4) return 2;
      if (slotCount <= 6) return 2;
      if (slotCount <= 8) return 2;
      return 3;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  void _logout() {
    _stopAutoGenerateTimer();
    _playbackService.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ── Show Settings Bottom Sheet ───────────────────────────────────────────
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
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
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
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
                          color: AppTheme.textMuted.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Title Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: AppTheme.primaryPurple, size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'Rhythm Settings',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.cardBorder),
                      
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
                                      activeColor: AppTheme.primaryPurple,
                                      inactiveColor: const Color(0xFFFFEAD6),
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
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppTheme.primaryPurple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                        fillColor: Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        _onBpmChanged(v);
                                        final p = int.tryParse(v);
                                        if (p != null) {
                                          setSheetState(() => _bpm = p);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Time Signature ───────────────────────────
                              _buildSectionTitle('TIME SIGNATURE'),
                              const SizedBox(height: 8),
                              Row(
                                children: ['4/4', '3/4', '6/8'].map((sig) {
                                  final isSelected = _selectedTimeSignature == sig;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedTimeSignature = sig);
                                        setSheetState(() => _selectedTimeSignature = sig);
                                        _generateNewRhythm();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.primaryPurple : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.primaryPurple : AppTheme.cardBorder,
                                            width: 1.5,
                                          ),
                                          boxShadow: isSelected ? [
                                            BoxShadow(
                                              color: AppTheme.primaryPurple.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            )
                                          ] : null,
                                        ),
                                        child: Text(
                                          sig,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),

                              // ── Slot Count (+ / -) ───────────────────────
                              _buildSectionTitle('NUMERO DI SLOT'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCounterButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: _slotsCount > 2
                                        ? () {
                                            setState(() => _slotsCount--);
                                            setSheetState(() => _slotsCount--);
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
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _buildCounterButton(
                                    icon: Icons.add_rounded,
                                    onPressed: _slotsCount < 16
                                        ? () {
                                            setState(() => _slotsCount++);
                                            setSheetState(() => _slotsCount++);
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
                                    activeColor: AppTheme.primaryPurple,
                                    onChanged: (val) {
                                      setSheetState(() => _isAutoGenerateEnabled = val);
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
                                        activeColor: AppTheme.primaryPurple,
                                        inactiveColor: const Color(0xFFFFEAD6),
                                        onChanged: (v) {
                                          setSheetState(() => _autoGenerateSeconds = v);
                                          _onAutoGenerateSpeedChanged(v);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_autoGenerateSeconds.toInt()}s',
                                      style: const TextStyle(
                                        color: AppTheme.primaryPurple,
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
                                      color: AppTheme.textSecondary.withOpacity(0.8),
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
                                        final allOn = _enabledAssets.values.contains(false);
                                        for (var k in _enabledAssets.keys) {
                                          _enabledAssets[k] = allOn;
                                        }
                                      });
                                      setState(() {});
                                      _generateNewRhythm();
                                    },
                                    child: const Text(
                                      'Tutte / Nessuna',
                                      style: TextStyle(color: AppTheme.primaryPurple, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _rhythmAssets.length,
                                itemBuilder: (context, idx) {
                                  final path = _rhythmAssets[idx];
                                  final isEnabled = _enabledAssets[path] ?? false;

                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        _enabledAssets[path] = !isEnabled;
                                      });
                                      setState(() {});
                                      _generateNewRhythm();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isEnabled ? AppTheme.primaryPurple : AppTheme.cardBorder,
                                          width: isEnabled ? 2.5 : 1.0,
                                        ),
                                        boxShadow: isEnabled ? [
                                          BoxShadow(
                                            color: AppTheme.primaryPurple.withOpacity(0.15),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ] : null,
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Opacity(
                                                opacity: isEnabled ? 1.0 : 0.4,
                                                child: Image.asset(path, fit: BoxFit.contain),
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
                                                  color: AppTheme.primaryPurple,
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
                                        final newVal = !_playbackService.isMetronomeEnabled;
                                        setSheetState(() {});
                                        _playbackService.updateSettings(isMetronomeEnabled: newVal);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _playbackService.isMetronomeEnabled
                                              ? AppTheme.primaryPurple.withOpacity(0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _playbackService.isMetronomeEnabled
                                                ? AppTheme.primaryPurple
                                                : AppTheme.cardBorder,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _playbackService.isMetronomeEnabled
                                                  ? Icons.graphic_eq_rounded
                                                  : Icons.volume_off_rounded,
                                              color: _playbackService.isMetronomeEnabled
                                                  ? AppTheme.primaryPurple
                                                  : AppTheme.textSecondary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Metronomo',
                                              style: TextStyle(
                                                color: _playbackService.isMetronomeEnabled
                                                    ? AppTheme.primaryPurple
                                                    : AppTheme.textSecondary,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _playbackService.soundInstrument,
                                      dropdownColor: Colors.white,
                                      underline: const SizedBox(),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'snare', child: Text('🥁 Snare')),
                                        DropdownMenuItem(value: 'stick', child: Text('🥢 Stick')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setSheetState(() {});
                                          _playbackService.updateSettings(soundInstrument: v);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

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
                                    backgroundColor: AppTheme.primaryPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shuffle_rounded, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text(
                                        'GENERATE RHYTHM',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _logout();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout_rounded),
                                      SizedBox(width: 10),
                                      Text(
                                        'LOGOUT',
                                        style: TextStyle(fontWeight: FontWeight.bold),
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
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCounterButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: onPressed != null ? AppTheme.primaryPurple.withOpacity(0.1) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onPressed != null ? AppTheme.primaryPurple.withOpacity(0.3) : AppTheme.cardBorder.withOpacity(0.5),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed != null ? AppTheme.primaryPurple : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note_rounded,
          size: 64,
          color: AppTheme.textMuted.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'Genera un ritmo per iniziare',
          style: TextStyle(
            color: AppTheme.textMuted.withOpacity(0.6),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Rhythm Slots Grid Widget ──────────────────────────────────────────────
  Widget _buildSlotsGrid(bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getGridColumns(_generatedSlots.length, isLandscape),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
            ),
            itemCount: _generatedSlots.length,
            itemBuilder: (context, index) {
              final slot = _generatedSlots[index];
              final bool isActive = _playbackService.isPlaying && _playbackService.currentElementIndex == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                transform: Matrix4.identity()..scale(isActive ? 1.06 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? AppTheme.primaryPurple : AppTheme.cardBorder,
                    width: isActive ? 3.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? AppTheme.primaryPurple.withOpacity(0.4)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isActive ? 16 : 6,
                      spreadRadius: isActive ? 2 : 0,
                      offset: isActive ? const Offset(0, 4) : const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        slot.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Metronome Beat Pulsing Indicator ──────────────────────────────────────
  Widget _buildMetronomeIndicator() {
    if (!_playbackService.isPlaying) {
      return const SizedBox(height: 52);
    }

    final beatNum = _currentBeatNumber;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: AppTheme.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'MOVIMENTO: ',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              '$beatNum',
              key: ValueKey<int>(beatNum),
              style: const TextStyle(
                color: AppTheme.primaryPurple,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
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
    final orientation = MediaQuery.of(context).orientation;
    final bool isLandscape = orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppTheme.textPrimary),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        title: const Text(
          'Beatter Flow Mode',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textPrimary),
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
          child: Column(
            children: [
              // Metronome pulse indicator
              _buildMetronomeIndicator(),

              // Notation Grid area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _generatedSlots.isEmpty
                        ? _buildEmptyState()
                        : _buildSlotsGrid(isLandscape),
              ),

              // Controls Bar
              _buildControlsBar(isLandscape),
            ],
          ),
        ),
      ),
    );
  }

  // ── Controls Bar ─────────────────────────────────────────────────────────
  Widget _buildControlsBar(bool isLandscape) {
    final bool isPlaying = _playbackService.isPlaying;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isLandscape ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: const Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop Button
          _buildControlButton(
            icon: Icons.stop_rounded,
            color: AppTheme.textSecondary,
            onTap: _playbackService.stop,
            label: 'Stop',
          ),

          // Play / Pause Button
          _buildPlayButton(isPlaying),

          // Generate Rhythm Button
          _buildControlButton(
            icon: Icons.shuffle_rounded,
            color: AppTheme.primaryPurple,
            onTap: () => _generateNewRhythm(),
            label: 'Generate',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(bool isPlaying) {
    return GestureDetector(
      onTap: _togglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isPlaying
                ? [const Color(0xFFFFC266), AppTheme.primaryPurple]
                : [AppTheme.primaryPurple, const Color(0xFFFF9E47)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
