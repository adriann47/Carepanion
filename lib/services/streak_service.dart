import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/services/task_service.dart';

class StreakService {
  StreakService._();

  static final ValueNotifier<int> current = ValueNotifier<int>(0);

  static Future<void> refresh({String? forUserId}) async {
    final client = Supabase.instance.client;
    final uid = forUserId ?? client.auth.currentUser?.id;
    if (uid == null) {
      current.value = 0;
      return;
    }
    try {
      final row = await client
          .from('user_streak')
          .select('current_streak, streak')
          .eq('user_id', uid)
          .maybeSingle();
      current.value =
          row?['current_streak'] as int? ?? row?['streak'] as int? ?? 0;
    } catch (_) {
      // Fallback to local calculation if DB query fails
      try {
        final s = await TaskService.computeCurrentStreak(forUserId: forUserId);
        current.value = s;
      } catch (_) {
        current.value = 0;
      }
    }
  }
}
