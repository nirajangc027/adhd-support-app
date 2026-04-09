import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kBg = Color(0xFFF8F3FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kPurple = Color(0xFF9B7FD4);
const Color _kAccentPink = Color(0xFFE8C8D8);
const Color _kGrey = Color(0xFF6B7280);
const Color _kText = Color(0xFF1F2937);
const Color _kBlueOut = Color(0xFF5B8DEF);

const List<Color> _moodColors = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFFFF9F4A),
  Color(0xFFFFCA3A),
  Color(0xFF5DBF7A),
  Color(0xFF4EC8C8),
];

const List<IconData> _moodIcons = <IconData>[
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_satisfied,
];

const List<String> _moodLabels = <String>[
  'Rough',
  'Low',
  'Okay',
  'Good',
  'Great',
];

const List<String> _moodMessages = <String>[
  "That's okay. You showed up. That counts.",
  "Low days happen. Let's find something small.",
  'Okay is enough. Small steps from here.',
  'Nice! Ride this wave today.',
  'Amazing! Channel this into something good.',
];

const List<String> _checklistItemsText = <String>[
  'Drink a glass of water',
  'Take 3 deep breaths',
  'Name 5 things you can see',
  'Feel your feet on the floor',
  'Put one hand on your heart',
];

const List<String> _affirmations = <String>[
  'My ADHD is a difference, not a deficit',
  'I am doing the best I can today',
  'Small progress is still progress',
  'My brain works differently, not wrongly',
  'I deserve patience and kindness',
  'Today I will focus on what I can control',
  'I am more than my productivity',
  'Rest is not laziness. Rest is necessary.',
];

class FeelScreen extends StatefulWidget {
  const FeelScreen({super.key});

  @override
  State<FeelScreen> createState() => _FeelScreenState();
}

class _FeelScreenState extends State<FeelScreen> with TickerProviderStateMixin {
  int? _selectedMood;
  final TextEditingController _noteController = TextEditingController();
  bool _showBreathing = false;
  bool _showChecklist = false;
  bool _showAffirmations = false;
  int _currentAffirmation = 0;
  List<bool> _checklistItems = List.filled(5, false);
  late AnimationController _breathingController;
  List<Map<String, dynamic>> _moodHistory = [];
  bool _isLoading = false;
  bool _saving = false;
  bool _showChecklistDone = false;
  Timer? _checklistResetTimer;

