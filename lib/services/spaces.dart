import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../store.dart';
import '../util/vietqr.dart';

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
  String tag; // 4 ký tự trong nội dung chuyển khoản "VT <mã quỹ> <tag>" để tự khớp khi tiền về
  bool ask; // khoản chi cần người khác duyệt
  int? proofAi; // số tiền AI đọc được trên ảnh chứng từ
  Map<int, String> marks; // userId -> confirm | reject | approve | deny

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
    this.tag = '',
    this.ask = false,
    this.proofAi,
    Map<int, String>? marks,
  })  : u = u ?? nowMs(),
        marks = marks ?? {};

  bool get hasProof => proofAi != null;

  /// Ảnh chứng từ lệch số khai (quá 2% hoặc 1.000 ₫).
  bool get proofOff => proofAi != null && (proofAi! - amount).abs() > (amount * 0.02 > 1000 ? amount * 0.02 : 1000);

  Map<String, dynamic> toData() => {
        'type': type,
        'amount': amount,
        'note': note,
        'cat': category,
        'date': date.millisecondsSinceEpoch,
        if (tag.isNotEmpty) 'tag': tag,
        if (ask) 'ask': true,
        if (tag.isNotEmpty && type == 'contrib') 'pending': true,
        if (proofAi != null) 'proofAi': proofAi,
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
      tag: '${d['tag'] ?? ''}',
      ask: d['ask'] == true,
      proofAi: (d['proofAi'] as num?)?.toInt(),
      marks: {
        for (final m in ((r['marks'] as Map?) ?? const {}).entries)
          if (int.tryParse('${m.key}') != null) int.parse('${m.key}'): '${m.value}'
      },
    );
  }

  Map<String, dynamic> toCache() => {
        'id': id,
        'by': by,
        'data': toData(),
        'u': u,
        'del': del,
        'marks': {for (final m in marks.entries) '${m.key}': m.value},
      };
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
  // Cài đặt kiểm chứng
  int holder = 0; // thủ quỹ (0 = không có, ai khai nấy chịu)
  String bankBin = '', bankName = '', bankAcct = '', bankOwner = '';
  int approveOver = 0; // khoản chi lớn hơn mức này cần người khác duyệt (0 = tắt)
  ({int actual, int book, int at, int by})? recon;

  Space({required this.id, required this.name, required this.code, required this.owner, this.target = 0, this.members = const []});

  void applyInfo(Map<String, dynamic> j) {
    name = '${j['name'] ?? name}';
    code = '${j['code'] ?? code}';
    owner = ((j['owner'] as num?) ?? owner).toInt();
    target = ((j['target'] as num?) ?? target).toInt();
    final st = Map<String, dynamic>.from((j['settings'] as Map?) ?? const {});
    holder = ((st['holder'] as num?) ?? 0).toInt();
    final bk = st['bank'] is Map ? Map<String, dynamic>.from(st['bank'] as Map) : const <String, dynamic>{};
    bankBin = '${bk['bin'] ?? ''}';
    bankName = '${bk['name'] ?? ''}';
    bankAcct = '${bk['acct'] ?? ''}';
    bankOwner = '${bk['owner'] ?? ''}';
    approveOver = ((st['approveOver'] as num?) ?? 0).toInt();
    final rc = st['recon'] is Map ? Map<String, dynamic>.from(st['recon'] as Map) : null;
    recon = rc == null
        ? null
        : (
            actual: ((rc['actual'] as num?) ?? 0).toInt(),
            book: ((rc['book'] as num?) ?? 0).toInt(),
            at: ((rc['at'] as num?) ?? 0).toInt(),
            by: ((rc['by'] as num?) ?? 0).toInt(),
          );
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
  List<SpaceEntry> get removed => entries.values.where((e) => e.del).toList()..sort((a, b) => b.u.compareTo(a.u));

  bool get hasBank => bankBin.isNotEmpty && bankAcct.isNotEmpty;

  /// Người xác nhận tiền nộp vào: thủ quỹ; không có thủ quỹ thì không cần xác nhận.
  bool needsConfirm(SpaceEntry e) => e.type == 'contrib' && holder != 0 && e.by != holder;
  bool needsApproval(SpaceEntry e) => e.type == 'spend' && (e.ask || (approveOver > 0 && e.amount > approveOver)) && members.length > 1;

  /// ok | pending (chờ thủ quỹ) | rejected | await (chờ duyệt) | denied
  String statusOf(SpaceEntry e) {
    if (needsConfirm(e)) {
      final m = e.marks[holder];
      if (m == 'confirm') return 'ok';
      if (m == 'reject') return 'rejected';
      return 'pending';
    }
    if (needsApproval(e)) {
      final others = e.marks.entries.where((m) => m.key != e.by).map((m) => m.value);
      if (others.contains('deny')) return 'denied';
      if (others.contains('approve')) return 'ok';
      return 'await';
    }
    return 'ok';
  }

  List<SpaceEntry> get counted => active.where((e) => statusOf(e) == 'ok').toList();
  int get contributed => counted.where((e) => e.type == 'contrib').fold(0, (s, e) => s + e.amount);
  int get spent => counted.where((e) => e.type == 'spend').fold(0, (s, e) => s + e.amount);
  int get balance => contributed - spent;
  int get pendingIn => active.where((e) => statusOf(e) == 'pending').fold(0, (s, e) => s + e.amount);
  int get awaiting => active.where((e) => statusOf(e) == 'await').length;
  int get flagged => active.where((e) => e.proofOff).length;

  /// Việc đang chờ chính tôi: thủ quỹ xác nhận tiền vào, thành viên duyệt khoản chi.
  List<SpaceEntry> todoFor(int me) => [
        for (final e in active)
          if ((statusOf(e) == 'pending' && me == holder) || (statusOf(e) == 'await' && e.by != me && !e.marks.containsKey(me))) e
      ];

  String nameOf(int userId) {
    for (final m in members) {
      if (m.id == userId) return m.name;
    }
    return 'Thành viên cũ';
  }

  /// Mỗi người đã nộp / đã chi bao nhiêu.
  Map<int, ({int contrib, int spent})> perMember() {
    final out = <int, ({int contrib, int spent})>{for (final m in members) m.id: (contrib: 0, spent: 0)};
    for (final e in counted) {
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
        'settings': {
          'holder': holder,
          if (hasBank) 'bank': {'bin': bankBin, 'name': bankName, 'acct': bankAcct, 'owner': bankOwner},
          'approveOver': approveOver,
          if (recon != null) 'recon': {'actual': recon!.actual, 'book': recon!.book, 'at': recon!.at, 'by': recon!.by},
        },
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

  /// Sửa số tiền / ghi chú khoản của chính mình (các xác nhận cũ bị gỡ, cả nhóm được báo).
  static Future<void> edit(AppStore s, Space sp, SpaceEntry e, {int? amount, String? note}) async {
    if (amount != null && amount != e.amount) {
      e.amount = amount;
      e.marks.clear();
      e.proofAi = null;
    }
    if (note != null) e.note = note;
    e.u = nowMs();
    s.spacesChanged();
    await sync(s, sp, changes: [e]);
  }

  static Future<void> settings(AppStore s, Space sp, {int? holder, Map<String, String>? bank, bool clearBank = false, int? approveOver}) async {
    final j = await _call(s, '/api/space/settings', {
      'space': sp.id,
      if (holder != null) 'holder': holder,
      if (bank != null || clearBank) 'bank': bank,
      if (approveOver != null) 'approveOver': approveOver,
    });
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  /// confirm / reject (thủ quỹ) · approve / deny (người khác người chi) · clear
  static Future<void> mark(AppStore s, Space sp, SpaceEntry e, String kind, {bool auto = false}) async {
    await _call(s, '/api/space/mark', {'space': sp.id, 'rec': e.id, 'kind': kind, if (auto) 'auto': true});
    if (kind == 'clear') {
      e.marks.remove(s.myUserId);
    } else {
      e.marks[s.myUserId] = kind;
    }
    s.spacesChanged();
    await sync(s, sp);
  }

  static Future<void> reconcile(AppStore s, Space sp, int actual) async {
    final j = await _call(s, '/api/space/recon', {'space': sp.id, 'actual': actual, 'book': sp.balance});
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  static Future<List<({int at, int by, String action, String text})>> log(AppStore s, Space sp) async {
    final j = await _call(s, '/api/space/log?space=${sp.id}');
    return [
      for (final r in (j['log'] as List? ?? const []))
        if (r is Map)
          (
            at: ((r['at'] as num?) ?? 0).toInt(),
            by: ((r['by'] as num?) ?? 0).toInt(),
            action: '${r['action'] ?? ''}',
            text: '${r['text'] ?? ''}',
          )
    ];
  }

  /// Tải ảnh chứng từ (base64 JPEG) và số tiền AI đọc được lên quỹ.
  static Future<void> attachProof(AppStore s, Space sp, SpaceEntry e, String imgB64, int? aiAmount) async {
    await _call(s, '/api/space/proof', {'space': sp.id, 'rec': e.id, 'img': imgB64});
    e.proofAi = aiAmount ?? e.amount;
    e.u = nowMs();
    s.spacesChanged();
    await sync(s, sp, changes: [e]);
  }

  /// Nhờ AI đọc tổng tiền trên ảnh chứng từ (dùng chung máy đọc hóa đơn của server).
  static Future<int?> readAmount(AppStore s, List<int> bytes) async {
    try {
      final now = DateTime.now();
      final r = await http
          .post(Uri.parse('${s.serverUrl}/api/receipt'),
              headers: _h(s),
              body: jsonEncode({
                'image': base64Encode(bytes),
                'mime': 'image/jpeg',
                'today': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
              }))
          .timeout(const Duration(seconds: 60));
      final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
      if (j['found'] != true) return null;
      return (j['amount'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> proof(AppStore s, Space sp, SpaceEntry e) async {
    try {
      final j = await _call(s, '/api/space/proof?space=${sp.id}&rec=${Uri.encodeComponent(e.id)}');
      return j['img'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Thủ quỹ trên Android: thông báo ngân hàng có "VT <mã quỹ> <tag>" (hoặc đúng số tiền một khoản đang chờ)
  /// thì tự xác nhận đã nhận. Trả về khoản đã khớp để ghi giao dịch cá nhân là "nhận hộ quỹ".
  static Future<({Space sp, SpaceEntry e})?> autoConfirm(AppStore s, {required int amount, required String text}) async {
    final memo = findVtMemo(text);
    if (memo == null) return null;
    for (final sp in s.spaces.values) {
      if (sp.code != memo.a || sp.holder != s.myUserId) continue;
      final waiting = sp.active.where((e) => sp.statusOf(e) == 'pending' && e.amount == amount).toList();
      SpaceEntry? hit;
      for (final e in waiting) {
        if (e.tag == memo.b) hit = e;
      }
      hit ??= waiting.length == 1 ? waiting.first : null;
      if (hit == null) {
        // chưa đồng bộ khoản mới: tải về rồi thử lại
        try {
          await sync(s, sp);
        } catch (_) {}
        for (final e in sp.active) {
          if (sp.statusOf(e) == 'pending' && e.amount == amount && (e.tag == memo.b || memo.b.isEmpty)) hit = e;
        }
      }
      if (hit == null) return null;
      try {
        await mark(s, sp, hit, 'confirm', auto: true);
        return (sp: sp, e: hit);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> remove(AppStore s, Space sp, SpaceEntry e) async {
    e
      ..del = true
      ..u = nowMs();
    s.spacesChanged();
    await sync(s, sp, changes: [e]);
  }
}
