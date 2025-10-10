import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';
import 'calendar_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import reusable navbar

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreen();
}

class _TasksScreen extends State<TasksScreen> {
  int _currentIndex = 0; // Home tab
  final List<bool> _taskDone = [true, false, false]; // initial checkboxes

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
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.brown,
                      child: Icon(Icons.person, size: 45, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "USER ID:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "SHAWN CABUTIHAN",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "EMAIL: URIELSHAWN@GMAIL.COM",
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            "NUMBER: 09541234567",
                            style: TextStyle(fontSize: 16),
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
                  children: [
                    _taskTile(
                      index: 0,
                      color: const Color(0xFFFFD6D6),
                      title: "MEDICATION",
                      time: "7:00 AM",
                      note: "Drink Glipten",
                      guardian: "Neriah Villapana",
                    ),
                    _taskTile(
                      index: 1,
                      color: const Color(0xFFFFE699),
                      title: "WALK",
                      time: "7:15 AM",
                      note: "Walk for 5 mins",
                      guardian: "Neriah Villapana",
                    ),
                    _taskTile(
                      index: 2,
                      color: const Color(0xFFFFD6D6),
                      title: "MEDICATION",
                      time: "7:30 AM",
                      note: "Drink Zykast",
                      guardian: "Neriah Villapana",
                    ),
                  ],
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
              Container(
                width: 3,
                height: 120,
                color: Colors.grey.shade400,
              ),
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
                          value: _taskDone[index],
                          onChanged: (val) {
                            setState(() => _taskDone[index] = val ?? false);
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
                  Text(" Guardian: $guardian",
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
