import 'package:flutter/material.dart';
import 'profile_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
import 'notification_screen.dart';
import 'edit_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/services/task_service.dart';
// import 'package:softeng/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
// Removed local TTS usage; global ReminderService handles any speech if needed.

class TasksScreenRegular extends StatefulWidget {
  const TasksScreenRegular({super.key});

  @override
  State<TasksScreenRegular> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreenRegular> {
  int _currentIndex = 0;

  String? _avatarUrl;
  String? _userId;
  String? _fullName;
  String? _email;
  RealtimeChannel? _profileChannel;
  // Local per-screen timer removed; popups handled by global ReminderService
  List<Map<String, dynamic>> _completedNotifications = [];
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeProfileChanges();
    _refreshStreak();
    // Popups are handled globally by ReminderService; no local timer here.
  }

  // Removed local timer; see ReminderService for global checks

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshStreak() async {
    try {
      final s = await TaskService.computeCurrentStreak();
      if (!mounted) return;
      setState(() => _streak = s);
    } catch (_) {}
  }

  String _friendlyFromEmail(String email) {
    if (email.contains('@')) {
      final local = email.split('@').first;
      final parts = local.split(RegExp(r'[._\s]+')).where((s) => s.isNotEmpty);
      if (parts.isEmpty) return email;
      return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
    }
    return email;
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;

      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;

      setState(() {
        // Prefer a short public_id (8-digit) stored in profile for display.
        final publicId = data?['public_id'] as String?;
        _userId = (publicId != null && publicId.trim().isNotEmpty)
            ? publicId
            : (authUser?.id ?? '—');

        _email = authUser?.email ?? (data?['email'] as String?) ?? '—';

        final name = (data?['fullname'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _fullName = name;
        } else {
          _fullName = _friendlyFromEmail(_email ?? '—');
        }

        final raw = data?['avatar_url'] as String?;
        _avatarUrl = (raw == null || raw.trim().isEmpty)
            ? null
            : '$raw?v=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (_) {
      // ignore silently
    }
  }

  void _subscribeProfileChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    _profileChannel = client
        .channel('public:profile')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profile',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['id'] != user.id) return;
            if (!mounted) return;
            setState(() {
              final name = (row['fullname'] as String?)?.trim();
              if (name != null && name.isNotEmpty) {
                _fullName = name;
              } else if ((_email ?? '').isNotEmpty) {
                _fullName = _friendlyFromEmail(_email!);
              }
              final em = (row['email'] as String?)?.trim();
              if (em != null && em.isNotEmpty) _email = em;
              final url = (row['avatar_url'] as String?)?.trim();
              if (url != null && url.isNotEmpty) {
                _avatarUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
              }
            });
          },
        )
        .subscribe();
  }

  // No local popup logic; handled by global ReminderService

  // Local add-notification removed; rely on DB changes and NotificationScreen input

  void _onTabTapped(int index) async {
    setState(() => _currentIndex = index);

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CalendarScreenRegular()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompanionListScreen()),
      );
    } else if (index == 3) {
      // Await result and update notifications if returned
      final result = await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NotificationScreen(notifications: _completedNotifications),
        ),
      );
      if (result is List<Map<String, dynamic>>) {
        setState(() {
          _completedNotifications = result;
        });
      }
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.nunito(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF2D2D2D),
      letterSpacing: 0.3,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      // No debug FAB
      floatingActionButton: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- USER CARD (updated) ---
              _UserHeaderCard(
                avatarUrl: _avatarUrl,
                userId: _userId ?? '—',
                fullName: _fullName ?? '—',
                email: _email ?? '—',
              ),

              const SizedBox(height: 18),

              // --- STREAK CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.orange,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _streak <= 0
                                ? "NO STREAK YET"
                                : (_streak == 1
                                      ? "1 DAY STREAK!"
                                      : "$_streak DAYS STREAK!"),
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Thanks for showing up today! Consistency is the key to forming strong habits.",
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: const Color(0xFF4A4A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // --- TODAY'S TASK TITLE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("TODAY’S TASK", style: titleStyle),
              ),
              const SizedBox(height: 14),

              // --- TASK LIST (from Supabase, realtime) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _TodayTasksStream(
                  onEdited: (task, done) async {
                    setState(() {
                      // Optimistically activate streak immediately for today's tasks
                      if (done && _streak == 0) {
                        _streak = 1;
                      }
                    });
                    await _refreshStreak();
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) _refreshStreak();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // --- NAV BAR ---
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          _navItem(Icons.home, 'Home', isSelected: _currentIndex == 0),
          _navItem(
            Icons.calendar_today,
            'Menu',
            isSelected: _currentIndex == 1,
          ),
          _navItem(
            Icons.family_restroom,
            'Companion',
            isSelected: _currentIndex == 2,
          ),
          _navItem(
            Icons.notifications,
            'Notifications',
            isSelected: _currentIndex == 3,
          ),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  // Debug helper removed.

  static BottomNavigationBarItem _navItem(
    IconData icon,
    String label, {
    required bool isSelected,
  }) {
    return BottomNavigationBarItem(
      label: label,
      icon: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ===================== User header card =====================
class _UserHeaderCard extends StatelessWidget {
  const _UserHeaderCard({
    required this.avatarUrl,
    required this.userId,
    required this.fullName,
    required this.email,
  });

  final String? avatarUrl;
  final String userId;
  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                ? NetworkImage(avatarUrl!)
                : null,
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.orange)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: $userId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Today stream =====================

class _TodayTasksStream extends StatelessWidget {
  const _TodayTasksStream({required this.onEdited});
  final void Function(Map<String, dynamic> task, bool done) onEdited;

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Important: Do not filter by due_date on the server for realtime.
    // Delete events may not include non-PK columns for filtering unless REPLICA IDENTITY FULL is set.
    // Stream rows for the current user (or all rows if unauthenticated) and filter client-side
    // to ensure deletes are reflected immediately.
    final uid = supabase.auth.currentUser?.id;
    final baseStream = supabase.from('tasks').stream(primaryKey: ['id']);
    final stream = uid != null ? baseStream.eq('user_id', uid) : baseStream;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Error loading tasks: ${snapshot.error}'),
          );
        }

        // Filter today's tasks client-side
        var tasks = (snapshot.data ?? const [])
            .where((row) => (row['due_date']?.toString() ?? '') == today)
            .toList();

        // Sort by start_at ascending
        tasks.sort((a, b) {
          final sa = a['start_at']?.toString();
          final sb = b['start_at']?.toString();
          if (sa == null && sb == null) return 0;
          if (sa == null) return 1;
          if (sb == null) return -1;
          return DateTime.parse(sa).compareTo(DateTime.parse(sb));
        });

        // no-op: global reminder service handles timing

        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No tasks for today',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: const Color(0xFF4A4A4A),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final t in tasks)
              _TaskTile(key: ValueKey(t['id']), task: t, onEdited: onEdited),
          ],
        );
      },
    );
  }
}

