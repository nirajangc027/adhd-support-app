import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

const Color _kBg = Color(0xFFF8F3FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kPink = Color(0xFFE8C8D8);
const Color _kText = Color(0xFF2D2D3A);
const Color _kGrey = Color(0xFF8A8A9A);
const Color _kRedStar = Color(0xFFFF6B6B);
const Color _kGreenDone = Color(0xFF5DBF7A);

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  final Set<String> _strikingIds = {};

  static const _motivators = [
    "What's the one thing that matters today?",
    "Small steps count. What's first?",
    "You've got this. Start anywhere.",
    "Progress over perfect. Always.",
  ];

  static const _palette = <(String hex, String label, Color color)>[
    ('#4EC8C8', 'Focus', Color(0xFF4EC8C8)),
    ('#5B9BD5', 'Study', Color(0xFF5B9BD5)),
    ('#E88FAA', 'Personal', Color(0xFFE88FAA)),
    ('#9B7FD4', 'Creative', Color(0xFF9B7FD4)),
    ('#FF9F4A', 'Urgent', Color(0xFFFF9F4A)),
    ('#5DBF7A', 'Health', Color(0xFF5DBF7A)),
    ('#FFCA3A', 'Quick win', Color(0xFFFFCA3A)),
    ('#FF6B6B', 'Important', Color(0xFFFF6B6B)),
  ];

  String _userId() => Supabase.instance.client.auth.currentUser?.id ?? '';

  String _userName() {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final n = meta?['full_name']?.toString().trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Friend';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _subtitle() {
    final day = DateTime.now().year * 1000 + DateTime.now().dayOfYear;
    final i = Random(day).nextInt(_motivators.length);
    return _motivators[i];
  }

  Color _parseHexColor(String? raw) {
    if (raw == null || raw.isEmpty) return _kTeal;
    var s = raw.trim();
    if (s.startsWith('#')) s = '0xFF${s.substring(1)}';
    try {
      return Color(int.parse(s));
    } catch (_) {
      return _kTeal;
    }
  }

  bool _isDone(Map<String, dynamic> t) => t['completed'] == true;

  bool _isImportant(Map<String, dynamic> t) =>
      t['is_important'] == true || t['is_important'] == 'true';

  List<Map<String, dynamic>> get _important {
    final list = _tasks.where((t) => !_isDone(t) && _isImportant(t)).toList();
    if (list.isEmpty) return [];
    return [list.first];
  }

  List<Map<String, dynamic>> get _today {
    final pinnedId = _important.isEmpty ? null : _important.first['id']?.toString();
    return _tasks.where((t) {
      if (_isDone(t)) return false;
      if (_isImportant(t)) {
        return pinnedId != null && t['id'].toString() != pinnedId;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _done {
    return _tasks.where(_isDone).toList();
  }

  double get _progress {
    if (_tasks.isEmpty) return 0;
    final c = _tasks.where(_isDone).length;
    return c / _tasks.length;
  }

  IconData _iconForTask(String title) {
    final t = title.toLowerCase();
    if (t.contains('medication') || t.contains('med ')) {
      return Icons.medication_rounded;
    }
    if (t.contains('exercise') || t.contains('walk') || t.contains('run')) {
      return Icons.directions_run_rounded;
    }
    if (t.contains('email') || t.contains('reply') || t.contains('emails')) {
      return Icons.email_outlined;
    }
    if (t.contains('water') || t.contains('drink')) {
      return Icons.water_drop_rounded;
    }
    return Icons.task_alt_rounded;
  }

  String _sizeLabel(String? s) {
    switch (s?.toString().toLowerCase()) {
      case 'quick':
        return 'Quick';
      case 'big':
        return 'Big';
      default:
        return 'Medium';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final uid = _userId();
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final e in rows as List<dynamic>) {
        list.add(Map<String, dynamic>.from(e as Map));
      }
      if (mounted) {
        setState(() {
          _tasks = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tasks = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleComplete(Map<String, dynamic> task, bool value) async {
    final uid = _userId();
    final id = task['id'];
    if (uid.isEmpty || id == null) return;

    if (value) {
      setState(() => _strikingIds.add(id.toString()));
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    try {
      await Supabase.instance.client.from('tasks').update({
        'completed': value,
      }).eq('id', id).eq('user_id', uid);
      if (!mounted) return;
      await _loadTasks();
      if (mounted) {
        setState(() => _strikingIds.remove(id.toString()));
        if (value) {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool(NotificationService.notificationsEnabledPrefKey) ?? true) {
            await NotificationService().showNotification(
              id: 100,
              title: 'Task complete!',
              body: 'Great work. Keep the momentum going.',
            );
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Task completed! Great work.'),
              backgroundColor: _kGreenDone,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _strikingIds.remove(id.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _deleteTask(String id) async {
    final uid = _userId();
    if (uid.isEmpty) return;
    try {
      await Supabase.instance.client.from('tasks').delete().eq('id', id).eq('user_id', uid);
      if (mounted) await _loadTasks();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _showAddTaskSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTaskSheet(
        palette: _palette,
        onTaskAdded: (_) {
          _loadTasks();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Task added',
                  style: GoogleFonts.poppins(),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _headerCard() {
    final date = DateTime.now();
    final dateStr =
        '${date.weekday == 1 ? 'Mon' : date.weekday == 2 ? 'Tue' : date.weekday == 3 ? 'Wed' : date.weekday == 4 ? 'Thu' : date.weekday == 5 ? 'Fri' : date.weekday == 6 ? 'Sat' : 'Sun'}, '
        '${date.day} ${_month(date.month)} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kTeal.withValues(alpha: 0.45),
            _kPink.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, ${_userName()}',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle(),
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: _kText.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _tasks.isEmpty ? 0 : _progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              color: _kTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {required IconData icon, required Color iconColor}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedTaskCard(Map<String, dynamic> task) {
    final id = task['id'].toString();
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('anim_$id'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, Widget? child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: _taskCard(task),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final id = task['id'].toString();
    final title = task['title']?.toString() ?? '';
    final color = _parseHexColor(task['color']?.toString());
    final done = _isDone(task);
    final striking = _strikingIds.contains(id);
    final showStrike = done || striking;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: Key('task_$id'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        onDismissed: (_) => _deleteTask(id),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _iconForTask(title),
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 280),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: showStrike ? _kGrey : _kText,
                                    decoration: showStrike ? TextDecoration.lineThrough : null,
                                    decorationColor: _kGrey,
                                    decorationThickness: 2,
                                  ),
                                  child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _sizeLabel(task['size']?.toString()),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _kGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 1.15,
                            child: Checkbox(
                              value: done,
                              onChanged: (v) {
                                if (v != null) _toggleComplete(task, v);
                              },
                              fillColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _kTeal;
                                }
                                return null;
                              }),
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              side: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Today',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: _kText),
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator(color: _kTeal)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Today',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: _kText),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _tasks.isEmpty
              ? RefreshIndicator(
                  color: _kTeal,
                  onRefresh: _loadTasks,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _headerCard()),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 56,
                                color: _kGrey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _kGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap Add task to get started',
                                style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kTeal,
                  onRefresh: _loadTasks,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _headerCard(),
                        if (_important.isNotEmpty) ...[
                          _sectionTitle('Most Important', icon: Icons.star_rounded, iconColor: _kRedStar),
                          ..._important.map(_animatedTaskCard),
                        ],
                        _sectionTitle("Today's Tasks", icon: Icons.checklist_rounded, iconColor: _kTeal),
                        if (_today.isEmpty && _important.isEmpty && _done.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Nothing here - add your first task below.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                            ),
                          )
                        else if (_today.isEmpty && _important.isEmpty && _done.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'All caught up for now - see Done below.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                            ),
                          )
                        else if (_today.isEmpty && _important.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Other tasks show here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                            ),
                          )
                        else
                          ..._today.map(_animatedTaskCard),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                            childrenPadding: const EdgeInsets.only(bottom: 16),
                            title: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: _kGreenDone, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Done',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _kText,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _kGreenDone,
                                  size: 22,
                                ),
                              ],
                            ),
                            children: _done.isEmpty
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'Completed tasks appear here',
                                        style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                                      ),
                                    ),
                                  ]
                                : _done.map(_animatedTaskCard).toList(),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'coach',
            onPressed: () => context.push('/coach-viv'),
            backgroundColor: const Color(0xFF9B7FD4),
            child: const Icon(Icons.psychology, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _showAddTaskSheet,
            backgroundColor: _kTeal,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: Text('Add task', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({
    required this.onTaskAdded,
    required this.palette,
  });

  final void Function(Map<String, dynamic> task) onTaskAdded;
  final List<(String, String, Color)> palette;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  String _selectedColor = '#4EC8C8';
  String _selectedSize = 'medium';
  bool _isImportant = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final task = <String, dynamic>{
      'title': _titleController.text.trim(),
      'color': _selectedColor,
      'size': _selectedSize,
      'is_important': _isImportant,
      'completed': false,
      'user_id': uid,
    };

    try {
      if (_isImportant) {
        await Supabase.instance.client
            .from('tasks')
            .update({'is_important': false})
            .eq('user_id', uid)
            .eq('is_important', true);
        if (!mounted) return;
      }
      await Supabase.instance.client.from('tasks').insert(task);
      if (!mounted) return;
      widget.onTaskAdded(Map<String, dynamic>.from(task));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not add task',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.65;

    Widget chip(String label) {
      return ActionChip(
        label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
        onPressed: _isLoading
            ? null
            : () {
                _titleController.text = label;
                setState(() {});
              },
      );
    }

    Widget sizeBtn(String key, String label, IconData icon) {
      final sel = _selectedSize == key;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => setState(() => _selectedSize = key),
            style: OutlinedButton.styleFrom(
              backgroundColor: sel ? _kTeal : Colors.white,
              foregroundColor: sel ? Colors.white : _kText,
              side: BorderSide(
                color: sel ? _kTeal : _kGrey.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22),
                const SizedBox(height: 4),
                Text(label, style: GoogleFonts.poppins(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: h,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What do you need to do?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                autofocus: true,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Task name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip('Medication'),
                  chip('Exercise'),
                  chip('Emails'),
                  chip('Water'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'How big is this task?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  sizeBtn('quick', 'Quick', Icons.bolt_rounded),
                  sizeBtn('medium', 'Medium', Icons.schedule_rounded),
                  sizeBtn('big', 'Big', Icons.flag_rounded),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Colour',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in widget.palette)
                    GestureDetector(
                      onTap: _isLoading ? null : () => setState(() => _selectedColor = e.$1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: e.$3,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == e.$1 ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: _selectedColor == e.$1
                                  ? [
                                      BoxShadow(
                                        color: e.$3.withValues(alpha: 0.55),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _selectedColor == e.$1
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.$2,
                            style: GoogleFonts.poppins(fontSize: 10, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Most important task?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => setState(() => _isImportant = true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isImportant ? _kTeal : Colors.white,
                        foregroundColor: _isImportant ? Colors.white : _kText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('YES', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => setState(() => _isImportant = false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isImportant ? _kTeal : Colors.white,
                        foregroundColor: !_isImportant ? Colors.white : _kText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('NO', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Add Task',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _month(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[m - 1];
}

extension on DateTime {
  int get dayOfYear {
    final start = DateTime(year);
    return difference(start).inDays + 1;
  }
}
