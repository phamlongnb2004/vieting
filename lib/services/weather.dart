import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:vieting/i18n.dart';

import '../consent.dart';
import '../store.dart';
import 'reminders.dart';

/// Thời tiết: dự báo lấy qua server VieTing (nguồn MET Norway), vị trí máy hoặc tỉnh / thành chọn tay.
/// Tác giả: Phạm Thành Long (thlong)

class VnPlace {
  final String id;
  final String vi;
  final String en;
  final double lat;
  final double lon;
  const VnPlace(this.id, this.vi, this.en, this.lat, this.lon);
  String get name => isEn ? en : vi;
}

/// 34 tỉnh, thành phố của Việt Nam sau sắp xếp từ 01/07/2025 (tọa độ trung tâm hành chính).
const kVnPlaces = <VnPlace>[
  VnPlace('hn', 'Hà Nội', 'Hanoi', 21.0285, 105.8542),
  VnPlace('hcm', 'TP. Hồ Chí Minh', 'Ho Chi Minh City', 10.7769, 106.7009),
  VnPlace('hp', 'Hải Phòng', 'Hai Phong', 20.8449, 106.6881),
  VnPlace('dn', 'Đà Nẵng', 'Da Nang', 16.0544, 108.2022),
  VnPlace('hue', 'Huế', 'Hue', 16.4637, 107.5909),
  VnPlace('ct', 'Cần Thơ', 'Can Tho', 10.0452, 105.7469),
  VnPlace('ag', 'An Giang', 'An Giang', 10.0125, 105.0809),
  VnPlace('bn', 'Bắc Ninh', 'Bac Ninh', 21.2731, 106.1946),
  VnPlace('cm', 'Cà Mau', 'Ca Mau', 9.1769, 105.1524),
  VnPlace('cb', 'Cao Bằng', 'Cao Bang', 22.6657, 106.2570),
  VnPlace('dl', 'Đắk Lắk', 'Dak Lak', 12.6667, 108.0500),
  VnPlace('db', 'Điện Biên', 'Dien Bien', 21.3860, 103.0230),
  VnPlace('dnai', 'Đồng Nai', 'Dong Nai', 10.9574, 106.8429),
  VnPlace('dt', 'Đồng Tháp', 'Dong Thap', 10.3600, 106.3600),
  VnPlace('gl', 'Gia Lai', 'Gia Lai', 13.7820, 109.2192),
  VnPlace('ht', 'Hà Tĩnh', 'Ha Tinh', 18.3428, 105.9057),
  VnPlace('hy', 'Hưng Yên', 'Hung Yen', 20.4463, 106.3366),
  VnPlace('kh', 'Khánh Hòa', 'Khanh Hoa', 12.2388, 109.1967),
  VnPlace('lc', 'Lai Châu', 'Lai Chau', 22.3964, 103.4582),
  VnPlace('ld', 'Lâm Đồng', 'Lam Dong', 11.9404, 108.4583),
  VnPlace('ls', 'Lạng Sơn', 'Lang Son', 21.8537, 106.7610),
  VnPlace('lca', 'Lào Cai', 'Lao Cai', 21.7229, 104.9113),
  VnPlace('na', 'Nghệ An', 'Nghe An', 18.6796, 105.6813),
  VnPlace('nb', 'Ninh Bình', 'Ninh Binh', 20.2506, 105.9745),
  VnPlace('pt', 'Phú Thọ', 'Phu Tho', 21.3227, 105.4019),
  VnPlace('qng', 'Quảng Ngãi', 'Quang Ngai', 15.1205, 108.7923),
  VnPlace('qn', 'Quảng Ninh', 'Quang Ninh', 20.9712, 107.0448),
  VnPlace('qt', 'Quảng Trị', 'Quang Tri', 17.4689, 106.6223),
  VnPlace('sl', 'Sơn La', 'Son La', 21.3256, 103.9188),
  VnPlace('tn', 'Tây Ninh', 'Tay Ninh', 10.5359, 106.4137),
  VnPlace('tng', 'Thái Nguyên', 'Thai Nguyen', 21.5942, 105.8482),
  VnPlace('th', 'Thanh Hóa', 'Thanh Hoa', 19.8067, 105.7852),
  VnPlace('tq', 'Tuyên Quang', 'Tuyen Quang', 21.8236, 105.2140),
  VnPlace('vl', 'Vĩnh Long', 'Vinh Long', 10.2537, 105.9722),
];

VnPlace? placeById(String id) {
  for (final p in kVnPlaces) {
    if (p.id == id) return p;
  }
  return null;
}

VnPlace nearestPlace(double lat, double lon) {
  VnPlace best = kVnPlaces.first;
  var bd = double.infinity;
  for (final p in kVnPlaces) {
    final d = pow(p.lat - lat, 2) + pow((p.lon - lon) * cos(lat * pi / 180), 2);
    if (d < bd) {
      bd = d.toDouble();
      best = p;
    }
  }
  return best;
}

