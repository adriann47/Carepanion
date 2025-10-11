import 'package:flutter/material.dart';
import 'profile_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
import 'notification_screen.dart'; // 👈 Import your notification screen
import 'package:softeng/services/task_service.dart';
import 'edit_task.dart';

class TasksScreenRegular extends StatefulWidget {
  const TasksScreenRegular({super.key});

  @override
  State<TasksScreenRegular> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreenRegular> {
  int _currentIndex = 0;

  /// --- NAVIGATION HANDLER ---
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreenRegular()),
      );
    } else if (index == 2) {
      // 👇 Redirect to Companion screen instead of Emergency
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CompanionListScreen()),
      );
    } else if (index == 3) {
      // 👇 Redirect to Notification screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationScreen()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// --- USER CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA94D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "USER ID: SHAWN CABUTIHAN",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "EMAIL: URIEL.SHAWN@GMAIL.COM",
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            "NUMBER: 09541234567",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// --- STREAK CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "3 DAYS STREAK!",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Thanks for showing up today! Consistency is the key to forming strong habits.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// --- TODAY'S TASK TITLE ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "TODAY’S TASK",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),

              const SizedBox(height: 16),

              /// --- TASK LIST (Today from Supabase) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: TaskService.getTasksForDate(DateTime.now()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
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
                    final tasks = snapshot.data ?? [];
                    if (tasks.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No tasks for today'),
                      );
                    }

                    return Column(
                      children: [
                        for (final t in tasks)
                          _taskTileDynamic(
                            task: t,
                            onEdited: () => setState(() {}),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      /// --- NAV BAR ---
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
          _navItem(Icons.family_restroom, 'Companion',
              isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications',
              isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  /// --- TASK TILE ---
  Widget _taskTileDynamic({
    required Map<String, dynamic> task,
    required VoidCallback onEdited,
  }) {
    final title = (task['title'] ?? '').toString();
    final note = (task['description'] ?? '').toString();
    String time = '';
    try {
      String fmt(dynamic iso) {
        if (iso == null) return '';
        final dt = DateTime.parse(iso.toString()).toLocal();
        return TimeOfDay(hour: dt.hour, minute: dt.minute).format(context);
      }
      final s = fmt(task['start_at']);
      final e = fmt(task['end_at']);
      time = s.isEmpty && e.isEmpty ? 'All day' : (s.isNotEmpty && e.isNotEmpty ? '$s - $e' : (s + e));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pinkAccent,
                ),
              ),
              Container(
                width: 2,
                height: 80,
                color: Colors.grey,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.2,
                        child: const Icon(Icons.event_note),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTaskScreen(task: task),
                            ),
                          );
                          if (changed == true) onEdited();
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Time: $time", style: const TextStyle(fontSize: 14)),
                  if (note.isNotEmpty)
                    Text("Note: $note", style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --- NAV ITEM ---
  static BottomNavigationBarItem _navItem(IconData icon, String label,
      {required bool isSelected}) {
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
