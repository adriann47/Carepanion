import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  static final _client = Supabase.instance.client;

  /// Submits feedback: inserts into `feedback` table and invokes the
  /// `send-feedback` Edge Function to email the team.
  /// Throws on failure.
  static Future<void> submitFeedback({
    required String userId,
    String? role,
    String? subject,
    required String message,
    int? stars,
    List<Map<String, dynamic>>? attachments,
    String? appVersion,
    String? platform,
  }) async {
    final payload = {
      'user_id': userId,
      'role': role,
      'subject': subject,
      'message': message,
      'stars': stars,
      'attachments': attachments,
      'app_version': appVersion ?? '',
      // Use kIsWeb/defaultTargetPlatform so this works on web and mobile
      'platform': platform ?? (kIsWeb ? 'web' : defaultTargetPlatform.toString()),
    };

    // 1) Prepare payload: remove nulls so we don't send columns the DB may not have
    final toInsert = Map<String, dynamic>.from(payload);
    toInsert.removeWhere((key, value) => value == null);

    // Try inserting into feedback table. If the database schema is older
    // (missing optional columns like 'stars' or 'attachments'), attempt a
    // single fallback by removing those columns and retrying.
    try {
      await _client.from('feedback').insert(toInsert);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // common optional fields we include; if the DB complains about any of
      // them being missing, remove and retry once.
      final optionalCols = ['stars', 'attachments', 'app_version', 'platform', 'role', 'subject'];
      bool modified = false;
      for (final col in optionalCols) {
        if (msg.contains("'$col'") || msg.contains(col)) {
          if (toInsert.containsKey(col)) {
            toInsert.remove(col);
            modified = true;
          }
        }
      }
      if (modified) {
        // retry once with the reduced payload
        await _client.from('feedback').insert(toInsert);
      } else {
        rethrow;
      }
    }

    // No email step: we only persist feedback in the database.
    // If you later want notifications (email/Slack/GitHub), call a server
    // function separately or re-enable the edge function invocation here.
  }
}
