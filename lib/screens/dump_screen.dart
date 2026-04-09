import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kBg = Color(0xFFF8FCFF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kText = Color(0xFF2D2D3A);
const Color _kGrey = Color(0xFF6B7280);
const Color _kTask = Color(0xFF4EC8C8);
const Color _kIdea = Color(0xFFFFCA3A);
const Color _kWorry = Color(0xFFFF9F4A);
const Color _kRemember = Color(0xFF9B7FD4);

enum _DumpFilter { all, task, idea, worry, remember }

class _DumpItem {
  _DumpItem({
    required this.id,
    required this.content,
    required this.createdAt,
    this.category,
    this.movedToTask = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  String? category;
  bool movedToTask;
}

class DumpScreen extends StatefulWidget {
  const DumpScreen({super.key});

  @override
  State<DumpScreen> createState() => _DumpScreenState();
}

class _DumpScreenState extends State<DumpScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<_DumpItem> _items = <_DumpItem>[];
  _DumpFilter _filter = _DumpFilter.all;
  String? _captureCategory;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _loadItems();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _userId() => Supabase.instance.client.auth.currentUser?.id ?? '';

  Color _categoryColor(String? c) {
    switch ((c ?? '').toLowerCase()) {
      case 'task':
        return _kTask;
      case 'idea':
        return _kIdea;
      case 'worry':
        return _kWorry;
      case 'remember':
        return _kRemember;
      default:
        return _kGrey;
    }
  }

  bool _matchesFilter(_DumpItem item) {
    switch (_filter) {
      case _DumpFilter.all:
        return true;
      case _DumpFilter.task:
        return (item.category ?? '').toLowerCase() == 'task';
      case _DumpFilter.idea:
        return (item.category ?? '').toLowerCase() == 'idea';
      case _DumpFilter.worry:
        return (item.category ?? '').toLowerCase() == 'worry';
      case _DumpFilter.remember:
        return (item.category ?? '').toLowerCase() == 'remember';
    }
  }

  Future<void> _loadItems() async {
    final uid = _userId();
    if (uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('dump_items')
          .select()
          .eq('user_id', uid)
          .or('moved_to_task.is.null,moved_to_task.eq.false')
          .order('created_at', ascending: false);

      final list = <_DumpItem>[];
      for (final e in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id']?.toString();
        final content = (m['content'] ?? '').toString().trim();
        if (id == null || id.isEmpty || content.isEmpty) continue;
        final created = DateTime.tryParse('${m['created_at']}') ?? DateTime.now();
        list.add(
          _DumpItem(
            id: id,
            content: content,
            createdAt: created,
            category: m['category']?.toString(),
            movedToTask: m['moved_to_task'] == true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    final uid = _userId();
    if (uid.isEmpty) return;

    setState(() => _saving = true);
    _controller.clear();
    _focusNode.requestFocus();

    try {
      final inserted = await Supabase.instance.client
          .from('dump_items')
          .insert({
            'user_id': uid,
            'content': text,
            if (_captureCategory != null) 'category': _captureCategory,
          })
          .select()
          .single();

      final map = Map<String, dynamic>.from(inserted as Map);
      final item = _DumpItem(
        id: map['id'].toString(),
        content: (map['content'] ?? '').toString(),
        createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
        category: map['category']?.toString(),
        movedToTask: map['moved_to_task'] == true,
      );

      if (mounted) {
        setState(() {
          _items.insert(0, item);
          _captureCategory = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save thought', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setCategory(_DumpItem item, String category) async {
    try {
      await Supabase.instance.client
          .from('dump_items')
          .update({'category': category})
          .eq('id', item.id)
          .eq('user_id', _userId());
      if (!mounted) return;
      setState(() => item.category = category);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update category', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<String> get _categories => const ['Task', 'Idea', 'Worry', 'Remember'];

  Map<String, dynamic> _itemToMap(_DumpItem item) {
    return <String, dynamic>{
      'id': item.id,
      'content': item.content,
      'category': item.category,
    };
  }

  Future<void> _openEditSheet(_DumpItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditDumpSheet(
        item: _itemToMap(item),
        onSaved: () {
          _loadItems();
        },
        onDeleted: () {
          _loadItems();
        },
      ),
    );
  }

  Future<void> _openCategorySheet(_DumpItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        currentCategory: item.category,
        onSelect: (category) async {
          await _setCategory(item, category);
          if (!mounted) return;
          await _loadItems();
        },
      ),
    );
  }

  Future<void> _sendToToday(_DumpItem item) async {
    final uid = _userId();
    if (uid.isEmpty) return;
    try {
      await Supabase.instance.client.from('tasks').insert({
        'title': item.content,
        'color': '#4EC8C8',
        'size': 'medium',
        'is_important': false,
        'completed': false,
        'user_id': uid,
      });
      await Supabase.instance.client
          .from('dump_items')
          .update({'moved_to_task': true})
          .eq('id', item.id)
          .eq('user_id', uid);

      if (!mounted) return;
      setState(() => item.movedToTask = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to Today!', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add task', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteDialog(_DumpItem item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete this thought?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              nav.pop();
              await _deleteItem(item.id);
              if (!mounted) return;
              await _loadItems();
              if (!mounted) return;
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    final uid = _userId();
    try {
      await Supabase.instance.client
          .from('dump_items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', uid);
    } catch (_) {
      return;
    }
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
  }

  Widget _chip(_DumpFilter value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: _kTeal,
        backgroundColor: _kGrey.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.poppins(
          color: selected ? Colors.white : _kGrey,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        showCheckmark: false,
      ),
    );
  }

  Widget _categoryQuickChip({
    required String label,
    required String? selectedCategory,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = (selectedCategory ?? '').toLowerCase() == label.toLowerCase();
    final color = _categoryColor(label);
    return GestureDetector(
      onTap: () => onChanged(selected ? null : label),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color : _kGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: selected ? Colors.white : _kGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where(_matchesFilter).toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _capture(),
                            decoration: InputDecoration(
                              hintText: "What's on your mind?",
                              hintStyle: GoogleFonts.poppins(color: _kGrey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            style: GoogleFonts.poppins(fontSize: 16, color: _kText),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _capture,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: _kTeal,
                              shape: BoxShape.circle,
                            ),
                            child: _saving
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories
                          .map(
                            (c) => _categoryQuickChip(
                              label: c,
                              selectedCategory: _captureCategory,
                              onChanged: (v) => setState(() => _captureCategory = v),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(_DumpFilter.all, 'All'),
                    _chip(_DumpFilter.task, 'Task'),
                    _chip(_DumpFilter.idea, 'Idea'),
                    _chip(_DumpFilter.worry, 'Worry'),
                    _chip(_DumpFilter.remember, 'Remember'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kTeal))
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, size: 56, color: _kGrey.withValues(alpha: 0.6)),
                              const SizedBox(height: 10),
                              Text(
                                'Nothing here yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap above to capture a thought',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _kGrey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            final cat = (item.category ?? '').trim();
                            final catLabel = cat.isEmpty ? 'Uncategorised' : cat;
                            final color = _categoryColor(catLabel);
                            final isTask = cat.toLowerCase() == 'task';
                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _confirmDeleteDialog(item);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              child: Opacity(
                                opacity: item.movedToTask ? 0.6 : 1,
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _openEditSheet(item),
                                    onLongPress: () => _openCategorySheet(item),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.content,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 15,
                                                    color: _kText,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 7),
                                                Text(
                                                  _relative(item.createdAt),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: _kGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.18),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  catLabel,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: color,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (isTask) ...[
                                                const SizedBox(height: 8),
                                                InkWell(
                                                  onTap: item.movedToTask
                                                      ? null
                                                      : () => _sendToToday(item),
                                                  customBorder: const CircleBorder(),
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _kTeal.withValues(alpha: 0.15),
                                                    ),
                                                    child: Icon(
                                                      Icons.add_task,
                                                      color: item.movedToTask
                                                          ? _kGrey.withValues(alpha: 0.6)
                                                          : _kTeal,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDumpSheet extends StatefulWidget {
  const _EditDumpSheet({
    required this.item,
    required this.onSaved,
    required this.onDeleted,
  });

  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  @override
  State<_EditDumpSheet> createState() => _EditDumpSheetState();
}

class _EditDumpSheetState extends State<_EditDumpSheet> {
  late TextEditingController _controller;
  String? _selectedCategory;

  static const List<String> _categories = ['Task', 'Idea', 'Worry', 'Remember'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.item['content'] ?? ''}');
    _selectedCategory = widget.item['category']?.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorFor(String category) {
    switch (category) {
      case 'Task':
        return _kTask;
      case 'Idea':
        return _kIdea;
      case 'Worry':
        return _kWorry;
      case 'Remember':
        return _kRemember;
      default:
        return _kGrey;
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await Supabase.instance.client.from('dump_items').update({
      'content': text,
      'category': _selectedCategory,
    }).eq('id', widget.item['id']);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved();
  }

  Future<void> _delete() async {
    await Supabase.instance.client.from('dump_items').delete().eq('id', widget.item['id']);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit thought',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kTeal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: _categories.map((cat) {
                  final isSelected = (_selectedCategory ?? '') == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _selectedCategory = isSelected ? null : cat,
                      ),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? _colorFor(cat) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _kTeal),
                      onPressed: _save,
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete this thought?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _delete();
                    }
                  },
                  child: const Text(
                    'Delete this thought',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.currentCategory,
    required this.onSelect,
  });

  final String? currentCategory;
  final Future<void> Function(String category) onSelect;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  static const List<String> _categories = ['Task', 'Idea', 'Worry', 'Remember'];

  Color _colorFor(String category) {
    switch (category) {
      case 'Task':
        return _kTask;
      case 'Idea':
        return _kIdea;
      case 'Worry':
        return _kWorry;
      case 'Remember':
        return _kRemember;
      default:
        return _kGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is this?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _categories.map((label) {
              final isSelected =
                  (widget.currentCategory ?? '').toLowerCase() == label.toLowerCase();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onSelect(label);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _colorFor(label)),
                      foregroundColor: isSelected ? Colors.white : _colorFor(label),
                      backgroundColor: isSelected ? _colorFor(label) : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
