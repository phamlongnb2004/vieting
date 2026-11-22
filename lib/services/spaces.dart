import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../store.dart';

/// Một khoản trong quỹ chung: nộp quỹ (contrib) hoặc chi từ quỹ (spend).
class SpaceEntry {
  final String id;
  final int by; // id người ghi
  String type; // contrib | spend
  int amount;
  String note;
  String category;
  DateTime date;
  int u;
  bool del;

  SpaceEntry({
    required this.id,
    required this.by,
    required this.type,
    required this.amount,
    this.note = '',
    this.category = '',
    required this.date,
    int? u,
    this.del = false,
  }) : u = u ?? nowMs();

  Map<String, dynamic> toData() => {
        'type': type,
        'amount': amount,
        'note': note,
        'cat': category,
        'date': date.millisecondsSinceEpoch,
      };

  factory SpaceEntry.fromRecord(Map<String, dynamic> r) {
    final d = Map<String, dynamic>.from((r['data'] as Map?) ?? const {});
    return SpaceEntry(
      id: '${r['id']}',
      by: ((r['by'] as num?) ?? 0).toInt(),
      type: d['type'] == 'contrib' ? 'contrib' : 'spend',
      amount: ((d['amount'] as num?) ?? 0).toInt(),
      note: '${d['note'] ?? ''}',
      category: '${d['cat'] ?? ''}',
      date: DateTime.fromMillisecondsSinceEpoch(((d['date'] as num?) ?? nowMs()).toInt()),
      u: ((r['u'] as num?) ?? 0).toInt(),
      del: r['del'] == true,
    );
  }

  Map<String, dynamic> toCache() => {'id': id, 'by': by, 'data': toData(), 'u': u, 'del': del};
}

/// Quỹ chung kết nối nhiều tài khoản (vợ chồng, bạn bè...). Dữ liệu nằm trên server, máy giữ bản sao để xem offline.
class Space {
  final int id;
  String name;
  String code;
  int owner;
  int target;
  List<({int id, String name})> members;
  final Map<String, SpaceEntry> entries = {};
  int cursor = 0;

  Space({required this.id, required this.name, required this.code, required this.owner, this.target = 0, this.members = const []});

  void applyInfo(Map<String, dynamic> j) {
    name = '${j['name'] ?? name}';
    code = '${j['code'] ?? code}';
    owner = ((j['owner'] as num?) ?? owner).toInt();
    target = ((j['target'] as num?) ?? target).toInt();
    members = [
      for (final m in (j['members'] as List? ?? const []))
        if (m is Map) (id: ((m['id'] as num?) ?? 0).toInt(), name: '${m['name'] ?? ''}')
    ];
  }

  factory Space.fromInfo(Map<String, dynamic> j) {
    final s = Space(id: ((j['id'] as num?) ?? 0).toInt(), name: '', code: '', owner: 0);
    s.applyInfo(j);
    return s;
  }

  List<SpaceEntry> get active => entries.values.where((e) => !e.del).toList()..sort((a, b) => b.date.compareTo(a.date));
  int get contributed => active.where((e) => e.type == 'contrib').fold(0, (s, e) => s + e.amount);
  int get spent => active.where((e) => e.type == 'spend').fold(0, (s, e) => s + e.amount);
  int get balance => contributed - spent;

  String nameOf(int userId) {
    for (final m in members) {
      if (m.id == userId) return m.name;
    }
    return 'Thành viên cũ';
  }

  /// Mỗi người đã nộp / đã chi bao nhiêu.
  Map<int, ({int contrib, int spent})> perMember() {
    final out = <int, ({int contrib, int spent})>{for (final m in members) m.id: (contrib: 0, spent: 0)};
    for (final e in active) {
      final cur = out[e.by] ?? (contrib: 0, spent: 0);
      out[e.by] = e.type == 'contrib' ? (contrib: cur.contrib + e.amount, spent: cur.spent) : (contrib: cur.contrib, spent: cur.spent + e.amount);
    }
    return out;
  }

  Map<String, dynamic> toCache() => {
        'id': id,
        'name': name,
        'code': code,
        'owner': owner,
        'target': target,
        'members': [for (final m in members) {'id': m.id, 'name': m.name}],
        'cursor': cursor,
        'entries': [for (final e in entries.values) e.toCache()],
      };

  factory Space.fromCache(Map<String, dynamic> j) {
    final s = Space.fromInfo(j);
    s.cursor = ((j['cursor'] as num?) ?? 0).toInt();
    for (final r in (j['entries'] as List? ?? const [])) {
      if (r is Map) {
        final e = SpaceEntry.fromRecord(Map<String, dynamic>.from(r));
        s.entries[e.id] = e;
      }
    }
    return s;
  }
}

class Spaces {
  static Map<String, String> _h(AppStore s) => {'content-type': 'application/json', 'authorization': 'Bearer ${s.token}'};

