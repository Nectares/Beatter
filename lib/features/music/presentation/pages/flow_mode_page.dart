import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/rhythm_element.dart';
import '../../../../services/rhythm_generator_service.dart';
import '../../../../services/rhythm_playback_service.dart';
import '../widgets/rhythm_line_painter.dart';
import '../../../auth/presentation/pages/login_page.dart';

class FlowModePage extends StatefulWidget {
  const FlowModePage({super.key});

  @override
  State<FlowModePage> createState() => _FlowModePageState();
}

class _FlowModePageState extends State<FlowModePage>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  late RhythmPlaybackService _playbackService;
  List<RhythmMeasure> _generatedMeasures = [];

  // ── Settings ─────────────────────────────────────────────────────────────
  int _bpm = 120;
  String _selectedTimeSignature = '4/4';
  int _measuresCount = 4;
  final Map<RhythmElementType, bool> _enabledFigures = {
    RhythmElementType.quarter: true,
    RhythmElementType.eighth: true,
    RhythmElementType.sixteenth: false,
    RhythmElementType.quarterRest: true,
    RhythmElementType.eighthRest: false,
    RhythmElementType.sixteenthRest: false,
    RhythmElementType.triplet: false,
  };

  // ── UI Controllers ────────────────────────────────────────────────────────
  late TextEditingController _bpmTextController;
  final ScrollController _staffScrollController = ScrollController();

  // ── Animation: highlight pulse ────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Animation: playback controls fade ────────────────────────────────────
  late AnimationController _controlsController;
  late Animation<double> _controlsAnimation;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _controlsVisible = true;
  double _noteScale = 1.0;

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

    // Highlight pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseAnimation.addListener(() => setState(() {}));

    // Playback controls fade animation
    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeInOut,
    );

    _generateNewRhythm();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playbackService.removeListener(_onPlaybackChanged);
    _playbackService.stop();
    _playbackService.dispose();
    _bpmTextController.dispose();
    _staffScrollController.dispose();
    _pulseController.dispose();
    _controlsController.dispose();
    super.dispose();
  }

  // ── Playback listener ────────────────────────────────────────────────────
  void _onPlaybackChanged() {
    if (!mounted) return;
    setState(() {});

    // Trigger highlight pulse on each new note
    if (_playbackService.isPlaying) {
      _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
      _autoScroll();
    }
  }

  // ── Auto-scroll ──────────────────────────────────────────────────────────
  void _autoScroll() {
    if (!_staffScrollController.hasClients) return;
    if (_playbackService.currentMeasureIndex < 0) return;

    final double targetX = _calculateNoteX(
      _playbackService.currentMeasureIndex,
      _playbackService.currentElementIndex,
    );

    final double screenWidth = MediaQuery.of(context).size.width;
    double offset = targetX - screenWidth / 2;
    offset = offset.clamp(
      0.0,
      _staffScrollController.position.maxScrollExtent,
    );

    _staffScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
    );
  }

  double _calculateNoteX(int measureIndex, int elementIndex) {
    if (_generatedMeasures.isEmpty) return 0;
    final double ns = _noteScale;
    double x = 16.0 * ns + 30.0 * ns; // left margin + time sig

    for (int m = 0; m < measureIndex && m < _generatedMeasures.length; m++) {
      x += _measureWidth(_generatedMeasures[m].timeSignature, ns);
    }

    if (measureIndex < _generatedMeasures.length) {
      final measure = _generatedMeasures[measureIndex];
      final double mw = _measureWidth(measure.timeSignature, ns);
      final double pad = 18.0 * ns;
      final double content = mw - pad * 2;
      final double totalBeats = _beatsInMeasure(measure.timeSignature);

      double elapsed = 0;
      for (int e = 0; e < elementIndex && e < measure.elements.length; e++) {
        elapsed += measure.elements[e].duration;
      }
      x += pad + (elapsed / totalBeats) * content;
    }
    return x;
  }

  double _measureWidth(String sig, double scale) {
    return _beatsInMeasure(sig) * 52.0 * scale + 18.0 * scale * 2;
  }

  double _beatsInMeasure(String sig) {
    if (sig == '3/4') return 3.0;
    if (sig == '6/8') return 3.0;
    return 4.0;
  }

  // ── Rhythm generation ────────────────────────────────────────────────────
  void _generateNewRhythm() {
    _playbackService.stop();
    final measures = RhythmGeneratorService.generate(
      timeSignature: _selectedTimeSignature,
      measuresCount: _measuresCount,
      enabledFigures: _enabledFigures,
    );
    setState(() => _generatedMeasures = measures);
    _playbackService.preparePlayback(measures);
    if (_staffScrollController.hasClients) {
      _staffScrollController.jumpTo(0);
    }
  }

  // ── BPM helpers ──────────────────────────────────────────────────────────
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

  // ── Playback controls ────────────────────────────────────────────────────
  void _togglePlay() {
    if (_playbackService.isPlaying) {
      _playbackService.pause();
    } else {
      _playbackService.play();
    }
  }

  // ── Controls visibility in landscape ────────────────────────────────────
  void _toggleControlsVisibility() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _controlsController.forward();
    } else {
      _controlsController.reverse();
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ── Settings Bottom Sheet ─────────────────────────────────────────────────
  void _showSettings() {
    Navigator.pop(context); // close drawer first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(
        bpm: _bpm,
        bpmController: _bpmTextController,
        selectedTimeSignature: _selectedTimeSignature,
        measuresCount: _measuresCount,
        enabledFigures: _enabledFigures,
        isMetronomeEnabled: _playbackService.isMetronomeEnabled,
        soundInstrument: _playbackService.soundInstrument,
        onBpmSlider: _onBpmSlider,
        onBpmText: _onBpmChanged,
        onTimeSignature: (sig) {
          setState(() => _selectedTimeSignature = sig);
          _generateNewRhythm();
        },
        onMeasuresCount: (count) {
          setState(() => _measuresCount = count);
          _generateNewRhythm();
        },
        onFigureToggle: (type, val) {
          setState(() => _enabledFigures[type] = val);
          _generateNewRhythm();
        },
        onMetronome: (val) => _playbackService.updateSettings(isMetronomeEnabled: val),
        onInstrument: (val) => _playbackService.updateSettings(soundInstrument: val),
        onGenerate: () {
          Navigator.pop(context);
          _generateNewRhythm();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final size = MediaQuery.of(context).size;
    final bool isLandscape = orientation == Orientation.landscape;
    final bool isTablet = size.shortestSide >= 600;

    _noteScale = isTablet
        ? 1.5
        : isLandscape
            ? 1.3
            : 1.0;

    final double staffHeight = isLandscape
        ? size.height * 0.72
        : size.height * 0.62;

    final double totalWidth = RhythmLinePainter.computeTotalWidth(
      _generatedMeasures,
      _noteScale,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isLandscape && _playbackService.isPlaying
          ? null // hide AppBar during landscape playback
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              title: const Text(
                'Random Rhythm Generator',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.4,
                  color: AppTheme.textPrimary,
                ),
              ),
              iconTheme: const IconThemeData(color: AppTheme.textPrimary),
            ),
      drawer: _buildDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: Stack(
          children: [
            // Decorative glowing orbs
            _buildGlowOrb(
              top: -80, right: -80, size: 260,
              color: AppTheme.secondaryCyan.withOpacity(0.12),
            ),
            _buildGlowOrb(
              bottom: -60, left: -60, size: 220,
              color: AppTheme.primaryPurple.withOpacity(0.10),
            ),

            // Main layout
            SafeArea(
              child: Column(
                children: [
                  // ── Notation area ─────────────────────────────────────────
                  Expanded(
                    child: GestureDetector(
                      onTap: isLandscape ? _toggleControlsVisibility : null,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_generatedMeasures.isEmpty)
                              _buildEmptyState()
                            else
                              _buildNotationArea(
                                totalWidth: totalWidth,
                                staffHeight: staffHeight,
                                isLandscape: isLandscape,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Playback controls bar ─────────────────────────────────
                  FadeTransition(
                    opacity: _controlsAnimation,
                    child: _buildControlsBar(isLandscape),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Notation area widget ─────────────────────────────────────────────────
  Widget _buildNotationArea({
    required double totalWidth,
    required double staffHeight,
    required bool isLandscape,
  }) {
    return Container(
      height: staffHeight,
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: isLandscape ? 0 : 12,
        vertical: isLandscape ? 0 : 8,
      ),
      decoration: isLandscape
          ? null
          : BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder, width: 1.2),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLandscape ? 0 : 20),
        child: RepaintBoundary(
          child: SingleChildScrollView(
            controller: _staffScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(totalWidth, staffHeight),
                  painter: RhythmLinePainter(
                    measures: _generatedMeasures,
                    activeMeasureIndex: _playbackService.currentMeasureIndex,
                    activeElementIndex: _playbackService.currentElementIndex,
                    activeTripletIndex: _playbackService.currentTripletIndex,
                    highlightScale: _pulseAnimation.value,
                    noteScale: _noteScale,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── Playback controls bar ────────────────────────────────────────────────
  Widget _buildControlsBar(bool isLandscape) {
    final bool isPlaying = _playbackService.isPlaying;
    final bool isMetronome = _playbackService.isMetronomeEnabled;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isLandscape ? 0.5 : 0.3),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop
          _buildControlButton(
            icon: Icons.stop_rounded,
            color: AppTheme.textSecondary,
            onTap: _playbackService.stop,
            label: 'Stop',
          ),

          // Play / Pause (main)
          _buildPlayButton(isPlaying),

          // Metronome
          _buildMetronomeButton(isMetronome),

          // Generate (hidden during playback on landscape)
          if (!isLandscape || !isPlaying)
            _buildControlButton(
              icon: Icons.shuffle_rounded,
              color: AppTheme.secondaryCyan,
              onTap: _generateNewRhythm,
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
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isPlaying
                ? [AppTheme.accentPink, AppTheme.primaryPurple]
                : [AppTheme.secondaryCyan, AppTheme.primaryPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPlaying ? AppTheme.accentPink : AppTheme.secondaryCyan)
                  .withOpacity(0.45),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetronomeButton(bool isOn) {
    return GestureDetector(
      onTap: () => _playbackService.updateSettings(isMetronomeEnabled: !isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOn
                    ? AppTheme.primaryPurple.withOpacity(0.2)
                    : AppTheme.textMuted.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOn ? AppTheme.primaryPurple : AppTheme.cardBorder,
                  width: 1.2,
                ),
              ),
              child: Icon(
                isOn ? Icons.graphic_eq_rounded : Icons.volume_off_rounded,
                color: isOn ? AppTheme.primaryPurple : AppTheme.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Metro',
              style: TextStyle(
                color: isOn
                    ? AppTheme.primaryPurple.withOpacity(0.8)
                    : AppTheme.textMuted.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F1120),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withOpacity(0.4),
                    AppTheme.secondaryCyan.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.accentPink],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Beatter',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Rhythm Studio',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _buildDrawerSection('MODULES'),
                  _buildDrawerItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Random Rhythm Generator',
                    subtitle: 'Flow Mode',
                    color: AppTheme.secondaryCyan,
                    isActive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Flow Mode',
                    color: AppTheme.secondaryCyan,
                    isActive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerComingSoon(
                    icon: Icons.self_improvement_rounded,
                    title: 'Practice Mode',
                  ),
                  _buildDrawerComingSoon(
                    icon: Icons.menu_book_rounded,
                    title: 'Sight Reading',
                  ),
                  _buildDrawerComingSoon(
                    icon: Icons.grid_4x4_rounded,
                    title: 'Polyrhythms',
                  ),

                  const SizedBox(height: 8),
                  _buildDrawerDivider(),
                  const SizedBox(height: 8),

                  _buildDrawerSection('APP'),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    color: AppTheme.textSecondary,
                    onTap: _showSettings,
                  ),
                ],
              ),
            ),

            // Logout at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDrawerItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                color: AppTheme.accentPink,
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: color.withOpacity(0.3), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(icon, color: isActive ? color : AppTheme.textSecondary, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? color : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerComingSoon({
    required IconData icon,
    required String title,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        enabled: false,
        leading: Icon(icon, color: AppTheme.textMuted.withOpacity(0.4), size: 20),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textMuted.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Soon',
                style: TextStyle(
                  color: AppTheme.textMuted.withOpacity(0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        onTap: null,
      ),
    );
  }

  Widget _buildDrawerDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.cardBorder,
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.music_note_rounded,
          size: 64,
          color: AppTheme.textMuted.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap Generate to start',
          style: TextStyle(
            color: AppTheme.textMuted.withOpacity(0.5),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ─── Decorative glow orb ──────────────────────────────────────────────────
  Widget _buildGlowOrb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Bottom Sheet (extracted as separate StatefulWidget for local state)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final int bpm;
  final TextEditingController bpmController;
  final String selectedTimeSignature;
  final int measuresCount;
  final Map<RhythmElementType, bool> enabledFigures;
  final bool isMetronomeEnabled;
  final String soundInstrument;

  final ValueChanged<double> onBpmSlider;
  final ValueChanged<String> onBpmText;
  final ValueChanged<String> onTimeSignature;
  final ValueChanged<int> onMeasuresCount;
  final void Function(RhythmElementType, bool) onFigureToggle;
  final ValueChanged<bool> onMetronome;
  final ValueChanged<String> onInstrument;
  final VoidCallback onGenerate;

  const _SettingsSheet({
    required this.bpm,
    required this.bpmController,
    required this.selectedTimeSignature,
    required this.measuresCount,
    required this.enabledFigures,
    required this.isMetronomeEnabled,
    required this.soundInstrument,
    required this.onBpmSlider,
    required this.onBpmText,
    required this.onTimeSignature,
    required this.onMeasuresCount,
    required this.onFigureToggle,
    required this.onMetronome,
    required this.onInstrument,
    required this.onGenerate,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late int _bpm;
  late String _timeSig;
  late int _measures;
  late Map<RhythmElementType, bool> _figures;
  late bool _metro;
  late String _instrument;

  @override
  void initState() {
    super.initState();
    _bpm       = widget.bpm;
    _timeSig   = widget.selectedTimeSignature;
    _measures  = widget.measuresCount;
    _figures   = Map.from(widget.enabledFigures);
    _metro     = widget.isMetronomeEnabled;
    _instrument = widget.soundInstrument;
  }

  static const Map<RhythmElementType, String> _figureLabels = {
    RhythmElementType.quarter:       'Semiminima (1/4)',
    RhythmElementType.eighth:        'Croma (1/8)',
    RhythmElementType.sixteenth:     'Semicroma (1/16)',
    RhythmElementType.quarterRest:   'Pausa 1/4',
    RhythmElementType.eighthRest:    'Pausa 1/8',
    RhythmElementType.sixteenthRest: 'Pausa 1/16',
    RhythmElementType.triplet:       'Terzine',
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F1E).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const Icon(Icons.settings_rounded,
                        color: AppTheme.secondaryCyan, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── BPM ──────────────────────────────────────────────
                      _sectionTitle('Tempo (BPM)'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.secondaryCyan,
                                inactiveTrackColor: AppTheme.cardBorder,
                                thumbColor: AppTheme.secondaryCyan,
                                overlayColor: AppTheme.secondaryCyan.withOpacity(0.15),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: _bpm.toDouble(),
                                min: 40,
                                max: 240,
                                onChanged: (v) {
                                  setState(() => _bpm = v.toInt());
                                  widget.onBpmSlider(v);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 58,
                            height: 36,
                            child: TextField(
                              controller: widget.bpmController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.secondaryCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                fillColor: Colors.black.withOpacity(0.3),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.secondaryCyan,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (v) {
                                widget.onBpmText(v);
                                final p = int.tryParse(v);
                                if (p != null) setState(() => _bpm = p);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Time Signature ───────────────────────────────────
                      _sectionTitle('Time Signature'),
                      const SizedBox(height: 10),
                      Row(
                        children: ['4/4', '3/4', '6/8'].map((sig) {
                          final sel = _timeSig == sig;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _timeSig = sig);
                                widget.onTimeSignature(sig);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppTheme.primaryPurple
                                      : Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sel
                                        ? AppTheme.primaryPurple
                                        : AppTheme.cardBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  sig,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: sel ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // ── Measures ────────────────────────────────────────
                      _sectionTitle('Numero Battute'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1, 2, 4, 8, 16].map((n) {
                          final sel = _measures == n;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _measures = n);
                              widget.onMeasuresCount(n);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 52,
                              height: 36,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.secondaryCyan.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sel ? AppTheme.secondaryCyan : AppTheme.cardBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$n',
                                  style: TextStyle(
                                    color: sel ? AppTheme.secondaryCyan : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // ── Rhythmic figures ────────────────────────────────
                      _sectionTitle('Figure Ritmiche'),
                      const SizedBox(height: 10),
                      ..._figureLabels.entries.map((entry) {
                        final type = entry.key;
                        final label = entry.value;
                        final isOn = _figures[type] ?? false;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _figures[type] = !isOn);
                            widget.onFigureToggle(type, !isOn);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isOn
                                  ? AppTheme.secondaryCyan.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOn
                                    ? AppTheme.secondaryCyan.withOpacity(0.4)
                                    : AppTheme.cardBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOn
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isOn
                                      ? AppTheme.secondaryCyan
                                      : AppTheme.textMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: isOn
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                    fontSize: 13,
                                    fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // ── Metronome & Instrument ──────────────────────────
                      _sectionTitle('Audio'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final newVal = !_metro;
                                setState(() => _metro = newVal);
                                widget.onMetronome(newVal);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _metro
                                      ? AppTheme.primaryPurple.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _metro ? AppTheme.primaryPurple : AppTheme.cardBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _metro ? Icons.graphic_eq_rounded : Icons.volume_off_rounded,
                                      color: _metro ? AppTheme.primaryPurple : AppTheme.textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Metronomo',
                                      style: TextStyle(
                                        color: _metro ? AppTheme.primaryPurple : AppTheme.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
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
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButton<String>(
                              value: _instrument,
                              dropdownColor: const Color(0xFF1E293B),
                              underline: const SizedBox(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'snare', child: Text('🥁 Rullante')),
                                DropdownMenuItem(value: 'stick', child: Text('🥢 Stick')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _instrument = v);
                                  widget.onInstrument(v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Generate button ──────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: widget.onGenerate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryCyan,
                            shadowColor: AppTheme.secondaryCyan.withOpacity(0.4),
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'GENERATE RHYTHM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 15,
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
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}
