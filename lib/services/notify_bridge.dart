import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Cầu nối tới dịch vụ đọc thông báo viết bằng Kotlin (chỉ có trên Android).
class NotifyBridge {
  static const _ch = MethodChannel('vieting/notify');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static void listen(VoidCallback onNew) {
    if (!supported) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onNotice') onNew();
      return null;
    });
  }

  static Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    if (supported) await _ch.invokeMethod('openSettings');
  }

  static Future<void> openAppDetails() async {
    if (supported) await _ch.invokeMethod('openAppDetails');
  }

  /// Lấy (và xóa) các thông báo đang chờ trong hàng đợi phía Android.
  static Future<List<RawNotice>> drain() async {
    if (!supported) return [];
    try {
      final s = await _ch.invokeMethod<String>('drain');
      if (s == null || s.isEmpty) return [];
      return (jsonDecode(s) as List)
          .map((e) => RawNotice.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('VieTing: drain lỗi $e');
      return [];
    }
  }
}
