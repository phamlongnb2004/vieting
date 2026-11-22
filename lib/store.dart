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
import 'services/spaces.dart';
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
  final Map<String, Goal> goals = {};
  final Map<String, Challenge> challenges = {};
  final Map<String, Group> groups = {};
  final Map<String, Bill> bills = {};
  final Map<String, Wish> wishes = {};
  final Map<String, GiftEntry> gifts = {};
  int hourlyWage = 0; // 0 = tự tính từ thu nhập
  int noticeSeen = 0; // id thông báo admin đã tắt
  final Map<int, Space> spaces = {}; // Quỹ chung kết nối tài khoản (dữ liệu trên server, bản sao trên máy)
  int myUserId = 0;
  // Số dư ngân hàng báo về lần gần nhất, để phát hiện sổ lệch với tài khoản thật (có khoản chưa ghi)
  final Map<String, ({int bal, int at})> bankBal = {};
  int savePct = 10; // Quỹ tiêu thoải mái: % thu nhập trích tiết kiệm đầu kỳ
  int incomePlan = 0; // thu nhập dự kiến mỗi kỳ; 0 = tự tính
  Map<String, dynamic>? notice; // thông báo admin đang hiện
  Map<String, dynamic> remote = {}; // cấu hình từ server (/api/config): thử thách, gói định kỳ, tỷ giá, lãi suất, nhắc tự động...
  bool remindersOn = true;
  int lastOpen = 0; // lần mở app gần nhất (ms)
  bool revealHidden = false; // đã mở khóa xem khoản riêng tư (chỉ trong phiên)
  String pinHash = ''; // khóa app (chỉ trên máy này)
  bool bioLock = false;
  final List<Map<String, int>> _recentSigs = []; // chống ghi trùng: {sig, t}
  Set<String> allowedApps = {};

  bool dark = false;
  int cycleDay = 1; // ngày bắt đầu kỳ chi tiêu (ngày nhận lương)
  String aiTone = 'funny'; // gentle | funny (Gen Z) | strict | expert
  Set<String> skipDays = {}; // ngày ngoại lệ (yyyy-mm-dd) không tính vào chuỗi
  Set<String> sweptDays = {}; // ngày đã cất tiền dư vào hũ
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
        for (final e in (j['goals'] as List? ?? [])) {
          final g = Goal.fromJson(Map<String, dynamic>.from(e as Map));
          goals[g.id] = g;
        }
        for (final e in (j['challenges'] as List? ?? [])) {
          final c = Challenge.fromJson(Map<String, dynamic>.from(e as Map));
          challenges[c.id] = c;
        }
        for (final e in (j['groups'] as List? ?? [])) {
          final g = Group.fromJson(Map<String, dynamic>.from(e as Map));
          groups[g.id] = g;
        }
        for (final e in (j['bills'] as List? ?? [])) {
          final b = Bill.fromJson(Map<String, dynamic>.from(e as Map));
          bills[b.id] = b;
        }
        for (final e in (j['wishes'] as List? ?? [])) {
          final w = Wish.fromJson(Map<String, dynamic>.from(e as Map));
          wishes[w.id] = w;
        }
        for (final e in (j['gifts'] as List? ?? [])) {
          final g = GiftEntry.fromJson(Map<String, dynamic>.from(e as Map));
          gifts[g.id] = g;
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
        pinHash = (s['pin'] ?? '') as String;
        cycleDay = ((s['cycle'] as num?)?.toInt() ?? 1).clamp(1, 28);
        aiTone = (s['tone'] ?? 'funny') as String;
        hourlyWage = (s['wage'] as num?)?.toInt() ?? 0;
        noticeSeen = (s['notice'] as num?)?.toInt() ?? 0;
        savePct = (s['savePct'] as num?)?.toInt() ?? 10;
        myUserId = (s['me'] as num?)?.toInt() ?? 0;
        for (final x in (s['spaces'] as List? ?? const [])) {
          if (x is Map) {
            final sp = Space.fromCache(Map<String, dynamic>.from(x));
            spaces[sp.id] = sp;
          }
        }
        for (final e in ((s['bankBal'] as Map?) ?? const {}).entries) {
          final v = e.value;
          if (v is List && v.length == 2) bankBal['${e.key}'] = (bal: (v[0] as num).toInt(), at: (v[1] as num).toInt());
        }
        incomePlan = (s['incomePlan'] as num?)?.toInt() ?? 0;
        remindersOn = s['remind'] != false;
        if (s['remote'] is Map) _applyRemote(Map<String, dynamic>.from(s['remote'] as Map), notify: false);
        skipDays = ((s['skip'] as List?) ?? []).map((e) => e.toString()).toSet();
        sweptDays = ((s['swept'] as List?) ?? []).map((e) => e.toString()).toSet();
        bioLock = s['bio'] == true;
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
        'goals': goals.values.map((e) => e.toJson()).toList(),
        'challenges': challenges.values.map((e) => e.toJson()).toList(),
        'groups': groups.values.map((e) => e.toJson()).toList(),
        'bills': bills.values.map((e) => e.toJson()).toList(),
        'wishes': wishes.values.map((e) => e.toJson()).toList(),
        'gifts': gifts.values.map((e) => e.toJson()).toList(),
        'settings': {
          'dark': dark,
          'server': serverUrl,
          'token': token,
          'email': email,
          'lastSync': lastSync,
          'lastPush': lastPush,
          'allowed': allowedApps.toList(),
          'pin': pinHash,
          'cycle': cycleDay,
          'tone': aiTone,
          'notice': noticeSeen,
          'savePct': savePct,
          'me': myUserId,
          'spaces': [for (final sp in spaces.values) sp.toCache()],
          'bankBal': {for (final e in bankBal.entries) e.key: [e.value.bal, e.value.at]},
          'incomePlan': incomePlan,
          'remind': remindersOn,
          'remote': remote,
          'wage': hourlyWage,
          'skip': skipDays.toList(),
          'swept': sweptDays.toList(),
          'bio': bioLock,
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

  // ---- Kỳ chi tiêu: mặc định theo tháng, hoặc theo ngày nhận lương (VD 10/11 – 9/12) ----

  ({int year, int month}) periodOf(DateTime d) {
    if (d.day >= cycleDay) return (year: d.year, month: d.month);
    final p = DateTime(d.year, d.month - 1);
    return (year: p.year, month: p.month);
  }

  ({int year, int month}) get currentPeriod => periodOf(DateTime.now());
  DateTime periodStart(int year, int month) => DateTime(year, month, cycleDay);
  DateTime periodEnd(int year, int month) => DateTime(year, month + 1, cycleDay);
  int periodDays(int year, int month) => periodEnd(year, month).difference(periodStart(year, month)).inDays;

  /// Số ngày còn lại của kỳ hiện tại, tính cả hôm nay.
  int get daysLeftInPeriod {
    final p = currentPeriod;
    final now = DateTime.now();
    return periodEnd(p.year, p.month).difference(DateTime(now.year, now.month, now.day)).inDays.clamp(1, 31);
  }

  String periodLabel(int year, int month) {
    if (cycleDay == 1) return 'Tháng $month/$year';
    final a = periodStart(year, month), b = periodEnd(year, month).subtract(const Duration(days: 1));
    return '${a.day}/${a.month} – ${b.day}/${b.month}/${b.year}';
  }

  void setCycleDay(int d) {
    cycleDay = d.clamp(1, 28);
    _changed(syncSoon: false);
  }

  void setAiTone(String t) {
    aiTone = t;
    _changed(syncSoon: false);
  }

  String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  bool isSkipDay(DateTime d) => skipDays.contains(dayKey(d));
  void markSwept(DateTime d, {String? key}) {
    sweptDays.add(key ?? dayKey(d));
    if (sweptDays.length > 120) sweptDays.remove(sweptDays.first);
    _changed(syncSoon: false);
  }

  void toggleSkipDay(DateTime d) {
    final k = dayKey(d);
    if (!skipDays.remove(k)) skipDays.add(k);
    _changed(syncSoon: false);
  }

  List<Txn> monthTxns(int year, int month) {
    final a = periodStart(year, month), b = periodEnd(year, month);
    return activeTxns.where((t) => !t.date.isBefore(a) && t.date.isBefore(b)).toList();
  }

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
      if (!countsInTotals(t.categoryId)) continue;
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
      if (t.income || !countsInTotals(t.categoryId)) continue;
      final k = t.hidden && !revealHidden ? 'khac_chi' : t.categoryId;
      m[k] = (m[k] ?? 0) + t.amount;
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
      if (t.income || !countsInTotals(t.categoryId)) continue;
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

  // ---------------- Mục tiêu, thử thách, sổ chung ----------------

  List<Goal> get activeGoals => goals.values.where((g) => !g.deleted).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void saveGoal(Goal g) {
    g.updatedAt = nowMs();
    goals[g.id] = g;
    _changed();
  }

  void deleteGoal(String id) {
    final g = goals[id];
    if (g == null) return;
    g.deleted = true;
    g.updatedAt = nowMs();
    _changed();
  }

  void startChallenge(String type) {
    for (final c in challenges.values) {
      if (!c.deleted) {
        c.deleted = true;
        c.updatedAt = nowMs();
      }
    }
    final c = Challenge(id: newId(), type: type, start: DateTime.now());
    challenges[c.id] = c;
    _changed();
  }

  void stopChallenge(String id) {
    final c = challenges[id];
    if (c == null) return;
    c.deleted = true;
    c.updatedAt = nowMs();
    _changed();
  }

  List<Group> get activeGroups => groups.values.where((g) => !g.deleted).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void saveGroup(Group g) {
    g.updatedAt = nowMs();
    groups[g.id] = g;
    _changed();
  }

  void deleteGroup(String id) {
    final g = groups[id];
    if (g == null) return;
    g.deleted = true;
    g.updatedAt = nowMs();
    _changed();
  }

  // ---------------- Khoản định kỳ, danh sách chờ, hiếu hỉ ----------------

  List<Bill> get activeBills => bills.values.where((b) => !b.deleted && !b.finished).toList()
    ..sort((a, b) => a.next.compareTo(b.next));

  void saveBill(Bill b) {
    b.updatedAt = nowMs();
    bills[b.id] = b;
    _changed();
  }

  void deleteBill(String id) {
    final b = bills[id];
    if (b == null) return;
    b.deleted = true;
    b.updatedAt = nowMs();
    _changed();
  }

  /// Đánh dấu đã trả kỳ này: ghi giao dịch, lùi hạn sang kỳ sau.
  Txn payBill(Bill b, {String? walletId}) {
    final wallets = activeWallets;
    final t = Txn(
      id: newId(),
      amount: b.amount,
      income: false,
      categoryId: b.categoryId,
      walletId: walletId ?? (wallets.any((w) => w.id == 'cash') ? 'cash' : wallets.first.id),
      date: DateTime.now(),
      note: b.isInstallment ? 'Trả góp: ${b.name}' : b.name,
      source: 'bill',
    );
    txns[t.id] = t;
    b.next = b.after(b.next);
    if (b.remaining != null) b.remaining = b.remaining! - 1;
    b.updatedAt = nowMs();
    _changed();
    return t;
  }

  List<Wish> get activeWishes => wishes.values.where((w) => !w.deleted).toList()
    ..sort((a, b) => b.created.compareTo(a.created));

  void saveWish(Wish w) {
    w.updatedAt = nowMs();
    wishes[w.id] = w;
    _changed();
  }

  List<GiftEntry> get activeGifts => gifts.values.where((g) => !g.deleted).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  void saveGift(GiftEntry g) {
    g.updatedAt = nowMs();
    gifts[g.id] = g;
    _changed();
  }

  void deleteGift(String id) {
    final g = gifts[id];
    if (g == null) return;
    g.deleted = true;
    g.updatedAt = nowMs();
    _changed();
  }

  /// Tải cấu hình admin cập nhật trên server: thông báo, từ điển, thử thách theo mùa, gói định kỳ,
  /// tỷ giá, lãi suất, gói Pro, nhắc tự động. Không cần cập nhật app. Lưu lại để dùng khi offline.
  Future<void> fetchConfig() async {
    if (serverUrl.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$serverUrl/api/config'),
          headers: {if (token.isNotEmpty) 'authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      _applyRemote(Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map));
      _scheduleSave();
    } catch (_) {}
  }

  Future<void> fetchNotice() => fetchConfig();

  void _applyRemote(Map<String, dynamic> j, {bool notify = true}) {
    remote = j;
    final n = j['notice'];
    notice = n is Map ? Map<String, dynamic>.from(n) : null;
    setRemoteDict([
      for (final e in (j['dict'] as List? ?? const []))
        if (e is Map) ('${e['k'] ?? ''}', '${e['c'] ?? ''}')
    ]);
    if (notify) notifyListeners();
  }

  List<Map<String, dynamic>> _remoteList(String k) =>
      [for (final e in (remote[k] as List? ?? const [])) if (e is Map) Map<String, dynamic>.from(e)];

  /// Thử thách / sự kiện theo mùa đang mở (admin tạo).
  List<Map<String, dynamic>> get campaigns {
    final now = nowMs();
    return _remoteList('campaigns').where((c) => ((c['end'] as num?) ?? 0) > now).toList();
  }

  /// Gói định kỳ phổ biến (admin cập nhật giá).
  List<Map<String, dynamic>> get catalog => _remoteList('catalog');

  /// Tỷ giá: mã ngoại tệ -> số đồng.
  Map<String, double> get fxRates {
    final m = (remote['fx'] as Map?)?['rates'] as Map?;
    return {if (m != null) for (final e in m.entries) '${e.key}': (e.value as num).toDouble()};
  }

  ({double saving6, double saving12, String note}) get savingRates {
    final r = (remote['rates'] as Map?) ?? const {};
    return (
      saving6: ((r['saving6'] as num?) ?? 4.5).toDouble(),
      saving12: ((r['saving12'] as num?) ?? 5.0).toDouble(),
      note: '${r['note'] ?? ''}',
    );
  }

  bool get isPro {
    final p = remote['plan'] as Map?;
    return p != null && p['plan'] == 'pro' && ((p['until'] as num?) ?? 0) > nowMs();
  }

  DateTime? get proUntil {
    final u = (remote['plan'] as Map?)?['until'] as num?;
    return u == null || u <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(u.toInt());
  }

  /// Lượt hỏi trợ lý hôm nay: {limit, left, pro}. null = chưa biết (chưa tải cấu hình).
  Map<String, dynamic>? get chatQuota => remote['chat'] is Map ? Map<String, dynamic>.from(remote['chat'] as Map) : null;

  void updateChatQuota(Map<String, dynamic> q) {
    remote = {...remote, 'chat': q};
    notifyListeners();
  }

  int get ticketsUnread => ((remote['ticketsUnread'] as num?) ?? 0).toInt();

  Map<String, dynamic> smartRule(String k) => Map<String, dynamic>.from(((remote['smart'] as Map?)?[k] as Map?) ?? const {});

  void setGuiltFree({required int income, required int pct}) {
    incomePlan = income < 0 ? 0 : income;
    savePct = pct.clamp(0, 90);
    _changed(syncSoon: false);
  }

  void spacesChanged() => _changed(syncSoon: false);

  /// Sổ đang lệch bao nhiêu so với số dư ngân hàng báo về gần nhất (dương: ngân hàng nhiều hơn sổ).
  List<({Wallet w, int gap, int at})> get balanceGaps {
    final out = <({Wallet w, int gap, int at})>[];
    final cutoff = nowMs() - 7 * 86400000;
    for (final e in bankBal.entries) {
      final w = wallets[e.key];
      if (w == null || w.deleted || e.value.at < cutoff) continue;
      // chỉ tính các khoản ghi tới thời điểm ngân hàng báo số dư
      var book = w.initial;
      for (final t in txns.values) {
        if (!t.deleted && t.walletId == w.id && t.date.millisecondsSinceEpoch <= e.value.at + 1000) book += t.signed;
      }
      final gap = e.value.bal - book;
      if (gap.abs() >= 1000) out.add((w: w, gap: gap, at: e.value.at));
    }
    return out;
  }

  /// Chấp nhận số dư ngân hàng là đúng: chỉnh số dư đầu của ví cho khớp.
  void acceptBankBalance(String walletId) {
    final g = balanceGaps.where((x) => x.w.id == walletId).firstOrNull;
    if (g == null) return;
    g.w.initial += g.gap;
    g.w.updatedAt = nowMs();
    _changed();
  }

  /// Đối chiếu tay (iPhone / ví không có thông báo): nhập số dư thật, trả về chênh lệch so với sổ.
  int reconcileWallet(Wallet w, int actual, {bool fix = false}) {
    final gap = actual - walletBalance(w);
    if (fix && gap != 0) {
      w.initial += gap;
      w.updatedAt = nowMs();
      _changed();
    }
    return gap;
  }

  void setRemindersOn(bool v) {
    remindersOn = v;
    _changed(syncSoon: false);
  }

  void markOpened() {
    lastOpen = nowMs();
  }

  void joinCampaign(Map<String, dynamic> c) {
    for (final x in challenges.values) {
      if (!x.deleted) {
        x.deleted = true;
        x.updatedAt = nowMs();
      }
    }
    final ch = Challenge(
      id: newId(),
      type: 'campaign',
      start: DateTime.now(),
      title: '${c['title'] ?? ''}',
      emoji: '${c['emoji'] ?? ''}',
      keywords: '${c['keywords'] ?? ''}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      category: '${c['category'] ?? ''}',
      dayCount: ((c['days'] as num?) ?? 7).toInt(),
    );
    challenges[ch.id] = ch;
    _changed();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$serverUrl$path'),
            headers: {'content-type': 'application/json', if (token.isNotEmpty) 'authorization': 'Bearer $token'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    if (r.statusCode >= 400) throw Exception(j['error'] ?? 'Lỗi ${r.statusCode}');
    return j;
  }

  /// Nhập mã khuyến mãi -> trả về số ngày Pro được tặng.
  Future<int> redeem(String code) async {
    final j = await _post('/api/redeem', {'code': code});
    remote = {...remote, 'plan': j['plan']};
    _changed(syncSoon: false);
    return ((j['days'] as num?) ?? 0).toInt();
  }

  Future<void> sendTicket(String feature, String body, {String contact = '', String app = ''}) =>
      _post('/api/ticket', {'feature': feature, 'body': body, 'contact': contact, 'app': app});

  Future<List<Map<String, dynamic>>> myTickets() async {
    if (token.isEmpty) return [];
    final r = await http.get(Uri.parse('$serverUrl/api/tickets'), headers: {'authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
    remote = {...remote, 'ticketsUnread': 0};
    notifyListeners();
    return [for (final e in (j['tickets'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
  }

  /// Nhờ AI bóc tách tin nhắn ví điện tử / ngân hàng mà bộ đọc có sẵn không hiểu.
  Future<List<Map<String, dynamic>>> aiParse(String text) async {
    final d = DateTime.now();
    final j = await _post('/api/parse', {
      'text': text,
      'today': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    });
    return [for (final e in (j['txns'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
  }

  /// Ghi các giao dịch AI đọc được (dán tin nhắn) vào ví đã chọn.
  List<Txn> addParsed(List<Map<String, dynamic>> list, {String? walletId}) {
    final out = <Txn>[];
    final wallets = activeWallets;
    for (final a in list) {
      final income = a['income'] == true;
      var cat = '${a['category'] ?? ''}';
      if (catById(cat).id != cat || catById(cat).income != income) {
        cat = guessCategory(income, '${a['note'] ?? ''}', learnedRules);
      }
      final now = DateTime.now();
      final d = DateTime.tryParse('${a['date'] ?? ''}');
      final date = d == null || sameDayDt(d, now) ? now : DateTime(d.year, d.month, d.day, 12);
      final t = Txn(
        id: newId(),
        amount: ((a['amount'] as num?) ?? 0).toInt(),
        income: income,
        categoryId: cat,
        walletId: walletId ?? (wallets.any((w) => w.id == 'cash') ? 'cash' : wallets.first.id),
        date: date,
        note: '${a['note'] ?? ''}',
        source: 'paste',
      );
      if (t.amount <= 0) continue;
      txns[t.id] = t;
      out.add(t);
    }
    if (out.isNotEmpty) _changed();
    return out;
  }

  static bool sameDayDt(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Báo AI đọc hóa đơn sai: chỉ gửi số AI đọc và số người dùng sửa (không gửi ảnh).
  Future<void> reportReceipt(Map<String, dynamic> ai, Map<String, dynamic> fixed, String comment) =>
      _post('/api/ocr-report', {'ai': ai, 'fixed': fixed, 'comment': comment});

  void dismissNotice() {
    final id = (notice?['id'] as num?)?.toInt() ?? 0;
    noticeSeen = id;
    _changed(syncSoon: false);
  }

  void setHourlyWage(int v) {
    hourlyWage = v < 0 ? 0 : v;
    _changed(syncSoon: false);
  }

  void setRevealHidden(bool v) {
    revealHidden = v;
    notifyListeners();
  }

  // ---------------- Khóa app ----------------

  static String hashPin(String pin) {
    // băm đơn giản kèm muối cố định: chỉ để không lưu mã PIN dạng chữ thường trên máy
    var h = 0x811c9dc5;
    for (final c in 'vieting:$pin'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  bool get locked => pinHash.isNotEmpty;

  void setPin(String? pin) {
    pinHash = pin == null || pin.isEmpty ? '' : hashPin(pin);
    if (pinHash.isEmpty) bioLock = false;
    _changed(syncSoon: false);
  }

  bool checkPin(String pin) => pinHash.isNotEmpty && hashPin(pin) == pinHash;

  void setBioLock(bool v) {
    bioLock = v;
    _changed(syncSoon: false);
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
      // Ví đã từng khớp với ngân hàng mà giờ lệch: có khoản chưa được ghi (tiêu thẻ khác, thông báo bị tắt...).
      // Không lặng lẽ sửa số dư nữa mà giữ lại để nhắc người dùng ghi khoản thiếu.
      final synced = bankBal.containsKey(wallet.id) ||
          txns.values.any((x) => x.id != t.id && !x.deleted && x.walletId == wallet.id && x.balanceAfter != null);
      final gap = parsed.balance! - walletBalance(wallet);
      if (!synced || gap.abs() < 1000) {
        wallet.initial += gap;
        wallet.updatedAt = nowMs();
      }
      bankBal[wallet.id] = (bal: parsed.balance!, at: n.time.millisecondsSinceEpoch);
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
    spaces.clear();
    myUserId = 0;
    bankBal.clear();
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
    for (final g in goals.values) {
      add('goal', g.id, g.toJson(), g.updatedAt, g.deleted);
    }
    for (final c in challenges.values) {
      add('challenge', c.id, c.toJson(), c.updatedAt, c.deleted);
    }
    for (final g in groups.values) {
      add('group', g.id, g.toJson(), g.updatedAt, g.deleted);
    }
    for (final b in bills.values) {
      add('bill', b.id, b.toJson(), b.updatedAt, b.deleted);
    }
    for (final w in wishes.values) {
      add('wish', w.id, w.toJson(), w.updatedAt, w.deleted);
    }
    for (final g in gifts.values) {
      add('gift', g.id, g.toJson(), g.updatedAt, g.deleted);
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
      case 'goal':
        if ((goals[id]?.updatedAt ?? -1) < u) goals[id] = Goal.fromJson(data)..updatedAt = u;
      case 'challenge':
        if ((challenges[id]?.updatedAt ?? -1) < u) challenges[id] = Challenge.fromJson(data)..updatedAt = u;
      case 'group':
        if ((groups[id]?.updatedAt ?? -1) < u) groups[id] = Group.fromJson(data)..updatedAt = u;
      case 'bill':
        if ((bills[id]?.updatedAt ?? -1) < u) bills[id] = Bill.fromJson(data)..updatedAt = u;
      case 'wish':
        if ((wishes[id]?.updatedAt ?? -1) < u) wishes[id] = Wish.fromJson(data)..updatedAt = u;
      case 'gift':
        if ((gifts[id]?.updatedAt ?? -1) < u) gifts[id] = GiftEntry.fromJson(data)..updatedAt = u;
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
