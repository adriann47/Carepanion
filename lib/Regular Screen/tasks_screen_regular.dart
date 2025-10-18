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
import 'package:softeng/services/guardian_notification_service.dart';
import 'dart:async';
// NOTE: Removed StreakService import – we now source the streak solely from user_streaks
// import 'package:softeng/services/streak_service.dart';

// ====================== MAIN SCREEN ======================
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
  RealtimeChannel? _streakChannel;

  List<Map<String, dynamic>> _completedNotifications = [];

  int? _streak; // null = loading; we’ll show 0 only when the DB actually says 0.

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeProfileChanges();
    _bindStreak(); // fetch + realtime subscribe
    _subscribeAssistedTaskCompletions();
    _subscribeNotificationsForStreak(); // will trigger a re-fetch when a “done” is recorded
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    _streakChannel?.unsubscribe();
    super.dispose();
  }

  // ---------- STREAK (user_streaks.current_streak) ----------
  Future<void> _bindStreak() async {
    await _fetchStreakFromDb(); // initial load
    _subscribeStreakChanges();   // live updates
  }

  Future<void> _fetchStreakFromDb() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Expect one row per user in user_streaks
      final rows = await client
          .from('user_streaks')
          .select('current_streak')
          .eq('user_id', user.id)
          .limit(1);

      final value = rows.isNotEmpty
          ? int.tryParse(rows.first['current_streak'].toString()) ?? 0
          : 0;

      if (mounted) setState(() => _streak = value);
    } catch (_) {
      if (mounted) setState(() => _streak ??= 0);
    }
  }

  void _subscribeStreakChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _streakChannel = client
        .channel('public:user_streaks:user:${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_streaks',
        callback: (payload) {
          final row = payload.newRecord;
          if (row['user_id']?.toString() != user.id) return;
          final val = int.tryParse('${row['current_streak'] ?? 0}') ?? 0;
          if (mounted) setState(() => _streak = val);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'user_streaks',
        callback: (payload) {
          final row = payload.newRecord;
          if (row['user_id']?.toString() != user.id) return;
          final val = int.tryParse('${row['current_streak'] ?? 0}') ?? 0;
          if (mounted) setState(() => _streak = val);
        },
      )
      ..subscribe();
  }

  Future<void> _refreshStreak() async {
    await _fetchStreakFromDb();
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return 'Recently';
    }
  }

  // ---------- PROFILE ----------
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
        final publicId = data?['public_id'] as String?;
        _userId = (publicId != null && publicId.trim().isNotEmpty)
            ? publicId
            : (authUser?.id ?? 'Unknown');
        _email = authUser?.email ?? (data?['email'] as String?) ?? 'Unknown';
        final name = (data?['fullname'] as String?)?.trim();
        _fullName = (name != null && name.isNotEmpty)
            ? name
            : _friendlyFromEmail(_email ?? 'Unknown');

        final raw = data?['avatar_url'] as String?;
        _avatarUrl = (raw == null || raw.trim().isEmpty)
            ? null
            : '$raw?v=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (_) {}
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

  // ---------- TASK/NOTIF SUBSCRIPTIONS ----------
  void _subscribeNotificationsForStreak() {
    // Using simpler approach to avoid realtime subscription timeouts
    // Streak updates will be handled through manual refreshes
  }

  void _subscribeAssistedTaskCompletions() {
    // Using simpler approach to avoid realtime subscription timeouts
    // Task completion notifications will be handled through manual refreshes
  }
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
        ),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.nunito(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF2D2D2D),
    );

    final int shownStreak = _streak ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      floatingActionButton: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserHeaderCard(
                avatarUrl: _avatarUrl,
                userId: _userId ?? 'Unknown',
                fullName: _fullName ?? 'Unknown',
                email: _email ?? 'Unknown',
              ),
              const SizedBox(height: 18),

              // --- STREAK CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    const Icon(Icons.emoji_events, color: Colors.orange, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_streak == null)
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.orange.shade400),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Loading streak…",
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: const Color(0xFF2D2D2D),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              shownStreak <= 0
                                  ? "NO STREAK YET"
                                  : (shownStreak == 1 ? "1 DAY STREAK!" : "$shownStreak DAYS STREAK!"),
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: const Color(0xFF2D2D2D),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            "Thanks for showing up today! Consistency is the key to forming strong habits.",
                            style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF4A4A4A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("TODAY'S TASK", style: titleStyle),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _TodayTasksStream(
                  onEdited: (task, done) async {
                    // No optimistic streak mutation here; we trust DB/trigger logic.
                    // Just re-fetch to reflect any server-side streak increments.
                    await _refreshStreak();
                    // tiny debounce to accommodate any trigger lag
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (mounted) _refreshStreak();
                    });
                  },
                ),
              ),

              // --- RECENT ACTIVITY ---
              if (_completedNotifications.isNotEmpty) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "RECENT ACTIVITY",
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _completedNotifications.take(5).map((notif) {
                      final user = notif['user'] as String? ?? 'Unknown';
                      final title = notif['title'] as String? ?? 'Task';
                      final time = notif['time'] as String? ?? '';
                      final isDone = notif['isDone'] as bool? ?? false;
                      final avatarUrl = notif['avatarUrl'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$user completed "$title"',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2D2D2D),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time.isNotEmpty ? _formatTime(time) : 'Just now',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isDone ? Icons.check_circle : Icons.skip_next,
                              color: isDone ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
          _navItem(Icons.calendar_today, 'Menu', isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Companion', isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications', isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

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
          child: Icon(icon, size: 28, color: isSelected ? Colors.pink : Colors.black87),
        ),
      ),
    );
  }
}

