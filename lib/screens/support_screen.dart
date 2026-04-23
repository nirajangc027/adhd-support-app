import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kBg = Color(0xFFF8F3FF);
const Color _kTeal = Color(0xFF4EC8C8);
const Color _kPurple = Color(0xFF9B7FD4);
const Color _kText = Color(0xFF1F2937);
const Color _kGrey = Color(0xFF6B7280);

String _dateLine(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final day = days[(d.weekday - 1).clamp(0, 6)];
  final month = months[(d.month - 1).clamp(0, 11)];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$day ${d.day} $month • $hour:$minute $ampm';
}

String _priceLabel({required bool isFree, double? price}) {
  if (isFree) return 'Free';
  final p = price ?? 0;
  final text = p % 1 == 0 ? p.toInt().toString() : p.toStringAsFixed(2);
  return '\$$text AUD';
}

enum _SupportTab { all, events, courses, programs, coaching, community }

class _SupportEvent {
  const _SupportEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.type,
    required this.isFree,
    this.price,
    this.registrationUrl,
    this.meetingUrl,
    this.location,
    this.maxAttendees,
    this.colorHex,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final String type;
  final bool isFree;
  final double? price;
  final String? registrationUrl;
  final String? meetingUrl;
  final String? location;
  final int? maxAttendees;
  final String? colorHex;
}

class _SupportCourse {
  const _SupportCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.duration,
    required this.isFree,
    this.price,
    this.purchaseUrl,
    this.whatYouLearn = const <String>[],
    this.colorHex,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String duration;
  final bool isFree;
  final double? price;
  final String? purchaseUrl;
  final List<String> whatYouLearn;
  final String? colorHex;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  _SupportTab _tab = _SupportTab.all;
  bool _isLoading = true;

  List<_SupportEvent> _events = <_SupportEvent>[];
  List<_SupportCourse> _courses = <_SupportCourse>[];
  Set<String> _registeredEventIds = <String>{};
  Set<String> _enrolledCourseIds = <String>{};
  Map<String, int> _eventRegistrationCount = <String, int>{};

