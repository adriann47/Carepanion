import 'package:flutter/material.dart';
import 'tasks_screen_regular.dart'; // For Home (example)
import 'calendar_screen_regular.dart'; // For Menu (example)
import 'companion_list.dart'; // For Companions tab (example)
import 'profile_screen_regular.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.notifications});
  final List<Map<String, dynamic>> notifications;

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
      // Fix: Pass notifications from parent via ModalRoute
      final notifications = ModalRoute.of(context)?.settings.arguments as List<Map<String, dynamic>>?;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NotificationScreen(
            notifications: notifications ?? [],
          ),
        ),
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
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // ✅ Removes the back button
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "NOTIFICATIONS",
                style: TextStyle(
                  color: Colors.pink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              if (widget.notifications.isEmpty)
                const Text("No notifications yet."),
              for (final notif in widget.notifications)
                Container(
                  width: double.infinity,
                  height: 110,
                  margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[100],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 10),
                      notif['avatarUrl'] != null
                        ? CircleAvatar(
                            radius: 36,
                            backgroundImage: NetworkImage(notif['avatarUrl']),
                          )
                        : CircleAvatar(
                            radius: 36,
                            child: Icon(
                              notif['isDone'] ? Icons.check_circle : Icons.cancel,
                              color: notif['isDone'] ? Colors.green : Colors.red,
                              size: 36,
                            ),
                            backgroundColor: Colors.white,
                          ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              notif['user'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  notif['isDone'] ? Icons.check_circle : Icons.cancel,
                                  color: notif['isDone'] ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  notif['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['time'] != null
                                ? TimeOfDay.fromDateTime(DateTime.parse(notif['time']).toLocal()).format(context)
                                : '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
