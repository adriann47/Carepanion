import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class DevicePermissions {
  static const MethodChannel _ch = MethodChannel('carepanion.reminder');

  static Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _ch.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _ch.invokeMethod<bool>('isExactAlarmAllowed');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestExactAlarmPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _ch.invokeMethod<bool>(
        'requestExactAlarmPermissionIfNeeded',
      );
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _ch.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<void> openIgnoreBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openIgnoreBatteryOptimizationSettings');
    } catch (_) {}
  }
}
