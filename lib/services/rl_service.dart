import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_prefs.dart';
import '../data/profile_service.dart';

enum ReminderAction { notifyNow, deferShort, deferLong, escalateGuardian }

class ReminderDecision {
  ReminderDecision({
    required this.action,
    this.deferDuration,
    this.eventId,
    this.policyMetadata,
    this.recommendedSnoozes = const [],
  });

  final ReminderAction action;
  final Duration? deferDuration;
  final String? eventId;
  final Map<String, dynamic>? policyMetadata;
  final List<SnoozeOption> recommendedSnoozes;
}

class ScheduleSuggestion {
  ScheduleSuggestion({
    required this.id,
    required this.label,
    required this.start,
    this.end,
    this.score,
    this.metadata,
  });

  final String id;
  final String label;
  final TimeOfDay start;
  final TimeOfDay? end;
  final double? score;
  final Map<String, dynamic>? metadata;
}

class TitleSuggestion {
  TitleSuggestion({
    required this.title,
    required this.reason,
    this.emoji,
    this.metadata,
  });

  final String title;
  final String reason;
  final String? emoji;
  final Map<String, dynamic>? metadata;
}

class ScheduleRecommendation {
  ScheduleRecommendation({
    required this.daysLabel,
    required this.timeLabel,
    this.metadata,
  });

  final String daysLabel;
  final String timeLabel;
  final Map<String, dynamic>? metadata;
}

class SnoozeOption {
  const SnoozeOption({
    required this.duration,
    this.label,
    this.isPreferred = false,
  });

  final Duration duration;
  final String? label;
  final bool isPreferred;
}

/// Centralised helper for reinforcement learning integrations.
///
/// The service takes care of collecting contextual data, invoking server-side
/// policies when available, and gracefully falling back to heuristics so the
/// app remains fully functional even if the ML pipeline is offline.
class ReinforcementLearningService {
  ReinforcementLearningService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Request a reminder action from the policy (with heuristics fallback) and
  /// persist the decision for later reward attribution.
  static Future<ReminderDecision> chooseReminderAction({
    required Map<String, dynamic> taskRow,
    required DateTime dueDate,
    required DateTime startAtLocal,
    required Map<String, dynamic> context,
  }) async {
    final now = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'task_id': taskRow['id'].toString(),
      'user_id': taskRow['user_id']?.toString(),
      'title': taskRow['title'],
      'category': taskRow['category'],
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'start_at_iso': startAtLocal.toUtc().toIso8601String(),
      'context': context,
      'collected_at': now.toIso8601String(),
    };

    ReminderAction action = ReminderAction.notifyNow;
    Duration? deferDuration;
    Map<String, dynamic>? policyMeta;
    List<SnoozeOption> snoozeOptions = const [];

    try {
      final response = await _client.functions.invoke(
        'reminder_policy',
        body: payload,
      );
      final data = response.data;
      if (data is Map && data['action'] != null) {
        final actionStr = data['action'].toString();
        policyMeta = Map<String, dynamic>.from(data);
        switch (actionStr) {
          case 'notify_now':
            action = ReminderAction.notifyNow;
            break;
          case 'defer_short':
            action = ReminderAction.deferShort;
            break;
          case 'defer_long':
            action = ReminderAction.deferLong;
            break;
          case 'escalate_guardian':
            action = ReminderAction.escalateGuardian;
            break;
        }
        if (data['defer_minutes'] != null) {
          final minutes = double.tryParse(data['defer_minutes'].toString());
          if (minutes != null && minutes > 0) {
            deferDuration = Duration(milliseconds: (minutes * 60000).round());
          }
        }
        if (data['snooze_options'] is List) {
          snoozeOptions = _mapSnoozeOptions(data['snooze_options'] as List);
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('RL reminder policy fallback due to error: $e');
        // ignore: avoid_print
        print(st);
      }
      // Fallback heuristic: short deferral at night, otherwise notify now.
      final hour = startAtLocal.hour;
      if (hour < 7 || hour >= 22) {
        action = ReminderAction.deferShort;
        deferDuration = const Duration(minutes: 15);
      } else {
        action = ReminderAction.notifyNow;
      }
    }

    if (action == ReminderAction.deferShort && deferDuration == null) {
      deferDuration = const Duration(minutes: 10);
    } else if (action == ReminderAction.deferLong && deferDuration == null) {
      deferDuration = const Duration(minutes: 30);
    }

    if (snoozeOptions.isEmpty) {
      snoozeOptions = const [
        SnoozeOption(
          duration: Duration(minutes: 5),
          label: '5 min',
          isPreferred: true,
        ),
        SnoozeOption(duration: Duration(minutes: 10), label: '10 min'),
        SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
      ];
    }

    String? eventId;
    try {
      final insertPayload = {
        'task_id': taskRow['id'],
        'user_id': taskRow['user_id'],
        'decision_at': now.toIso8601String(),
        'action': describeEnum(action),
        'context': payload,
        'platform': _platformTag(),
        'policy_meta': policyMeta != null ? jsonEncode(policyMeta) : null,
      };
      final inserted = await _client
          .from('task_reminder_events')
          .insert(insertPayload)
          .select('id')
          .maybeSingle();
      if (inserted != null && inserted['id'] != null) {
        eventId = inserted['id'].toString();
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('RL reminder decision logging failed: $e');
      }
    }

    return ReminderDecision(
      action: action,
      deferDuration: deferDuration,
      eventId: eventId,
      policyMetadata: policyMeta,
      recommendedSnoozes: snoozeOptions,
    );
  }

