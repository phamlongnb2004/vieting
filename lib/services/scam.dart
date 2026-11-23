// Kiểm tra / báo cáo tài khoản lừa đảo. Tác giả: Phạm Thành Long (thlong)
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../store.dart';

class ScamReport {
  final int id;
  final String bin, holder, channel, body, happened;
  final int amount, at;
  final List<int> photos;
  ScamReport.fromJson(Map j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        bin = '${j['bin'] ?? ''}',
        holder = '${j['holder'] ?? ''}',
        channel = '${j['channel'] ?? ''}',
        body = '${j['body'] ?? ''}',
        happened = '${j['happened'] ?? ''}',
        amount = (j['amount'] as num?)?.toInt() ?? 0,
        at = (j['at'] as num?)?.toInt() ?? 0,
        photos = [for (final p in (j['photos'] as List? ?? const [])) (p as num).toInt()];
}

class ScamResult {
  final String acct, bin;
  final int count, people;
  final List<ScamReport> reports;
  ScamResult.fromJson(Map j)
      : acct = '${j['acct'] ?? ''}',
        bin = '${j['bin'] ?? ''}',
        count = (j['count'] as num?)?.toInt() ?? 0,
        people = (j['people'] as num?)?.toInt() ?? 0,
        reports = [for (final r in (j['reports'] as List? ?? const [])) ScamReport.fromJson(r as Map)];
}

const kScamChannels = {
  'mua_ban': 'Mua bán online',
  'viec_lam': 'Việc làm, cộng tác viên',
  'dau_tu': 'Đầu tư, tiền ảo',
  'vay': 'Vay tiền',
  'gia_danh': 'Giả danh cơ quan, người quen',
  'tinh_cam': 'Tình cảm',
  'game': 'Game, nạp thẻ',
  'khac': 'Khác',
};

class ScamApi {
  static Map<String, String> _h(AppStore s) => {
        'content-type': 'application/json',
        if (s.token.isNotEmpty) 'authorization': 'Bearer ${s.token}',
      };

  static Future<Map<String, dynamic>> _call(AppStore s, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${s.serverUrl}$path');
    final r = body == null
        ? await http.get(uri, headers: _h(s)).timeout(const Duration(seconds: 25))
        : await http.post(uri, headers: _h(s), body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {
      throw Exception('Máy chủ chưa hỗ trợ chức năng này, thử lại sau');
    }
    if (r.statusCode >= 400) throw Exception(j['error'] ?? 'Lỗi ${r.statusCode}');
    return j;
  }

  static Future<ScamResult> check(AppStore s, String acct, String bin) async {
    final q = 'acct=${Uri.encodeQueryComponent(acct)}&bin=${Uri.encodeQueryComponent(bin)}';
    return ScamResult.fromJson(await _call(s, '/api/scam/check?$q'));
  }

  static final Map<int, String> _photoCache = {};
  static Future<String> photo(AppStore s, int id) async {
    final c = _photoCache[id];
    if (c != null) return c;
    final j = await _call(s, '/api/scam/photo?id=$id');
    final img = '${j['img'] ?? ''}';
    _photoCache[id] = img;
    return img;
  }

  static Future<void> report(
    AppStore s, {
    required String bin,
    required String acct,
    required String holder,
    required String channel,
    required String body,
    required int amount,
    required String happened,
    required List<String> photos,
  }) =>
      _call(s, '/api/scam/report', {
        'agree': true,
        'bin': bin,
        'acct': acct,
        'holder': holder,
        'channel': channel,
        'body': body,
        'amount': amount,
        'happened': happened,
        'photos': photos,
      });

  static Future<Map<String, dynamic>> mine(AppStore s) => _call(s, '/api/scam/mine');

  static Future<void> appeal(AppStore s, {required String bin, required String acct, required String contact, required String body}) =>
      _call(s, '/api/scam/appeal', {'bin': bin, 'acct': acct, 'contact': contact, 'body': body});

  static Future<void> flag(AppStore s, int report, String reason) => _call(s, '/api/scam/flag', {'report': report, 'reason': reason});

  static Future<void> block(AppStore s, int report) => _call(s, '/api/scam/block', {'report': report});
}
