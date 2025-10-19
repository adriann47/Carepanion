import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/services/task_service.dart';
import '../Regular Screen/edit_task.dart';
// no extra imports needed for created-by display

class DailyTasksScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? forUserId; // optional: show tasks for this user id

  const DailyTasksScreen({
    super.key,
    required this.selectedDate,
    this.forUserId,
  });

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  // layout constants
  static const double _headerHeight = 110; // ample space for date title
  static const double _pageSidePadding = 16;
  static const double _sectionGap = 24;
  static const double _labelToTilesGap = 12;

  @override
  void initState() {
    super.initState();
    // Best-effort: mark any past 'todo' tasks as 'skip' for current user
    TaskService.autoSkipPastDueTodos().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        "${_monthNames[widget.selectedDate.month - 1].toUpperCase()} ${widget.selectedDate.day}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3ED),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER CONTAINER (only for the date + back) ---
            Container(
              height: _headerHeight,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              // keep same bg to look seamless; add subtle divider feel with bottom padding
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // back button on the left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // centered date title
                  Text(
                    formattedDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3D3D3D),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY (scrollable sections) ---
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: TaskService.getTasksForDate(
                  widget.selectedDate,
                  forUserId: widget.forUserId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading tasks: ${snapshot.error}',
                        style: GoogleFonts.nunito(fontSize: 14),
                      ),
                    );
                  }

                  final all = snapshot.data ?? [];
                  if (all.isEmpty) {
                    return Center(
                      child: Text(
                        'No tasks for this day',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: const Color(0xFF555555),
                        ),
                      ),
                    );
                  }

                  // Split into buckets
                  final todo = <Map<String, dynamic>>[];
                  final done = <Map<String, dynamic>>[];
                  final skip = <Map<String, dynamic>>[];

                  for (final t in all) {
                    switch (_bucketFor(t)) {
                      case _Bucket.todo:
                        todo.add(t);
                        break;
                      case _Bucket.done:
                        done.add(t);
                        break;
                      case _Bucket.skip:
                        skip.add(t);
                        break;
                    }
                  }

                  // Sort by start time ascending within each bucket
                  int cmpStart(a, b) {
                    DateTime? dt(dynamic iso) {
                      if (iso == null) return null;
                      try {
                        return DateTime.parse(iso.toString());
                      } catch (_) {
                        return null;
                      }
                    }

                    final sa = dt(a['start_at']);
                    final sb = dt(b['start_at']);
                    if (sa == null && sb == null) return 0;
                    if (sa == null) return 1;
                    if (sb == null) return -1;
                    return sa.compareTo(sb);
                  }

                  todo.sort(cmpStart);
                  done.sort(cmpStart);
                  skip.sort(cmpStart);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      _pageSidePadding,
                      0,
                      _pageSidePadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TO DO (blue)
                        _sectionHeader('TO DO'),
                        const SizedBox(height: _labelToTilesGap),
                        if (todo.isEmpty)
                          _emptyHint('No tasks to do')
                        else
                          ...todo.map(
                            (t) => _taskCard(
                              task: t,
                              isDone: _isDone(t),
                              onToggleDone: (value) => _toggleStatus(t, value),
                              onTap: () => _openEdit(t),
                              onSkip: () => _setSkip(t),
                              colorA: const Color(0xFFBEE6FF),
                              colorB: const Color(0xFF9ED8FF),
                              textColor: const Color(0xFF163047),
                            ),
                          ),

                        const SizedBox(height: _sectionGap),

                        // DONE (green)
                        _sectionHeader('DONE'),
                        const SizedBox(height: _labelToTilesGap),
                        if (done.isEmpty)
                          _emptyHint('No tasks done yet')
                        else
                          ...done.map(
                            (t) => _taskCard(
                              task: t,
                              isDone: true,
                              onToggleDone: (value) => _toggleStatus(t, value),
                              onTap: () => _openEdit(t),
                              colorA: const Color(0xFFCFF8C8),
                              colorB: const Color(0xFFB6F0AD),
                              textColor: const Color(0xFF14391D),
                            ),
                          ),

                        const SizedBox(height: _sectionGap),

                        // SKIP (salmon/red)
                        _sectionHeader('SKIP'),
                        const SizedBox(height: _labelToTilesGap),
                        if (skip.isEmpty)
                          _emptyHint('No skipped tasks')
                        else
                          ...skip.map(
                            (t) => _taskCard(
                              task: t,
                              isDone: _isDone(t),
                              onToggleDone: (value) => _toggleStatus(t, value),
                              onTap: () => _openEdit(t),
                              colorA: const Color(0xFFFFC7B8),
                              colorB: const Color(0xFFFFB6A3),
                              textColor: const Color(0xFF4A1E1A),
                            ),
                          ),
                      ],
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

  // ---------- Helpers ----------

  void _openEdit(Map<String, dynamic> t) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(
          task: t,
          forUserId: widget.forUserId ?? t['user_id'] as String?,
        ),
      ),
    );
    if (changed == true) setState(() {});
  }

  bool _isDone(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString().toLowerCase();
    if (status == 'done') return true;
    final raw = t['is_done'] ?? t['done'] ?? false;
    return raw is bool
        ? raw
        : (raw.toString() == 'true' || raw.toString() == '1');
  }

  Future<void> _toggleStatus(Map<String, dynamic> t, bool value) async {
    final id = (t['id'] as num).toInt();
    try {
      await TaskService.setTaskStatus(id: id, status: value ? 'done' : 'todo');
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> _setSkip(Map<String, dynamic> t) async {
    final id = (t['id'] as num).toInt();
    try {
      await TaskService.markSkip(id);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to skip task: $e')));
    }
  }

  // Decide which section a task belongs to.
  _Bucket _bucketFor(Map<String, dynamic> t) {
    // Prefer canonical 'status' column first
    final status = (t['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'done') return _Bucket.done;
    if (status == 'skip') return _Bucket.skip;

    // Legacy fallbacks
    final isSkip = (t['is_skipped'] ?? false);
    if (isSkip == true ||
        isSkip.toString() == 'true' ||
        isSkip.toString() == '1') {
      return _Bucket.skip;
    }
    final isDone = (t['is_done'] ?? t['done'] ?? false);
    if (isDone == true ||
        isDone.toString() == 'true' ||
        isDone.toString() == '1') {
      return _Bucket.done;
    }
    return _Bucket.todo;
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      textAlign: TextAlign.left,
      style: GoogleFonts.nunito(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF6B6B6B),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF8A8A8A)),
      ),
    );
  }

  Widget _taskCard({
    required Map<String, dynamic> task,
    required bool isDone,
    required Future<void> Function(bool value) onToggleDone,
    required VoidCallback onTap,
    VoidCallback? onSkip,
    required Color colorA,
    required Color colorB,
    required Color textColor,
  }) {
    final title = (task['title'] ?? '').toString();
    final note = (task['description'] ?? '').toString();
    final time = _formatTimeRange(task['start_at'], task['end_at']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorA, colorB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with checkbox and optional Skip
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: isDone,
                      onChanged: (v) => onToggleDone(v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (onSkip != null)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: textColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        'SKIP',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // TIME
              _infoLine(label: 'TIME', value: time, color: textColor),

              // NOTE
              if (note.isNotEmpty)
                _infoLine(label: 'NOTE', value: note, color: textColor),

              // CREATED BY (guardian who created the task), if available on the row
              if ((task['created_by_name'] ?? '').toString().trim().isNotEmpty)
                _infoLine(
                  label: 'CREATED BY',
                  value: (task['created_by_name'] ?? '').toString().trim(),
                  color: textColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a time or time range for a task row

  Widget _infoLine({
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: RichText(
        textAlign: TextAlign.left,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.nunito(
                color: color.withOpacity(0.95),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.nunito(
                color: color.withOpacity(0.95),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange(dynamic startIso, dynamic endIso) {
    String fmt(dynamic iso) {
      if (iso == null) return '';
      try {
        final dt = DateTime.parse(iso.toString()).toLocal();
        return DateFormat('h:mm a').format(dt);
      } catch (_) {
        return '';
      }
    }

    final s = fmt(startIso);
    final e = fmt(endIso);
    if (s.isEmpty && e.isEmpty) return 'All day';
    if (s.isNotEmpty && e.isEmpty) return s;
    if (s.isEmpty && e.isNotEmpty) return e;
    return '$s - $e';
  }

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

enum _Bucket { todo, done, skip }
