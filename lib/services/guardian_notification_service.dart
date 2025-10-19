import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';

class GuardianNotificationService {
  GuardianNotificationService._();

  static const String _queueKey = 'task_outcome_queue_v1';

  static Future<void> recordTaskOutcome({
    required String taskId,
    required String assistedId,
    required String title,
    required DateTime? scheduledAt,
    required String action, // 'done' | 'skipped'
    DateTime? actionAt,
  }) async {
    print(
      'GuardianNotificationService.recordTaskOutcome called: taskId=$taskId, assistedId=$assistedId, action=$action',
    );
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      print('GuardianNotificationService: No authenticated user');
      return;
    }

    final act = (action.toLowerCase() == 'skip')
        ? 'skipped'
        : action.toLowerCase();
    final when = (actionAt ?? DateTime.now().toUtc());
    final whenIso = when.toIso8601String();
    final scheduledIso = scheduledAt?.toUtc().toIso8601String();

    // Determine target guardians
    List<String> guardianIds = [];
    try {
      final role = (await ProfileService.getCurrentUserRole(
        client,
      ))?.toLowerCase();
      print('GuardianNotificationService: Current user role = $role');
      if (role == 'regular') {
        guardianIds = [user.id];
        print(
          'GuardianNotificationService: Regular user, adding self as guardian: ${user.id}',
        );
      } else {
        print(
          'GuardianNotificationService: Assisted user, querying assisted_guardians table for assistedId: $assistedId',
        );
        final List rows = await client
            .from('assisted_guardians')
            .select('guardian_id,status')
            .eq('assisted_id', assistedId);
        print(
          'GuardianNotificationService: Found ${rows.length} guardian relationships',
        );
        for (final r in rows) {
          final gid = (r['guardian_id'] ?? '').toString();
          final status = (r['status'] ?? 'accepted').toString();
          print(
            'GuardianNotificationService: Guardian $gid with status $status',
          );
          if (gid.isEmpty) continue;
          if (status == 'accepted' || status.isEmpty) {
            guardianIds.add(gid);
            print(
              'GuardianNotificationService: Added guardian $gid to notification targets',
            );
          }
        }
        // If no guardians found, fall back to creator seeing their own page if they are the assisted
        if (guardianIds.isEmpty) {
          guardianIds = [user.id];
          print(
            'GuardianNotificationService: No guardians found, falling back to user: ${user.id}',
          );
        }
      }
    } catch (e) {
      print('GuardianNotificationService: Error determining guardians: $e');
      // If fetching guardians fails, queue locally to retry later
      await _enqueue(
        taskId: taskId,
        assistedId: assistedId,
        title: title,
        scheduledIso: scheduledIso,
        act: act,
        whenIso: whenIso,
      );
      return;
    }

