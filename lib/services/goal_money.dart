import 'dart:math';

import '../models.dart';
import '../store.dart';
import '../util/vietqr.dart';

/// Tiền của mục tiêu: bỏ vào bằng mã VietQR sang tài khoản tiết kiệm riêng, tự xác nhận khi thông báo
/// ngân hàng báo tiền đã đi, rút ra phải có lý do. Tác giả: Phạm Thành Long (thlong).
class GoalMoney {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String ensureCode(AppStore s, Goal g) {
    if (g.code.isNotEmpty) return g.code;
    final r = Random.secure();
    String c;
    do {
      c = List.generate(4, (_) => _chars[r.nextInt(_chars.length)]).join();
    } while (s.goals.values.any((x) => x.code == c));
    g.code = c;
    return c;
  }

  static String memo(Goal g) => 'VTG ${g.code} ${plainMemo(g.name).toUpperCase()}'.trim();

  static String qr(Goal g, int amount) => vietQrPayload(bin: g.bin, acct: g.acct, amount: amount, memo: memo(g));

  /// Ghi giao dịch "chuyển sang hũ" trong ví (không tính là chi tiêu).
  static Txn _transfer(AppStore s, Goal g, int amount, String walletId, {required bool toGoal}) {
    final t = Txn(
      id: newId(),
      amount: amount,
      income: !toGoal,
      categoryId: 'chuyen_vi',
      walletId: walletId,
      date: DateTime.now(),
      note: toGoal ? 'Cất vào "${g.name}"' : 'Rút từ "${g.name}"',
      source: 'goal',
    );
    s.saveTxn(t);
    return t;
  }

  /// Bỏ tiền vào. Mục tiêu có tài khoản riêng: [confirmed] = false nghĩa là mới tạo mã QR, chờ tiền đi thật.
  static GoalMove deposit(AppStore s, Goal g, int amount, {bool confirmed = true, String? fromWallet}) {
    final m = GoalMove(id: newId(), amount: amount, at: nowMs(), status: confirmed ? 'ok' : 'pending');
    if (confirmed) {
      g.saved += amount;
      if (g.hold == 'bank' && fromWallet != null) m.txnId = _transfer(s, g, amount, fromWallet, toGoal: true).id;
    }
    g.moves.add(m);
    s.saveGoal(g);
    return m;
  }

  /// Người dùng bấm "Tôi đã chuyển" cho một khoản đang chờ.
  static void confirm(AppStore s, Goal g, GoalMove m, {String? fromWallet}) {
    if (m.status == 'ok') return;
    m.status = 'ok';
    g.saved += m.amount;
    if (g.hold == 'bank' && fromWallet != null) m.txnId = _transfer(s, g, m.amount, fromWallet, toGoal: true).id;
    s.saveGoal(g);
  }

  static void cancel(AppStore s, Goal g, GoalMove m) {
    g.moves.remove(m);
    s.saveGoal(g);
  }

  static void withdraw(AppStore s, Goal g, int amount, String reason, {String? toWallet}) {
    final v = amount > g.saved ? g.saved : amount;
    final m = GoalMove(id: newId(), amount: -v, at: nowMs(), reason: reason);
    g.saved -= v;
    if (g.hold == 'bank' && toWallet != null) m.txnId = _transfer(s, g, v, toWallet, toGoal: false).id;
    g.moves.add(m);
    s.saveGoal(g);
  }

  /// Đối chiếu số dư thật của tài khoản tiết kiệm / phong bì với số trên sổ.
  static void reconcile(AppStore s, Goal g, int actual) {
    final gap = actual - g.saved;
    if (gap != 0) g.moves.add(GoalMove(id: newId(), amount: gap, at: nowMs(), reason: 'Đối chiếu: số dư thật ${actual}đ'));
    g.saved = actual < 0 ? 0 : actual;
    g.reconAt = nowMs();
    s.saveGoal(g);
  }

  /// Tốc độ để dành trung bình (đồng / ngày) trong 90 ngày qua, để tính khoản rút làm mục tiêu lùi bao lâu.
  static double dailyRate(Goal g) {
    final from = nowMs() - 90 * 86400000;
    final ins = g.moves.where((m) => m.amount > 0 && m.status == 'ok' && m.at >= from && !m.reason.startsWith('Đối chiếu'));
    if (ins.isEmpty) return 0;
    final first = ins.map((m) => m.at).reduce(min);
    final days = ((nowMs() - first) / 86400000).clamp(30, 90);
    return ins.fold<int>(0, (t, m) => t + m.amount) / days;
  }

  static bool needsRecon(Goal g) => g.separate && g.saved > 0 && nowMs() - (g.reconAt > 0 ? g.reconAt : _firstMove(g)) > 30 * 86400000;

  static int _firstMove(Goal g) => g.moves.isEmpty ? nowMs() : g.moves.map((m) => m.at).reduce(min);

  /// Thông báo ngân hàng vừa ghi một khoản chi có nội dung "VTG <mã>": đó là tiền chuyển sang hũ mục tiêu.
  /// Đổi giao dịch thành "chuyển sang hũ" (không tính chi tiêu) và xác nhận khoản đang chờ.
  static Goal? autoMatch(AppStore s, Txn t) {
    if (t.income) return null;
    final memo = findVtMemo('${t.raw} ${t.note}', prefix: 'G');
    if (memo == null) return null;
    Goal? g;
    for (final x in s.activeGoals) {
      if (x.code == memo.a) g = x;
    }
    if (g == null) return null;
    t
      ..categoryId = 'chuyen_vi'
      ..note = 'Cất vào "${g.name}"';
    s.saveTxn(t);
    final waiting = g.pending.where((m) => m.amount == t.amount).toList();
    if (waiting.isNotEmpty) {
      final m = waiting.first
        ..status = 'ok'
        ..txnId = t.id;
      g.saved += m.amount;
    } else {
      // đã bấm "Tôi đã chuyển" trước khi thông báo về: bỏ giao dịch ghi tay để không bị trừ hai lần
      final cutoff = nowMs() - 3 * 86400000;
      final manual = g.moves.where((m) => m.status == 'ok' && m.amount == t.amount && m.at > cutoff && m.txnId.isNotEmpty).toList();
      final dup = manual.where((m) => s.txns[m.txnId]?.source == 'goal').toList();
      if (dup.isNotEmpty) {
        s.deleteTxn(dup.last.txnId);
        dup.last.txnId = t.id;
      } else {
        g.saved += t.amount;
        g.moves.add(GoalMove(id: newId(), amount: t.amount, at: nowMs(), txnId: t.id, reason: 'Tự ghi từ thông báo ngân hàng'));
      }
    }
    s.saveGoal(g);
    return g;
  }
}
