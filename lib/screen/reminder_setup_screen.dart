import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/device_permissions.dart';
import '../services/notification_service.dart';

class ReminderSetupScreen extends StatefulWidget {
  const ReminderSetupScreen({super.key});

  @override
  State<ReminderSetupScreen> createState() => _ReminderSetupScreenState();
}

class _ReminderSetupScreenState extends State<ReminderSetupScreen> {
  bool? _notifs;
  bool? _exactAlarms;
  bool? _batteryOk;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final notifs = await DevicePermissions.areNotificationsEnabled();
    final exact = await DevicePermissions.isExactAlarmAllowed();
    final battery = await DevicePermissions.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notifs = notifs;
      _exactAlarms = exact;
      _batteryOk = battery;
      _busy = false;
    });
  }

  Future<void> _testReminder() async {
    final now = DateTime.now();
    final when = now.add(const Duration(seconds: 30));
    final id = now.millisecondsSinceEpoch % 100000000; // reasonably unique
    try {
      await NotificationService.init();
      await NotificationService.scheduleAt(
        id: id,
        whenLocal: when,
        title: 'Test Reminder',
        body: 'This is a background alarm test. If you hear this, it works.',
        payload: '{"type":"test_reminder"}',
      );
      if (!mounted) return;
      final timeStr = TimeOfDay.fromDateTime(when).format(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled test reminder at $timeStr (in ~30s). You can press Home/lock the screen.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule test reminder: $e')),
      );
    }
  }

  Widget _tile({
    required String label,
    required bool? ok,
    required VoidCallback onFix,
  }) {
    final state = ok == null ? 'Checking…' : (ok ? 'Enabled' : 'Needs action');
    final color = ok == null ? Colors.grey : (ok ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                Text(state, style: GoogleFonts.nunito(color: Colors.black54)),
              ],
            ),
          ),
          if (ok == false)
            ElevatedButton(onPressed: onFix, child: const Text('Fix')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      appBar: AppBar(
        title: const Text('Enable Reminders'),
        actions: [
          IconButton(
            tooltip: 'Test 30s',
            icon: const Icon(Icons.alarm),
            onPressed: _busy ? null : _testReminder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _tile(
                label: 'Notifications permission',
                ok: _notifs,
                onFix: () async {
                  await DevicePermissions.openNotificationSettings();
                },
              ),
              const SizedBox(height: 12),
              _tile(
                label: 'Exact alarms (Alarms & reminders)',
                ok: _exactAlarms,
                onFix: () async {
                  await DevicePermissions.requestExactAlarmPermissionIfNeeded();
                },
              ),
              const SizedBox(height: 12),
              _tile(
                label: 'Ignore battery optimizations',
                ok: _batteryOk,
                onFix: () async {
                  await DevicePermissions.requestIgnoreBatteryOptimizations();
                  // If still not enabled, open the full settings page as fallback
                  await Future.delayed(const Duration(milliseconds: 300));
                  final ok =
                      await DevicePermissions.isIgnoringBatteryOptimizations();
                  if (!ok) {
                    await DevicePermissions.openIgnoreBatteryOptimizationSettings();
                  }
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _busy ? null : _refresh,
                    child: const Text('Recheck'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'After fixing, tap Recheck',
                    style: GoogleFonts.nunito(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.alarm),
                  onPressed: _busy ? null : _testReminder,
                  label: const Text('Test reminder in 30 seconds'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
