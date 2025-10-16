import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:softeng/services/task_service.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';
import 'calendar_screen.dart';
import 'navbar_assisted.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/services/streak_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreen();
}

class _TasksScreen extends State<TasksScreen> {
  int _currentIndex = 0; // Home tab
  final List<bool> _taskDone = []; // tracked per loaded task
  String? _avatarUrl;
  String? _fullName;
  String? _email;
  String? _guardianFullName;
  List<Map<String, dynamic>> _tasks = [];
  RealtimeChannel? _profileChannel;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTodayTasks();
    _subscribeProfileChanges();
    _refreshStreak();
    // Listen for global streak updates (e.g., from popup DONE)
    StreakService.current.addListener(_onStreakUpdate);
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;
      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;

      setState(() {
        final rawUrl = data?['avatar_url'] as String?;
        _avatarUrl = (rawUrl == null || rawUrl.trim().isEmpty)
            ? null
            : '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';

        final name = (data?['fullname'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _fullName = name;
        } else {
          final email = authUser?.email ?? (data?['email'] as String?) ?? '';
          _fullName = _friendlyFromEmail(email);
        }
        _email = authUser?.email ?? (data?['email'] as String?) ?? 'â€”';
      });

      // Linked guardian (best effort)
      final guardianId = (data?['guardian_id'] as String?)?.trim();
      if (guardianId != null && guardianId.isNotEmpty) {
        try {
          final g = await ProfileService.fetchProfile(
            client,
            userId: guardianId,
          );
          if (!mounted) return;
          final gName = (g?['fullname'] as String?)?.trim();
          if (gName != null && gName.isNotEmpty) {
            setState(() => _guardianFullName = gName);
          }
        } catch (_) {}
      }
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
              if (name != null && name.isNotEmpty) _fullName = name;
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

  @override
  void dispose() {
    StreakService.current.removeListener(_onStreakUpdate);
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  void _onStreakUpdate() {
    if (!mounted) return;
    setState(() => _streak = StreakService.current.value);
  }

  Future<void> _loadTodayTasks() async {
    try {
      final today = DateTime.now();
      final tasks = await TaskService.getTasksForDate(today);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _taskDone
          ..clear()
          ..addAll(_tasks.map((t) => (t['status']?.toString() == 'done')));
      });
      await _refreshStreak();
    } catch (e) {
      // ignore errors silently for now
    }
  }

  Future<void> _refreshStreak() async {
    try {
      final s = await TaskService.computeCurrentStreak();
      if (!mounted) return;
      setState(() => _streak = s);
      // Broadcast so other screens/popups can reflect immediately
      try { StreakService.current.value = s; } catch (_) {}
    } catch (_) {}
  }

  // ignore: unused_element
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyScreen()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.nunito(
      fontSize: 26, // Slightly reduced from 28
      fontWeight: FontWeight.w800,
      color: const Color(0xFF2D2D2D),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- USER ID CARD (smaller profile picture, slightly smaller text) ---
              _UserHeaderCardAssisted(
                avatarUrl: _avatarUrl,
                fullName: _fullName ?? 'â€”',
                email: _email ?? 'â€”',
                numberOrId:
                    _guardianFullName != null && _guardianFullName!.isNotEmpty
                    ? _guardianFullName!
                    : 'â€”',
              ),
              const SizedBox(height: 18),

              // --- LARGER STREAK CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.orange.shade200, width: 2.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.orange,
                      size: 42,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _streak <= 0
                                ? 'NO STREAK YET'
                                : (_streak == 1
                                      ? '1 DAY STREAK!'
                                      : '$_streak DAYS STREAK!'),
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Thanks for showing up today! Consistency is the key to forming strong habits.',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              color: const Color(0xFF4A4A4A),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// --- TASK LIST ---
              // --- TODAY'S TASK TITLE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("TODAY'S TASKS", style: titleStyle),
              ),
              const SizedBox(height: 14),

