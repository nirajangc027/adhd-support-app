import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kBg = Color(0xFFF8F3FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kText = Color(0xFF2D2D3A);
const Color _kGrey = Color(0xFF6B7280);

class CoachVivScreen extends StatefulWidget {
  const CoachVivScreen({super.key});

  @override
  State<CoachVivScreen> createState() => _CoachVivScreenState();
}

class _CoachVivScreenState extends State<CoachVivScreen>
    with TickerProviderStateMixin {
  final List<_Message> _messages = <_Message>[];
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _dotsController;

  bool _showQuickChips = true;
  String _userName = 'Friend';

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final name = (meta?['full_name'] ?? '').toString().trim();
    _userName = name.isEmpty ? 'Friend' : name;

    _messages.insert(
      0,
      _Message(
        role: 'assistant',
        content:
            "Hi $_userName! I'm Coach Viv. I'm here to help you navigate ADHD with kindness and practical strategies. What's on your mind today?",
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  String _userInitial() {
    final n = _userName.trim();
    if (n.isEmpty) return '?';
    return n.substring(0, 1).toUpperCase();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _controller.clear();

    setState(() {
      _showQuickChips = false;
      _messages.insert(
        0,
        _Message(
          role: 'user',
          content: content,
          timestamp: DateTime.now(),
          isLoading: false,
        ),
      );
      _messages.insert(
        0,
        _Message(
          role: 'assistant',
          content: '',
          timestamp: DateTime.now(),
          isLoading: true,
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      print('Calling coach-viv function...');

      final supabaseUrl = 'https://hadcnsywhfnqylgpgsoe.supabase.co';
      final anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhhZGNuc3l3aGZucXlsZ3Bnc29lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNTE4NDQsImV4cCI6MjA4OTcyNzg0NH0.Utw1gyolUJGnCNrzjSEicJOj4ghm6LCRtInk-2JDlNk';

      final httpResponse = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/smooth-responder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'messages': [
            {'role': 'user', 'content': content},
          ],
          'userName': _userName,
        }),
      );

      print('Got response!');
      print('HTTP Status: ${httpResponse.statusCode}');
      print('HTTP Body: ${httpResponse.body}');

      final decoded = jsonDecode(httpResponse.body);
      String reply;
      if (decoded is Map) {
        reply = decoded['reply']?.toString() ?? "I'm here for you!";
      } else {
        reply = "I'm here for you!";
      }

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _messages.insert(
          0,
          _Message(
            role: 'assistant',
            content: reply,
            timestamp: DateTime.now(),
            isLoading: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, stack) {
      print('ERROR: $e');
      print('STACK: $stack');

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _messages.insert(
          0,
          _Message(
            role: 'assistant',
            content: 'Error: $e',
            timestamp: DateTime.now(),
            isLoading: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Widget _quickChips() {
    final chips = <String>[
      "I can't get started",
      "I'm feeling overwhelmed",
      'Help me break down a task',
      'I need some encouragement',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips
          .map(
            (t) => ActionChip(
              onPressed: () => _sendMessage(t),
              label: Text(
                t,
                style: GoogleFonts.poppins(
                  color: _kTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: _kTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _typingBubble() {
    return _VivBubble(
      timestamp: DateTime.now(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Coach Viv is typing...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kGrey,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _dotsController,
            builder: (context, _) {
              final v = _dotsController.value;
              double o(int i) {
                final phase = (v * 3 - i).abs();
                final opacity = 1.0 - phase.clamp(0.0, 1.0);
                return 0.25 + opacity * 0.75;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(o(0)),
                  const SizedBox(width: 4),
                  _dot(o(1)),
                  const SizedBox(width: 4),
                  _dot(o(2)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: _kGrey,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _messages.length;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _kText),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kTeal,
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach Viv',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                Text(
                  'ADHD Support Australia',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _kGrey,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              reverse: true,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final m = _messages[index];
                Widget inner;
                if (m.isLoading) {
                  inner = _typingBubble();
                } else {
                  final ts = _formatTime(m.timestamp);
                  if (m.role == 'user') {
                    inner = _UserBubble(
                      text: m.content,
                      timestamp: ts,
                      initial: _userInitial(),
                    );
                  } else {
                    inner = _VivBubble(
                      timestamp: m.timestamp,
                      child: Text(
                        m.content,
                        style: GoogleFonts.poppins(fontSize: 14, color: _kText),
                      ),
                    );
                  }
                }
                return TweenAnimationBuilder<double>(
                  key: ValueKey<String>('msg_${m.timestamp}_$index'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, Widget? child) {
                    return Opacity(
                      opacity: t,
                      child: child,
                    );
                  },
                  child: inner,
                );
              },
            ),
          ),
          if (_showQuickChips)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _quickChips(),
            ),
          _InputBar(
            controller: _controller,
            isLoading: _isLoading,
            onSend: () => _sendMessage(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _Message {
  const _Message({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });

  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.text,
    required this.timestamp,
    required this.initial,
  });

  final String text;
  final String timestamp;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75 - 48,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kTeal,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _kTeal.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: GoogleFonts.poppins(fontSize: 11, color: _kGrey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VivBubble extends StatelessWidget {
  const _VivBubble({required this.child, required this.timestamp});

  final Widget child;
  final DateTime timestamp;

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: _kTeal, size: 18),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: GoogleFonts.poppins(fontSize: 11, color: _kGrey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _sendPressed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _InputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.controller.text.trim().isNotEmpty && !widget.isLoading;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        top: 8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => canSend ? widget.onSend() : null,
                decoration: InputDecoration(
                  hintText: 'Message Coach Viv...',
                  hintStyle: GoogleFonts.poppins(color: _kGrey),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(color: _kText),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canSend
                    ? () {
                        widget.onSend();
                      }
                    : null,
                customBorder: const CircleBorder(),
                splashColor: _kTeal.withValues(alpha: 0.25),
                highlightColor: _kTeal.withValues(alpha: 0.08),
                onHighlightChanged: canSend
                    ? (v) => setState(() => _sendPressed = v)
                    : null,
                child: Transform.scale(
                  scale: _sendPressed ? 0.92 : 1.0,
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: canSend ? _kTeal : const Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: canSend ? Colors.white : _kGrey,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

