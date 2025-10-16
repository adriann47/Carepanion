import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  NotificationPreferences._();

  static const _kPush = 'notif_push_enabled';
  static const _kTts = 'notif_tts_enabled';
  static const _kVibration = 'notif_vibration_enabled';

  static late SharedPreferences _prefs;
  static final ValueNotifier<bool> pushEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> ttsEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> vibrationEnabled = ValueNotifier<bool>(true);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    pushEnabled.value = _prefs.getBool(_kPush) ?? true;
    ttsEnabled.value = _prefs.getBool(_kTts) ?? true;
    vibrationEnabled.value = _prefs.getBool(_kVibration) ?? true;
  }

  static Future<void> setPush(bool enabled) async {
    pushEnabled.value = enabled;
    await _prefs.setBool(_kPush, enabled);
  }

  static Future<void> setTts(bool enabled) async {
    ttsEnabled.value = enabled;
    await _prefs.setBool(_kTts, enabled);
  }

  static Future<void> setVibration(bool enabled) async {
    vibrationEnabled.value = enabled;
    await _prefs.setBool(_kVibration, enabled);
  }
}
