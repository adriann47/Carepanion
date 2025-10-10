import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'emergency_screen.dart';
import 'profile_screen.dart';

class NavbarAssisted extends StatelessWidget {
  final int currentIndex;

  const NavbarAssisted({super.key, required this.currentIndex});

  void _onTabTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget nextScreen;
    switch (index) {
      case 0:
        nextScreen = const TasksScreen();
        break;
      case 1:
        nextScreen = const CalendarScreen();
        break;
      case 2:
        nextScreen = const EmergencyScreen();
        break;
      case 3:
        nextScreen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.pink,
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      onTap: (index) => _onTabTapped(context, index),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        _navItem(Icons.home, 'Home', isSelected: currentIndex == 0),
        _navItem(Icons.calendar_today, 'Menu', isSelected: currentIndex == 1),
        _navItem(Icons.warning_amber_rounded, 'Alert', isSelected: currentIndex == 2),
        _navItem(Icons.person, 'Profile', isSelected: currentIndex == 3),
      ],
    );
  }

  static BottomNavigationBarItem _navItem(
      IconData icon, String label, {bool isSelected = false}) {
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
