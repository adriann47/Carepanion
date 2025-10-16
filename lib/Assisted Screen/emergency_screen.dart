import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'emergency_alert_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your reusable navbar
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:softeng/data/multi_guardian_service.dart';
// removed db wiring to revert to previous behavior

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

  void _triggerEmergency() async {
    _createEmergencyAlert();
    // Resolve assisted name for display
    String assistedName = '';
    try {
      final me = await ProfileService.fetchProfile(Supabase.instance.client);
      assistedName = (me?['fullname'] ?? '').toString().trim();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyAlertScreen(
          assistedName: assistedName,
          isGuardianView: false,
        ),
      ),
    );
    if (!mounted) return;
    _controller.reset(); // Reset when returning
  }

  Future<void> _createEmergencyAlert() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final assistedId = user.id;

      // Resolve all guardians for this assisted (join table + legacy fallback)
      final Set<String> guardianIds = await MultiGuardianService.listGuardianIds(
        client,
        assistedUserId: assistedId,
      );

      if (guardianIds.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No guardian linked. Guardian will not be notified.')),
        );
      }

      // Insert one alert row per guardian, including assisted_id when available
      int successCount = 0;
      final int attempts = guardianIds.length;
      bool assistedIdSupported = true; // assume column exists until proven otherwise
      for (final gid in guardianIds) {
        final basePayload = <String, dynamic>{
          'guardian_id': gid,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'active',
        };

        if (assistedIdSupported) {
          try {
            await client.from('emergency_alerts').insert({
              ...basePayload,
              'assisted_id': assistedId,
            });
            successCount++;
            continue; // success with assisted_id
          } catch (e) {
            final msg = e.toString().toLowerCase();
            final missingAssisted = msg.contains('assisted_id') && (msg.contains('column') || msg.contains('does not exist'));
            if (!missingAssisted) rethrow;
            assistedIdSupported = false; // fallback for subsequent inserts
          }
        }
        // Fallback insert without assisted_id (older schema)
        try {
          await client.from('emergency_alerts').insert(basePayload);
          successCount++;
        } catch (_) {
          // ignore individual insert failures
        }
      }

      // Inform the assisted how many guardians were notified
      if (mounted && attempts > 0) {
        final msg = (successCount == attempts)
            ? 'Emergency sent to $successCount guardian${successCount == 1 ? '' : 's'}'
            : 'Emergency sent to $successCount of $attempts guardians';
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (_) {
      // Non-blocking; UI flow proceeds regardless
    }
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