/// Mã thời tiết của MET Norway (VD "heavyrainandthunder_day") -> biểu tượng + mô tả.
(IconData, String) wxLook(String sym) {
  final s = sym.replaceAll(RegExp(r'_(day|night|polartwilight)$'), '');
  final night = sym.endsWith('_night');
  if (s.contains('thunder')) return (PhosphorIconsRegular.cloudLightning, 'Dông');
  if (s.contains('snow') || s.contains('sleet')) return (PhosphorIconsRegular.cloudSnow, 'Tuyết / mưa tuyết');
  if (s.startsWith('heavyrain')) return (PhosphorIconsRegular.cloudRain, 'Mưa to');
  if (s.startsWith('lightrain')) return (PhosphorIconsRegular.cloudRain, 'Mưa nhỏ');
  if (s.contains('rain')) return (PhosphorIconsRegular.cloudRain, 'Có mưa');
  if (s == 'fog') return (PhosphorIconsRegular.cloudFog, 'Sương mù');
  if (s == 'cloudy') return (PhosphorIconsRegular.cloud, 'Nhiều mây');
  if (s == 'partlycloudy' || s == 'fair') return (night ? PhosphorIconsRegular.cloudMoon : PhosphorIconsRegular.cloudSun, 'Có mây');
  if (s == 'clearsky') return (night ? PhosphorIconsRegular.moon : PhosphorIconsRegular.sun, 'Trời quang');
  return (PhosphorIconsRegular.cloudSun, 'Thời tiết');
}

/// Cảnh báo -> (biểu tượng, tiêu đề, lời khuyên ngắn, màu).
(IconData, String, String, Color) alertLook(Map a) {
  final peak = (a['peak'] as num?)?.toDouble() ?? 0;
  final rain = (a['rain'] as num?)?.toDouble();
  switch (a['kind']) {
    case 'storm':
      return (
        PhosphorIconsFill.warning,
        'Gió bão mạnh (giật ${(peak * 3.6).round()} km/h)',
        '${rain != null ? 'Kèm mưa to. ' : ''}Hạn chế ra ngoài, cất đồ ngoài ban công, sạc đầy điện thoại và pin dự phòng.',
        const Color(0xFFC1272C),
      );
    case 'thunder':
      return (PhosphorIconsFill.cloudLightning, 'Mưa dông', 'Tránh trú dưới cây to, cột điện; rút phích thiết bị điện khi có sét.', const Color(0xFFB45309));
    case 'heavyrain':
      return (PhosphorIconsFill.cloudRain, 'Mưa rất to (${peak.toStringAsFixed(0)} mm/giờ)', 'Có thể ngập đường. Mang áo mưa, tránh đi qua chỗ trũng.', const Color(0xFF1D4ED8));
    case 'rainday':
      return (PhosphorIconsFill.umbrella, 'Mưa to cả ngày (~${peak.toStringAsFixed(0)} mm)', 'Chuẩn bị áo mưa, để ý nguy cơ ngập úng.', const Color(0xFF1D4ED8));
    case 'wind':
      return (PhosphorIconsFill.wind, 'Gió mạnh (giật ${(peak * 3.6).round()} km/h)', 'Cẩn thận khi đi xe máy, cây đổ và biển quảng cáo.', const Color(0xFF6B21A8));
    case 'heat':
      return (PhosphorIconsFill.thermometer, 'Nắng nóng ${peak.round()}°C', 'Uống đủ nước, hạn chế ra nắng buổi trưa.', const Color(0xFFDC2626));
    case 'cold':
      return (PhosphorIconsFill.thermometer, 'Trời rét ${peak.round()}°C', 'Mặc đủ ấm, để ý người già và trẻ nhỏ.', const Color(0xFF0369A1));
  }
  return (PhosphorIconsFill.warning, 'Thời tiết xấu', '', const Color(0xFFC1272C));
}

class Weather {
  static bool _busy = false;
  static String get _base => kServer.replaceAll(RegExp(r'/+$'), '');
  static String kServer = '';

  static String placeName(AppStore s) {
    final w = s.weather;
    if (s.weatherLoc == 'device') {
      final near = w?['near'] as String?;
      final p = near == null ? null : placeById(near);
      return p == null ? tr('Vị trí của bạn') : tr('Gần {0}').replaceAll('{0}', p.name);
    }
    return placeById(s.weatherLoc)?.name ?? tr('Chọn nơi xem thời tiết');
  }

