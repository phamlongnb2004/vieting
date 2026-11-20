import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'categories.dart';
import 'config.dart';
import 'models.dart';
import 'parser/bank_parser.dart';
import 'parser/banks.dart';

final _rnd = Random();
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

class IngestResult {
  final String status; // added | duplicate | skipped | unparsed
  final Txn? txn;
  const IngestResult(this.status, [this.txn]);
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// Toàn bộ dữ liệu app, lưu trong một file JSON trên máy. Đồng bộ (tùy chọn) qua server.
class AppStore extends ChangeNotifier {
  final Map<String, Txn> txns = {};
  final Map<String, Wallet> wallets = {};
  final Map<String, Budget> budgets = {};
  final Map<String, CatRule> rules = {};
  final List<NoticeLog> logs = [];
  final List<ChatMsg> chat = [];
  final List<Map<String, int>> _recentSigs = []; // chống ghi trùng: {sig, t}
  Set<String> allowedApps = {};

  bool dark = false;
  String serverUrl = kServerUrl;
  String token = '';
  String email = '';
  int lastSync = 0; // mốc thời gian server lần đồng bộ trước
  int lastPush = 0; // mốc thời gian máy lần đẩy trước
  bool syncing = false;
  String? syncError;

  File? _file;
  Timer? _saveTimer;
  Timer? _syncTimer;

  bool get loggedIn => token.isNotEmpty && serverUrl.isNotEmpty;