  String _prefillName = '';
  String _prefillEmail = '';

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    _prefillName =
        (meta?['full_name'] ?? meta?['name'] ?? meta?['display_name'] ?? '').toString();
    _prefillEmail = (user?.email ?? '').toString();
    _loadAll();
  }

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final eventsReq = Supabase.instance.client
          .from('events')
          .select()
          .eq('is_active', true)
          .order('start_date', ascending: true);
      final coursesReq =
          Supabase.instance.client.from('courses').select().eq('is_active', true);
      final regsReq = _uid.isEmpty
          ? Future.value(<dynamic>[])
          : Supabase.instance.client
              .from('event_registrations')
              .select('event_id')
              .eq('user_id', _uid)
              .eq('status', 'registered');
      final enrolReq = _uid.isEmpty
          ? Future.value(<dynamic>[])
          : Supabase.instance.client
              .from('enrollments')
              .select('course_id')
              .eq('user_id', _uid);

      final results = await Future.wait<dynamic>([eventsReq, coursesReq, regsReq, enrolReq]);
      final eventsRows = results[0] as List<dynamic>;
      final coursesRows = results[1] as List<dynamic>;
      final regRows = results[2] as List<dynamic>;
      final enrolRows = results[3] as List<dynamic>;

      final events = <_SupportEvent>[];
      for (final e in eventsRows) {
        final m = Map<String, dynamic>.from(e as Map);
        final dt = DateTime.tryParse('${m['start_date']}');
        if (dt == null) continue;
        events.add(
          _SupportEvent(
            id: '${m['id']}',
            title: (m['title'] ?? 'Untitled event').toString(),
            description: (m['description'] ?? '').toString(),
            startDate: dt,
            type: (m['type'] ?? 'Online').toString(),
            isFree: m['is_free'] == true || m['price'] == null,
            price: m['price'] is num ? (m['price'] as num).toDouble() : null,
            registrationUrl: m['registration_url']?.toString(),
            meetingUrl: m['meeting_url']?.toString(),
            location: m['location']?.toString(),
            maxAttendees: m['max_attendees'] is int
                ? m['max_attendees'] as int
                : int.tryParse('${m['max_attendees'] ?? ''}'),
            colorHex: m['color']?.toString(),
          ),
        );
      }

      final courses = <_SupportCourse>[];
      for (final e in coursesRows) {
        final m = Map<String, dynamic>.from(e as Map);
        final learn = <String>[];
        final raw = m['what_you_learn'];
        if (raw is List) {
          for (final item in raw) {
            final txt = '$item'.trim();
            if (txt.isNotEmpty) learn.add(txt);
          }
        }
        courses.add(
          _SupportCourse(
            id: '${m['id']}',
            title: (m['title'] ?? 'Untitled course').toString(),
            description: (m['description'] ?? '').toString(),
            category: (m['category'] ?? 'Program').toString(),
            duration: (m['duration'] ?? 'Flexible').toString(),
            isFree: m['is_free'] == true || m['price'] == null,
            price: m['price'] is num ? (m['price'] as num).toDouble() : null,
            purchaseUrl: m['purchase_url']?.toString(),
            whatYouLearn: learn,
            colorHex: m['color']?.toString(),
          ),
        );
      }

      final regIds = <String>{};
      for (final e in regRows) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['event_id']?.toString();
        if (id != null && id.isNotEmpty) regIds.add(id);
      }
      final enrolIds = <String>{};
      for (final e in enrolRows) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['course_id']?.toString();
        if (id != null && id.isNotEmpty) enrolIds.add(id);
      }

      final countMap = <String, int>{};
      if (events.isNotEmpty) {
        try {
          final eventIds = events.map((e) => e.id).toList();
          final allRegs = await Supabase.instance.client
              .from('event_registrations')
              .select('event_id')
              .inFilter('event_id', eventIds)
              .eq('status', 'registered');
          for (final row in allRegs as List<dynamic>) {
            final m = Map<String, dynamic>.from(row as Map);
            final id = m['event_id']?.toString();
            if (id == null) continue;
            countMap[id] = (countMap[id] ?? 0) + 1;
          }
        } catch (_) {
          // Ignore count failures, cards still render.
        }
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _courses = courses;
        _registeredEventIds = regIds;
        _enrolledCourseIds = enrolIds;
        _eventRegistrationCount = countMap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = <_SupportEvent>[];
        _courses = <_SupportCourse>[];
        _registeredEventIds = <String>{};
        _enrolledCourseIds = <String>{};
        _eventRegistrationCount = <String, int>{};
        _isLoading = false;
      });
    }
  }

  Future<void> _openExternal(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCalendarForEvent(_SupportEvent event) async {
    final start = event.startDate.toUtc();
    final end = start.add(const Duration(hours: 1));
    String fmt(DateTime d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
    }

    final uri = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(event.title)}'
      '&details=${Uri.encodeComponent(event.description)}'
      '&location=${Uri.encodeComponent(event.location ?? event.meetingUrl ?? '')}'
      '&dates=${fmt(start)}/${fmt(end)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _weekday(int w) {
    const v = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return v[(w - 1).clamp(0, 6)];
  }

  String _month(int m) {
    const v = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return v[(m - 1).clamp(0, 11)];
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _dateLine(DateTime d) => '${_weekday(d.weekday)} ${d.day} ${_month(d.month)} • ${_time(d)}';

  String _priceLabel({required bool isFree, double? price}) {
    if (isFree) return 'Free';
    final p = price ?? 0;
    final text = p % 1 == 0 ? p.toInt().toString() : p.toStringAsFixed(2);
    return '\$$text AUD';
  }

  Color _parseHex(String? hex, {Color fallback = _kTeal}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final intVal = int.tryParse(value, radix: 16);
    if (intVal == null) return fallback;
    return Color(intVal);
  }

  bool _showEvents() => _tab == _SupportTab.all || _tab == _SupportTab.events;
  bool _showCourses() =>
      _tab == _SupportTab.all ||
      _tab == _SupportTab.courses ||
      _tab == _SupportTab.programs ||
      _tab == _SupportTab.coaching;
  bool _showCommunity() => _tab == _SupportTab.all || _tab == _SupportTab.community;

  List<_SupportCourse> _filteredCourses() {
    if (_tab == _SupportTab.programs) {
      return _courses.where((c) => c.category.toLowerCase().contains('program')).toList();
    }
    if (_tab == _SupportTab.coaching) {
      return _courses.where((c) => c.category.toLowerCase().contains('coaching')).toList();
    }
    if (_tab == _SupportTab.courses) {
      return _courses.where((c) => c.category.toLowerCase().contains('course')).toList();
    }
    return _courses;
  }

  Future<void> _openEventDetails(_SupportEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _detailLine('Date', _dateLine(event.startDate)),
                    _detailLine('Type', event.type),
                    if ((event.location ?? '').isNotEmpty) _detailLine('Location', event.location!),
                    if ((event.meetingUrl ?? '').isNotEmpty) _detailLine('Meeting Link', event.meetingUrl!),
                    if (event.maxAttendees != null) _detailLine('Max attendees', '${event.maxAttendees}'),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: event.isFree ? const Color(0xFFE9F9EE) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _priceLabel(isFree: event.isFree, price: event.price),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: event.isFree ? const Color(0xFF2E7D32) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => _openEventRegistrationSheet(event),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Register Now',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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

  Future<void> _openCourseDetails(_SupportCourse course) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      course.description,
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _detailLine('Category', course.category),
                    _detailLine('Duration', course.duration),
                    if (course.whatYouLearn.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        "What you'll learn",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...course.whatYouLearn.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 7, color: _kTeal),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p,
                                  style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: course.isFree ? const Color(0xFFE9F9EE) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _priceLabel(isFree: course.isFree, price: course.price),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: course.isFree ? const Color(0xFF2E7D32) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => _openCourseEnrollmentSheet(course),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Enrol Now',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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

  Future<void> _openEventRegistrationSheet(_SupportEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EventRegistrationSheet(
        event: event,
        prefillName: _prefillName,
        prefillEmail: _prefillEmail,
        onRegistered: () async {
          await _loadAll();
        },
        onOpenCalendar: () => _openCalendarForEvent(event),
      ),
    );
  }

  Future<void> _openCourseEnrollmentSheet(_SupportCourse course) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CourseEnrollmentSheet(
        course: course,
        prefillName: _prefillName,
        prefillEmail: _prefillEmail,
        onEnrolled: () async {
          await _loadAll();
        },
        openExternal: _openExternal,
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.poppins(
                color: _kText,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _chip(_SupportTab tab, String label) {
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _kTeal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kTeal : const Color(0xFFE5E7EB)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kTeal.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _tab = tab),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : _kGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventCard(_SupportEvent event) {
    final isRegistered = _registeredEventIds.contains(event.id);
    final isOnline = event.type.toLowerCase().contains('online');
    final left = _parseHex(event.colorHex, fallback: _kTeal);
    final registeredCount = _eventRegistrationCount[event.id] ?? 0;
    final spotsLeft = event.maxAttendees != null ? event.maxAttendees! - registeredCount : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    left.withValues(alpha: 0.95),
                    left.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOnline ? _kTeal.withValues(alpha: 0.15) : const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOnline ? 'Online' : 'In Person',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? _kTeal : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    event.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_dateLine(event.startDate), style: GoogleFonts.poppins(fontSize: 13, color: _kGrey)),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _priceLabel(isFree: event.isFree, price: event.price),
                        style: GoogleFonts.poppins(
                          color: event.isFree ? const Color(0xFF2E7D32) : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (spotsLeft != null)
                        Text(
                          '${spotsLeft < 0 ? 0 : spotsLeft} spots left',
                          style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openEventDetails(event),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Details', style: GoogleFonts.poppins()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isRegistered
                            ? Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9F9EE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Registered',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: () => _openEventRegistrationSheet(event),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kTeal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _courseCard(_SupportCourse course) {
    final isEnrolled = _enrolledCourseIds.contains(course.id);
    final left = _parseHex(course.colorHex, fallback: _kPurple);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    left.withValues(alpha: 0.95),
                    left.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        course.category,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kTeal,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    course.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          course.duration,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF4B5563),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _priceLabel(isFree: course.isFree, price: course.price),
                        style: GoogleFonts.poppins(
                          color: course.isFree ? const Color(0xFF2E7D32) : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openCourseDetails(course),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Details', style: GoogleFonts.poppins()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isEnrolled
                            ? Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9F9EE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Enrolled',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: () => _openCourseEnrollmentSheet(course),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kTeal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Enrol Now',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _communityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _kTeal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: _kGrey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openExternal(url),
                style: FilledButton.styleFrom(
                  backgroundColor: _kTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Open', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = _filteredCourses();
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kTeal, _kPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'ADHD Support Australia',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Real support from real people',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      'By Vivian Dunstan',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(_SupportTab.all, 'All'),
                    _chip(_SupportTab.events, 'Events'),
                    _chip(_SupportTab.courses, 'Courses'),
                    _chip(_SupportTab.programs, 'Programs'),
                    _chip(_SupportTab.coaching, 'Coaching'),
                    _chip(_SupportTab.community, 'Community'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: CircularProgressIndicator(color: _kTeal)),
                )
              else ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _kTeal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology, color: _kTeal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat with Coach Viv',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kText,
                              ),
                            ),
                            Text(
                              'Warm coaching with practical strategies',
                              style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => context.push('/coach-viv'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Open',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showEvents()) ...[
                  Text(
                    'Upcoming Events',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_events.isEmpty)
                    Text(
                      'No upcoming events right now.',
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                    )
                  else
                    ..._events.map(_eventCard),
                  const SizedBox(height: 14),
                ],
                if (_showCourses()) ...[
                  Text(
                    'Courses & Programs',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (courses.isEmpty)
                    Text(
                      'No courses available right now.',
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                    )
                  else
                    ...courses.map(_courseCard),
                  const SizedBox(height: 14),
                ],
                if (_showCommunity()) ...[
                  Text(
                    'Community',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _communityCard(
                    icon: Icons.workspace_premium,
                    title: 'Patreon',
                    subtitle: 'Member-only resources and regular support sessions.',
                    url: 'https://www.adhdsupportaustralia.com.au',
                  ),
                  _communityCard(
                    icon: Icons.self_improvement,
                    title: 'Self-Care Circle',
                    subtitle: 'A gentle check-in group with practical support.',
                    url: 'https://www.adhdsupportaustralia.com.au',
                  ),
                  _communityCard(
                    icon: Icons.flash_on,
                    title: 'Power Hour',
                    subtitle: 'Body-doubling sessions to start and finish tasks.',
                    url: 'https://www.adhdsupportaustralia.com.au',
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kTeal, _kPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Questions? We'd love to help",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _openExternal(
                            'https://www.adhdsupportaustralia.com.au/contact',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _kTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Contact Vivian',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _EventRegStep { form, done }

class _EventRegistrationSheet extends StatefulWidget {
  const _EventRegistrationSheet({
    required this.event,
    required this.prefillName,
    required this.prefillEmail,
    required this.onRegistered,
    required this.onOpenCalendar,
  });

  final _SupportEvent event;
  final String prefillName;
  final String prefillEmail;
  final Future<void> Function() onRegistered;
  final Future<void> Function() onOpenCalendar;

  @override
  State<_EventRegistrationSheet> createState() => _EventRegistrationSheetState();
}

class _EventRegistrationSheetState extends State<_EventRegistrationSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _dietary = TextEditingController();
  _EventRegStep _step = _EventRegStep.form;
  bool _loading = false;

  bool get _isOnline => widget.event.type.toLowerCase().contains('online');

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName);
    _email = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _dietary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _loading) return;
    if (Supabase.instance.client.auth.currentUser?.id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('event_registrations').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'event_id': widget.event.id,
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'dietary_requirements': !_isOnline && _dietary.text.trim().isNotEmpty
            ? _dietary.text.trim()
            : null,
        'status': 'registered',
        'payment_status': widget.event.isFree ? 'free' : 'pending',
      });
      await widget.onRegistered();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _EventRegStep.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not complete registration. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _step == _EventRegStep.form
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register for ${widget.event.title}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_dateLine(widget.event.startDate)} • ${widget.event.type}',
                    style: GoogleFonts.poppins(fontSize: 13, color: _kGrey),
                  ),
                  const SizedBox(height: 16),
                  _field('Full Name', _name),
                  _field('Email', _email, keyboardType: TextInputType.emailAddress),
                  _field('Phone number (optional)', _phone, keyboardType: TextInputType.phone),
                  if (!_isOnline)
                    _field('Dietary requirements (optional)', _dietary, maxLines: 3),
                  if (!widget.event.isFree) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _priceLabel(isFree: false, price: widget.event.price),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                            ),
                          ),
                          Text(
                            'Payment will be arranged after registration',
                            style: GoogleFonts.poppins(fontSize: 12, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              'Confirm Registration',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.check_circle, size: 80, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 10),
                  Text(
                    "You're registered!",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.event.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateLine(widget.event.startDate),
                    style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                  ),
                  const SizedBox(height: 12),
                  if (_isOnline) ...[
                    Text(
                      'Meeting link will be emailed to you',
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                    ),
                    if ((widget.event.meetingUrl ?? '').isNotEmpty)
                      Text(
                        widget.event.meetingUrl!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: _kTeal),
                      ),
                  ] else ...[
                    if ((widget.event.location ?? '').isNotEmpty)
                      Text(
                        'Location: ${widget.event.location!}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                      ),
                    Text(
                      "We'll send full details to your email",
                      style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: widget.onOpenCalendar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTeal,
                        side: const BorderSide(color: _kTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Add to Calendar', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: _kGrey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kTeal, width: 2),
          ),
        ),
      ),
    );
  }
}

