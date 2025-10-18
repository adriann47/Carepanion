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
            // Debug: print payload
            print('GuardianRequestService: Received insert payload: $payload');
            final newRec = payload.newRecord as Map<String, dynamic>?;
            if (newRec == null) return;
            final target = newRec['guardian_id']?.toString();
            print('GuardianRequestService: Target guardian_id: $target, current gid: $gid');
            if (target != gid) return;

            final assistedId = newRec['assisted_id']?.toString();
            if (assistedId == null || assistedId.isEmpty) return;

            // Lookup assisted profile for a nicer label
            final prof = await ProfileService.fetchProfile(supa, userId: assistedId);
            final name = (prof?['fullname'] ?? prof?['name'] ?? 'Assisted').toString();
            print('GuardianRequestService: Showing dialog for assisted: $name');

            // Show an interrupting dialog using global nav key
            final ctx = navKey.currentState?.context;
            if (ctx == null) {
              print('GuardianRequestService: No context available for dialog');
              return;
            }

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
                      width: 320,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
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

                          // Orange user id pill
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC68A),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0xFFCA5000), width: 1.6),
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
                              // Accept (teal) button - left
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7DECF7),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 28),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  if (!dctx.mounted) return;
                                  Navigator.of(dctx).pop();
                                  try {
                                    print('GuardianRequestService: Accepting request for assisted_id: $assistedId');
                                    await supa.from('assisted_guardians').update({'status': 'accepted'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                                    // Do not update profile here; let assisted user handle linking after confirmation
                                  } catch (e) {
                                    print('GuardianRequestService: Error accepting: $e');
                                  }
                                },
                                child: Text(
                                  'ACCEPT',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              // Reject (pink) button - right
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF9687C),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 28),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  if (!dctx.mounted) return;
                                  Navigator.of(dctx).pop();
                                  try {
                                    print('GuardianRequestService: Rejecting request for assisted_id: $assistedId');
                                    await supa.from('assisted_guardians').update({'status': 'rejected'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                                  } catch (e) {
                                    print('GuardianRequestService: Error rejecting: $e');
                                  }
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
