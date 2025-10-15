import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/navigation.dart';
import '../data/profile_service.dart';

class ReminderService {
  ReminderService._();
  static Timer? _timer;
  static final FlutterTts _tts = FlutterTts();
  static bool _popupActive = false;
  static String? _today; // yyyy-MM-dd
  static final Set<String> _alerted = {};
  static String? _guardianFullNameCache;
  static String? _guardianCacheForUserId;

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  static bool get isRunning => _timer != null;

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _tick() async {
    if (_popupActive) return; // one at a time
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    if (_today != today) {
      _today = today;
      _alerted.clear();
    }
    final nowStr = DateFormat('HH:mm:ss').format(now);

    // Cache guardian full name for the current user (assisted) if available
    if (_guardianCacheForUserId != user.id || _guardianFullNameCache == null) {
      try {
        final me = await ProfileService.fetchProfile(client);
        final guardianId = (me?['guardian_id'] as String?)?.trim();
        String? gName;
        if (guardianId != null && guardianId.isNotEmpty) {
          final g = await ProfileService.fetchProfile(client, userId: guardianId);
          final gn = (g?['fullname'] as String?)?.trim();
          if (gn != null && gn.isNotEmpty) gName = gn;
        }
        _guardianFullNameCache = gName;
        _guardianCacheForUserId = user.id;
      } catch (_) {}
    }

    // Fetch today's tasks for the signed-in user (only tasks assigned to them).
    List<dynamic> rows;
    try {
      rows = await client
          .from('tasks')
          .select('id,title,description,start_at,end_at,due_date,status,user_id')
          .eq('due_date', today)
          .eq('user_id', user.id)
          .limit(200);
    } catch (_) {
      return;
    }

    for (final r in rows) {
      final id = r['id'].toString();
      final key = '${id}_$today';
      if (_alerted.contains(key)) continue;

      final startAt = r['start_at'];
      if (startAt == null) continue;
      DateTime dt;
      try {
        dt = DateTime.parse(startAt.toString()).toLocal();
      } catch (_) {
        continue;
      }
      final match = DateFormat('HH:mm:ss').format(dt) == nowStr;
      if (!match) continue;

      _alerted.add(key);
      _popupActive = true;

      final title = (r['title'] ?? 'Task').toString();
      final note = (r['description'] ?? '').toString();
      try {
        if (!kIsWeb) {
          await _tts.speak('Reminder: $title. ${note.isNotEmpty ? note : ""}');
        }
      } catch (_) {}

      final navigatorState = navKey.currentState;
      final ctx = navigatorState?.overlay?.context;
      if (navigatorState == null || ctx == null) {
        _popupActive = false;
        return;
      }

      // Try to resolve the creator name for the popup (created_by_name > created_by profile > cached guardian)
      String? popupGuardianName = _guardianFullNameCache;
      try {
        final detail = await client
            .from('tasks')
            .select('created_by_name, created_by')
            .eq('id', id)
            .maybeSingle();
        final n = (detail?['created_by_name'] ?? '').toString().trim();
        if (n.isNotEmpty) {
          popupGuardianName = n;
        } else {
          final createdBy = (detail?['created_by'] ?? '').toString().trim();
          if (createdBy.isNotEmpty) {
            try {
              final p = await ProfileService.fetchProfile(client, userId: createdBy);
              final fn = (p?['fullname'] ?? '').toString().trim();
              if (fn.isNotEmpty) popupGuardianName = fn;
            } catch (_) {}
          }
        }
      } catch (_) {
        // Column may not exist or RLS may block read; fall back to cached guardian
      }

      // Show dialog immediately using the current overlay context
      // ignore: use_build_context_synchronously
      await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => _ReminderDialog(
          task: r as Map<String, dynamic>,
          guardianFullName: popupGuardianName,
          onSkip: () async {
            try {
              await client.from('tasks').update({'status': 'skipped'}).eq('id', id);
            } catch (_) {}
          },
          onDone: () async {
            try {
              await client.from('tasks').update({'status': 'done'}).eq('id', id);
            } catch (_) {}
          },
        ),
      );

      _popupActive = false;
      break; // one popup per tick
    }
  }
}

class _ReminderDialog extends StatelessWidget {
  const _ReminderDialog({required this.task, required this.onSkip, required this.onDone, this.guardianFullName});
  final Map<String, dynamic> task;
  final VoidCallback onSkip;
  final VoidCallback onDone;
  final String? guardianFullName;

  @override
  Widget build(BuildContext context) {
    final title = (task['title'] ?? '').toString().toUpperCase();
    final note = (task['description'] ?? '').toString();
    // Prefer task's own created_by_name if present; else use provided guardianFullName; else fallback field
    String guardian = '';
    final createdByName = (task['created_by_name'] ?? '').toString().trim();
    if (createdByName.isNotEmpty) {
      guardian = createdByName;
    } else if ((guardianFullName ?? '').trim().isNotEmpty) {
      guardian = guardianFullName!.trim();
    } else {
      guardian = (task['guardian_name'] ?? '').toString();
    }

    String fmt(dynamic iso) {
      if (iso == null) return '';
      try {
        final dt = DateTime.parse(iso.toString()).toLocal();
        return TimeOfDay(hour: dt.hour, minute: dt.minute).format(context);
      } catch (_) {
        return '';
      }
    }
    final s = fmt(task['start_at']);
    final e = fmt(task['end_at']);
    final time = s.isEmpty && e.isEmpty
        ? 'All day'
        : (s.isNotEmpty && e.isNotEmpty ? '$s - $e' : (s + e));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ACTIVITY ALERT',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Time: $time', style: GoogleFonts.nunito(fontSize: 14)),
                    if (note.isNotEmpty)
                      Text('Note: $note', style: GoogleFonts.nunito(fontSize: 14)),
                    if (guardian.isNotEmpty)
                      Text('Guardian: $guardian', style: GoogleFonts.nunito(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF77CA0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      onSkip();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7DECF7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      onDone();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'DONE',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