  static const double _inhale = 4;
  static const double _hold = 7;
  static const double _exhale = 8;
  static const double _cycle = 19;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 19000),
    )..addListener(() {
        if (mounted && _showBreathing) setState(() {});
      });
    _loadMoodHistory();
  }

  @override
  void dispose() {
    _checklistResetTimer?.cancel();
    _breathingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodHistory() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _moodHistory = <Map<String, dynamic>>[];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('mood_entries')
          .select('score, note, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(30);

      final parsed = <Map<String, dynamic>>[];
      for (final e in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(e as Map);
        final scoreRaw = m['score'];
        final score = scoreRaw is int ? scoreRaw : int.tryParse('$scoreRaw') ?? 0;
        if (score < 1 || score > 5) continue;
        final dt = DateTime.tryParse('${m['created_at']}');
        if (dt == null) continue;
        parsed.add(<String, dynamic>{
          'score': score,
          'note': (m['note'] ?? '').toString(),
          'created_at': dt,
        });
      }

      if (!mounted) return;
      setState(() {
        _moodHistory = parsed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moodHistory = <Map<String, dynamic>>[];
        _isLoading = false;
      });
    }
  }

  void _applyMoodToolPreset(int mood) {
    if (mood == 1) {
      _showBreathing = true;
      _showChecklist = false;
      _showAffirmations = false;
      if (!_breathingController.isAnimating) _breathingController.repeat();
    } else if (mood == 2) {
      _showBreathing = false;
      _showChecklist = true;
      _showAffirmations = false;
      _breathingController.stop();
      _breathingController.reset();
    } else if (mood == 3) {
      _showBreathing = false;
      _showChecklist = false;
      _showAffirmations = false;
      _breathingController.stop();
      _breathingController.reset();
    } else {
      _showBreathing = false;
      _showChecklist = false;
      _showAffirmations = true;
      _breathingController.stop();
      _breathingController.reset();
    }
  }

  void _onMoodTap(int mood) {
    setState(() {
      _selectedMood = mood;
      _applyMoodToolPreset(mood);
    });
  }

  Future<void> _saveCheckIn() async {
    if (_selectedMood == null || _saving) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('mood_entries').insert(<String, dynamic>{
        'user_id': uid,
        'score': _selectedMood,
        if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked in!'),
          backgroundColor: Color(0xFF5DBF7A),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _noteController.clear();
      await _loadMoodHistory();
    } catch (_) {
      // silent fail for now
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _breathingSize() {
    final t = _breathingController.value * _cycle;
    if (t < _inhale) {
      return 80 + (t / _inhale) * 60;
    }
    if (t < _inhale + _hold) {
      return 140;
    }
    final exhaleElapsed = t - _inhale - _hold;
    return 140 - (exhaleElapsed / _exhale) * 60;
  }

  String _breathingText() {
    final t = _breathingController.value * _cycle;
    if (t < _inhale) return 'Breathe in...';
    if (t < _inhale + _hold) return 'Hold...';
    return 'Breathe out...';
  }

  Color _breathingTextColor() {
    final t = _breathingController.value * _cycle;
    if (t < _inhale) return _kTeal;
    if (t < _inhale + _hold) return _kPurple;
    return _kBlueOut;
  }

  void _toggleBreathing() {
    setState(() {
      _showBreathing = !_showBreathing;
      if (_showBreathing) {
        _breathingController.repeat();
      } else {
        _breathingController.stop();
        _breathingController.reset();
      }
    });
  }

  void _toggleChecklist() {
    setState(() => _showChecklist = !_showChecklist);
  }

  void _toggleAffirmations() {
    setState(() => _showAffirmations = !_showAffirmations);
  }

  void _onChecklistChanged(int i, bool v) {
    setState(() => _checklistItems[i] = v);
    final allDone = _checklistItems.every((e) => e);
    if (allDone) {
      _checklistResetTimer?.cancel();
      setState(() => _showChecklistDone = true);
      _checklistResetTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        setState(() {
          _checklistItems = List<bool>.filled(5, false);
          _showChecklistDone = false;
        });
      });
    }
  }

  String _toolsTitle() {
    final mood = _selectedMood;
    if (mood == null) return 'Quick support tools';
    if (mood <= 2) return 'You need this right now';
    if (mood == 3) return 'Quick support tools';
    return 'Keep the momentum';
  }

  Color _toolsTitleColor() {
    final mood = _selectedMood;
    if (mood == null || mood == 3) return _kGrey;
    if (mood == 1) return const Color(0xFFFF6B6B);
    if (mood == 2) return const Color(0xFFFF9F4A);
    return _kTeal;
  }

  String _toolsMessage() {
    final mood = _selectedMood;
    if (mood == 1) {
      return "When you're having a rough day, start with breathing";
    }
    if (mood == 2) {
      return 'Small grounding actions can shift low energy';
    }
    if (mood == 3) return 'Pick what feels right today';
    if (mood == 4 || mood == 5) {
      return "You're doing great — here's a reminder why";
    }
    return 'Pick what feels right today';
  }

  bool _showBreathingCard() {
    final mood = _selectedMood;
    if (mood == null || mood == 1 || mood == 2 || mood == 3) return true;
    return false;
  }

  bool _showChecklistCard() {
    final mood = _selectedMood;
    if (mood == null || mood == 1 || mood == 2 || mood == 3) return true;
    return false;
  }

  bool _showAffirmationCard() {
    final mood = _selectedMood;
    if (mood == null || mood == 1 || mood == 3 || mood == 4 || mood == 5) return true;
    return mood == 2 ? false : true;
  }

  int? _latestScoreForDate(DateTime day) {
    for (final e in _moodHistory) {
      final dt = e['created_at'] as DateTime;
      if (dt.year == day.year && dt.month == day.month && dt.day == day.day) {
        return e['score'] as int;
      }
    }
    return null;
  }

  List<DateTime> _currentWeekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List<DateTime>.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  List<Map<String, dynamic>> _last7Entries() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _moodHistory.where((e) => (e['created_at'] as DateTime).isAfter(cutoff)).toList();
  }

  int _streakDays() {
    if (_moodHistory.isEmpty) return 0;
    final days = <DateTime>{};
    for (final e in _moodHistory) {
      final dt = e['created_at'] as DateTime;
      days.add(DateTime(dt.year, dt.month, dt.day));
    }
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _weekdayName(int weekday) {
    const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _insightMostCommon(List<Map<String, dynamic>> entries) {
    if (entries.length < 3) return 'Check in daily to unlock insights';
    final counts = <int, int>{};
    for (final e in entries) {
      final s = e['score'] as int;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mood = _moodLabels[top.first.key - 1];
    return 'Your most common mood this week was $mood';
  }

  String _insightBestDay(List<Map<String, dynamic>> entries) {
    if (entries.length < 3) return 'Check in daily to unlock insights';
    final totals = <int, int>{};
    final counts = <int, int>{};
    for (final e in entries) {
      final dt = e['created_at'] as DateTime;
      final s = e['score'] as int;
      totals[dt.weekday] = (totals[dt.weekday] ?? 0) + s;
      counts[dt.weekday] = (counts[dt.weekday] ?? 0) + 1;
    }
    var bestDay = 1;
    var bestAvg = -1.0;
    for (final w in totals.keys) {
      final avg = totals[w]! / (counts[w] ?? 1);
      if (avg > bestAvg) {
        bestAvg = avg;
        bestDay = w;
      }
    }
    final full = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return 'You tend to feel best on ${full[bestDay - 1]}s';
  }

  String _insightStreak() {
    if (_moodHistory.length < 3) return 'Check in daily to unlock insights';
    return '${_streakDays()} day check-in streak! Keep going.';
  }

  String _streakMessage(int streak) {
    if (streak >= 30) return "You're a check-in champion!";
    if (streak >= 14) return 'Two weeks strong!';
    if (streak >= 7) return 'One full week! Amazing.';
    if (streak >= 3) return 'Building awareness!';
    return 'Great start!';
  }

  Widget _softCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _toolHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
                  ),
                ],
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, color: _kGrey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last7 = _last7Entries();
    final streak = _streakDays();
    final week = _currentWeekDays();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'How are you feeling?',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check in takes 10 seconds',
                style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
              ),
              const SizedBox(height: 18),
              Row(
                children: List<Widget>.generate(5, (index) {
                  final mood = index + 1;
                  final selected = _selectedMood == mood;
                  return Expanded(
                    child: Column(
                      children: <Widget>[
                        InkWell(
                          onTap: () => _onMoodTap(mood),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? _moodColors[index]
                                  : const Color(0xFFE5E7EB),
                            ),
                            child: Icon(
                              _moodIcons[index],
                              size: 32,
                              color: selected ? Colors.white : _kGrey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _moodLabels[index],
                          style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              if (_selectedMood != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  _moodMessages[_selectedMood! - 1],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _moodColors[_selectedMood! - 1],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "What's going on? (optional)",
                    hintStyle: GoogleFonts.poppins(color: _kGrey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kTeal, width: 2),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveCheckIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(
                            'Save Check-in',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                _toolsTitle(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _toolsTitleColor(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _toolsMessage(),
                style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
              ),
              const SizedBox(height: 14),
              if (_showBreathingCard()) ...<Widget>[
                _softCard(
                  child: Column(
                    children: <Widget>[
                      _toolHeader(
                        icon: Icons.air,
                        iconColor: _kTeal,
                        title: '4-7-8 Breathing',
                        subtitle: 'Calm your nervous system in 2 minutes',
                        expanded: _showBreathing,
                        onTap: _toggleBreathing,
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 240),
                        crossFadeState:
                            _showBreathing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: <Widget>[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _breathingSize(),
                                height: _breathingSize(),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kTeal.withValues(alpha: 0.30),
                                  border: Border.all(color: _kTeal, width: 3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _breathingText(),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _breathingTextColor(),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _breathingController.stop();
                                  _breathingController.reset();
                                  setState(() => _showBreathing = false);
                                },
                                child: Text(
                                  'Stop breathing exercise',
                                  style: GoogleFonts.poppins(color: _kGrey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_showChecklistCard()) ...<Widget>[
                _softCard(
                  child: Column(
                    children: <Widget>[
                      _toolHeader(
                        icon: Icons.checklist,
                        iconColor: _kAccentPink,
                        title: 'Nervous System Checklist',
                        subtitle: '5 quick actions to ground yourself',
                        expanded: _showChecklist,
                        onTap: _toggleChecklist,
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 240),
                        crossFadeState:
                            _showChecklist ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            children: <Widget>[
                              ...List<Widget>.generate(5, (i) {
                                return CheckboxListTile(
                                  value: _checklistItems[i],
                                  onChanged: (v) => _onChecklistChanged(i, v ?? false),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: _kAccentPink,
                                  title: Text(
                                    _checklistItemsText[i],
                                    style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                                  ),
                                );
                              }),
                              if (_showChecklistDone)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'You completed the checklist! Well done.',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_showAffirmationCard()) ...<Widget>[
                _softCard(
                  child: Column(
                    children: <Widget>[
                      _toolHeader(
                        icon: Icons.favorite,
                        iconColor: _kAccentPink,
                        title: 'ADHD Affirmations',
                        subtitle: 'Kind words for your brain',
                        expanded: _showAffirmations,
                        onTap: _toggleAffirmations,
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 240),
                        crossFadeState: _showAffirmations
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: <Widget>[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                decoration: BoxDecoration(
                                  color: _kAccentPink.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _affirmations[_currentAffirmation],
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: _kText,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentAffirmation =
                                            (_currentAffirmation - 1 + _affirmations.length) %
                                                _affirmations.length;
                                      });
                                    },
                                    child: Text('Previous', style: GoogleFonts.poppins()),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentAffirmation =
                                            (_currentAffirmation + 1) % _affirmations.length;
                                      });
                                    },
                                    child: Text('Next', style: GoogleFonts.poppins()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List<Widget>.generate(_affirmations.length, (i) {
                                  final active = i == _currentAffirmation;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 12 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: active ? _kTeal : const Color(0xFFD1D5DB),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              Text(
                'Your Mood Journey',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              _softCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: week.map((day) {
                      final score = _latestScoreForDate(day);
                      final today = DateTime.now();
                      final isToday =
                          day.year == today.year && day.month == today.month && day.day == today.day;
                      return Column(
                        children: <Widget>[
                          Text(
                            _weekdayName(day.weekday),
                            style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: score == null ? const Color(0xFFE5E7EB) : _moodColors[score - 1],
                              border: isToday ? Border.all(color: _kTeal, width: 2) : null,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _softCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _insightMostCommon(last7),
                        style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _insightBestDay(last7),
                        style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _insightStreak(),
                        style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _softCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      if (streak >= 3) const Icon(Icons.local_fire_department, color: Color(0xFFEF4444)),
                      if (streak >= 3) const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '$streak day streak',
                              style: GoogleFonts.poppins(
                                color: _kTeal,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _streakMessage(streak),
                              style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator(color: _kTeal)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
