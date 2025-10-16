import 'package:flutter/material.dart';
import 'package:softeng/services/notification_prefs.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool pushNotification = true;
  bool audioAlerts = true;
  bool vibration = true; // ✅ renamed from hapticFeedback

  @override
  void initState() {
    super.initState();
    // Load initial values from preferences
    pushNotification = NotificationPreferences.pushEnabled.value;
    audioAlerts = NotificationPreferences.ttsEnabled.value;
    vibration = NotificationPreferences.vibrationEnabled.value;
    // Listen for external changes to keep UI in sync
    NotificationPreferences.pushEnabled.addListener(_syncFromPrefs);
    NotificationPreferences.ttsEnabled.addListener(_syncFromPrefs);
    NotificationPreferences.vibrationEnabled.addListener(_syncFromPrefs);
  }

  @override
  void dispose() {
    NotificationPreferences.pushEnabled.removeListener(_syncFromPrefs);
    NotificationPreferences.ttsEnabled.removeListener(_syncFromPrefs);
    NotificationPreferences.vibrationEnabled.removeListener(_syncFromPrefs);
    super.dispose();
  }

  void _syncFromPrefs() {
    if (!mounted) return;
    setState(() {
      pushNotification = NotificationPreferences.pushEnabled.value;
      audioAlerts = NotificationPreferences.ttsEnabled.value;
      vibration = NotificationPreferences.vibrationEnabled.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header (matching about.dart style)
            Container(
              width: double.infinity,
              height: h * 0.20,
              decoration: const BoxDecoration(
                color: Color(0xFFF7A9AC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.05,
                  vertical: h * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.arrow_back,
                        size: w * 0.07,
                        color: const Color(0xFF3D3D3D),
                      ),
                    ),
                    SizedBox(height: h * 0.01),
                    Text(
                      "NOTIFICATION",
                      style: TextStyle(
                        fontSize: w * 0.08,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3D3D3D),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Push Notification
            _buildToggleTile(
              title: "PUSH NOTIFICATION",
              value: pushNotification,
              onChanged: (val) async {
                setState(() => pushNotification = val);
                await NotificationPreferences.setPush(val);
              },
              activeColor: const Color(0xFFF7A9AC),
            ),

            const SizedBox(height: 20),

            // Audio Alerts
            _buildToggleTile(
              title: "AUDIO ALERTS",
              value: audioAlerts,
              onChanged: (val) async {
                setState(() => audioAlerts = val);
                await NotificationPreferences.setTts(val);
              },
              activeColor: const Color(0xFFF7A9AC),
            ),

            const SizedBox(height: 20),

            // 🔹 Vibration
            _buildToggleTile(
              title: "VIBRATION",
              value: vibration,
              onChanged: (val) async {
                setState(() => vibration = val);
                await NotificationPreferences.setVibration(val);
              },
              activeColor: const Color(0xFFF7A9AC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.lightBlue[200],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: activeColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
