import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:softeng/services/task_service.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';
import 'calendar_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import reusable navbar
// Global ReminderService handles popups across screens; no local timer here.
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreen();
}

class _TasksScreen extends State<TasksScreen> {
  // ignore: unused_field
  int _currentIndex = 0; // Home tab
  final List<bool> _taskDone = []; // tracked per loaded task
  String? _avatarUrl;
  String? _fullName;
  String? _email;
  String? _guardianFullName;
  List<Map<String, dynamic>> _tasks = [];
  RealtimeChannel? _profileChannel;


  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTodayTasks();
    _subscribeProfileChanges();
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
        _email = authUser?.email ?? (data?['email'] as String?) ?? '—';
      });

      // Fetch linked guardian's full name if present
      final guardianId = (data?['guardian_id'] as String?)?.trim();
      if (guardianId != null && guardianId.isNotEmpty) {
        try {
          final g = await ProfileService.fetchProfile(client, userId: guardianId);
          if (!mounted) return;
          final gName = (g?['fullname'] as String?)?.trim();
          if (gName != null && gName.isNotEmpty) {
            setState(() {
              _guardianFullName = gName;
            });
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
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadTodayTasks() async {
    try {
      final today = DateTime.now();
      final tasks = await TaskService.getTasksForDate(today);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _taskDone.clear();
        _taskDone.addAll(
          _tasks.map((t) => (t['status']?.toString() == 'done')),
        );
      });
    } catch (e) {
      // ignore errors silently for now
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),

              /// --- USER ID CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB6B6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.brown,
                      backgroundImage: _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 45,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "USER ID:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _fullName ?? '—',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "EMAIL: ${_email ?? '—'}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Divider(thickness: 1),

              /// --- TODAY'S TASK TITLE ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  "TODAY’S TASK",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              /// --- TASK LIST ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _tasks.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No tasks for today',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ]
                      : List.generate(_tasks.length, (i) {
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
                          // 2) If missing, and we have a creator id, resolve it (best-effort cache-less)
                          if (guardian.isEmpty) {
                            final createdBy = t['created_by']?.toString();
                            if (createdBy != null && createdBy.isNotEmpty) {
                              // Best-effort fetch; not awaited per item to avoid rebuild jank.
                              ProfileService.fetchProfile(Supabase.instance.client, userId: createdBy)
                                  .then((p) {
                                if (!mounted || p == null) return;
                                final name = (p['fullname'] ?? '')
                                    .toString()
                                    .trim();
                                if (name.isNotEmpty) {
                                  setState(() {
                                    // Update task map locally so subsequent builds show the name
                                    _tasks[i]['created_by_name'] = name;
                                  });
                                }
                              }).catchError((_) {});
                            }
                          }
                          // 3) As final fallback, show linked guardian of assisted (legacy single guardian)
                          if (guardian.isEmpty) {
                            guardian = (_guardianFullName ??
                                    (t['guardian_name'] ?? t['created_by_name'] ?? ''))
                                .toString()
                                .trim();
                          }
                          final color = i % 2 == 0
                              ? const Color(0xFFFFD6D6)
                              : const Color(0xFFFFE699);
                          return _taskTile(
                            index: i,
                            color: color,
                            title: title,
                            time: timeStr,
                            note: note,
                            guardian: guardian,
                            taskId: t['id'] as int?,
                          );
                        }),
                ),
              ),
            ],
          ),
        ),
      ),

      /// ✅ Reusable navigation bar
      /// ✅ Custom reusable navigation bar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 0),
    );
  }

  /// --- TASK TILE ---
  Widget _taskTile({
    required int index,
    required Color color,
    required String title,
    required String time,
    required String note,
    required String guardian,
    int? taskId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Timeline dot + line
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == 1 ? Colors.amber : Colors.pinkAccent,
                ),
              ),
              Container(width: 3, height: 120, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(width: 20),

          /// Task card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.6,
                        child: Checkbox(
                          value: index < _taskDone.length
                              ? _taskDone[index]
                              : false,
                          onChanged: (val) async {
                            final newVal = val ?? false;
                            if (index < _taskDone.length) {
                              setState(() => _taskDone[index] = newVal);
                            }
                            if (taskId != null) {
                              try {
                                if (newVal) {
                                  await TaskService.markDone(taskId);
                                } else {
                                  await TaskService.markTodo(taskId);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to update task status'),
                                    ),
                                  );
                                }
                              }
                              await _loadTodayTasks();
                            }
                          },
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(" Time: $time", style: const TextStyle(fontSize: 18)),
                  Text(" Note: $note", style: const TextStyle(fontSize: 18)),
                  Text(
                    " Guardian: ${guardian.isNotEmpty ? guardian : 'Unknown'}",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
