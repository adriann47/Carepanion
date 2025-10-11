import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'emergency_alert_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your reusable navbar

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  // ignore: unused_field
  int _currentIndex = 2; // Start on Alert tab
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Fill duration = 3 seconds
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

  // ignore: unused_element
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
    _controller.forward(from: 0.0); // Start filling
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_controller.value < 1.0) {
      // Released too early → reset
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
      _controller.reset(); // Reset when returning
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

      /// ✅ Use custom navbar
       bottomNavigationBar: const NavbarAssisted(currentIndex: 2),
    );
  }
}