enum _CourseEnrolStep { overview, expressInterest, done }

class _CourseEnrollmentSheet extends StatefulWidget {
  const _CourseEnrollmentSheet({
    required this.course,
    required this.prefillName,
    required this.prefillEmail,
    required this.onEnrolled,
    required this.openExternal,
  });

  final _SupportCourse course;
  final String prefillName;
  final String prefillEmail;
  final Future<void> Function() onEnrolled;
  final Future<void> Function(String? url) openExternal;

  @override
  State<_CourseEnrollmentSheet> createState() => _CourseEnrollmentSheetState();
}

class _CourseEnrollmentSheetState extends State<_CourseEnrollmentSheet> {
  _CourseEnrolStep _step = _CourseEnrolStep.overview;
  bool _loading = false;
  String _doneTitle = "You're enrolled!";
  String _doneSubtitle = 'You now have access';

  late final TextEditingController _name;
  late final TextEditingController _email;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _question = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName);
    _email = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _saveEnrollment({
    required String paymentStatus,
    String? notes,
  }) async {
    if (_loading) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('enrollments').insert({
        'user_id': uid,
        'course_id': widget.course.id,
        'status': 'enrolled',
        'payment_status': paymentStatus,
        'notes': notes,
      });
      await widget.onEnrolled();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not save enrollment. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _enrolFree() async {
    await _saveEnrollment(paymentStatus: 'free');
    if (!mounted) return;
    setState(() {
      _doneTitle = "You're enrolled!";
      _doneSubtitle = 'You now have access';
      _step = _CourseEnrolStep.done;
    });
  }

  Future<void> _payOnline() async {
    await _saveEnrollment(paymentStatus: 'pending');
    if (!mounted) return;
    await widget.openExternal(widget.course.purchaseUrl);
    if (!mounted) return;
    setState(() {
      _doneTitle = "You're enrolled!";
      _doneSubtitle = 'Complete payment to get access';
      _step = _CourseEnrolStep.done;
    });
  }

  Future<void> _submitInterest() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) return;
    final noteParts = <String>[
      if (_name.text.trim().isNotEmpty) 'Full Name: ${_name.text.trim()}',
      if (_email.text.trim().isNotEmpty) 'Email: ${_email.text.trim()}',
      if (_phone.text.trim().isNotEmpty) 'Phone: ${_phone.text.trim()}',
      if (_question.text.trim().isNotEmpty) 'Questions: ${_question.text.trim()}',
    ];
    await _saveEnrollment(
      paymentStatus: 'interest',
      notes: noteParts.isEmpty ? null : noteParts.join('\n'),
    );
    if (!mounted) return;
    setState(() {
      _doneTitle = 'Interest registered!';
      _doneSubtitle = 'Vivian will be in touch within 2 days';
      _step = _CourseEnrolStep.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _step == _CourseEnrolStep.done
            ? Column(
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.school, size: 80, color: _kTeal),
                  const SizedBox(height: 12),
                  Text(
                    _doneTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _kTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.course.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _doneSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Done', style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                ],
              )
            : _step == _CourseEnrolStep.expressInterest
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Express Interest',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _field('Full Name', _name),
                      _field('Email', _email, keyboardType: TextInputType.emailAddress),
                      _field('Phone (optional)', _phone, keyboardType: TextInputType.phone),
                      _field('Any questions for Vivian? (optional)', _question, maxLines: 3),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _submitInterest,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(
                                  'Submit Interest',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enrol in ${widget.course.title}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.course.description,
                        style: GoogleFonts.poppins(fontSize: 14, color: _kGrey, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      if (widget.course.whatYouLearn.isNotEmpty) ...[
                        Text(
                          "What you'll learn",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.course.whatYouLearn.map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 7, color: _kTeal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    v,
                                    style: GoogleFonts.poppins(fontSize: 14, color: _kGrey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.course.duration,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _priceLabel(isFree: widget.course.isFree, price: widget.course.price),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (widget.course.isFree)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _enrolFree,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kTeal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Text('Enrol Now', style: GoogleFonts.poppins(color: Colors.white)),
                          ),
                        )
                      else ...[
                        Text(
                          'How would you like to pay?',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _optionCard(
                          icon: Icons.credit_card,
                          title: 'Pay Online',
                          subtitle: 'Secure payment via website',
                          onTap: _loading ? null : _payOnline,
                        ),
                        _optionCard(
                          icon: Icons.mail_outline,
                          title: 'Express Interest',
                          subtitle: "We'll contact you with payment details",
                          onTap: _loading
                              ? null
                              : () => setState(() => _step = _CourseEnrolStep.expressInterest),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: _kTeal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: _kGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: _kGrey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kTeal, width: 2),
          ),
        ),
      ),
    );
  }
}
