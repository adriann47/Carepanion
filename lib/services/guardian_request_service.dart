import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/navigation.dart';
import '../data/profile_service.dart';
import 'notification_service.dart';

/// Service that listens for incoming assisted_guardians requests targeted at
/// the currently signed-in guardian and shows an interrupting dialog to
/// accept or reject the request. Uses the global navigator key so the
/// dialog appears on top of whatever page is active.
class GuardianRequestService {
  GuardianRequestService._();

  static final _instance = GuardianRequestService._();
  factory GuardianRequestService() => _instance;

  RealtimeChannel? _channel;
  Timer? _poll;
  bool _dialogOpen = false;
  String? _lastAssistedShown;
  DateTime? _lastShownAt;

  void start({SupabaseClient? client}) {
    final supa = client ?? Supabase.instance.client;
    final gid = supa.auth.currentUser?.id;
    if (gid == null) return;

    // Unsubscribe existing
    _channel?.unsubscribe();

    _channel = supa.channel('public:assisted_guardians:guardian:$gid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) async {
          await _handleRequestEvent(supa, gid, payload.newRecord);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) async {
          await _handleRequestEvent(supa, gid, payload.newRecord);
        },
      )
      ..subscribe();

    // Also check for any existing pending requests on start (cold start or missed insert)
    _showLatestPendingIfAny(supa, gid);

    // Start a lightweight polling fallback in case Realtime is unavailable
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await _showLatestPendingIfAny(supa, gid);
      } catch (_) {}
    });
  }

  void stop() {
    _channel?.unsubscribe();
    _channel = null;
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _showLatestPendingIfAny(SupabaseClient supa, String gid) async {
    try {
      final List rows = await supa
          .from('assisted_guardians')
          .select('assisted_id, status')
          .eq('guardian_id', gid)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return;
      final assistedId = rows.first['assisted_id']?.toString();
      if (assistedId == null || assistedId.isEmpty) return;
      // Dedup: avoid re-showing the same request too frequently or multiple dialogs
      final now = DateTime.now();
      if (_dialogOpen) return;
      if (_lastAssistedShown == assistedId &&
          _lastShownAt != null &&
          now.difference(_lastShownAt!).inSeconds < 20) {
        return;
      }
      await _presentDialogFor(supa, gid, assistedId);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _handleRequestEvent(
    SupabaseClient supa,
    String gid,
    Map<String, dynamic>? rec,
  ) async {
    try {
      if (rec == null) return;
      final target = rec['guardian_id']?.toString();
      if (target != gid) return;
      final status = (rec['status'] ?? '').toString().toLowerCase();
      if (status != 'pending') return;
      final assistedId = rec['assisted_id']?.toString();
      if (assistedId == null || assistedId.isEmpty) return;
      await _presentDialogFor(supa, gid, assistedId);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _presentDialogFor(
    SupabaseClient supa,
    String gid,
    String assistedId,
  ) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    // Lookup assisted profile for a nicer label
    final prof = await ProfileService.fetchProfile(
      supa,
      userId: assistedId,
    );
    final name =
        (prof?['fullname'] ?? prof?['name'] ?? 'Assisted').toString().trim();

    // Show a local notification
    await NotificationService.showNow(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Companion Request',
      body: '$name wants to connect with you',
      payload: jsonEncode({
        'type': 'guardian_request',
        'assisted_id': assistedId,
        'guardian_id': gid,
      }),
      channelId: 'carepanion_requests',
    );

    // Show an interrupting dialog on top
    BuildContext? ctx;
    for (int attempt = 0; attempt < 5; attempt++) {
      ctx = navKey.currentState?.overlay?.context;
      if (ctx != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (ctx == null) return;

    _lastAssistedShown = assistedId;
    _lastShownAt = DateTime.now();

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'COMPANION REQUEST',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC68A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFCA5000),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USER ID:',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5A2F00),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DECF7),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 28,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (!dctx.mounted) return;
                          Navigator.of(dctx).pop();
                          try {
                            await supa
                                .from('assisted_guardians')
                                .update({'status': 'accepted'})
                                .eq('assisted_id', assistedId)
                                .eq('guardian_id', gid)
                                .eq('status', 'pending');
                            try {
                              await ProfileService.setGuardianIdForAssisted(
                                supa,
                                assistedUserId: assistedId,
                                guardianUserId: gid,
                              );
                            } catch (_) {}
                          } catch (e) {
                            // ignore
                          }
                          _dialogOpen = false;
                        },
                        child: Text(
                          'ACCEPT',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF9687C),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 28,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (!dctx.mounted) return;
                          Navigator.of(dctx).pop();
                          try {
                            await supa
                                .from('assisted_guardians')
                                .update({'status': 'rejected'})
                                .eq('assisted_id', assistedId)
                                .eq('guardian_id', gid)
                                .eq('status', 'pending');
                          } catch (e) {
                            // ignore
                          }
                          _dialogOpen = false;
                        },
                        child: Text(
                          'REJECT',
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
      },
    );
    _dialogOpen = false;
  }
}
