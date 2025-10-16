import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/navigation.dart';
import '../data/profile_service.dart';

/// Service that listens for incoming assisted_guardians requests targeted at
/// the currently signed-in guardian and shows an interrupting dialog to
/// accept or reject the request. Uses the global navigator key so the
/// dialog appears on top of whatever page is active.
class GuardianRequestService {
  GuardianRequestService._();

  static final _instance = GuardianRequestService._();
  factory GuardianRequestService() => _instance;

  RealtimeChannel? _channel;

  void start({SupabaseClient? client}) {
    final supa = client ?? Supabase.instance.client;
    final gid = supa.auth.currentUser?.id;
    if (gid == null) return;

    // Unsubscribe existing
    _channel?.unsubscribe();

    _channel = supa
        .channel('public:assisted_guardians:guardian:$gid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) async {
          try {
            final newRec = payload.newRecord as Map<String, dynamic>?;
            if (newRec == null) return;
            final target = newRec['guardian_id']?.toString();
            if (target != gid) return;

            final assistedId = newRec['assisted_id']?.toString();
            if (assistedId == null || assistedId.isEmpty) return;

            // Lookup assisted profile for a nicer label
            final prof = await ProfileService.fetchProfile(supa, userId: assistedId);
            final name = (prof?['fullname'] ?? prof?['name'] ?? 'Assisted').toString();

            // Show an interrupting dialog using global nav key
            final ctx = navKey.currentState?.overlay?.context;
            if (ctx == null) return;

            // Ensure dialog is shown on UI thread
            await showDialog<void>(
              context: ctx,
              barrierDismissible: false,
              builder: (dctx) {
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
                            'GUARDIAN REQUEST',
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
                                  '$name has requested you as their guardian.',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Would you like to accept or reject this request?',
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
                                onPressed: () async {
                                  if (!dctx.mounted) return;
                                  Navigator.of(dctx).pop();
                                  try {
                                    await supa.from('assisted_guardians').update({'status': 'rejected'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                                  } catch (_) {}
                                },
                                child: Text(
                                  'REJECT',
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
                                onPressed: () async {
                                  if (!dctx.mounted) return;
                                  Navigator.of(dctx).pop();
                                  try {
                                    await supa.from('assisted_guardians').update({'status': 'accepted'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                                    // Also update assisted profile guardian_id for legacy flows
                                    await supa.from('profile').update({'guardian_id': gid}).eq('id', assistedId);
                                  } catch (_) {}
                                },
                                child: Text(
                                  'ACCEPT',
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
          } catch (e) {
            // ignore errors
          }
        },
      )
      ..subscribe();
  }

  void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
