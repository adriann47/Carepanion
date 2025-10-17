import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
import 'profile_screen_regular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/services/guardian_notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.notifications});
  final List<Map<String, dynamic>>? notifications;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _currentIndex = 3; // Notifications tab selected

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TasksScreenRegular()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreenRegular()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CompanionListScreen()),
      );
    } else if (index == 3) {
      // Already on notifications
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    final baseStream = supabase.from('task_notifications').stream(primaryKey: ['id']);
    final stream = uid != null ? baseStream.eq('guardian_id', uid) : baseStream;

    final titleTextStyle = GoogleFonts.nunito(
      color: Colors.pink,
      fontSize: 26,
      fontWeight: FontWeight.w800,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () async {
                await GuardianNotificationService.markAllReadForGuardian(uid);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('NOTIFICATIONS', style: titleTextStyle),
            const SizedBox(height: 16),
            Expanded(
              child: widget.notifications != null
                  ? _ListView(notifications: widget.notifications!)
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final items = (snapshot.data ?? const [])
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList();
                        items.sort((a, b) {
                          final ta = DateTime.tryParse((a['action_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final tb = DateTime.tryParse((b['action_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return tb.compareTo(ta);
                        });
                        if (items.isEmpty) {
                          return const Center(child: Text('No notifications yet.'));
                        }
                        return _ListView(notifications: items);
                      },
                    ),
            ),
          ],
        ),
      ),

      // --- ✅ Bottom Navigation Bar ---
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
          _navItem(Icons.family_restroom, 'Companions', isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications', isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  // --- Reusable Nav Item Widget ---
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

class _ListView extends StatelessWidget {
  const _ListView({required this.notifications});
  final List<Map<String, dynamic>> notifications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final n = notifications[i];
        final isDone = (n['action'] ?? '') == 'done' || (n['isDone'] == true);
        final title = (n['title'] ?? 'Task').toString();
        final at = DateTime.tryParse((n['action_at'] ?? n['time'] ?? '').toString())?.toLocal();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.lightBlue[100],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(
                  isDone ? Icons.check_circle : Icons.cancel,
                  color: isDone ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      at != null ? TimeOfDay.fromDateTime(at).format(ctx) : '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}