  // ---------------- Lưu / đọc ----------------

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      _file = File('${dir.path}${Platform.pathSeparator}vieting.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        for (final e in (j['txns'] as List? ?? [])) {
          final t = Txn.fromJson(Map<String, dynamic>.from(e as Map));
          txns[t.id] = t;
        }
        for (final e in (j['wallets'] as List? ?? [])) {
          final w = Wallet.fromJson(Map<String, dynamic>.from(e as Map));
          wallets[w.id] = w;
        }
        for (final e in (j['budgets'] as List? ?? [])) {
          final b = Budget.fromJson(Map<String, dynamic>.from(e as Map));
          budgets[b.id] = b;
        }
        for (final e in (j['rules'] as List? ?? [])) {
          final r = CatRule.fromJson(Map<String, dynamic>.from(e as Map));
          rules[r.id] = r;
        }
        for (final e in (j['logs'] as List? ?? [])) {
          logs.add(NoticeLog.fromJson(Map<String, dynamic>.from(e as Map)));
        }
        for (final e in (j['chat'] as List? ?? [])) {
          chat.add(ChatMsg.fromJson(Map<String, dynamic>.from(e as Map)));
        }
        for (final e in (j['sigs'] as List? ?? [])) {
          final m = Map<String, dynamic>.from(e as Map);
          _recentSigs.add({'s': (m['s'] as num).toInt(), 't': (m['t'] as num).toInt()});
        }
        final s = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
        dark = s['dark'] == true;
        if ((s['server'] as String? ?? '').isNotEmpty) serverUrl = s['server'] as String;
        token = (s['token'] ?? '') as String;
        email = (s['email'] ?? '') as String;
        lastSync = (s['lastSync'] as num?)?.toInt() ?? 0;
        lastPush = (s['lastPush'] as num?)?.toInt() ?? 0;
        allowedApps = ((s['allowed'] as List?) ?? []).map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('VieTing: không đọc được dữ liệu: $e');
    }
    if (activeWallets.isEmpty) {
      final w = Wallet(id: 'cash', name: 'Tiền mặt', kind: 'cash', color: 0xFF3E8E41);
      wallets[w.id] = w;
      _scheduleSave();
    }
    if (loggedIn) {
      _syncTimer = Timer(const Duration(seconds: 2), () => sync());
    }
  }

  Map<String, dynamic> _toJson() => {
        'v': 1,
        'txns': txns.values.map((e) => e.toJson()).toList(),
        'wallets': wallets.values.map((e) => e.toJson()).toList(),
        'budgets': budgets.values.map((e) => e.toJson()).toList(),
        'rules': rules.values.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
        'sigs': _recentSigs,
        'chat': chat.map((e) => e.toJson()).toList(),
        'settings': {
          'dark': dark,
          'server': serverUrl,
          'token': token,
          'email': email,
          'lastSync': lastSync,
          'lastPush': lastPush,
          'allowed': allowedApps.toList(),
        },
      };

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  Future<void> saveNow() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('VieTing: không lưu được: $e');
    }
  }

  void _changed({bool syncSoon = true}) {
    notifyListeners();
    _scheduleSave();
    if (syncSoon && loggedIn) {
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(seconds: 5), () => sync());
    }
  }

  // ---------------- Truy vấn ----------------

  List<Wallet> get activeWallets => wallets.values.where((w) => !w.deleted).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Txn> get activeTxns => txns.values.where((t) => !t.deleted).toList()..sort((a, b) => b.date.compareTo(a.date));

  List<Txn> monthTxns(int year, int month) =>
      activeTxns.where((t) => t.date.year == year && t.date.month == month).toList();

  int walletBalance(Wallet w) {
    var s = w.initial;
    for (final t in txns.values) {
      if (!t.deleted && t.walletId == w.id) s += t.signed;
    }
    return s;
  }

  int get totalBalance => activeWallets.fold(0, (s, w) => s + walletBalance(w));

  String walletName(String id) {
    final w = wallets[id];
    if (w == null) return 'Ví không rõ';
    return w.deleted ? '${w.name} (đã xóa)' : w.name;
  }

  ({int income, int expense}) monthTotals(int year, int month) {
    var i = 0, e = 0;
    for (final t in monthTxns(year, month)) {
      if (t.income) {
        i += t.amount;
      } else {
        e += t.amount;
      }
    }
    return (income: i, expense: e);
  }

  Map<String, int> expenseByCategory(int year, int month) {
    final m = <String, int>{};
    for (final t in monthTxns(year, month)) {
      if (!t.income) m[t.categoryId] = (m[t.categoryId] ?? 0) + t.amount;
    }
    return m;
  }

  /// Chi tiêu từng ngày trong [days] ngày gần nhất (cũ -> mới).
  List<({DateTime day, int expense})> dailyExpense(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final out = List.generate(days, (i) => start.add(Duration(days: i)));
    final sums = List.filled(days, 0);
    for (final t in activeTxns) {
      if (t.income) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final idx = d.difference(start).inDays;
      if (idx >= 0 && idx < days) sums[idx] += t.amount;
    }
    return [for (var i = 0; i < days; i++) (day: out[i], expense: sums[i])];
  }

  List<Budget> get activeBudgets => budgets.values.where((b) => !b.deleted && b.limit > 0).toList()
    ..sort((a, b) => a.id == 'all' ? -1 : (b.id == 'all' ? 1 : a.id.compareTo(b.id)));

  int spentFor(String budgetId, int year, int month) {
    if (budgetId == 'all') return monthTotals(year, month).expense;
    return expenseByCategory(year, month)[budgetId] ?? 0;
  }

  Map<String, String> get learnedRules =>
      {for (final r in rules.values) if (!r.deleted) r.id: r.categoryId};

  // ---------------- Sửa dữ liệu ----------------

  void saveTxn(Txn t) {
    t.updatedAt = nowMs();
    txns[t.id] = t;
    _changed();
  }

  void deleteTxn(String id) {
    final t = txns[id];
    if (t == null) return;
    t.deleted = true;
    t.updatedAt = nowMs();
    _changed();
  }

  void restoreTxn(String id) {
    final t = txns[id];
    if (t == null) return;
    t.deleted = false;
    t.updatedAt = nowMs();
    _changed();
  }

  void learnCategory(String note, String categoryId) {
    final key = ruleKey(note);
    if (key.isEmpty) return;
    rules[key] = CatRule(id: key, categoryId: categoryId);
    _changed();
  }

  void saveWallet(Wallet w, {int? currentBalance}) {
    wallets[w.id] = w;
    if (currentBalance != null) {
      w.initial = 0;
      w.initial = currentBalance - walletBalance(w);
    }
    w.updatedAt = nowMs();
    _changed();
  }

  bool walletHasTxns(String id) => txns.values.any((t) => !t.deleted && t.walletId == id);

  void deleteWallet(String id) {
    final w = wallets[id];
    if (w == null) return;
    w.deleted = true;
    w.updatedAt = nowMs();
    _changed();
  }

  void setBudget(String id, int limit) {
    budgets[id] = Budget(id: id, limit: limit, deleted: limit <= 0);
    _changed();
  }

  // ---------------- Trợ lý AI ----------------

  void setServerUrl(String url) {
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _changed(syncSoon: false);
  }

  void addChat(ChatMsg m) {
    chat.add(m);
    if (chat.length > 80) chat.removeRange(0, chat.length - 80);
    _changed(syncSoon: false);
  }

  void clearChat() {
    chat.clear();
    _changed(syncSoon: false);
  }

  /// Thực hiện hành động trợ lý đề xuất (sau khi người dùng bấm xác nhận). Trả về mô tả ngắn.
  String applyAction(ChatMsg msg, int index) {
    final a = msg.actions[index];
    String done;
    if (a['type'] == 'add_txn') {
      final income = a['income'] == true;
      var cat = (a['category'] ?? '') as String;
      if (catById(cat).id != cat || catById(cat).income != income) cat = income ? 'khac_thu' : 'khac_chi';
      var date = DateTime.now();
      final ds = (a['date'] ?? '') as String;
      final d = DateTime.tryParse(ds);
      if (d != null && !(d.year == date.year && d.month == date.month && d.day == date.day)) {
        date = DateTime(d.year, d.month, d.day, 12);
      }
      final wallets = activeWallets;
      final t = Txn(
        id: newId(),
        amount: (a['amount'] as num).toInt(),
        income: income,
        categoryId: cat,
        walletId: (a['wallet'] as String?) ?? (wallets.any((w) => w.id == 'cash') ? 'cash' : wallets.first.id),
        date: date,
        note: (a['note'] ?? '') as String,
        source: 'assistant',
      );
      txns[t.id] = t;
      done = 'txn:${t.id}';
    } else {
      final id = (a['category'] ?? 'all') as String;
      budgets[id] = Budget(id: id, limit: (a['limit'] as num).toInt(), deleted: (a['limit'] as num) <= 0);
      done = 'budget';
    }
    msg.status[index] = 'done';
    _changed();
    return done;
  }

  void skipAction(ChatMsg msg, int index) {
    msg.status[index] = 'skip';
    _changed(syncSoon: false);
  }

  void setDark(bool v) {
    dark = v;
    _changed(syncSoon: false);
  }

  // ---------------- Thông báo ngân hàng ----------------

  Wallet _walletForBank(BankInfo bank) {
    for (final w in wallets.values) {
      if (!w.deleted && w.bankId == bank.id) return w;
    }
    final isEwallet = const {'momo', 'zalopay', 'vtmoney', 'shopeepay'}.contains(bank.id);
    final w = Wallet(
      id: 'bank_${bank.id}',
      name: bank.name,
      kind: isEwallet ? 'ewallet' : 'bank',
      bankId: bank.id,
      color: isEwallet ? 0xFFA50064 : 0xFF152758,
    );
    w.deleted = false;
    wallets[w.id] = w;
    return w;
  }

  int _sig(ParsedTxn p) => Object.hash(p.income, p.amount, p.balance ?? -1);

  bool _isDuplicate(ParsedTxn p, DateTime time) {
    final t = time.millisecondsSinceEpoch;
    _recentSigs.removeWhere((e) => (t - e['t']!).abs() > 24 * 3600 * 1000);
    final s = _sig(p);
    // Cùng số tiền + cùng số dư trong 15 phút: trùng (SMS + app cùng báo). Không có số dư: trong 2 phút.
    final window = p.balance != null ? 15 * 60 * 1000 : 2 * 60 * 1000;
    return _recentSigs.any((e) => e['s'] == s && (t - e['t']!).abs() <= window);
  }

  /// Xử lý một thông báo: đọc số tiền, chống trùng, đoán danh mục, ghi giao dịch, cập nhật số dư ví.
  IngestResult ingest(RawNotice n, {bool force = false, String source = 'notify', String? walletId}) {
    if (!force && ignoredPackages.contains(n.package)) {
      return const IngestResult('skipped');
    }
    final parsed = BankParser.parse(n.full);
    if (parsed == null) {
      if (source == 'notify') _log(NoticeLog(n, 'unparsed'));
      return const IngestResult('unparsed');
    }
    BankInfo? bank = identifyBank(n.package, n.appName, n.title);
    final allowed = force || source != 'notify' || bank != null || allowedApps.contains(n.package);
    if (!allowed) {
      // App lạ: chỉ tự ghi khi thông báo có cả số dư (gần như chắc là ngân hàng)
      if (parsed.balance == null) {
        _log(NoticeLog(n, 'skipped'));
        return const IngestResult('skipped');
      }
    }
    if (source == 'notify' && _isDuplicate(parsed, n.time)) {
      _log(NoticeLog(n, 'duplicate'));
      return const IngestResult('duplicate');
    }

    Wallet wallet;
    if (walletId != null && wallets[walletId] != null) {
      wallet = wallets[walletId]!;
    } else {
      bank ??= source == 'notify' && !smsPackages.contains(n.package)
          ? BankInfo(n.package, n.appName.isEmpty ? n.package : n.appName)
          : null;
      wallet = bank != null ? _walletForBank(bank) : (activeWallets.isNotEmpty ? activeWallets.first : _walletForBank(const BankInfo('cash', 'Tiền mặt')));
    }

    final t = Txn(
      id: newId(),
      amount: parsed.amount,
      income: parsed.income,
      categoryId: guessCategory(parsed.income, parsed.note, learnedRules),
      walletId: wallet.id,
      date: n.time,
      note: parsed.note,
      source: source,
      raw: n.full,
      balanceAfter: parsed.balance,
    );
    txns[t.id] = t;
    if (parsed.balance != null) {
      // Khớp số dư ví với số dư ngân hàng báo về
      wallet.initial = 0;
      wallet.initial = parsed.balance! - walletBalance(wallet);
      wallet.updatedAt = nowMs();
    }
    _recentSigs.add({'s': _sig(parsed), 't': n.time.millisecondsSinceEpoch});
    if (_recentSigs.length > 200) _recentSigs.removeRange(0, _recentSigs.length - 200);
    if (source == 'notify') _log(NoticeLog(n, 'added', t.id), notify: false);
    _changed();
    return IngestResult('added', t);
  }

  void _log(NoticeLog l, {bool notify = true}) {
    logs.insert(0, l);
    if (logs.length > 150) logs.removeRange(150, logs.length);
    if (notify) _changed(syncSoon: false);
  }

  /// Cho phép một app lạ và xử lý lại các thông báo đã bỏ qua của app đó.
  int allowApp(String package) {
    allowedApps.add(package);
    var added = 0;
    for (final l in logs.where((l) => l.notice.package == package && l.status == 'skipped').toList()) {
      final r = ingest(l.notice, force: true);
      if (r.status == 'added') {
        logs.remove(l);
        added++;
      }
    }
    _changed();
    return added;
  }

  // ---------------- Đăng nhập & đồng bộ ----------------

  String get _base => serverUrl.replaceAll(RegExp(r'/+$'), '');

  Future<void> login(String server, String mail, String password, {bool register = false}) async {
    serverUrl = server.trim();
    final res = await http
        .post(Uri.parse('$_base/api/${register ? 'register' : 'login'}'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'email': mail.trim().toLowerCase(), 'password': password}))
        .timeout(const Duration(seconds: 20));
    final body = _decode(res.body);
    if (res.statusCode != 200) throw body['error'] ?? 'Lỗi server (${res.statusCode})';
    token = body['token'] as String;
    email = mail.trim().toLowerCase();
    lastSync = 0;
    lastPush = 0;
    _changed(syncSoon: false);
    await sync();
  }

  void logout() {
    token = '';
    email = '';
    lastSync = 0;
    lastPush = 0;
    _changed(syncSoon: false);
  }

  Map<String, dynamic> _decode(String s) {
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {'error': 'Server trả về dữ liệu không hợp lệ'};
    }
  }

  List<Map<String, dynamic>> _localChanges(int since) {
    final out = <Map<String, dynamic>>[];
    void add(String kind, String id, Map<String, dynamic> data, int u, bool del) {
      if (u > since) out.add({'kind': kind, 'id': id, 'data': data, 'u': u, 'del': del});
    }

    for (final t in txns.values) {
      add('txn', t.id, t.toJson(), t.updatedAt, t.deleted);
    }
    for (final w in wallets.values) {
      add('wallet', w.id, w.toJson(), w.updatedAt, w.deleted);
    }
    for (final b in budgets.values) {
      add('budget', b.id, b.toJson(), b.updatedAt, b.deleted);
    }
    for (final r in rules.values) {
      add('rule', r.id, r.toJson(), r.updatedAt, r.deleted);
    }
    return out;
  }

  void _apply(Map<String, dynamic> c) {
    final kind = c['kind'] as String;
    final data = Map<String, dynamic>.from(c['data'] as Map);
    final u = (c['u'] as num).toInt();
    final id = c['id'] as String;
    switch (kind) {
      case 'txn':
        if ((txns[id]?.updatedAt ?? -1) < u) txns[id] = Txn.fromJson(data)..updatedAt = u;
      case 'wallet':
        if ((wallets[id]?.updatedAt ?? -1) < u) wallets[id] = Wallet.fromJson(data)..updatedAt = u;
      case 'budget':
        if ((budgets[id]?.updatedAt ?? -1) < u) budgets[id] = Budget.fromJson(data)..updatedAt = u;
      case 'rule':
        if ((rules[id]?.updatedAt ?? -1) < u) rules[id] = CatRule.fromJson(data)..updatedAt = u;
    }
  }

  Future<void> sync() async {
    if (!loggedIn || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final started = nowMs();
      final changes = _localChanges(lastPush);
      var since = lastSync;
      var offset = 0;
      var more = false;
      do {
        final chunk = changes.sublist(offset, min(offset + 500, changes.length));
        offset += chunk.length;
        final res = await http
            .post(Uri.parse('$_base/api/sync'),
                headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
                body: jsonEncode({'since': since, 'changes': chunk}))
            .timeout(const Duration(seconds: 30));
        final body = _decode(res.body);
        if (res.statusCode == 401) {
          token = '';
          throw 'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại';
        }
        if (res.statusCode != 200) throw body['error'] ?? 'Lỗi server (${res.statusCode})';
        for (final c in (body['changes'] as List? ?? [])) {
          _apply(Map<String, dynamic>.from(c as Map));
        }
        since = (body['now'] as num).toInt();
        more = body['more'] == true;
      } while (offset < changes.length || more);
      lastSync = since;
      lastPush = started;
    } catch (e) {
      syncError = e.toString();
    } finally {
      syncing = false;
      notifyListeners();
      _scheduleSave();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
