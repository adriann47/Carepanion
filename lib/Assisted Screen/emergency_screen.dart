import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'emergency_alert_screen.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 2; // Start on Alert tab

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // fill duration = 3 seconds
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerEmergency();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasksScreen()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CalendarScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _controller.forward(from: 0.0); // start filling
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_controller.value < 1.0) {
      // released too early → reset
      _controller.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hold for at least 3 seconds")),
      );
    }
  }

  void _triggerEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencyAlertScreen()),
    ).then((_) {
      _controller.reset(); // reset when returning
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Red fill animated from bottom to top
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: screenHeight * _controller.value,
                  color: Colors.redAccent,
                );
              },
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "EMERGENCY BUTTON",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Long press for 3 seconds to trigger\n"
                    "the emergency button.",
                    style: TextStyle(fontSize: 17, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                    child: Image.asset(
                      "assets/emergency.png",
                      width: 320,
                      height: 320,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

       /// --- CUSTOM NAV BAR ---
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
          _navItem(Icons.warning_amber_rounded, 'Alert',
              isSelected: _currentIndex == 2),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 3),
        ],
      ),
    );
  }

  /// --- NAV ITEM WITH HIGHLIGHT ---
  static BottomNavigationBarItem _navItem(IconData icon, String label,
      {required bool isSelected}) {
    return BottomNavigationBarItem(
      label: label,
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 32,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }
}