// ===================== Tile (title + category; persistent checkbox) =====================

class _TaskTile extends StatefulWidget {
  const _TaskTile({super.key, required this.task, required this.onEdited});

  final Map<String, dynamic> task;
  final void Function(Map<String, dynamic> task, bool done) onEdited;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  late bool _done;

  bool _deriveDone(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString().toLowerCase();
    if (status == 'done') return true;
    final raw = t['is_done'] ?? t['done'] ?? false;
    return raw is bool
        ? raw
        : (raw.toString() == 'true' || raw.toString() == '1');
  }

  @override
  void initState() {
    super.initState();
    _done = _deriveDone(widget.task);
  }

  @override
  void didUpdateWidget(covariant _TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _deriveDone(widget.task);
    if (incoming != _done) {
      setState(() => _done = incoming);
    }
  }

  Future<void> _toggleDone(bool value) async {
    final id = widget.task['id'];
    final prev = _done;
    setState(() => _done = value);

    try {
      await TaskService.setTaskStatus(id: id, status: value ? 'done' : 'todo');

      final supabase = Supabase.instance.client;
      try {
        await supabase.from('tasks').update({'is_done': value}).eq('id', id);
      } catch (_) {
        try {
          await supabase.from('tasks').update({'done': value}).eq('id', id);
        } catch (_) {}
      }

      widget.task['status'] = value ? 'done' : 'todo';
      widget.task['is_done'] = value;
      widget.task['done'] = value;
      // Inform parent so it can refresh streak
      if (mounted) widget.onEdited(widget.task, value);
    } catch (e) {
      if (mounted) {
        setState(() => _done = prev);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.task['title'] ?? '').toString();
    final note = (widget.task['description'] ?? '').toString();

    final rawCat = (widget.task['category'] ?? 'other')
        .toString()
        .trim()
        .toLowerCase();
    final cat = rawCat.isEmpty ? 'other' : rawCat;
    late final Color catColor;
    late final String catLabel;
    switch (cat) {
      case 'medication':
      case 'medicine':
      case 'meds':
        catColor = const Color(0xFF6C5CE7);
        catLabel = 'Medication';
        break;
      case 'exercise':
      case 'workout':
      case 'fitness':
        catColor = const Color(0xFF00A896);
        catLabel = 'Exercise';
        break;
      default:
        catColor = const Color(0xFF607D8B);
        catLabel = 'Other';
    }

    String fmt(dynamic iso) {
      if (iso == null) return '';
      try {
        final dt = DateTime.parse(iso.toString()).toLocal();
        return TimeOfDay(hour: dt.hour, minute: dt.minute).format(context);
      } catch (_) {
        return '';
      }
    }

    final s = fmt(widget.task['start_at']);
    final e = fmt(widget.task['end_at']);
    final time = s.isEmpty && e.isEmpty
        ? 'All day'
        : (s.isNotEmpty && e.isNotEmpty ? '$s - $e' : (s + e));

    final double opacity = _done ? 0.55 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF77CA0),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
              ],
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD8F1FF), Color(0xFFBEE6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 1.15,
                            child: Checkbox(
                              value: _done,
                              onChanged: (v) => _toggleDone(v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                            child: Wrap(
                              direction: Axis.horizontal,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 2,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 0.5,
                                    color: const Color(0xFF1E2A36),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: catColor.withOpacity(0.45),
                                    ),
                                  ),
                                  child: Text(
                                    catLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF36495A),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditTaskScreen(task: widget.task),
                                ),
                              );
                              if (changed == true) {
                                widget.onEdited(widget.task, _done);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      _infoLine(label: 'TIME', value: time),
                      if ((note).isNotEmpty)
                        _infoLine(label: 'NOTE', value: note),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.nunito(
              color: const Color(0xFF2D2D2D),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                color: const Color(0xFF2D2D2D),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
