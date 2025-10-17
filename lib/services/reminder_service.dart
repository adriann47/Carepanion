import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/navigation.dart';
import '../data/profile_service.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';
import 'streak_service.dart';
import 'guardian_notification_service.dart';

class ReminderService {
  ReminderService._();
  static Timer? _timer;
  static final FlutterTts _tts = FlutterTts();
  static bool _popupActive = false;
  static String? _today; // yyyy-MM-dd
  static final Set<String> _alerted = {};
  static String? _guardianFullNameCache;
  static String? _guardianCacheForUserId;
  static bool _scheduledForToday = false;
  static RealtimeChannel? _taskChannel;

  static int _notifIdFor(DateTime dt) => dt.millisecondsSinceEpoch % 2147483647;

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _setupRealtime();
    // Try to sync any locally queued task outcome notifications
    // (offline submissions) as soon as service starts.
    // ignore: discarded_futures
    GuardianNotificationService.syncQueuedOutcomes();
  }

  static bool get isRunning => _timer != null;

  static void stop() {
    _timer?.cancel();
    _timer = null;
    if (_taskChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_taskChannel!);
      } catch (_) {}
      _taskChannel = null;
    }
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
      _scheduledForToday = false;
    }
    final nowStr = DateFormat('HH:mm:ss').format(now);

    // Determine role once per user and cache guardian full name for assisted
    if (_guardianCacheForUserId != user.id || _guardianFullNameCache == null) {
      try {
        final me = await ProfileService.fetchProfile(client);
        final guardianId = (me?['guardian_id'] as String?)?.trim();
        String? gName;
        if (guardianId != null && guardianId.isNotEmpty) {
          final g = await ProfileService.fetchProfile(
            client,
            userId: guardianId,
          );
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
          .select(
            'id,title,description,start_at,end_at,due_date,status,user_id',
          )
          .eq('due_date', today)
          .eq('user_id', user.id)
          .limit(200);
    } catch (_) {
      return;
    }

    // Ensure today's upcoming tasks are scheduled for background notification delivery
    if (!_scheduledForToday) {
      for (final r in rows) {
        final startAt = r['start_at'];
        if (startAt == null) continue;
        DateTime dt;
        try {
          dt = DateTime.parse(startAt.toString()).toLocal();
        } catch (_) {
          continue;
        }
        // Skip past times
        if (dt.isBefore(DateTime.now())) continue;
        final title = (r['title'] ?? 'Task').toString();
        final note = (r['description'] ?? '').toString();
        final nid = _notifIdFor(dt);
        await NotificationService.scheduleAt(
          id: nid,
          whenLocal: dt,
          title: 'Task Reminder: $title',
          body: note.isNotEmpty ? note : "It's time to do this task.",
          payload: '{"task_id":"${r['id']}"}',
        );
      }
      _scheduledForToday = true;
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
      final match = dt.isAfter(now.subtract(const Duration(seconds: 1))) && dt.isBefore(now.add(const Duration(seconds: 1)));
      if (!match) continue;

      _alerted.add(key);

      final title = (r['title'] ?? 'Task').toString();
      final note = (r['description'] ?? '').toString();
      // Speak if enabled (log errors so we can diagnose when speech fails)
      try {
        if (!kIsWeb && NotificationPreferences.ttsEnabled.value) {
          if (kDebugMode) {
            // Indicate in logs that we are about to speak
            // ignore: avoid_print
            print(
              'ReminderService: speaking TTS for task id=${r['id']} title="$title"',
            );
          }
          try {
            await _tts.awaitSpeakCompletion(true);
          } catch (_) {}
          await _tts.speak('Reminder: $title. ${note.isNotEmpty ? note : ""}');
          if (kDebugMode) {
            // ignore: avoid_print
            print('ReminderService: TTS complete for task id=${r['id']}');
          }
        }
      } catch (e, st) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('ReminderService: TTS failed for task id=${r['id']}: $e');
          // ignore: avoid_print
          print(st);
        }
      }

      // If app is not in foreground or we can't get a context, show a push notification instead of popup
      final navigatorState = navKey.currentState;
      final ctx = navigatorState?.overlay?.context;
      if (navigatorState == null || ctx == null) {
        await NotificationService.showNow(
          id: _notifIdFor(dt),
          title: 'Task Reminder: $title',
          body: note.isNotEmpty ? note : 'It\'s time to do this task.',
          payload: '{"task_id":"$id"}',
        );
        continue;
      }

      // Popup path
      _popupActive = true;

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
              final p = await ProfileService.fetchProfile(
                client,
                userId: createdBy,
              );
              final fn = (p?['fullname'] ?? '').toString().trim();
              if (fn.isNotEmpty) popupGuardianName = fn;
            } catch (_) {}
          }
        }
      } catch (_) {
        // Column may not exist or RLS may block read; fall back to cached guardian
      }

      // Resolve role to hide Guardian line for Regular users
      bool isRegularUser = false;
      try {
        final role = await ProfileService.getCurrentUserRole(client);
        isRegularUser = ((role ?? '').toLowerCase() == 'regular');
      } catch (_) {}

      // Show dialog immediately using the current overlay context
      // ignore: use_build_context_synchronously
      await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => _ReminderDialog(
          task: r as Map<String, dynamic>,
          guardianFullName: popupGuardianName,
          showGuardian: !isRegularUser,

          onSkip: () async {
            try {
              await client
                  .from('tasks')
                  .update({'status': 'skip'})
                  .eq('id', id);
              // Cancel scheduled notification if any
              final sa = r['start_at'];
              if (sa != null) {
                try {
                  final dt = DateTime.parse(sa.toString()).toLocal();
                  await NotificationService.cancel(_notifIdFor(dt));
                } catch (_) {}
              }
              try {
                await GuardianNotificationService.recordTaskOutcome(
                  taskId: id,
                  assistedId: (r['user_id'] ?? '').toString(),
                  title: (r['title'] ?? 'Task').toString(),
                  scheduledAt: sa != null ? DateTime.tryParse(sa.toString()) : null,
                  action: 'skipped',
                  actionAt: DateTime.now().toUtc(),
                );
              } catch (_) {}
            } catch (_) {}
          },
          onDone: () async {
            try {
              await client
                  .from('tasks')
                  .update({'status': 'done'})
                  .eq('id', id);
              // Cancel scheduled notification if any
              final sa = r['start_at'];
              if (sa != null) {
                try {
                  final dt = DateTime.parse(sa.toString()).toLocal();
                  await NotificationService.cancel(_notifIdFor(dt));
                } catch (_) {}
              }
              // Recompute global streak immediately
              try { await StreakService.refresh(); } catch (_) {}
              try {
                await GuardianNotificationService.recordTaskOutcome(
                  taskId: id,
                  assistedId: (r['user_id'] ?? '').toString(),
                  title: (r['title'] ?? 'Task').toString(),
                  scheduledAt: sa != null ? DateTime.tryParse(sa.toString()) : null,
                  action: 'done',
                  actionAt: DateTime.now().toUtc(),
                );
              } catch (_) {}
            } catch (_) {}
          },
        ),
      );

      _popupActive = false;
      break; // one popup per tick
    }
  }

  // Exposed for notification tap to recreate the popup when user opens from push
  static Future<void> showPopupForTaskId(String taskId) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ReminderService.showPopupForTaskId called with taskId=$taskId');
    }
    final client = Supabase.instance.client;
    Map<String, dynamic>? r;
    try {
      final data = await client
          .from('tasks')
          .select('*')
          .eq('id', taskId)
          .maybeSingle();
      if (data != null) r = Map<String, dynamic>.from(data);
    } catch (_) {}
    if (r == null) return;

    final navigatorState = navKey.currentState;
    final ctx = navigatorState?.overlay?.context;
    if (navigatorState == null || ctx == null) return;

    // Guard: if a popup is already active or this task was already alerted today, do not show again
    if (_popupActive) return;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dupKey = '${taskId}_$todayKey';
    if (_alerted.contains(dupKey)) return;
    _alerted.add(dupKey);
    _popupActive = true;

    String? popupGuardianName;
    try {
      final detail = await client
          .from('tasks')
          .select('created_by_name, created_by')
          .eq('id', taskId)
          .maybeSingle();
      final n = (detail?['created_by_name'] ?? '').toString().trim();
      if (n.isNotEmpty) {
        popupGuardianName = n;
      } else {
        final createdBy = (detail?['created_by'] ?? '').toString().trim();
        if (createdBy.isNotEmpty) {
          try {
            final p = await ProfileService.fetchProfile(
              client,
              userId: createdBy,
            );
            final fn = (p?['fullname'] ?? '').toString().trim();
            if (fn.isNotEmpty) popupGuardianName = fn;
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Determine if guardian line should be shown for this user
    bool regularRole = false;
    try {
      final role = await ProfileService.getCurrentUserRole(client);
      regularRole = ((role ?? '').toLowerCase() == 'regular');
    } catch (_) {}

    // ignore: use_build_context_synchronously
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => _ReminderDialog(
        task: r!,
        guardianFullName: popupGuardianName,
        showGuardian: !regularRole,
        onSkip: () async {
          try {
            await client
                .from('tasks')
                .update({'status': 'skip'})
                .eq('id', taskId);
            final sa = r!['start_at'];
            if (sa != null) {
              try {
                final dt = DateTime.parse(sa.toString()).toLocal();
                await NotificationService.cancel(_notifIdFor(dt));
              } catch (_) {}
            }
            try {
              await GuardianNotificationService.recordTaskOutcome(
                taskId: taskId.toString(),
                assistedId: (r!['user_id'] ?? '').toString(),
                title: (r!['title'] ?? 'Task').toString(),
                scheduledAt: sa != null ? DateTime.tryParse(sa.toString()) : null,
                action: 'skipped',
                actionAt: DateTime.now().toUtc(),
              );
            } catch (_) {}
          } catch (_) {}
        },
        onDone: () async {
          try {
            await client
                .from('tasks')
                .update({'status': 'done'})
                .eq('id', taskId);
            final sa = r!['start_at'];
            if (sa != null) {
              try {
                final dt = DateTime.parse(sa.toString()).toLocal();
                await NotificationService.cancel(_notifIdFor(dt));
              } catch (_) {}
            }
            try { await StreakService.refresh(); } catch (_) {}
            try {
              await GuardianNotificationService.recordTaskOutcome(
                taskId: taskId.toString(),
                assistedId: (r!['user_id'] ?? '').toString(),
                title: (r!['title'] ?? 'Task').toString(),
                scheduledAt: sa != null ? DateTime.tryParse(sa.toString()) : null,
                action: 'done',
                actionAt: DateTime.now().toUtc(),
              );
            } catch (_) {}
          } catch (_) {}
        },
      ),
    );
    _popupActive = false;
  }

  static void _setupRealtime() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // If already subscribed for this user, skip
    if (_taskChannel != null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _taskChannel = client.channel('public:tasks')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'tasks',
        callback: (payload) async {
          try {
            final rec = payload.newRecord;
            if (rec['user_id']?.toString() != user.id) return;
            if (rec['due_date']?.toString() != today) return;
            final startAt = rec['start_at'];
            if (startAt == null) return;
            final dt = DateTime.parse(startAt.toString()).toLocal();
            if (dt.isBefore(DateTime.now())) return;
            final status = (rec['status'] ?? '').toString();
            if (status == 'done' || status == 'skip' || status == 'skipped') return;
            await NotificationService.scheduleAt(
              id: _notifIdFor(dt),
              whenLocal: dt,
              title: 'Task Reminder: ${rec['title'] ?? 'Task'}',
              body: (rec['description'] ?? '').toString().isNotEmpty
                  ? rec['description'].toString()
                  : "It's time to do this task.",
              payload: '{"task_id":"${rec['id']}"}',
            );
          } catch (_) {}
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'tasks',
        callback: (payload) async {
          try {
            final oldRec = payload.oldRecord;
            final newRec = payload.newRecord;
            if (newRec['user_id']?.toString() != user.id) return;
            final oldStart = oldRec['start_at'];
            if (oldStart != null) {
              final oldDt = DateTime.parse(oldStart.toString()).toLocal();
              await NotificationService.cancel(_notifIdFor(oldDt));
            }

            final status = (newRec['status'] ?? '').toString();
            if (status == 'done' || status == 'skip' || status == 'skipped') return;
            if (newRec['due_date']?.toString() != today) return;
            final startAt = newRec['start_at'];
            if (startAt == null) return;
            final dt = DateTime.parse(startAt.toString()).toLocal();
            if (dt.isBefore(DateTime.now())) return;
            await NotificationService.scheduleAt(
              id: _notifIdFor(dt),
              whenLocal: dt,
              title: 'Task Reminder: ${newRec['title'] ?? 'Task'}',
              body: (newRec['description'] ?? '').toString().isNotEmpty
                  ? newRec['description'].toString()
                  : "It's time to do this task.",
              payload: '{"task_id":"${newRec['id']}"}',
            );
          } catch (_) {}
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'tasks',
        callback: (payload) async {
          try {
            final oldRec = payload.oldRecord;
            if (oldRec['user_id']?.toString() != user.id) return;
            final startAt = oldRec['start_at'];
            if (startAt == null) return;
            final dt = DateTime.parse(startAt.toString()).toLocal();
            await NotificationService.cancel(_notifIdFor(dt));
          } catch (_) {}
        },
      )
      ..subscribe();
  }
}

class _ReminderDialog extends StatelessWidget {
  const _ReminderDialog({
    required this.task,
    required this.onSkip,
    required this.onDone,
    this.guardianFullName,
    this.showGuardian = true,
  });
  final Map<String, dynamic> task;
  final VoidCallback onSkip;
  final VoidCallback onDone;
  final String? guardianFullName;
  final bool showGuardian;

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

    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
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
                      Text(
                        'Time: $time',
                        style: GoogleFonts.nunito(fontSize: 14),
                      ),
                      if (note.isNotEmpty)
                        Text(
                          'Note: $note',
                          style: GoogleFonts.nunito(fontSize: 14),
                        ),
                      if (guardian.isNotEmpty && showGuardian)
                        Text(
                          'Guardian: $guardian',
                          style: GoogleFonts.nunito(fontSize: 14),
                        ),
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
      ),
    );
  }
}