              // --- TASK LIST (slightly smaller tiles) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _tasks.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No tasks for today',
                          style: GoogleFonts.nunito(
                            fontSize: 17, // Slightly reduced from 18
                            color: const Color(0xFF4A4A4A),
                          ),
                        ),
                      )
                    : Column(
                        children: List.generate(_tasks.length, (i) {
                          final t = _tasks[i];
                          final title = (t['title'] ?? '') as String;
                          final note = (t['description'] ?? '') as String;
                          final startAt = t['start_at']?.toString();
                          String timeStr = '';
                          if (startAt != null) {
                            try {
                              final dt = DateTime.parse(startAt).toLocal();
                              timeStr = DateFormat('h:mm a').format(dt);
                            } catch (_) {}
                          }
                          // Determine which guardian set the task
                          // 1) Use created_by_name if present
                          String guardian = (t['created_by_name'] ?? '')
                              .toString()
                              .trim();
                          if (guardian.isEmpty) {
                            final createdBy = t['created_by']?.toString();
                            if (createdBy != null && createdBy.isNotEmpty) {
                              ProfileService.fetchProfile(
                                    Supabase.instance.client,
                                    userId: createdBy,
                                  )
                                  .then((p) {
                                    if (!mounted || p == null) return;
                                    final name = (p['fullname'] ?? '')
                                        .toString()
                                        .trim();
                                    if (name.isNotEmpty) {
                                      setState(() {
                                        _tasks[i]['created_by_name'] = name;
                                      });
                                    }
                                  })
                                  .catchError((_) {});
                            }
                          }
                          if (guardian.isEmpty) {
                            guardian =
                                (_guardianFullName ??
                                        (t['guardian_name'] ??
                                            t['created_by_name'] ??
                                            ''))
                                    .toString()
                                    .trim();
                          }

                          String fmt(dynamic iso) {
                            if (iso == null) return '';
                            try {
                              final dt = DateTime.parse(
                                iso.toString(),
                              ).toLocal();
                              return TimeOfDay(
                                hour: dt.hour,
                                minute: dt.minute,
                              ).format(context);
                            } catch (_) {
                              return '';
                            }
                          }

                          final s = fmt(t['start_at']);
                          final e = fmt(t['end_at']);
                          final time = s.isEmpty && e.isEmpty
                              ? 'All day'
                              : (s.isNotEmpty && e.isNotEmpty
                                    ? '$s - $e'
                                    : (s + e));

                          final taskId = (t['id'] is int)
                              ? t['id'] as int
                              : int.tryParse('${t['id']}');

                          final checked = i < _taskDone.length
                              ? _taskDone[i]
                              : (t['status']?.toString() == 'done');

                          return _AssistedTaskTile(
                            key: ValueKey('assisted_task_$i'),
                            title: title,
                            time: time,
                            note: note,
                            guardian: guardian.isNotEmpty
                                ? guardian
                                : 'Unknown',
                            checked: checked,
                            onChanged: (val) async {
                              final newVal = val ?? false;
                              if (i < _taskDone.length) {
                                                                setState(() {
                                  _taskDone[i] = newVal;
                                  // Optimistically activate streak immediately for today's tasks
                                  if (newVal && _streak == 0) {
                                    _streak = 1;
                                    try { StreakService.current.value = _streak; } catch (_) {}
                                  }
                                });
                              }
                              if (taskId != null) {
                                try {
                                  if (newVal) {
                                    await TaskService.markDone(taskId);
                                  } else {
                                    await TaskService.markTodo(taskId);
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to update task status',
                                        ),
                                      ),
                                    );
                                  }
                                }
                                await _loadTodayTasks();
                                await _refreshStreak();
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  if (mounted) _refreshStreak();
                                });
                              }
                            },
                          );
                        }),
                      ),
              ),
            ],
          ),
        ),
      ),

      // Reusable navigation bar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 0),
    );
  }
}

// =============== Assisted Header (smaller profile picture, slightly smaller text) ===============
class _UserHeaderCardAssisted extends StatelessWidget {
  const _UserHeaderCardAssisted({
    required this.avatarUrl,
    required this.fullName,
    required this.email,
    required this.numberOrId,
  });

