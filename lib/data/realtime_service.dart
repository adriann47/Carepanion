import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight helper for Supabase Realtime subscriptions.
///
/// Use cases:
/// - Guardians subscribe to an assisted user's task changes
/// - Guardians subscribe to emergency alerts from one or more assisted users
class RealtimeService {
  RealtimeService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  /// Subscribe to tasks table changes for a single assisted user.
  /// Triggers on insert, update and delete.
  /// Returns the channel key to allow later unsubscription.
  String subscribeTasksForAssisted({
    required String assistedUserId,
    required void Function(PostgresChangePayload payload) onChange,
  }) {
    final key = 'tasks_$assistedUserId';
    // Clean any existing channel with the same key
    _channels[key]?.unsubscribe();

    void guarded(PostgresChangePayload payload) {
      final Map<String, dynamic>? newRec =
          payload.newRecord as Map<String, dynamic>?;
      final Map<String, dynamic>? oldRec =
          payload.oldRecord as Map<String, dynamic>?;
      final newAssisted = newRec?['assisted_id']?.toString();
      final oldAssisted = oldRec?['assisted_id']?.toString();
      if (newAssisted == assistedUserId || oldAssisted == assistedUserId) {
        onChange(payload);
      }
    }

    final channel = _client.channel(key)
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'tasks',
        callback: guarded,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'tasks',
        callback: guarded,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'tasks',
        callback: guarded,
      )
      ..subscribe();

    _channels[key] = channel;
    return key;
  }

  /// Subscribe to emergency alerts for a single assisted user.
  /// Guardians can create one subscription per assisted user they monitor.
  String subscribeEmergencyForAssisted({
    required String assistedUserId,
    required void Function(PostgresChangePayload payload) onAlert,
  }) {
    final key = 'emergency_$assistedUserId';
    _channels[key]?.unsubscribe();

    void guarded(PostgresChangePayload payload) {
      final Map<String, dynamic>? newRec =
          payload.newRecord as Map<String, dynamic>?;
      final newAssisted = newRec?['assisted_id']?.toString();
      if (newAssisted == assistedUserId) onAlert(payload);
    }

    final channel = _client.channel(key)
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'emergency_alerts',
        callback: guarded,
      )
      ..subscribe();

    _channels[key] = channel;
    return key;
  }

  /// Unsubscribe a specific channel by key returned from a subscribe method.
  void unsubscribe(String key) {
    _channels[key]?.unsubscribe();
    _channels.remove(key);
  }

  /// Unsubscribe and clean up all active channels.
  void dispose() {
    for (final ch in _channels.values) {
      ch.unsubscribe();
    }
    _channels.clear();
  }
}