  /// Update the decision row with the execution result (e.g. popup_shown,
  /// deferred, escalated). Errors are swallowed to avoid blocking UX.
  static Future<void> markReminderDecisionResult(
    String? eventId, {
    required String result,
    Map<String, dynamic>? extra,
  }) async {
    if (eventId == null) return;
    try {
      final payload = <String, dynamic>{
        'result': result,
        'result_at': DateTime.now().toUtc().toIso8601String(),
        if (extra != null && extra.isNotEmpty) 'result_meta': jsonEncode(extra),
      };
      await _client
          .from('task_reminder_events')
          .update(payload)
          .eq('id', eventId);
    } catch (_) {
      // non-fatal
    }
  }

  /// Log the downstream outcome so the bandit can be trained offline.
  static Future<void> logReminderOutcome({
    required String taskId,
    required String status,
    DateTime? completedAt,
    Duration? latency,
    String? decisionEventId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'task_id': taskId,
        'status': status,
        'logged_at': DateTime.now().toUtc().toIso8601String(),
        if (completedAt != null)
          'completed_at': completedAt.toUtc().toIso8601String(),
        if (latency != null) 'latency_seconds': latency.inSeconds,
        if (decisionEventId != null) 'decision_event_id': decisionEventId,
      };
      await _client.from('task_reminder_outcomes').insert(payload);
    } catch (_) {
      // swallow
    }
  }

  /// When escalation is requested, notify guardian services via Edge Function.
  static Future<void> escalateReminder({
    required Map<String, dynamic> taskRow,
    Map<String, dynamic>? metadata,
    String? decisionEventId,
  }) async {
    unawaited(
      markReminderDecisionResult(
        decisionEventId,
        result: 'escalated',
        extra: metadata,
      ),
    );
    try {
      await _client.functions.invoke(
        'notify_guardian',
        body: {
          'task_id': taskRow['id'],
          'assisted_id': taskRow['user_id'],
          'metadata': metadata,
        },
      );
    } catch (_) {
      // ignore; guardian notification is best-effort
    }
  }

  /// Fetch ranked schedule suggestions with conflict detection and personalization.
  static Future<List<ScheduleSuggestion>> fetchScheduleSuggestions({
    required DateTime dueDate,
    String? assistedUserId,
    String? category,
    String? guardianId,
    String? taskId,
    List<Map<String, dynamic>>? existingTasks,
  }) async {
    final baseContext = {
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'assisted_user_id': assistedUserId,
      'category': category,
      'guardian_id': guardianId,
      'task_id': taskId,
    };

    final List<ScheduleSuggestion> result = [];
    bool fetched = false;
    try {
      final resp = await _client.functions.invoke(
        'schedule_policy',
        body: baseContext,
      );
      final data = resp.data;
      if (data is List) {
        for (final raw in data) {
          if (raw is! Map) continue;
          final startIso = raw['start_at_iso']?.toString();
          if (startIso == null) continue;
          TimeOfDay? start;
          TimeOfDay? end;
          try {
            final dt = DateTime.parse(startIso).toLocal();
            start = TimeOfDay(hour: dt.hour, minute: dt.minute);
            final endIso = raw['end_at_iso']?.toString();
            if (endIso != null) {
              final endDt = DateTime.parse(endIso).toLocal();
              end = TimeOfDay(hour: endDt.hour, minute: endDt.minute);
            }
          } catch (_) {
            continue;
          }

          // Check for conflicts if existing tasks are provided
          bool hasConflict = false;
          if (existingTasks != null) {
            hasConflict = _hasTimeConflict(
              start!,
              end,
              dueDate,
              existingTasks,
              taskId,
            );
          }

          result.add(
            ScheduleSuggestion(
              id:
                  raw['suggestion_id']?.toString() ??
                  'policy_${result.length}_${DateTime.now().millisecondsSinceEpoch}',
              label: raw['label']?.toString() ?? 'Suggested slot',
              start: start!,
              end: end,
              score: raw['score'] != null
                  ? double.tryParse(raw['score'].toString())
                  : null,
              metadata: {
                ...Map<String, dynamic>.from(raw),
                'has_conflict': hasConflict,
              },
            ),
          );
        }
        fetched = result.isNotEmpty;
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('RL schedule policy fallback due to error: $e');
      }
    }

    if (!fetched) {
      // Enhanced fallback suggestions with time-aware, contextual scheduling
      result.addAll(
        _generateTimeAwareScheduleSuggestions(
          dueDate,
          category,
          existingTasks,
          taskId,
        ),
      );
    }

    // Filter out conflicting suggestions and sort by score
    final conflictFree = result
        .where((s) => !(s.metadata?['has_conflict'] ?? false))
        .toList();
    conflictFree.sort((a, b) {
      final aScore = a.score ?? 0.0;
      final bScore = b.score ?? 0.0;
      return bScore.compareTo(aScore); // Higher score first
    });

    return conflictFree.take(5).toList(); // Return top 5 suggestions
  }

  static Future<void> recordScheduleSelection({
    required DateTime dueDate,
    required TimeOfDay? start,
    required TimeOfDay? end,
    String? assistedUserId,
    String? guardianId,
    String? category,
    String? suggestionId,
    bool acceptedSuggestion = false,
    bool duringEdit = false,
    String? taskId,
  }) async {
    try {
      final DateFormat df = DateFormat('yyyy-MM-dd');
      final payload = <String, dynamic>{
        'task_id': taskId,
        'assisted_user_id': assistedUserId,
        'guardian_id': guardianId,
        'due_date': df.format(dueDate),
        'start_time': start != null ? _timeToString(start) : null,
        'end_time': end != null ? _timeToString(end) : null,
        'category': category,
        'suggestion_id': suggestionId,
        'accepted_suggestion': acceptedSuggestion,
        'during_edit': duringEdit,
        'platform': _platformTag(),
      };
      await _client.from('task_schedule_events').insert(payload);
    } catch (_) {
      // no-op
    }
  }

  static Future<void> recordTaskStatusChange({
    required int taskId,
    required String status,
    String? decisionEventId,
  }) async {
    try {
      await _client.from('task_status_events').insert({
        'task_id': taskId,
        'status': status,
        'logged_at': DateTime.now().toUtc().toIso8601String(),
        if (decisionEventId != null) 'decision_event_id': decisionEventId,
      });
    } catch (_) {
      // ignore
    }
  }

  static Future<List<TitleSuggestion>> fetchTitleSuggestions({
    String? assistedUserId,
    DateTime? dueDate,
    TimeOfDay? startTime,
    String? partialQuery,
    String? category,
  }) async {
    // Remove time-based filtering - suggestions should be available anytime
    final body = {
      'assisted_user_id': assistedUserId,
      'due_date': dueDate != null
          ? DateFormat('yyyy-MM-dd').format(dueDate)
          : null,
      'local_time': startTime != null ? _timeToString(startTime) : null,
      'query': partialQuery,
      'category': category,
    }..removeWhere((key, value) => value == null);

    try {
      final resp = await _client.functions.invoke('title_policy', body: body);
      final data = resp.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) {
              return TitleSuggestion(
                title: row['title']?.toString() ?? '',
                reason: row['reason']?.toString() ?? '',
                emoji: row['emoji']?.toString(),
                metadata: Map<String, dynamic>.from(row),
              );
            })
            .where((suggestion) => suggestion.title.trim().isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('RL title suggestion fallback: $e');
      }
    }

    // Enhanced fallback with intelligent suggestions based on user patterns
    List<TitleSuggestion> fallbacks = _generateIntelligentTitleSuggestions(
      partialQuery,
      category,
    );

    // Category-specific enhancements
    if (category != null && category.isNotEmpty) {
      final mapped = category.toUpperCase();
      if (mapped == 'MEDICATION') {
        final medicationSuggestions = [
          TitleSuggestion(
            title: 'Take prescribed medication',
            reason: 'Stay on schedule with health routine',
            emoji: '💊',
            metadata: {
              'category': 'MEDICATION',
              'priority': 'high',
              'time_context': 'health_routine',
            },
          ),
          TitleSuggestion(
            title: 'Schedule doctor appointment',
            reason: 'Book routine health check-up',
            emoji: '🏥',
            metadata: {
              'category': 'OTHER',
              'priority': 'medium',
              'time_context': 'planning',
              'suggested_date_offset': 14,
              'suggested_time': '09:00',
            },
          ),
          TitleSuggestion(
            title: 'Weekly medication refill reminder',
            reason: 'Order prescription refills',
            emoji: '�',
            metadata: {
              'category': 'MEDICATION',
              'priority': 'medium',
              'time_context': 'planning',
              'suggested_date_offset': 7,
              'suggested_time': '10:00',
            },
          ),
        ];
        fallbacks.insertAll(
          0,
          medicationSuggestions,
        ); // Add to beginning for priority
      } else if (mapped == 'EXERCISE') {
        final exerciseSuggestions = [
          TitleSuggestion(
            title: 'Morning exercise routine',
            reason: 'Start the day with gentle exercise',
            emoji: '🏃',
            metadata: {
              'category': 'EXERCISE',
              'priority': 'medium',
              'time_context': 'morning_routine',
              'suggested_time': '07:30',
            },
          ),
          TitleSuggestion(
            title: 'Short walk outside',
            reason: 'Light cardio and fresh air',
            emoji: '🚶',
            metadata: {
              'category': 'EXERCISE',
              'priority': 'medium',
              'time_context': 'cardio',
            },
          ),
          TitleSuggestion(
            title: 'Weekly grocery shopping',
            reason: 'Plan and shop for weekly meals',
            emoji: '🛒',
            metadata: {
              'category': 'OTHER',
              'priority': 'medium',
              'time_context': 'planning',
              'suggested_date_offset': 7,
              'suggested_time': '10:00',
            },
          ),
        ];
        fallbacks.insertAll(0, exerciseSuggestions);
      }
    }

    // Filter by partial query if provided
    if (partialQuery != null && partialQuery.isNotEmpty) {
      final lower = partialQuery.toLowerCase();
      fallbacks = fallbacks
          .where((suggestion) => suggestion.title.toLowerCase().contains(lower))
          .toList();
    }

    // Sort by priority (high -> medium -> low) and return top suggestions
    fallbacks.sort((a, b) {
      final aPriority = a.metadata?['priority'] ?? 'medium';
      final bPriority = b.metadata?['priority'] ?? 'medium';
      const priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
      return (priorityOrder[bPriority] ?? 2).compareTo(
        priorityOrder[aPriority] ?? 2,
      );
    });

    return fallbacks.take(8).toList(); // Return top 8 suggestions
  }

  static Future<String?> classifyTitle(String title) async {
    if (title.trim().isEmpty) return null;
    try {
      final resp = await _client.functions.invoke(
        'title_classifier',
        body: {'title': title},
      );
      final data = resp.data;
      if (data is Map && data['category'] != null) {
        return data['category'].toString();
      }
    } catch (_) {}

    final lower = title.toLowerCase();
    if (lower.contains('vitamin') ||
        lower.contains('medicine') ||
        lower.contains('doctor') ||
        lower.contains('pill')) {
      return 'Health';
    }
    if (lower.contains('call') || lower.contains('guardian')) {
      return 'Communication';
    }
    if (lower.contains('pay') ||
        lower.contains('bill') ||
        lower.contains('bank')) {
      return 'Finance';
    }
    if (lower.contains('exercise') ||
        lower.contains('walk') ||
        lower.contains('stretch')) {
      return 'Fitness';
    }
    return null;
  }

  static Future<ScheduleRecommendation?> fetchScheduleRecommendation({
    String? assistedUserId,
    String? category,
  }) async {
    try {
      final resp = await _client.functions.invoke(
        'schedule_frequency_policy',
        body: {'assisted_user_id': assistedUserId, 'category': category}
          ..removeWhere((key, value) => value == null),
      );
      final data = resp.data;
      if (data is Map) {
        final days = data['days_label']?.toString();
        final time = data['time_label']?.toString();
        if (days != null &&
            days.isNotEmpty &&
            time != null &&
            time.isNotEmpty) {
          return ScheduleRecommendation(
            daysLabel: days,
            timeLabel: time,
            metadata: Map<String, dynamic>.from(data),
          );
        }
      }
    } catch (_) {}

    return ScheduleRecommendation(
      daysLabel: 'Mon – Fri',
      timeLabel: '8:00 PM',
      metadata: const {'source': 'fallback'},
    );
  }

  static Future<List<SnoozeOption>> fetchSnoozeRecommendations({
    required String taskId,
    required String userId,
    Duration? defaultDefer,
    String? category,
  }) async {
    try {
      final resp = await _client.functions.invoke(
        'snooze_policy',
        body: {
          'task_id': taskId,
          'user_id': userId,
          'category': category,
          'default_defer_seconds': defaultDefer?.inSeconds,
        }..removeWhere((key, value) => value == null),
      );
      final data = resp.data;
      if (data is List) {
        final mapped = _mapSnoozeOptions(data);
        if (mapped.isNotEmpty) return mapped;
      }
    } catch (_) {}

    // Enhanced fallback with category-specific and behavior-based recommendations
    final baseOptions = <SnoozeOption>[];

    if (category == 'MEDICATION') {
      // For medication, shorter snoozes to ensure timely taking
      baseOptions.addAll([
        SnoozeOption(
          duration: Duration(minutes: 5),
          label: '5 min',
          isPreferred: true,
        ),
        SnoozeOption(duration: Duration(minutes: 10), label: '10 min'),
        SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
      ]);
    } else if (category == 'EXERCISE') {
      // For exercise, slightly longer to allow preparation
      baseOptions.addAll([
        SnoozeOption(
          duration: Duration(minutes: 10),
          label: '10 min',
          isPreferred: true,
        ),
        SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
        SnoozeOption(duration: Duration(minutes: 30), label: '30 min'),
      ]);
    } else {
      // General tasks - adaptive based on time of day
      final now = DateTime.now();
      if (now.hour < 12) {
        // Morning - shorter snoozes for morning routine
        baseOptions.addAll([
          SnoozeOption(
            duration: Duration(minutes: 5),
            label: '5 min',
            isPreferred: true,
          ),
          SnoozeOption(duration: Duration(minutes: 10), label: '10 min'),
          SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
        ]);
      } else if (now.hour >= 18) {
        // Evening - can be more flexible
        baseOptions.addAll([
          SnoozeOption(
            duration: Duration(minutes: 10),
            label: '10 min',
            isPreferred: true,
          ),
          SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
          SnoozeOption(duration: Duration(minutes: 30), label: '30 min'),
        ]);
      } else {
        // Daytime - balanced options
        baseOptions.addAll([
          SnoozeOption(duration: Duration(minutes: 5), label: '5 min'),
          SnoozeOption(
            duration: Duration(minutes: 10),
            label: '10 min',
            isPreferred: true,
          ),
          SnoozeOption(duration: Duration(minutes: 15), label: '15 min'),
          SnoozeOption(duration: Duration(minutes: 30), label: '30 min'),
        ]);
      }
    }

    return baseOptions;
  }

  static List<SnoozeOption> _mapSnoozeOptions(List rawList) {
    return rawList.whereType<Map>().map((item) {
      Duration? duration;
      if (item['seconds'] != null) {
        final secs = double.tryParse(item['seconds'].toString());
        if (secs != null) {
          duration = Duration(milliseconds: (secs * 1000).round());
        }
      } else if (item['minutes'] != null) {
        final mins = double.tryParse(item['minutes'].toString());
        if (mins != null) {
          duration = Duration(milliseconds: (mins * 60000).round());
        }
      }
      duration ??= const Duration(minutes: 5);
      return SnoozeOption(
        duration: duration,
        label: item['label']?.toString(),
        isPreferred: item['preferred'] == true,
      );
    }).toList();
  }

  static Future<String?> resolveGuardianIdFor(String? assistedId) async {
    if (assistedId == null) return null;
    try {
      final prof = await ProfileService.fetchProfile(
        _client,
        userId: assistedId,
      );
      final guardianId = (prof?['guardian_id'] as String?)?.trim();
      if (guardianId != null && guardianId.isNotEmpty) return guardianId;
    } catch (_) {}
    return null;
  }

  static String _timeToString(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static List<TitleSuggestion> _generateIntelligentTitleSuggestions(
    String? partialQuery,
    String? category,
  ) {
    // Base suggestions that are always available regardless of time
    final baseSuggestions = [
      // Health and medication
      TitleSuggestion(
        title: 'Take medication',
        reason: 'Stay on schedule with health routine',
        emoji: '💊',
        metadata: {
          'category': 'MEDICATION',
          'priority': 'high',
          'suggested_time': '08:00',
        },
      ),
      TitleSuggestion(
        title: 'Morning vitamins',
        reason: 'Start the day with essential nutrients',
        emoji: '🌅',
        metadata: {
          'category': 'MEDICATION',
          'priority': 'medium',
          'suggested_time': '08:00',
        },
      ),
      TitleSuggestion(
        title: 'Evening medication',
        reason: 'Complete daily medication routine',
        emoji: '💊',
        metadata: {
          'category': 'MEDICATION',
          'priority': 'high',
          'suggested_time': '20:00',
        },
      ),

      // Exercise and activity
      TitleSuggestion(
        title: 'Light exercise',
        reason: 'Stay active and healthy',
        emoji: '🏃',
        metadata: {
          'category': 'EXERCISE',
          'priority': 'medium',
          'suggested_time': '09:00',
        },
      ),
      TitleSuggestion(
        title: 'Short walk',
        reason: 'Light cardio and fresh air',
        emoji: '🚶',
        metadata: {'category': 'EXERCISE', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Stretching routine',
        reason: 'Improve flexibility and relaxation',
        emoji: '🧘',
        metadata: {'category': 'EXERCISE', 'priority': 'medium'},
      ),

      // Daily routines
      TitleSuggestion(
        title: 'Drink water',
        reason: 'Stay hydrated throughout the day',
        emoji: '💧',
        metadata: {'category': 'OTHER', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Meal preparation',
        reason: 'Prepare healthy meals',
        emoji: '🍽️',
        metadata: {'category': 'OTHER', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Hygiene routine',
        reason: 'Personal care and cleanliness',
        emoji: '🧼',
        metadata: {'category': 'OTHER', 'priority': 'high'},
      ),

      // Planning and organization
      TitleSuggestion(
        title: 'Review schedule',
        reason: 'Plan and organize tasks',
        emoji: '📅',
        metadata: {'category': 'OTHER', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Call family',
        reason: 'Stay connected with loved ones',
        emoji: '📞',
        metadata: {'category': 'OTHER', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Doctor appointment',
        reason: 'Schedule health check-ups',
        emoji: '🏥',
        metadata: {
          'category': 'OTHER',
          'priority': 'medium',
          'suggested_date_offset': 14,
          'suggested_time': '09:00',
        },
      ),

      // Common tasks
      TitleSuggestion(
        title: 'Grocery shopping',
        reason: 'Plan weekly meal shopping',
        emoji: '🛒',
        metadata: {
          'category': 'OTHER',
          'priority': 'medium',
          'suggested_date_offset': 7,
          'suggested_time': '10:00',
        },
      ),
      TitleSuggestion(
        title: 'Pay bills',
        reason: 'Manage financial obligations',
        emoji: '💳',
        metadata: {'category': 'OTHER', 'priority': 'high'},
      ),
      TitleSuggestion(
        title: 'Laundry',
        reason: 'Keep clothes clean and organized',
        emoji: '👕',
        metadata: {'category': 'OTHER', 'priority': 'low'},
      ),

      // Relaxation and self-care
      TitleSuggestion(
        title: 'Relaxation time',
        reason: 'Take time to unwind and recharge',
        emoji: '😴',
        metadata: {'category': 'OTHER', 'priority': 'medium'},
      ),
      TitleSuggestion(
        title: 'Reading',
        reason: 'Enjoy quiet time with a book',
        emoji: '📖',
        metadata: {'category': 'OTHER', 'priority': 'low'},
      ),
      TitleSuggestion(
        title: 'Meditation',
        reason: 'Practice mindfulness and breathing',
        emoji: '🧘',
        metadata: {'category': 'EXERCISE', 'priority': 'low'},
      ),
    ];

    return baseSuggestions;
  }

  static String _resolveDayPeriod(TimeOfDay? startTime) {
    final int hour = startTime?.hour ?? DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  static bool _hasTimeConflict(
    TimeOfDay start,
    TimeOfDay? end,
    DateTime date,
    List<Map<String, dynamic>> existingTasks,
    String? excludeTaskId,
  ) {
    final startDate = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    final endDate = end != null
        ? DateTime(date.year, date.month, date.day, end.hour, end.minute)
        : startDate.add(const Duration(minutes: 15)); // Default 15 min duration

    for (final task in existingTasks) {
      // Skip the task being edited (if any)
      final taskId = task['id']?.toString();
      if (excludeTaskId != null && taskId == excludeTaskId) continue;

      final otherStart = _parseTaskTime(task['start_at'], date);
      if (otherStart == null) continue;

      final otherEnd =
          _parseTaskTime(task['end_at'], date) ??
          otherStart.add(const Duration(minutes: 15));

      // Check for time overlap
      if (startDate.isBefore(otherEnd) && otherStart.isBefore(endDate)) {
        return true;
      }
    }
    return false;
  }

  static DateTime? _parseTaskTime(dynamic raw, DateTime date) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      final time = _parseTimeOfDay(raw.toString());
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
  }

  static String _platformTag() {
    if (kIsWeb) return 'web';
    try {
      return defaultTargetPlatform.name.toLowerCase();
    } catch (_) {
      return 'unknown';
    }
  }

  static List<ScheduleSuggestion> _generateTimeAwareScheduleSuggestions(
    DateTime dueDate,
    String? category,
    List<Map<String, dynamic>>? existingTasks,
    String? taskId,
  ) {
    final currentPeriod = _resolveDayPeriod(null); // Current time period

    final suggestions = <ScheduleSuggestion>[];

    // Category-specific scheduling patterns with enhanced time awareness
    if (category != null && category.isNotEmpty) {
      final mapped = category.toUpperCase();

      if (mapped == 'MEDICATION') {
        // Medication scheduling - spread throughout the day with meal alignment
        final medicationSlots = [
          _ScheduleSlot(
            'Morning medication with breakfast',
            8,
            0,
            8,
            30,
            0.95,
            'morning_routine',
          ),
          _ScheduleSlot(
            'Lunchtime medication',
            12,
            0,
            12,
            30,
            0.90,
            'lunch_routine',
          ),
          _ScheduleSlot(
            'Evening medication with dinner',
            18,
            0,
            18,
            30,
            0.95,
            'dinner_routine',
          ),
          _ScheduleSlot(
            'Bedtime medication',
            21,
            0,
            21,
            30,
            0.85,
            'bedtime_routine',
          ),
          _ScheduleSlot(
            'Mid-morning medication',
            10,
            0,
            10,
            30,
            0.75,
            'mid_morning',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            medicationSlots,
            dueDate,
            existingTasks,
            taskId,
            'MEDICATION',
          ),
        );
      } else if (mapped == 'EXERCISE') {
        // Exercise scheduling - optimal times for energy and safety
        final exerciseSlots = [
          _ScheduleSlot(
            'Morning energy boost exercise',
            9,
            0,
            10,
            0,
            0.85,
            'morning_energy',
          ),
          _ScheduleSlot(
            'Post-lunch circulation walk',
            13,
            30,
            14,
            30,
            0.80,
            'afternoon_circulation',
          ),
          _ScheduleSlot(
            'Gentle evening stretching',
            17,
            0,
            17,
            45,
            0.75,
            'evening_relaxation',
          ),
          _ScheduleSlot(
            'Late afternoon mobility',
            16,
            0,
            16,
            45,
            0.70,
            'late_afternoon',
          ),
          _ScheduleSlot(
            'Mid-morning light activity',
            10,
            30,
            11,
            15,
            0.65,
            'mid_morning',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            exerciseSlots,
            dueDate,
            existingTasks,
            taskId,
            'EXERCISE',
          ),
        );
      } else {
        // General/other tasks - time-based suggestions with context
        suggestions.addAll(
          _generateGeneralScheduleSuggestions(
            dueDate,
            currentPeriod,
            existingTasks,
            taskId,
          ),
        );
      }
    } else {
      // No category specified - provide general time-based suggestions
      suggestions.addAll(
        _generateGeneralScheduleSuggestions(
          dueDate,
          currentPeriod,
          existingTasks,
          taskId,
        ),
      );
    }

    return suggestions;
  }

  static List<ScheduleSuggestion> _generateGeneralScheduleSuggestions(
    DateTime dueDate,
    String currentPeriod,
    List<Map<String, dynamic>>? existingTasks,
    String? taskId,
  ) {
    final suggestions = <ScheduleSuggestion>[];

    switch (currentPeriod) {
      case 'morning':
        final morningSlots = [
          _ScheduleSlot(
            'Morning routine completion',
            9,
            0,
            10,
            0,
            0.85,
            'morning_productivity',
          ),
          _ScheduleSlot(
            'Mid-morning focus time',
            10,
            30,
            11,
            30,
            0.80,
            'mid_morning',
          ),
          _ScheduleSlot(
            'Pre-lunch preparation',
            11,
            30,
            12,
            30,
            0.75,
            'pre_lunch',
          ),
          _ScheduleSlot(
            'Early morning start',
            8,
            30,
            9,
            30,
            0.70,
            'early_morning',
          ),
          _ScheduleSlot(
            'Late morning planning',
            11,
            0,
            12,
            0,
            0.65,
            'late_morning',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            morningSlots,
            dueDate,
            existingTasks,
            taskId,
            'GENERAL',
          ),
        );
        break;
      case 'afternoon':
        final afternoonSlots = [
          _ScheduleSlot(
            'Post-lunch productivity',
            13,
            30,
            14,
            30,
            0.85,
            'post_lunch',
          ),
          _ScheduleSlot(
            'Afternoon focus window',
            14,
            30,
            15,
            30,
            0.80,
            'afternoon_focus',
          ),
          _ScheduleSlot(
            'Late afternoon tasks',
            16,
            0,
            17,
            0,
            0.75,
            'late_afternoon',
          ),
          _ScheduleSlot(
            'Mid-afternoon break activities',
            15,
            0,
            16,
            0,
            0.70,
            'mid_afternoon',
          ),
          _ScheduleSlot(
            'Early afternoon planning',
            13,
            0,
            14,
            0,
            0.65,
            'early_afternoon',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            afternoonSlots,
            dueDate,
            existingTasks,
            taskId,
            'GENERAL',
          ),
        );
        break;
      case 'evening':
        final eveningSlots = [
          _ScheduleSlot(
            'Evening routine tasks',
            18,
            0,
            19,
            0,
            0.85,
            'evening_routine',
          ),
          _ScheduleSlot(
            'Pre-dinner preparation',
            17,
            30,
            18,
            30,
            0.80,
            'pre_dinner',
          ),
          _ScheduleSlot(
            'Wind-down activities',
            19,
            30,
            20,
            30,
            0.75,
            'wind_down',
          ),
          _ScheduleSlot(
            'Late evening planning',
            20,
            0,
            21,
            0,
            0.70,
            'late_evening',
          ),
          _ScheduleSlot(
            'Early evening tasks',
            18,
            30,
            19,
            30,
            0.65,
            'early_evening',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            eveningSlots,
            dueDate,
            existingTasks,
            taskId,
            'GENERAL',
          ),
        );
        break;
      default: // night
        final nightSlots = [
          _ScheduleSlot('Pre-bed preparation', 21, 0, 22, 0, 0.60, 'pre_bed'),
          _ScheduleSlot(
            'Nighttime routine',
            20,
            30,
            21,
            30,
            0.55,
            'night_routine',
          ),
        ];
        suggestions.addAll(
          _createScheduleSuggestions(
            nightSlots,
            dueDate,
            existingTasks,
            taskId,
            'GENERAL',
          ),
        );
        break;
    }

    return suggestions;
  }

  static List<ScheduleSuggestion> _createScheduleSuggestions(
    List<_ScheduleSlot> slots,
    DateTime dueDate,
    List<Map<String, dynamic>>? existingTasks,
    String? taskId,
    String category,
  ) {
    return slots.map((slot) {
      final start = TimeOfDay(hour: slot.startHour, minute: slot.startMinute);
      final end = TimeOfDay(hour: slot.endHour, minute: slot.endMinute);

      bool hasConflict = false;
      if (existingTasks != null) {
        hasConflict = _hasTimeConflict(
          start,
          end,
          dueDate,
          existingTasks,
          taskId,
        );
      }

      return ScheduleSuggestion(
        id: 'fallback_${category.toLowerCase()}_${slot.label.hashCode}',
        label: slot.label,
        start: start,
        end: end,
        score: slot.score,
        metadata: {
          'source': 'fallback',
          'category': category,
          'time_context': slot.timeContext,
          'has_conflict': hasConflict,
        },
      );
    }).toList();
  }

  static TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _ScheduleSlot {
  const _ScheduleSlot(
    this.label,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.score,
    this.timeContext,
  );

  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final double score;
  final String timeContext;
}
