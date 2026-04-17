import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';

const Color _kBg = Color(0xFFF8F3FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kPurple = Color(0xFF9B7FD4);
const Color _kText = Color(0xFF2D2D3A);
const Color _kGrey = Color(0xFF6B7280);
const Color _kPink = Color(0xFFE88FAA);

const List<Color> _moodColors = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFFFF9F4A),
  Color(0xFFFFCA3A),
  Color(0xFF5DBF7A),
  Color(0xFF4EC8C8),
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _notificationsEnabled = true;
  final List<bool> _statVisible = <bool>[false, false, false];

  int _tasksDone = 0;
  int _focusSessions = 0;
  int _moodStreak = 0;

  List<Map<String, dynamic>> _moods = <Map<String, dynamic>>[];

  String _displayName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    _displayName =
        (meta?['full_name'] ?? meta?['name'] ?? meta?['display_name'] ?? '').toString().trim();
    _email = (user?.email ?? '').toString();
    _loadNotificationPref();
    _loadStats();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(NotificationService.notificationsEnabledPrefKey) ?? true;
    });
  }

  Future<void> _onNotificationsToggle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.notificationsEnabledPrefKey, value);
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
    if (value) {
      await NotificationService().initialize();
      await NotificationService().scheduleAllDailyReminders();
    } else {
      await NotificationService().cancelAll();
    }
  }

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);
    final uid = _uid;
    if (uid.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      _revealStatsStaggered();
      return;
    }

    try {
      final tasksFuture = Supabase.instance.client
          .from('tasks')
          .select('id')
          .eq('user_id', uid)
          .eq('completed', true);

      final focusFuture = () async {
        try {
          final rows = await Supabase.instance.client
              .from('focus_sessions')
              .select('id')
              .eq('user_id', uid);
          return (rows as List<dynamic>).length;
        } catch (_) {
          return 0;
        }
      }();

      final moodsFuture = Supabase.instance.client
          .from('mood_entries')
          .select('score, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(30);

      final results = await Future.wait<dynamic>([tasksFuture, focusFuture, moodsFuture]);
      final taskRows = results[0] as List<dynamic>;
      final focusCount = results[1] as int;
      final moodRows = results[2] as List<dynamic>;

      final moods = <Map<String, dynamic>>[];
      for (final e in moodRows) {
        final row = Map<String, dynamic>.from(e as Map);
        final scoreRaw = row['score'];
        final score = scoreRaw is int ? scoreRaw : int.tryParse('$scoreRaw') ?? 0;
        if (score < 1 || score > 5) continue;
        final dt = DateTime.tryParse('${row['created_at']}');
        if (dt == null) continue;
        moods.add(<String, dynamic>{'score': score, 'created_at': dt});
      }

      final streak = _computeStreak(moods);

      if (!mounted) return;
      setState(() {
        _tasksDone = taskRows.length;
        _focusSessions = focusCount;
        _moods = moods;
        _moodStreak = streak;
        _loading = false;
      });
      _revealStatsStaggered();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _revealStatsStaggered() {
    for (var i = 0; i < 3; i++) {
      Future<void>.delayed(Duration(milliseconds: 90 * i), () {
        if (!mounted) return;
        setState(() {
          if (i < _statVisible.length) _statVisible[i] = true;
        });
      });
    }
  }

  int _computeStreak(List<Map<String, dynamic>> moods) {
    if (moods.isEmpty) return 0;
    final days = <DateTime>{};
    for (final e in moods) {
      final dt = e['created_at'] as DateTime;
      days.add(DateTime(dt.year, dt.month, dt.day));
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<DateTime> _weekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List<DateTime>.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  int? _scoreForDay(DateTime day) {
    for (final e in _moods) {
      final dt = e['created_at'] as DateTime;
      if (dt.year == day.year && dt.month == day.month && dt.day == day.day) {
        return e['score'] as int;
      }
    }
    return null;
  }

  String _initials() {
    final name = _displayName.trim();
    if (name.isEmpty) return 'A';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    final first = parts.first.characters.first.toUpperCase();
    final second = parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return (first + second).trim();
  }

  Future<void> _editNameSheet() async {
    final controller = TextEditingController(text: _displayName);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.poppins(color: _kGrey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kTeal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(data: {'full_name': newName}),
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        setState(() => _displayName = newName);
                      },
                      style: FilledButton.styleFrom(backgroundColor: _kTeal),
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon', style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign out of ADHD Support?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
    required bool visible,
  }) {
    return Expanded(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.08),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationsToggleRow() {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined, color: _kText, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    color: _kText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _notificationsEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: _kTeal,
                onChanged: _onNotificationsToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    Color iconColor = _kText,
    required String title,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isDestructive ? Colors.red : _kText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: _kGrey, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekDays();
    final now = DateTime.now();
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _kTeal,
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kTeal, _kPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kTeal,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _kTeal.withValues(alpha: 0.45),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(),
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayName.isEmpty ? 'ADHD Support Member' : _displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _email,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _editNameSheet,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your Progress',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(
                  icon: Icons.check_circle,
                  iconColor: _kTeal,
                  label: 'Tasks Done',
                  value: _loading ? 0 : _tasksDone,
                  visible: _statVisible[0],
                ),
                const SizedBox(width: 10),
                _statCard(
                  icon: Icons.timer,
                  iconColor: _kPurple,
                  label: 'Focus Sessions',
                  value: _loading ? 0 : _focusSessions,
                  visible: _statVisible[1],
                ),
                const SizedBox(width: 10),
                _statCard(
                  icon: Icons.favorite,
                  iconColor: _kPink,
                  label: 'Day Streak',
                  value: _loading ? 0 : _moodStreak,
                  visible: _statVisible[2],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Recent Mood',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = week[i];
                  final score = _scoreForDay(day);
                  final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                  return Column(
                    children: [
                      Text(
                        dayLetters[i],
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
                }),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Account',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _notificationsToggleRow(),
                  const Divider(height: 1, thickness: 1),
                  _settingsRow(
                    icon: Icons.dark_mode_outlined,
                    title: 'Appearance',
                    onTap: _comingSoon,
                  ),
                  const Divider(height: 1, thickness: 1),
                  _settingsRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _openUrl('https://www.adhdsupportaustralia.com.au'),
                  ),
                  const Divider(height: 1, thickness: 1),
                  _settingsRow(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => _openUrl('https://www.adhdsupportaustralia.com.au/contact'),
                  ),
                  const Divider(height: 1, thickness: 1),
                  _settingsRow(
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    title: 'Sign Out',
                    onTap: _confirmSignOut,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Text(
                    'ADHD Support Australia v1.0.0',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                  ),
                  Text(
                    'Made with care for neurodivergent minds',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

