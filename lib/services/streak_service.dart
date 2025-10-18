import 'package:flutter/foundation.dart';
import 'package:softeng/services/task_service.dart';

class StreakService {
  StreakService._();

  static final ValueNotifier<int> current = ValueNotifier<int>(0);

  static Future<void> refresh({String? forUserId}) async {
    try {
      final s = await TaskService.computeCurrentStreak(forUserId: forUserId);
      current.value = s;
    } catch (_) {}
  }
}