  static Future<Map<String, dynamic>> _call(AppStore s, String path, [Map<String, dynamic>? body]) async {
    if (!s.loggedIn) throw Exception('Đăng nhập (Cài đặt → Đăng nhập để đồng bộ) để dùng Quỹ chung');
    final uri = Uri.parse('${s.serverUrl}$path');
    final r = body == null
        ? await http.get(uri, headers: _h(s)).timeout(const Duration(seconds: 20))
        : await http.post(uri, headers: _h(s), body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {
      throw Exception('Server chưa có Quỹ chung (chạy lại tai-len-cloudflare.bat)');
    }
    if (r.statusCode >= 400) throw Exception(j['error'] ?? 'Lỗi ${r.statusCode}');
    return j;
  }

  /// Tải danh sách quỹ; giữ lại khoản đã lưu trên máy.
  static Future<void> refreshList(AppStore s) async {
    final j = await _call(s, '/api/spaces');
    s.myUserId = ((j['me'] as num?) ?? 0).toInt();
    final ids = <int>{};
    for (final x in (j['spaces'] as List? ?? const [])) {
      final info = Map<String, dynamic>.from(x as Map);
      final id = ((info['id'] as num?) ?? 0).toInt();
      ids.add(id);
      final cur = s.spaces[id];
      if (cur == null) {
        s.spaces[id] = Space.fromInfo(info);
      } else {
        cur.applyInfo(info);
      }
    }
    s.spaces.removeWhere((k, _) => !ids.contains(k));
    s.spacesChanged();
  }

  static Future<Space> create(AppStore s, String name, {int target = 0, String nick = ''}) async {
    final j = await _call(s, '/api/space/create', {'name': name, 'target': target, 'nick': nick});
    final sp = Space.fromInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spaces[sp.id] = sp;
    s.spacesChanged();
    return sp;
  }

  static Future<Space> join(AppStore s, String code, {String nick = ''}) async {
    final j = await _call(s, '/api/space/join', {'code': code, 'nick': nick});
    final sp = Space.fromInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spaces[sp.id] = s.spaces[sp.id] ?? sp;
    s.spaces[sp.id]!.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
    await sync(s, s.spaces[sp.id]!);
    return s.spaces[sp.id]!;
  }

  static Future<void> update(AppStore s, Space sp, {String? name, int? target, String? nick}) async {
    final j = await _call(s, '/api/space/update', {
      'space': sp.id,
      if (name != null) 'name': name,
      if (target != null) 'target': target,
      if (nick != null) 'nick': nick,
    });
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  static Future<void> leave(AppStore s, Space sp) async {
    await _call(s, '/api/space/leave', {'space': sp.id});
    s.spaces.remove(sp.id);
    s.spacesChanged();
  }

  /// Gửi khoản mới / sửa / xóa (changes) và nhận khoản người khác vừa ghi.
  static Future<void> sync(AppStore s, Space sp, {List<SpaceEntry> changes = const []}) async {
    var more = true;
    var first = true;
    while (more) {
      final j = await _call(s, '/api/space/sync', {
        'space': sp.id,
        'since': sp.cursor,
        if (first) 'changes': [for (final e in changes) {'id': e.id, 'data': e.toData(), 'u': e.u, 'del': e.del}],
      });
      first = false;
      if (j['space'] is Map) sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
      for (final r in (j['records'] as List? ?? const [])) {
        final e = SpaceEntry.fromRecord(Map<String, dynamic>.from(r as Map));
        sp.entries[e.id] = e;
      }
      sp.cursor = ((j['cursor'] as num?) ?? sp.cursor).toInt();
      more = j['more'] == true;
    }
    s.spacesChanged();
  }

  /// Ghi một khoản vào quỹ (có thể ghi luôn vào sổ cá nhân).
  static Future<void> add(AppStore s, Space sp, SpaceEntry e, {String? personalWallet}) async {
    sp.entries[e.id] = e;
    s.spacesChanged();
    if (personalWallet != null) {
      s.saveTxn(Txn(
        id: newId(),
        amount: e.amount,
        income: false,
        // nộp quỹ: tiền rời ví cá nhân sang quỹ (trung gian, không tính là tiêu); chi từ quỹ bằng tiền túi: tính là chi
        categoryId: e.type == 'contrib' ? 'chuyen_vi' : (e.category.isEmpty ? 'khac_chi' : e.category),
        walletId: personalWallet,
        date: e.date,
        note: '${e.type == 'contrib' ? 'Nộp quỹ' : 'Chi quỹ'} ${sp.name}${e.note.isEmpty ? '' : ' · ${e.note}'}',
        source: 'space',
      ));
    }
    await sync(s, sp, changes: [e]);
  }

  static Future<void> remove(AppStore s, Space sp, SpaceEntry e) async {
    e
      ..del = true
      ..u = nowMs();
    s.spacesChanged();
    await sync(s, sp, changes: [e]);
  }
}
