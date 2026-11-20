import 'categories.dart';
import 'models.dart';
import 'store.dart';
import 'util/format.dart';

/// Gợi ý khoản chi quen thuộc ở khung giờ hiện tại.
class Suggestion {
  final String note;
  final int amount;
  final String categoryId;
  final String walletId;
  final int count;
  const Suggestion(this.note, this.amount, this.categoryId, this.walletId, this.count);
}

/// Cảnh báo cố vấn sau khi ghi một khoản chi.
class Nudge {
  final String text;
  final bool serious;
  const Nudge(this.text, {this.serious = false});
}

int _median(List<int> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[s.length ~/ 2];
}

extension Insights on AppStore {
  // ---------------- Gợi ý theo khung giờ ----------------

  List<Suggestion> suggestionsAt(DateTime now, {int max = 3}) {
    final from = now.subtract(const Duration(days: 60));
    final groups = <String, List<Txn>>{};
    for (final t in activeTxns) {
      if (t.income || t.date.isBefore(from)) continue;
      final dh = (t.date.hour - now.hour).abs();
      if (dh > 1 && dh < 23) continue; // cùng khung giờ ±1h
      final key = '${t.categoryId}|${ruleKey(t.note)}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    final out = <Suggestion>[];
    groups.forEach((k, list) {
      if (list.length < 2) return;
      final last = list.first;
      out.add(Suggestion(
        last.note.isEmpty ? catById(last.categoryId).name : last.note,
        _median(list.map((t) => t.amount).toList()),
        last.categoryId,
        last.walletId,
        list.length,
      ));
    });
    out.sort((a, b) => b.count.compareTo(a.count));
    return out.take(max).toList();
  }

  // ---------------- Cảnh báo tức thì ----------------

  List<Nudge> nudgesFor(Txn t) {
    if (t.income || t.deleted) return const [];
    final out = <Nudge>[];
    final now = t.date;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (final id in [t.categoryId, 'all']) {
      final b = budgets[id];
      if (b == null || b.deleted || b.limit <= 0) continue;
      final spent = spentFor(id, now.year, now.month);
      final before = spent - t.amount;
      final name = id == 'all' ? 'tổng chi' : catById(id).name;
      if (spent > b.limit && before <= b.limit) {
        out.add(Nudge('Bạn vừa vượt ngân sách $name tháng này (${compactMoney(spent)}/${compactMoney(b.limit)}).', serious: true));
      } else if (spent >= b.limit * 0.8 && before < b.limit * 0.8) {
        final left = b.limit - spent;
        final perDay = left ~/ (daysInMonth - now.day + 1);
        out.add(Nudge('Ngân sách $name đã dùng ${(spent * 100 / b.limit).round()}%. Còn ${compactMoney(left)}, khoảng ${compactMoney(perDay)}/ngày.'));
      }
    }
    // Khoản chi lớn bất thường so với thường lệ của danh mục
    final from = now.subtract(const Duration(days: 60));
    final same = activeTxns
        .where((x) => !x.income && x.id != t.id && x.categoryId == t.categoryId && x.date.isAfter(from))
        .map((x) => x.amount)
        .toList();
    if (same.length >= 4) {
      final med = _median(same);
      if (med > 0 && t.amount >= med * 3 && t.amount >= 100000) {
        out.add(Nudge('Khoản này gấp ${(t.amount / med).toStringAsFixed(1)} lần mức thường chi cho ${catById(t.categoryId).name} (${compactMoney(med)}).'));
      }
    }
    // Tuần này chi nhiều hơn trung bình 4 tuần trước
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    int sumBetween(DateTime a, DateTime b) =>
        activeTxns.where((x) => !x.income && !x.date.isBefore(a) && x.date.isBefore(b)).fold(0, (s, x) => s + x.amount);
    final thisWeek = sumBetween(weekStart, weekStart.add(const Duration(days: 7)));
    var prev = 0;
    for (var i = 1; i <= 4; i++) {
      prev += sumBetween(weekStart.subtract(Duration(days: 7 * i)), weekStart.subtract(Duration(days: 7 * (i - 1))));
    }
    final avg = prev ~/ 4;
    if (avg > 0 && thisWeek > avg * 1.5 && thisWeek - t.amount <= avg * 1.5) {
      out.add(Nudge('Tuần này bạn đã chi ${compactMoney(thisWeek)}, nhiều hơn 50% so với trung bình (${compactMoney(avg)}/tuần).'));
    }
    if (t.tag == 'boc_dong') {
      final c = activeChallenge;
      if (c != null) out.add(const Nudge('Khoản bốc đồng này làm đứt thử thách 7 ngày. Thử lại lần sau nhé!', serious: true));
    }
    return out;
  }

  // ---------------- Thẻ cảm xúc ----------------

  Map<String, int> expenseByTag(int year, int month) {
    final m = <String, int>{};
    for (final t in monthTxns(year, month)) {
      if (!t.income && t.tag.isNotEmpty) m[t.tag] = (m[t.tag] ?? 0) + t.amount;
    }
    return m;
  }

  // ---------------- Chuỗi ngày giữ ngân sách ----------------

  /// Hạn mức chi mỗi ngày (từ ngân sách tổng tháng), null nếu chưa đặt.
  int? get dailyAllowance {
    final b = budgets['all'];
    if (b == null || b.deleted || b.limit <= 0) return null;
    final now = DateTime.now();
    return b.limit ~/ DateTime(now.year, now.month + 1, 0).day;
  }

  int _spentOn(DateTime d) => activeTxns
      .where((t) => !t.income && t.date.year == d.year && t.date.month == d.month && t.date.day == d.day)
      .fold(0, (s, t) => s + t.amount);

  /// Số ngày liên tiếp (tính đến hôm nay) chi không quá hạn mức ngày và không có khoản bốc đồng.
  int get streak {
    final limit = dailyAllowance;
    if (limit == null) return 0;
    final txs = activeTxns;
    if (txs.isEmpty) return 0;
    final first = txs.last.date;
    var d = DateTime.now();
    var n = 0;
    while (!DateTime(d.year, d.month, d.day).isBefore(DateTime(first.year, first.month, first.day))) {
      final impulsive = txs.any((t) =>
          t.tag == 'boc_dong' && t.date.year == d.year && t.date.month == d.month && t.date.day == d.day);
      if (_spentOn(d) > limit || impulsive) break;
      n++;
      d = d.subtract(const Duration(days: 1));
      if (n > 365) break;
    }
    return n;
  }

  // ---------------- Thử thách ----------------

  Challenge? get activeChallenge {
    final list = challenges.values.where((c) => !c.deleted).toList()..sort((a, b) => b.start.compareTo(a.start));
    if (list.isEmpty) return null;
    final c = list.first;
    if (DateTime.now().isAfter(c.end.add(const Duration(days: 3)))) return null;
    return c;
  }

  /// 'running' | 'failed' | 'done'
  String challengeStatus(Challenge c) {
    final bad = activeTxns.any((t) => t.tag == 'boc_dong' && !t.date.isBefore(c.start) && t.date.isBefore(c.end));
    if (bad) return 'failed';
    return DateTime.now().isAfter(c.end) ? 'done' : 'running';
  }

  int challengeDay(Challenge c) {
    final d = DateTime.now().difference(DateTime(c.start.year, c.start.month, c.start.day)).inDays + 1;
    return d.clamp(1, c.days);
  }

  // ---------------- Mô phỏng ----------------

  /// Giá trung bình các khoản có nội dung chứa [keyword] (bỏ dấu), dùng cho mô phỏng.
  int averagePriceFor(String keyword) {
    final k = ruleKey(keyword);
    if (k.isEmpty) return 0;
    final v = activeTxns.where((t) => !t.income && ruleKey(t.note).contains(k)).map((t) => t.amount).toList();
    return _median(v);
  }

  // ---------------- Xuất dữ liệu ----------------

  String exportCsv() {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('﻿Ngày,Giờ,Loại,Số tiền,Danh mục,Thẻ,Ví,Ghi chú,Nguồn\n');
    for (final t in activeTxns.reversed) {
      b.writeln([
        dmy(t.date),
        hm(t.date),
        t.income ? 'Thu' : 'Chi',
        t.signed,
        q(catById(t.categoryId).name),
        q(tagById(t.tag)?.name ?? ''),
        q(walletName(t.walletId)),
        q(t.note),
        t.source,
      ].join(','));
    }
    return b.toString();
  }
}
