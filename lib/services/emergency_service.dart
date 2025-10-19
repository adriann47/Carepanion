import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';
import 'navigation.dart';
import '../Assisted Screen/emergency_alert_screen.dart';

/// Global emergency listener.
/// For guardian users, subscribes to emergency_alerts from linked assisteds
/// and surfaces EmergencyAlertScreen when a new alert is inserted.
class EmergencyService {
  EmergencyService._();
  static StreamSubscription<AuthState>? _authSub;
  static RealtimeChannel? _channel;
  static String? _forGuardianId;

  static void start() {
    final client = Supabase.instance.client;
    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((event) async {
      await _refresh();
    });
    // initial
    _refresh();
  }

  static Future<void> _refresh() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _unsubscribe();
      return;
    }

    try {
      if (_forGuardianId == user.id && _channel != null)
        return; // already active
      _unsubscribe();
      _forGuardianId = user.id;

      // Subscribe to emergency_alerts targeted to this guardian or all alerts from their assisteds
      // Here we subscribe to guardian_id == current guardian, which avoids extra joins client side.
      _channel = client
          .channel('emergency_alerts_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'emergency_alerts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'guardian_id',
              value: user.id,
            ),
            callback: (payload) async {
              final nav = navKey.currentState;
              final ctx = nav?.overlay?.context;
              if (ctx == null) return;

              // Try to resolve assisted name if assisted_id is present
              String assistedName = '';
              try {
                final newRec = payload.newRecord as Map<String, dynamic>?;
                final assistedId = newRec?['assisted_id']?.toString();
                if (assistedId != null && assistedId.isNotEmpty) {
                  final prof = await ProfileService.fetchProfile(
                    Supabase.instance.client,
                    userId: assistedId,
                  );
                  assistedName = (prof?['fullname'] ?? '').toString().trim();
                }
              } catch (_) {}

              // Present the alert screen for guardian
              // ignore: use_build_context_synchronously
              await Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => EmergencyAlertScreen(
                    assistedName: assistedName,
                    isGuardianView: true,
                  ),
                ),
              );
            },
          )
          .subscribe();
    } catch (_) {
      // ignore
    }
  }

  static void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    _forGuardianId = null;
  }
}
