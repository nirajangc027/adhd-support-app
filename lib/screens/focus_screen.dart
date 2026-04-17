import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/app_theme.dart';

const Color _kBgStart = Color(0xFFF8F3FF);
const Color _kBgEnd = Color(0xFFEEF6FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kGrey = Color(0xFF6B7280);
const Color _kGreyLight = Color(0xFF9CA3AF);
const Color _kText = Color(0xFF1F2937);

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const int _breakMinutes = 5;
  static const List<int> _focusOptions = [15, 25, 45];

  static const String _assetRain = 'assets/audio/rain.wav';
  static const String _assetOcean = 'assets/audio/ocean.wav';
  static const String _assetLofi = 'assets/audio/lofi.wav';
  static const String _tagForest = 'soundscape_forest';
  static const String _tagCafe = 'soundscape_cafe';

  Timer? _timer;
  AudioPlayer? _audioPlayer;
  String? _selectedSound;
  int _selectedFocusMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isBreak = false;
  /// Completed focus sessions this cycle (0–4). After 4th completes, break then reset to 0.
  int _completedFocusSessions = 0;
  bool _isRunning = false;

  int get _focusSeconds => _selectedFocusMinutes * 60;
  int get _breakSeconds => _breakMinutes * 60;
  int get _totalPhaseSeconds => _isBreak ? _breakSeconds : _focusSeconds;

  double get _progress {
    final total = _totalPhaseSeconds;
    if (total <= 0) return 0;
    return 1.0 - (_remainingSeconds / total);
  }

  Future<void> _playSound(String? sound) async {
    await _audioPlayer?.stop();
    if (sound == null) {
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      return;
    }

    await _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();
    await _audioPlayer?.setAsset(sound);
    await _audioPlayer?.setLoopMode(LoopMode.one);
    await _audioPlayer?.play();
  }

  @override
  void dispose() {
    _timer?.cancel();
    final player = _audioPlayer;
    _audioPlayer = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  void _applyPhaseSeconds() {
    _remainingSeconds = _isBreak ? _breakSeconds : _focusSeconds;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() => _isRunning = true);
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    unawaited(_playSound(null));
    setState(() {
      _isRunning = false;
      _applyPhaseSeconds();
    });
  }

  void _tick() {
    if (_remainingSeconds <= 1) {
      _timer?.cancel();
      _timer = null;
      setState(() => _isRunning = false);
      _onPhaseComplete();
      return;
    }
    setState(() => _remainingSeconds--);
  }

  void _onPhaseComplete() {
    if (!_isBreak) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Focus complete! Take a break.',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _completedFocusSessions++;
        _isBreak = true;
        _applyPhaseSeconds();
      });
    } else {
      setState(() {
        _isBreak = false;
        if (_completedFocusSessions >= 4) {
          _completedFocusSessions = 0;
        }
        _applyPhaseSeconds();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Break over. Ready to focus.',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _selectFocusLength(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedFocusMinutes = minutes;
      if (!_isBreak) {
        _remainingSeconds = _focusSeconds;
      }
    });
  }

  Future<void> _onSoundscapeTap(String? soundId) async {
    setState(() => _selectedSound = soundId);

    if (soundId == null) {
      await _playSound(null);
      return;
    }
    if (soundId == _tagForest || soundId == _tagCafe) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming soon! Audio in next update',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _playSound(soundId);
  }

  String _formatMmSs(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Display session index 1–4 for label (next cycle shows 1 after 4 completed).
  int get _sessionDisplayIndex {
    if (_isBreak && _completedFocusSessions >= 4) return 1;
    return math.min(4, _completedFocusSessions + 1);
  }

  bool get _atFullPhaseDuration => _remainingSeconds == _totalPhaseSeconds;
  bool get _isPaused => !_isRunning && !_atFullPhaseDuration;

  /// Session dots inside the ring (compact).
  Widget _buildMiniSessionDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final completed = i < _completedFocusSessions;
        final onBreak = _isBreak;
        final currentFocus = !onBreak && i == _completedFocusSessions;
        final nextAfterBreak =
            onBreak && i == _completedFocusSessions && _completedFocusSessions < 4;
        final cycleDoneBreak = onBreak && _completedFocusSessions >= 4;

        final filled = completed || (cycleDoneBreak && i < 4);
        final outlinedTeal = currentFocus || nextAfterBreak;

        final border = filled ? _kTeal : (outlinedTeal ? _kTeal : _kGreyLight);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _kTeal : Colors.transparent,
              border: Border.all(color: border, width: 1.5),
            ),
          ),
        );
      }),
    );
  }

  Widget _sessionCounterRow() {
    return Column(
      children: [
        Text(
          'Session $_sessionDisplayIndex of 4',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kGrey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final completed = i < _completedFocusSessions;
            final onBreak = _isBreak;
            final currentFocus = !onBreak && i == _completedFocusSessions;
            final nextAfterBreak =
                onBreak && i == _completedFocusSessions && _completedFocusSessions < 4;
            final cycleDoneBreak = onBreak && _completedFocusSessions >= 4;

            final filled = completed || (cycleDoneBreak && i < 4);
            final outlinedTeal = currentFocus || nextAfterBreak;
            final border = filled ? _kTeal : (outlinedTeal ? _kTeal : _kGreyLight);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? _kTeal : Colors.transparent,
                  border: Border.all(color: border, width: 2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _pill(int minutes, bool selected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isRunning ? null : () => _selectFocusLength(minutes),
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kTeal : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? _kTeal : _kGreyLight.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            '$minutes min',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _kGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _soundCard({
    required IconData icon,
    required String label,
    required String? soundId,
  }) {
    final selected = _selectedSound == soundId;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => unawaited(_onSoundscapeTap(soundId)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? _kTeal.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: selected ? _kTeal : _kGreyLight.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4EC8C8).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? _kTeal : _kGrey, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? _kTeal : _kGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgStart, _kBgEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Focus',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      Text(
                        'One thing at a time',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _kGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(220, 220),
                              painter: _FocusRingPainter(
                                progress: _progress,
                                trackColor: _kGrey.withValues(alpha: 0.15),
                                progressColor: _kTeal,
                                strokeWidth: 12,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatMmSs(_remainingSeconds),
                                  style: GoogleFonts.poppins(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w700,
                                    color: _kTeal,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isBreak ? 'Break' : 'Focus',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: _kGrey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMiniSessionDots(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _focusOptions.map((m) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _pill(m, m == _selectedFocusMinutes),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                      const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isRunning || _isPaused
                      ? Row(
                          key: const ValueKey('dual_controls'),
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _isRunning ? _pauseTimer : _startTimer,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kTeal,
                                  side: const BorderSide(color: _kTeal, width: 2),
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _isRunning ? 'PAUSE' : 'RESUME',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetTimer,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kGrey,
                                  side: BorderSide(
                                    color: _kGreyLight.withValues(alpha: 0.8),
                                    width: 2,
                                  ),
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'RESET',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          key: const ValueKey('start_only'),
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _startTimer,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'START',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                _sessionCounterRow(),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Sound',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _soundCard(
                              icon: Icons.volume_off,
                              label: 'None',
                              soundId: null,
                            ),
                            _soundCard(
                              icon: Icons.water,
                              label: 'Rain',
                              soundId: _assetRain,
                            ),
                            _soundCard(
                              icon: Icons.waves,
                              label: 'Ocean',
                              soundId: _assetOcean,
                            ),
                            _soundCard(
                              icon: Icons.forest,
                              label: 'Forest',
                              soundId: _tagForest,
                            ),
                            _soundCard(
                              icon: Icons.local_cafe,
                              label: 'Cafe',
                              soundId: _tagCafe,
                            ),
                            _soundCard(
                              icon: Icons.music_note,
                              label: 'Lo-fi',
                              soundId: _assetLofi,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
            },
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring: background track + teal arc with round caps.
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width / 2) - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, bgPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