    //print debug terminal to test if data is correct
    print(
      'recordTaskOutcome: user=${user.id}, assisted=$assistedId, action=$action, guardians=$guardianIds',
    );
    // Fan-out inserts (idempotent)
    for (final gid in guardianIds.toSet()) {
      print(
        'GuardianNotificationService: Attempting to create notification for guardian $gid',
      );
      try {
        final exist = await client
            .from('task_notifications')
            .select('id')
            .eq('task_id', taskId)
            .eq('guardian_id', gid)
            .eq('action_at', whenIso)
            .limit(1)
            .maybeSingle();
        if (exist != null) {
          print(
            'GuardianNotificationService: Notification already exists for guardian $gid, skipping',
          );
          continue;
        }

        print(
          'GuardianNotificationService: Inserting notification for guardian $gid',
        );
        await client.from('task_notifications').upsert({
          'task_id': taskId,
          'assisted_id': assistedId,
          'guardian_id': gid,
          'user_id': user.id,
          'title': title,
          if (scheduledIso != null) 'scheduled_at': scheduledIso,
          'action': act,
          'action_at': whenIso,
          'is_read': false,
        });
        print(
          'GuardianNotificationService: Successfully created notification for guardian $gid',
        );
      } catch (e) {
        print(
          'GuardianNotificationService: Failed to create notification for guardian $gid: $e',
        );
        if (kDebugMode) {
          // ignore: avoid_print
          print('GuardianNotificationService insert failed, queuing: $e');
        }
        await _enqueue(
          taskId: taskId,
          assistedId: assistedId,
          title: title,
          scheduledIso: scheduledIso,
          act: act,
          whenIso: whenIso,
          guardianId: gid,
        );
      }
    }
  }

  static Future<void> _enqueue({
    required String taskId,
    required String assistedId,
    required String title,
    required String act,
    required String whenIso,
    String? scheduledIso,
    String? guardianId, // optional; if null, will expand on sync
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? <String>[];
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final item = jsonEncode({
        'task_id': taskId,
        'assisted_id': assistedId,
        'title': title,
        'scheduled_at': scheduledIso,
        'action': act,
        'action_at': whenIso,
        if (guardianId != null) 'guardian_id': guardianId,
        if (userId != null) 'user_id': userId,
      });
      raw.add(item);
      await prefs.setStringList(_queueKey, raw);
    } catch (_) {}
  }

  static Future<void> syncQueuedOutcomes() async {
    List<String> raw;
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      raw = prefs.getStringList(_queueKey) ?? <String>[];
    } catch (_) {
      return;
    }
    if (raw.isEmpty) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final List<String> remaining = [];
    for (final s in raw) {
      Map<String, dynamic> m;
      try {
        m = jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final String taskId = m['task_id'].toString();
      final String assistedId = m['assisted_id'].toString();
      final String title = (m['title'] ?? 'Task').toString();
      final String act = (m['action'] ?? 'done').toString();
      final String whenIso =
          (m['action_at'] ?? DateTime.now().toUtc().toIso8601String())
              .toString();
      final String? scheduledIso = m['scheduled_at']?.toString();
      final String? gid = m['guardian_id']?.toString();

      List<String> targets = [];
      if (gid != null && gid.isNotEmpty) {
        targets = [gid];
      } else {
        try {
          final role = (await ProfileService.getCurrentUserRole(
            client,
          ))?.toLowerCase();
          if (role == 'regular') {
            targets = [user.id];
          } else {
            final List rows = await client
                .from('assisted_guardians')
                .select('guardian_id,status')
                .eq('assisted_id', assistedId);
            for (final r in rows) {
              final gid2 = (r['guardian_id'] ?? '').toString();
              final status = (r['status'] ?? 'accepted').toString();
              if (gid2.isEmpty) continue;
              if (status == 'accepted' || status.isEmpty) targets.add(gid2);
            }
            if (targets.isEmpty) targets = [user.id];
          }
        } catch (_) {
          remaining.add(s);
          continue;
        }
      }

      bool anyFailed = false;
      for (final t in targets.toSet()) {
        try {
          final exist = await client
              .from('task_notifications')
              .select('id')
              .eq('task_id', taskId)
              .eq('guardian_id', t)
              .eq('action_at', whenIso)
              .limit(1)
              .maybeSingle();
          if (exist != null) continue;
          await client.from('task_notifications').upsert({
            'task_id': taskId,
            'assisted_id': assistedId,
            'guardian_id': t,
            'user_id':
                (m['user_id'] ?? Supabase.instance.client.auth.currentUser?.id),
            'title': title,
            if (scheduledIso != null) 'scheduled_at': scheduledIso,
            'action': act,
            'action_at': whenIso,
            'is_read': false,
          });
        } catch (_) {
          anyFailed = true;
        }
      }
      if (anyFailed) {
        remaining.add(s);
      }
    }

    try {
      await prefs.setStringList(_queueKey, remaining);
    } catch (_) {}
  }

  static Future<void> markAllReadForGuardian(String guardianId) async {
    final client = Supabase.instance.client;
    try {
      await client
          .from('task_notifications')
          .update({'is_read': true})
          .eq('guardian_id', guardianId)
          .eq('is_read', false);
    } catch (_) {}
  }
}
