import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../store.dart';
import '../util/format.dart';
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
  bool img; // có ảnh chứng từ
  bool? proofOk; // AI kiểm tra ảnh: đúng loại, đúng số tiền, đúng người nhận, còn mới, chưa dùng lại
  String proofWhy; // lý do không khớp (cho cả nhóm xem)
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
    this.img = false,
    this.proofOk,
    this.proofWhy = '',
    Map<int, String>? marks,
  })  : u = u ?? nowMs(),
        marks = marks ?? {};

  bool get hasProof => img || proofAi != null;

  /// Ảnh chứng từ lệch số khai (quá 2% hoặc 1.000 ₫).
  bool get proofOff =>
      proofOk == false || (proofAi != null && (proofAi! - amount).abs() > (amount * 0.02 > 1000 ? amount * 0.02 : 1000));

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
        if (img) 'img': true,
        if (proofOk != null) 'proofOk': proofOk,
        if (proofWhy.isNotEmpty) 'proofWhy': proofWhy,
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
      img: d['img'] == true,
      proofOk: d['proofOk'] is bool ? d['proofOk'] as bool : null,
      proofWhy: '${d['proofWhy'] ?? ''}',
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
  // Nối ngân hàng (SePay): số dư thật của tài khoản quỹ do ngân hàng báo
  bool linked = false;
  int? bankBalance;
  int bankBalanceAt = 0, bankSyncAt = 0;
  String bankError = '';
  // Thử thách số dư
  Map<String, dynamic>? challenge;
  // Bàn giao thủ quỹ, trần tiền một người giữ, nhắc đổi thủ quỹ
  Map<String, dynamic>? handover;
  int maxHold = 0, rotateDays = 0, holderSince = 0;

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
    linked = j['linked'] == true;
    final bl = st['bankLink'] is Map ? Map<String, dynamic>.from(st['bankLink'] as Map) : const <String, dynamic>{};
    bankBalance = (bl['balance'] as num?)?.toInt();
    bankBalanceAt = ((bl['balanceAt'] as num?) ?? 0).toInt();
    bankSyncAt = ((bl['lastSync'] as num?) ?? 0).toInt();
    bankError = '${bl['error'] ?? ''}';
    challenge = st['challenge'] is Map ? Map<String, dynamic>.from(st['challenge'] as Map) : null;
    handover = st['handover'] is Map ? Map<String, dynamic>.from(st['handover'] as Map) : null;
    maxHold = ((st['maxHold'] as num?) ?? 0).toInt();
    rotateDays = ((st['rotateDays'] as num?) ?? 0).toInt();
    holderSince = ((st['holderSince'] as num?) ?? 0).toInt();
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
  /// Khoản chi lớn / xin ý kiến, hoặc khoản có ảnh chứng từ không khớp (mà không có thủ quỹ xác nhận): cần người khác duyệt.
  bool needsApproval(SpaceEntry e) =>
      members.length > 1 &&
      !needsConfirm(e) &&
      ((e.type == 'spend' && (e.ask || (approveOver > 0 && e.amount > approveOver))) || e.proofOff);

  /// ok | pending (chờ thủ quỹ) | rejected | await (chờ duyệt) | denied
  String statusOf(SpaceEntry e) {
    if (needsConfirm(e) && linked) {
      if (e.marks[0] == 'bank') return 'ok';
      if (e.marks[holder] == 'reject') return 'rejected';
      return 'pending';
    }
    if (needsConfirm(e)) {
      if (e.marks[0] == 'bank') return 'ok';
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

  bool bankConfirmed(SpaceEntry e) => e.marks[0] == 'bank';

  /// Thử thách số dư đang chạy (chưa xong, chưa hết hạn).
  bool get challengeOpen {
    final c = challenge;
    if (c == null || c['passed'] == true || c['failed'] == true) return false;
    return nowMs() < ((c['exp'] as num?) ?? 0).toInt();
  }

  String nameOf(int userId) {
    if (userId == 0) return 'Ngân hàng';
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
        'linked': linked,
        'settings': {
          'holder': holder,
          'bankLink': {'balance': bankBalance, 'balanceAt': bankBalanceAt, 'lastSync': bankSyncAt, if (bankError.isNotEmpty) 'error': bankError},
          if (challenge != null) 'challenge': challenge,
          if (handover != null) 'handover': handover,
          'maxHold': maxHold,
          'rotateDays': rotateDays,
          'holderSince': holderSince,
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
      e.img = false;
      e.proofOk = null;
      e.proofWhy = '';
    }
    if (note != null) e.note = note;
    e.u = nowMs();
    s.spacesChanged();
    await sync(s, sp, changes: [e]);
  }

  static Future<void> settings(AppStore s, Space sp,
      {int? holder, Map<String, String>? bank, bool clearBank = false, int? approveOver, int? maxHold, int? rotateDays}) async {
    final j = await _call(s, '/api/space/settings', {
      'space': sp.id,
      'book': sp.balance,
      if (maxHold != null) 'maxHold': maxHold,
      if (rotateDays != null) 'rotateDays': rotateDays,
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

  static Future<String> bankLink(AppStore s, Space sp, String token) async {
    final j = await _call(s, '/api/space/bank-link', {'space': sp.id, 'token': token});
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
    await sync(s, sp);
    return '${j['note'] ?? ''}';
  }

  static Future<void> bankUnlink(AppStore s, Space sp) async {
    final j = await _call(s, '/api/space/bank-unlink', {'space': sp.id});
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  static Future<List<({String dir, int amount, String content, int? balance, int at, String rec})>> bankTxns(AppStore s, Space sp) async {
    final j = await _call(s, '/api/space/bank-txns?space=${sp.id}');
    if (j['space'] is Map) sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
    return [
      for (final t in (j['txns'] as List? ?? const []))
        if (t is Map)
          (
            dir: '${t['dir']}',
            amount: ((t['amount'] as num?) ?? 0).toInt(),
            content: '${t['content'] ?? ''}',
            balance: (t['balance'] as num?)?.toInt(),
            at: ((t['at'] as num?) ?? 0).toInt(),
            rec: '${t['rec'] ?? ''}',
          )
    ];
  }

  static Future<void> challenge(AppStore s, Space sp, Map<String, String> bank) async {
    final j = await _call(s, '/api/space/challenge', {'space': sp.id, 'bank': bank});
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  static Future<void> challengeDone(AppStore s, Space sp, String kind, {int? actual, bool auto = false}) async {
    final j = await _call(s, '/api/space/challenge-done', {
      'space': sp.id,
      'kind': kind,
      if (actual != null) 'actual': actual,
      'book': sp.balance,
      if (auto) 'auto': true,
    });
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  static Future<void> handover(AppStore s, Space sp, int actual) async {
    final j = await _call(s, '/api/space/handover', {'space': sp.id, 'actual': actual});
    sp.applyInfo(Map<String, dynamic>.from(j['space'] as Map));
    s.spacesChanged();
  }

  /// Android: máy người nộp vừa có thông báo ngân hàng TRỪ tiền đúng nội dung "VT <mã quỹ> <tag>" của khoản mình đang chờ,
  /// hoặc máy người yêu cầu thử thách vừa NHẬN 1.000 ₫ có mã "VT KT <mã>". Gửi lên làm bằng chứng.
  static Future<String?> autoEvidence(AppStore s, {required bool income, required int amount, required String text}) async {
    final f = plainMemo(text).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    for (final sp in s.spaces.values) {
      if (income) {
        final c = sp.challenge;
        if (sp.challengeOpen && c != null && ((c['by'] as num?) ?? 0).toInt() == s.myUserId && f.contains('VTKT${c['code']}')) {
          try {
            await challengeDone(s, sp, 'transfer', auto: true);
            return 'Thủ quỹ "${sp.name}" đã chuyển đúng mã thử thách: đang giữ đúng tài khoản quỹ';
          } catch (_) {}
        }
        continue;
      }
      if (!f.contains('VT${sp.code}')) continue;
      for (final e in sp.active) {
        if (e.by != s.myUserId || e.type != 'contrib' || e.amount != amount || e.marks[s.myUserId] == 'sent') continue;
        if (e.tag.isNotEmpty && !f.contains('VT${sp.code}${e.tag}')) continue;
        try {
          await mark(s, sp, e, 'sent');
          return 'Đã gửi thông báo trừ tiền ${groupDigits(amount)} ₫ làm bằng chứng nộp quỹ "${sp.name}"';
        } catch (_) {}
      }
    }
    return null;
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
    e.proofAi = aiAmount;
    e.img = true;
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

  /// AI kiểm tra ảnh chứng từ trên server (loại ảnh, số tiền, người nhận, nội dung, thời gian, dùng lại).
  static Future<ProofCheck> verify(AppStore s, Space sp,
      {required String recId, required List<int> bytes, required String type, required int amount, String tag = ''}) async {
    final j = await _call(s, '/api/space/verify', {
      'space': sp.id,
      'rec': recId,
      'img': base64Encode(bytes),
      'type': type,
      'amount': amount,
      'tag': tag,
    });
    final ai = Map<String, dynamic>.from((j['ai'] as Map?) ?? const {});
    return ProofCheck(
      amount: (ai['amount'] as num?)?.toInt(),
      kind: '${ai['kind'] ?? 'other'}',
      checks: [
        for (final c in (j['checks'] as List? ?? const []))
          if (c is Map) (id: '${c['id']}', ok: c['ok'] == true, text: '${c['text'] ?? ''}')
      ],
    );
  }

  /// Tải ảnh chứng từ lên TRƯỚC khi ghi khoản (bắt buộc có ảnh ngay từ đầu).
  static Future<void> uploadProof(AppStore s, Space sp, String recId, String imgB64) async {
    await _call(s, '/api/space/proof', {'space': sp.id, 'rec': recId, 'img': imgB64});
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

/// Kết quả AI kiểm tra một ảnh chứng từ.
class ProofCheck {
  final int? amount;
  final String kind;
  final List<({String id, bool ok, String text})> checks;
  const ProofCheck({this.amount, required this.kind, required this.checks});

  /// Các mục kiểm tra, với mục số tiền tính lại theo số người dùng nhập cuối cùng.
  List<({String id, bool ok, String text})> forAmount(int v) => [
        for (final c in checks)
          c.id == 'amount'
              ? (
                  id: 'amount',
                  ok: amount != null && amount == v,
                  text: amount == null
                      ? 'Không đọc được số tiền'
                      : amount == v
                          ? 'Đúng số tiền'
                          : 'Ảnh ghi ${groupDigits(amount!)} ₫, bạn khai ${groupDigits(v)} ₫',
                )
              : c
      ];

  bool okFor(int v) => forAmount(v).every((c) => c.ok);
  String whyFor(int v) => forAmount(v).where((c) => !c.ok).map((c) => c.text).join('; ');
}