// ===================== User header card (guardian-style, adjusted) =====================
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
    const bg = Color(0xFFFFB04A);
    const stroke = Color(0xFFE88926);
    const plusTint = Color(0x22E88926);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: stroke, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: stroke.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: stroke, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(Icons.person, size: 44, color: Color(0xFF8E4A1E))),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'USER CARD:',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1.0,
                            letterSpacing: 0.4,
                            color: const Color(0xFF3B2717),
                          ),
                        ),
                        const SizedBox(height: 2),

                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.05,
                            letterSpacing: 0.1,
                            color: const Color(0xFF23160E),
                          ),
                        ),
                        const SizedBox(height: 6),

                        _line('EMAIL:', email, fontSize: 13),
                        const SizedBox(height: 2),

                        _line('USER ID:', userId, fontSize: 13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 20,
            top: 8,
            child: Icon(Icons.add, size: 36, color: plusTint),
          ),
          const Positioned(
            right: 30,
            top: 18,
            child: Icon(Icons.add, size: 20, color: plusTint),
          ),
          const Positioned(
            right: 52,
            bottom: 10,
            child: Icon(Icons.add, size: 30, color: plusTint),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {double fontSize = 13}) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              height: 1.05,
              color: const Color(0xFF3B2717),
            ),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              height: 1.05,
              color: const Color(0xFF3B2717),
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

        var tasks = (snapshot.data ?? const [])
            .where((row) => (row['due_date']?.toString() ?? '') == today)
            .toList();

        tasks.sort((a, b) {
          final sa = a['start_at']?.toString();
          final sb = b['start_at']?.toString();
          if (sa == null && sb == null) return 0;
          if (sa == null) return 1;
          if (sb == null) return -1;
          return DateTime.parse(sa).compareTo(DateTime.parse(sb));
        });

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

// ===================== Task Tile =====================
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
      if (mounted) widget.onEdited(widget.task, value);

      // Record an outcome notification for regular users as well (to own page)
      try {
        if (value) {
          final assistedId = (widget.task['user_id'] ?? supabase.auth.currentUser?.id ?? '').toString();
          final sa = widget.task['start_at'];
          DateTime? scheduled;
          if (sa != null) {
            try { scheduled = DateTime.parse(sa.toString()); } catch (_) {}
          }
          await GuardianNotificationService.recordTaskOutcome(
            taskId: id.toString(),
            assistedId: assistedId,
            title: (widget.task['title'] ?? 'Task').toString(),
            scheduledAt: scheduled,
            action: 'done',
            actionAt: DateTime.now().toUtc(),
          );
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => _done = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: catColor.withOpacity(0.45)),
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
                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF36495A)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditTaskScreen(task: widget.task),
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
                      if ((note).isNotEmpty) _infoLine(label: 'NOTE', value: note),
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
