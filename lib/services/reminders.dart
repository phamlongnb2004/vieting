import 'dart:convert';

import 'package:flutter/services.dart';

import '../insights.dart';
import '../store.dart';
import '../util/format.dart';
import 'notify_bridge.dart';

/// Nhắc tự động hiện trên máy kể cả khi không mở app (Android).
/// App tự tính lịch theo dữ liệu của chính người dùng rồi giao cho hệ thống hẹn giờ;
/// lời nhắc & mốc giờ do admin chỉnh trên trang quản trị (mục "Nhắc tự động").
class Reminders {
  static const _ch = MethodChannel('vieting/notify');
  static String _last = '';
  static bool _asked = false;

  static String _fill(String s, {String name = '', int amount = 0}) =>
      s.replaceAll('{name}', name).replaceAll('{amount}', amount > 0 ? money(amount) : '');

  static DateTime _at(DateTime d, int h, [int m = 0]) => DateTime(d.year, d.month, d.day, h, m);

  static List<Map<String, dynamic>> build(AppStore s) {
    final out = <Map<String, dynamic>>[];
    if (!s.remindersOn) return out;
    final now = DateTime.now();
    void add(int id, DateTime at, String title, String body) {
      if (at.isAfter(now.add(const Duration(minutes: 1)))) {
        out.add({'id': id, 'at': at.millisecondsSinceEpoch, 'title': title, 'body': body});
      }
    }

    Map<String, dynamic> rule(String k, Map<String, dynamic> d) {
      final r = s.smartRule(k);
      return {...d, ...r};
    }

    // 1) Nhắc ghi chi tiêu buổi tối (chỉ khi hôm đó chưa ghi gì)
    final daily = rule('daily', {'on': true, 'hour': 21, 'title': 'Hôm nay tiêu gì rồi? 📝', 'body': 'Dành 10 giây ghi lại chi tiêu hôm nay nhé.'});
    if (daily['on'] != false) {
      final h = ((daily['hour'] as num?) ?? 21).toInt();
      final hasToday = s.activeTxns.any((t) => sameDay(t.date, now));
      if (!hasToday) add(1001, _at(now, h), '${daily['title']}', '${daily['body']}');
      add(1002, _at(now.add(const Duration(days: 1)), h), '${daily['title']}', '${daily['body']}');
    }
    // 2) Lâu không mở app
    final back = rule('comeback', {'on': true, 'days': 3, 'title': 'Lâu rồi không gặp 🎋', 'body': 'Mở VieTing xem tuần này đã tiêu bao nhiêu nhé.'});
    if (back['on'] != false) {
      final d = ((back['days'] as num?) ?? 3).toInt();
      add(1100, _at(now.add(Duration(days: d)), 19, 30), '${back['title']}', '${back['body']}');
    }
    // 3) Ngày nhận lương
    final pay = rule('payday', {'on': true, 'title': 'Hôm nay nhận lương 💰', 'body': 'Trích tiền tiết kiệm trước khi tiêu nhé.'});
    if (pay['on'] != false && s.cycleDay > 1) {
      var d = DateTime(now.year, now.month, s.cycleDay, 9);
      if (!d.isAfter(now)) d = DateTime(now.year, now.month + 1, s.cycleDay, 9);
      add(1200, d, '${pay['title']}', '${pay['body']}');
    }
    // 4) Khoản định kỳ sắp trừ tiền
    final bill = rule('bill', {'on': true, 'before': 1, 'title': 'Sắp trừ tiền: {name}', 'body': '{amount} sẽ bị trừ sớm. Không dùng thì hủy kịp nhé.'});
    if (bill['on'] != false) {
      final before = ((bill['before'] as num?) ?? 1).toInt();
      var i = 0;
      for (final b in s.activeBills) {
        if (i >= 15) break;
        add(2000 + i++, _at(b.next.subtract(Duration(days: before)), 9), _fill('${bill['title']}', name: b.name, amount: b.amount),
            _fill('${bill['body']}', name: b.name, amount: b.amount));
      }
    }
    // 5) Món chờ mua đủ 48 giờ
    final wish = rule('wish', {'on': true, 'title': 'Đủ 48 giờ rồi: {name}', 'body': 'Bạn còn muốn mua không?'});
    if (wish['on'] != false) {
      var i = 0;
      for (final w in s.activeWishes.where((w) => w.status == 'waiting' && !w.ready)) {
        if (i >= 10) break;
        add(3000 + i++, w.readyAt, _fill('${wish['title']}', name: w.name, amount: w.price), _fill('${wish['body']}', name: w.name, amount: w.price));
      }
    }
    // 6) Dịp hiếu hỉ (trước 1 ngày)
    final gift = rule('gift', {'on': true, 'title': 'Sắp tới dịp của {name}', 'body': 'Xem lần trước đã mừng bao nhiêu.'});
    if (gift['on'] != false) {
      var i = 0;
      for (final g in s.activeGifts.where((g) => g.remind != null && g.remind!.isAfter(now))) {
        if (i >= 10) break;
        add(4000 + i++, _at(g.remind!.subtract(const Duration(days: 1)), 9), _fill('${gift['title']}', name: g.person),
            _fill('${gift['body']}', name: g.person));
      }
    }
    return out;
  }

  static String _lastWidget = '';

  /// Cập nhật widget màn hình chính (Android): hạn mức còn lại hôm nay + 1 câu theo tính cách trợ lý.
  static Future<void> updateWidget(AppStore s) async {
    if (!NotifyBridge.supported) return;
    final g = s.guiltFree;
    final over = g != null && g.leftToday < 0;
    final data = {
      'label': g == null ? 'VieTing' : (over ? 'Hôm nay đã vượt' : 'Hôm nay còn được tiêu'),
      'amount': g == null ? 'Bấm + để ghi' : money(over ? -g.leftToday : g.leftToday),
      'line': s.personaLine,
      'over': over,
    };
    final key = jsonEncode(data);
    if (key == _lastWidget) return;
    _lastWidget = key;
    try {
      await _ch.invokeMethod('updateWidget', data);
    } catch (_) {}
  }

  /// Đặt lại toàn bộ lịch nhắc (gọi khi mở app / dữ liệu đổi). Bỏ qua nếu không có gì thay đổi.
  static Future<void> sync(AppStore s) async {
    if (!NotifyBridge.supported) return;
    await updateWidget(s);
    try {
      final items = build(s);
      final key = jsonEncode([items, s.serverUrl, s.token]);
      if (key == _last) return;
      _last = key;
      if (items.isNotEmpty && !_asked) {
        _asked = true;
        await _ch.invokeMethod('askNotifyPermission');
      }
      await _ch.invokeMethod('schedule', {'items': jsonEncode(items)});
      await _ch.invokeMethod('setServer', {'url': s.serverUrl, 'token': s.token});
    } catch (_) {}
  }

  static Future<void> test() async {
    if (!NotifyBridge.supported) return;
    try {
      await _ch.invokeMethod('askNotifyPermission');
      await _ch.invokeMethod('testNotify', {'title': 'VieTing đã bật nhắc nhở 🎋', 'body': 'Thông báo sẽ hiện như thế này, kể cả khi bạn không mở app.'});
    } catch (_) {}
  }
}