  final String? avatarUrl;
  final String fullName;
  final String email;
  final String numberOrId;

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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ), // Slightly reduced
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26), // Slightly smaller
              border: Border.all(color: stroke, width: 2.0), // Back to original
              boxShadow: [
                BoxShadow(
                  color: stroke.withOpacity(0.18),
                  blurRadius: 10, // Back to original
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Smaller profile picture as requested
                Container(
                  width: 80, // Made smaller from 110
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: stroke,
                      width: 1.5,
                    ), // Thinner border
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? Image.network(avatarUrl!, fit: BoxFit.cover)
                      : Center(
                          child: Icon(
                            Icons.person,
                            size: 42,
                            color: const Color(0xFF8E4A1E),
                          ), // Smaller icon
                        ),
                ),
                const SizedBox(width: 16), // Slightly reduced

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NAME: ',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 15, // Slightly reduced from 16
                            height: 1.0,
                            letterSpacing: 0.4,
                            color: const Color(0xFF3B2717),
                          ),
                        ),
                        const SizedBox(height: 3), // Slightly reduced
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w900,
                            fontSize: 24, // Slightly reduced from 26
                            height: 1.05,
                            letterSpacing: 0.1,
                            color: const Color(0xFF23160E),
                          ),
                        ),
                        const SizedBox(height: 6), // Slightly reduced
                        _kv(
                          'EMAIL:',
                          email,
                          size: 15,
                        ), // Slightly reduced from 16
                        const SizedBox(height: 3), // Slightly reduced
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Decorative plus icons (slightly smaller)
          Positioned(
            right: 20,
            top: 10,
            child: Icon(Icons.add, size: 32, color: plusTint), // Smaller
          ),
          const Positioned(
            right: 30,
            top: 20,
            child: Icon(Icons.add, size: 18, color: plusTint), // Smaller
          ),
          const Positioned(
            right: 50,
            bottom: 12,
            child: Icon(Icons.add, size: 26, color: plusTint), // Smaller
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {double size = 15}) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: size,
              height: 1.05,
              color: const Color(0xFF3B2717),
            ),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              fontSize: size,
              height: 1.05,
              color: const Color(0xFF3B2717),
            ),
          ),
        ],
      ),
    );
  }
}

// =============== Assisted Task Tile (slightly smaller) ===============
class _AssistedTaskTile extends StatelessWidget {
  const _AssistedTaskTile({
    super.key,
    required this.title,
    required this.time,
    required this.note,
    required this.guardian,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final String time;
  final String note;
  final String guardian;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18), // Slightly reduced
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline with slightly smaller dot
            Column(
              children: [
                Container(
                  width: 16, // Slightly reduced from 18
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF77CA0),
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ), // Slightly thinner
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: Colors.grey.shade300,
                  ), // Slightly thinner
                ),
              ],
            ),
            const SizedBox(width: 14), // Slightly reduced

            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  20,
                ), // Slightly reduced
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD8F1FF), Color(0xFFBEE6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18), // Slightly smaller
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.07,
                      ), // Slightly less prominent
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
                          scale: 1.3, // Slightly reduced from 1.4
                          child: Checkbox(
                            value: checked,
                            onChanged: onChanged,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                4,
                              ), // Back to original
                            ),
                          ),
                        ),
                        const SizedBox(width: 10), // Slightly reduced
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              fontSize: 20, // Slightly reduced from 22
                              letterSpacing: 0.4,
                              color: const Color(0xFF1E2A36),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10), // Slightly reduced

                    _infoLine(
                      label: 'TIME',
                      value: time,
                      size: 16,
                    ), // Slightly reduced from 17
                    if (note.isNotEmpty)
                      _infoLine(label: 'NOTE', value: note, size: 16),
                    _infoLine(label: 'GUARDIAN', value: guardian, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine({
    required String label,
    required String value,
    double size = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 5), // Slightly reduced
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.nunito(
              color: const Color(0xFF2D2D2D),
              fontWeight: FontWeight.w800,
              fontSize: size,
              height: 1.25, // Slightly reduced
              letterSpacing: 0.2,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                color: const Color(0xFF2D2D2D),
                fontWeight: FontWeight.w600,
                fontSize: size,
                height: 1.25, // Slightly reduced
              ),
            ),
          ),
        ],
      ),
    );
  }
}