  /// Lấy tọa độ máy (độ chính xác thấp, đủ cho thời tiết). [ask]: được phép hỏi quyền / hiện công bố.
  static Future<(double, double)?> devicePos(AppStore s, {bool ask = false, BuildContext? context}) async {
    if (!Consent.given(s, 'location')) {
      if (!ask) return null;
      if (!await Consent.ensure(s, 'location', context: context)) return null;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (ask) await Geolocator.openLocationSettings();
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
        );
      } catch (_) {
        p = await Geolocator.getLastKnownPosition();
      }
      if (p == null) return null;
      return ((p.latitude * 100).round() / 100, (p.longitude * 100).round() / 100);
    } catch (_) {
      return null;
    }
  }

  /// Cập nhật dự báo (tối đa 30 phút một lần trừ khi [force]). Trả về lỗi để hiện, hoặc null.
  static Future<String?> refresh(AppStore s, {bool force = false, bool ask = false, BuildContext? context}) async {
    if (!s.weatherOn || s.weatherLoc.isEmpty || _busy) return null;
    if (!force && s.weather != null && DateTime.now().millisecondsSinceEpoch - s.weatherAt < 30 * 60000) return null;
    kServer = s.serverUrl;
    if (_base.isEmpty) return tr('Chưa có server');
    _busy = true;
    try {
      double lat, lon;
      String? near;
      if (s.weatherLoc == 'device') {
        final pos = await devicePos(s, ask: ask, context: context);
        if (pos == null) return tr('Chưa lấy được vị trí. Bật định vị hoặc chọn tỉnh / thành bằng tay.');
        (lat, lon) = pos;
        near = nearestPlace(lat, lon).id;
      } else {
        final p = placeById(s.weatherLoc);
        if (p == null) return null;
        lat = p.lat;
        lon = p.lon;
      }
      final tz = DateTime.now().timeZoneOffset.inMinutes;
      final r = await http
          .get(Uri.parse('$_base/api/weather?lat=$lat&lon=$lon&tz=$tz'), headers: {'accept-language': appLang})
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode != 200 || j is! Map) return '${(j is Map ? j['error'] : null) ?? tr('Không lấy được dự báo thời tiết')}';
      final w = Map<String, dynamic>.from(j);
      if (near != null) w['near'] = near;
      s.putWeather(w);
      Reminders.sync(s);
      return null;
    } catch (e) {
      return tr('Không lấy được dự báo thời tiết');
    } finally {
      _busy = false;
    }
  }

  static List<Map<String, dynamic>> alerts(AppStore s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final a in (s.weather?['alerts'] as List?) ?? const [])
        if (a is Map && ((a['end'] as num?) ?? 0) > now) Map<String, dynamic>.from(a)
    ];
  }

  /// Thông báo nhắc trước khi có thời tiết xấu (Android hẹn giờ sẵn, kể cả khi đóng app).
  static List<Map<String, dynamic>> notifications(AppStore s) {
    if (!s.weatherOn || !s.weatherAlertsOn) return const [];
    final out = <Map<String, dynamic>>[];
    final now = DateTime.now();
    var i = 0;
    for (final a in alerts(s)) {
      if (((a['level'] as num?) ?? 0) < 2) continue; // chỉ báo mưa to, dông, bão
      final start = DateTime.fromMillisecondsSinceEpoch((a['start'] as num).toInt());
      var at = start.subtract(const Duration(hours: 2));
      if (at.isBefore(now.add(const Duration(minutes: 2)))) at = now.add(const Duration(minutes: 2));
      if (start.isBefore(now) && now.difference(start).inMinutes > 30) continue;
      final (_, title, tip, _) = alertLook(a);
      final when = '${start.hour.toString().padLeft(2, '0')}:00${sameDayAs(start, now) ? '' : ' ${start.day}/${start.month}'}';
      out.add({
        'id': 5000 + i++,
        'at': at.millisecondsSinceEpoch,
        'title': '${tr(title)} · ${placeName(s)}',
        'body': '${tr('Từ khoảng {0}.').replaceAll('{0}', when)} ${tr(tip)}',
      });
    }
    return out;
  }

  static bool sameDayAs(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Tóm tắt dự báo để gửi AI xin gợi ý.
  static String summary(AppStore s) {
    final w = s.weather;
    if (w == null) return '';
    final b = StringBuffer();
    final c = w['current'];
    if (c is Map) b.writeln('Now: ${c['temp']}°C, ${c['sym']}, wind ${c['wind']} m/s, humidity ${c['hum']}%');
    for (final d in ((w['daily'] as List?) ?? const []).take(3)) {
      if (d is Map) b.writeln('${d['date']}: ${d['min']}-${d['max']}°C, ${d['sym']}, rain ${d['rain']} mm, max gust ${d['wind']} m/s');
    }
    for (final a in alerts(s)) {
      final st = DateTime.fromMillisecondsSinceEpoch((a['start'] as num).toInt());
      b.writeln('ALERT ${a['kind']} from ${st.toIso8601String().substring(0, 16)} peak ${a['peak']}');
    }
    return b.toString();
  }

  static Future<(String, List<String>)?> advice(AppStore s) async {
    final sum = summary(s);
    if (sum.isEmpty) return null;
    kServer = s.serverUrl;
    try {
      final r = await http
          .post(Uri.parse('$_base/api/weather/advice'),
              headers: {'content-type': 'application/json', if (s.loggedIn) 'authorization': 'Bearer ${s.token}'},
              body: jsonEncode({'place': placeName(s), 'lang': appLang, 'summary': sum}))
          .timeout(const Duration(seconds: 40));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode != 200 || j is! Map || j['tips'] is! List) throw '${j is Map ? j['error'] ?? '' : ''}';
      return ('${j['title'] ?? ''}', [for (final t in j['tips'] as List) '$t']);
    } catch (e) {
      throw e.toString().isEmpty ? tr('AI đang bận, thử lại sau') : e.toString();
    }
  }
}
