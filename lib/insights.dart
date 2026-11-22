import 'categories.dart';
import 'models.dart';
import 'store.dart';
import 'util/text.dart';
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
  /// Chọn câu theo tính cách trợ lý người dùng chọn.
  String _tone({required String gentle, required String funny, required String strict, String? expert}) =>
      switch (aiTone) { 'funny' => funny, 'strict' => strict, 'expert' => expert ?? gentle, _ => gentle };

  /// Lời chào đầu trang Tổng quan: theo giờ + một câu bắt trend (đổi mỗi ngày).
  ({String hello, String quip}) get greeting {
    final now = DateTime.now();
    final h = now.hour;
    final hello = h < 5
        ? 'Khuya rồi, ngủ đi bestie'
        : h < 11
            ? 'Chào buổi sáng'
            : h < 14
                ? 'Trưa rồi, ăn gì chưa'
                : h < 18
                    ? 'Chiều an lành'
                    : h < 22
                        ? 'Tối vui vẻ nha'
                        : 'Khuya rồi, cất điện thoại thôi';
    final quips = aiTone == 'funny'
        ? const [
            'Hôm nay mình tiêu tiền có chủ đích, khum tiêu theo cảm xúc nha.',
            'Ví mỏng nhưng tinh thần dày, vẫn slay như thường.',
            'Nhắc nhẹ: giỏ hàng Shopee không phải là kế hoạch tiết kiệm.',
            'Mỗi lần ghi chép là một lần cứu ví khỏi bị ghost.',
            'Tiền không mọc trên cây, nhưng cây tre mục tiêu thì có lớn đó.',
            'Flex nhẹ bằng số dư, khum flex bằng thẻ tín dụng.',
            'Trà sữa hôm nay là nợ tương lai của ngày mai đó nha.',
            'Main character tiết kiệm trước, quẩy sau.',
          ]
        : const [
            'Mỗi khoản ghi lại là một bước gần hơn tới mục tiêu.',
            'Tiêu có kế hoạch, sống thong thả.',
            'Nhìn rõ dòng tiền, ngủ ngon hơn.',
            'Một chút tiết kiệm mỗi ngày, một khoản lớn cuối năm.',
          ];
    return (hello: hello, quip: quips[(now.day + now.month * 3) % quips.length]);
  }

  /// Một câu trạng thái theo tính cách trợ lý, hiện trên Tổng quan và widget màn hình chính.
  String get personaLine {
    final g = guiltFree;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final drinks = activeTxns
        .where((t) =>
            !t.income &&
            t.date.isAfter(weekAgo) &&
            RegExp(r'tra sua|milk ?tea|ca phe|cafe|coffee|highlands|phuc long|starbucks|katinat|cong ca|trung nguyen').hasMatch(fold(t.note)))
        .length;
    if (g != null && g.leftToday < 0) {
      return _tone(
        gentle: 'Hôm nay hơi quá tay ${compactMoney(-g.leftToday)}, mai mình tiết chế chút là ổn',
        funny: 'Ét o ét! Lố ${compactMoney(-g.leftToday)} rồi bestie ơi, ví đang xỉu ngang, khum cứu nổi đâu',
        strict: 'Tiêu lố ${compactMoney(-g.leftToday)} rồi! Từ giờ tới tối không chi thêm nữa nghe chưa',
        expert: 'Vượt hạn mức ngày ${compactMoney(-g.leftToday)}. Hạn mức các ngày còn lại sẽ giảm tương ứng.',
      );
    }
    if (drinks >= 4) {
      return _tone(
        gentle: 'Tuần này $drinks lần trà sữa / cà phê rồi, thử pha ở nhà vài hôm nhé',
        funny: '$drinks ly trà sữa / cà phê một tuần, máu bạn giờ toàn đường với trân châu, ví thì khô như tình cũ',
        strict: '$drinks ly trong một tuần! Trà sữa không phải bữa chính đâu con',
        expert: '$drinks lần đồ uống trong 7 ngày ≈ ${compactMoney(drinks * 45000 * 4)}/tháng nếu duy trì.',
      );
    }
    if (g != null) {
      return _tone(
        gentle: 'Hôm nay còn ${compactMoney(g.leftToday)} để tiêu thoải mái, không cần áy náy',
        funny: 'Còn ${compactMoney(g.leftToday)} để quẩy hôm nay, slay nhẹ thôi đừng flex quá tay nha',
        strict: 'Còn ${compactMoney(g.leftToday)}. Tiêu gì cũng phải ghi lại đấy!',
        expert: 'Hạn mức an toàn hôm nay: ${compactMoney(g.leftToday)} (đã trừ cố định & tiết kiệm).',
      );
    }
    return 'Nhập thu nhập để biết mỗi ngày được tiêu thoải mái bao nhiêu';
  }

  // ---------------- Gợi ý theo khung giờ ----------------

  List<Suggestion> suggestionsAt(DateTime now, {int max = 3}) {
    final from = now.subtract(const Duration(days: 60));
    final groups = <String, List<Txn>>{};
    for (final t in activeTxns) {
      if (t.income || t.date.isBefore(from) || !countsInTotals(t.categoryId)) continue;
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
    if (!countsInTotals(t.categoryId)) return const [];
    // Khoản chi lấn vào tiền đã cất cho mục tiêu
    final locked = lockedInGoals;
    if (locked > 0) {
      final spendable = spendableBalance;
      final goals = activeGoals.where((g) => g.saved > 0).toList()..sort((a, b) => b.saved.compareTo(a.saved));
      final gName = goals.isEmpty ? 'mục tiêu' : '"${goals.first.name}"';
      if (spendable < 0) {
        final eaten = -spendable > t.amount ? t.amount : -spendable;
        out.add(Nudge(
            _tone(
              gentle: 'Khoản này đã lấn ${compactMoney(eaten)} vào tiền bạn cất cho $gName. Nếu thật sự cần, nhớ rút khỏi hũ cho sổ sách khớp nhé.',
              funny: 'U là trời, ${compactMoney(eaten)} vừa bay là tiền hũ $gName đó! Cây tre đang héo, mục tiêu đang khóc ở góc phòng',
              strict: 'Dừng lại! Bạn vừa tiêu ${compactMoney(eaten)} của hũ $gName. Tiền mục tiêu không phải để tiêu.',
              expert: 'Số dư khả dụng âm ${compactMoney(-spendable)}: khoản chi này dùng tiền dành cho $gName. Cân nhắc rút hũ hoặc bù lại trong kỳ.',
            ),
            serious: true));
      } else if (spendable < t.amount) {
        out.add(Nudge('Chỉ còn ${compactMoney(spendable)} có thể tiêu, phần còn lại trong ví là tiền đã cất cho $gName.', serious: true));
      }
    }
    final now = t.date;
    final per = periodOf(now);
    final daysLeft = periodEnd(per.year, per.month).difference(DateTime(now.year, now.month, now.day)).inDays.clamp(1, 31);
    for (final id in [t.categoryId, 'all']) {
      final b = budgets[id];
      if (b == null || b.deleted || b.limit <= 0) continue;
      final spent = spentFor(id, per.year, per.month);
      final before = spent - t.amount;
      final name = id == 'all' ? 'tổng chi' : catById(id).name;
      if (spent > b.limit && before <= b.limit) {
        out.add(Nudge(_tone(
            gentle: 'Kỳ này mình tiêu cho $name hơi quá tay một chút (${compactMoney(spent)}/${compactMoney(b.limit)}). Không sao, tuần tới mình cùng điều chỉnh nhẹ nhé',
            funny: 'Ngân sách $name "bay màu" real rồi (${compactMoney(spent)}/${compactMoney(b.limit)}). Ví: "tui mệt quá, tui đi ngủ đây"',
            strict: 'Đã vượt ngân sách $name: ${compactMoney(spent)}/${compactMoney(b.limit)}. Dừng chi mục này đến hết kỳ!'), serious: true));
      } else if (spent >= b.limit * 0.8 && before < b.limit * 0.8) {
        final left = b.limit - spent;
        final perDay = left ~/ daysLeft;
        out.add(Nudge(_tone(
            gentle: 'Ngân sách $name đã dùng ${(spent * 100 / b.limit).round()}%. Còn ${compactMoney(left)}, mình chi khoảng ${compactMoney(perDay)}/ngày là vừa đẹp.',
            funny: '$name đã ngốn ${(spent * 100 / b.limit).round()}% ngân sách, còn ${compactMoney(left)}, tức ~${compactMoney(perDay)}/ngày. Ăn mì gói arc sắp bắt đầu',
            strict: 'Ngân sách $name đã dùng ${(spent * 100 / b.limit).round()}%. Chỉ được chi tối đa ${compactMoney(perDay)}/ngày.')));
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
        out.add(Nudge(_tone(
            gentle: 'Khoản này lớn hơn thường lệ (gấp ${(t.amount / med).toStringAsFixed(1)} lần mức hay chi cho ${catById(t.categoryId).name}). Nếu là dịp đặc biệt thì cứ thoải mái nhé.',
            funny: 'Gấp ${(t.amount / med).toStringAsFixed(1)} lần bình thường?! Hôm nay main character energy dữ vậy, có biến gì kể nghe coi',
            strict: 'Bất thường: gấp ${(t.amount / med).toStringAsFixed(1)} lần mức chi ${catById(t.categoryId).name} thông thường (${compactMoney(med)}).')));
      }
    }
    // Tuần này chi nhiều hơn trung bình 4 tuần trước
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    int sumBetween(DateTime a, DateTime b) =>
        activeTxns.where((x) => !x.income && countsInTotals(x.categoryId) && !x.date.isBefore(a) && x.date.isBefore(b)).fold(0, (s, x) => s + x.amount);
    final thisWeek = sumBetween(weekStart, weekStart.add(const Duration(days: 7)));
    var prev = 0;
    for (var i = 1; i <= 4; i++) {
      prev += sumBetween(weekStart.subtract(Duration(days: 7 * i)), weekStart.subtract(Duration(days: 7 * (i - 1))));
    }
    final avg = prev ~/ 4;
    if (avg > 0 && thisWeek > avg * 1.5 && thisWeek - t.amount <= avg * 1.5) {
      out.add(Nudge(_tone(
          gentle: 'Tuần này mình chi ${compactMoney(thisWeek)}, hơi nhiều hơn mọi tuần (${compactMoney(avg)}). Mấy ngày tới thong thả lại chút nhé.',
          funny: 'Tuần này đốt ${compactMoney(thisWeek)}, vượt phong độ thường ngày (${compactMoney(avg)}). Ví bạn đang chạy deadline đó',
          strict: 'Tuần này chi ${compactMoney(thisWeek)}, cao hơn 50% mức trung bình ${compactMoney(avg)}/tuần.')));
    }
    if (t.tag == 'boc_dong') {
      final c = activeChallenge;
      if (c != null) out.add(Nudge(_tone(gentle: 'Thử thách 7 ngày tạm dừng ở đây. Không sao cả, mình bắt đầu lại khi sẵn sàng nhé.', funny: 'Toang thử thách 7 ngày rồi, nhưng không sao, mình là main character, làm lại ván mới thôi!', strict: 'Thử thách 7 ngày thất bại vì khoản bốc đồng này.')));
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
    if (b == null || b.deleted || b.limit <= 0) return guiltFree?.daily;
    final p = currentPeriod;
    return b.limit ~/ periodDays(p.year, p.month);
  }

  int _spentOn(DateTime d) => activeTxns
      .where((t) => !t.income && countsInTotals(t.categoryId) && t.date.year == d.year && t.date.month == d.month && t.date.day == d.day)
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
      if (!isSkipDay(d) && (_spentOn(d) > limit || impulsive)) break;
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
    bool breaks(Txn t) {
      if (t.income || t.date.isBefore(c.start) || !t.date.isBefore(c.end)) return false;
      if (c.type != 'campaign') return t.tag == 'boc_dong';
      if (c.category.isNotEmpty && t.categoryId == c.category) return true;
      final f = fold(t.note);
      return c.keywords.any((k) => fold(k).trim().isNotEmpty && f.contains(fold(k).trim()));
    }

    final bad = activeTxns.any(breaks);
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

/// Số liệu cho thẻ tổng kết tháng (kiểu Spotify Wrapped).
class Wrapped {
  final String period;
  final int income;
  final int expense;
  final int count;
  final String? topCat;
  final int topCatAmount;
  final Txn? biggest;
  final String? topPlace;
  final int topPlaceCount;
  final String title;
  const Wrapped({
    required this.period,
    required this.income,
    required this.expense,
    required this.count,
    this.topCat,
    this.topCatAmount = 0,
    this.biggest,
    this.topPlace,
    this.topPlaceCount = 0,
    required this.title,
  });
}

extension Planning on AppStore {
  // ---------------- Dự báo & "sống được bao lâu" ----------------

  int _periodSpent(int y, int m, {Set<String>? only}) => monthTxns(y, m)
      .where((t) => !t.income && countsInTotals(t.categoryId) && (only == null || only.contains(t.categoryId)))
      .fold(0, (s, t) => s + t.amount);

  int _periodIncome(int y, int m) =>
      monthTxns(y, m).where((t) => t.income && countsInTotals(t.categoryId)).fold(0, (s, t) => s + t.amount);

  /// Chi phí gói định kỳ quy ra mỗi tháng.
  int get monthlyBills => activeBills.fold(0, (s, b) {
        final m = switch (b.cycle) { 'year' => b.amount / 12, 'week' => b.amount * 52 / 12, _ => b.amount.toDouble() };
        return s + m.round();
      });

  /// Mức chi thiết yếu mỗi tháng (TB 3 kỳ gần nhất có dữ liệu) + khoản định kỳ.
  int get essentialMonthly {
    final cur = currentPeriod;
    final vals = <int>[];
    for (var i = 1; i <= 3; i++) {
      final d = DateTime(cur.year, cur.month - i);
      final v = _periodSpent(d.year, d.month, only: kEssentialCats);
      if (v > 0) vals.add(v);
    }
    if (vals.isEmpty) {
      // chưa có kỳ trước: suy từ kỳ này
      final spent = _periodSpent(cur.year, cur.month, only: kEssentialCats);
      final passed = periodDays(cur.year, cur.month) - daysLeftInPeriod + 1;
      if (spent > 0 && passed > 0) vals.add((spent * 30 / passed).round());
    }
    final avg = vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) ~/ vals.length;
    return avg + monthlyBills;
  }

  /// "Sống được bao lâu nếu mất thu nhập": số ngày, null nếu chưa đủ dữ liệu.
  int? get runwayDays {
    final m = essentialMonthly;
    if (m <= 0) return null;
    final bal = totalBalance;
    if (bal <= 0) return 0;
    return (bal / (m / 30)).floor();
  }

  /// Dự báo số dư cuối kỳ theo tốc độ tiêu hiện tại; ngày chạm đáy ví nếu có.
  ({int endBalance, DateTime? zeroDay, int dailyRate}) get forecast {
    final cur = currentPeriod;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final passed = periodDays(cur.year, cur.month) - daysLeftInPeriod + 1;
    final billNames = {for (final b in bills.values) b.name};
    final spentNoBills = monthTxns(cur.year, cur.month)
        .where((t) => !t.income && countsInTotals(t.categoryId) && t.source != 'bill' && !billNames.any((n) => t.note.contains(n)))
        .fold<int>(0, (s, t) => s + t.amount);
    final rate = passed <= 0 ? 0 : spentNoBills ~/ passed;
    var bal = totalBalance;
    DateTime? zero;
    final end = periodEnd(cur.year, cur.month);
    for (var d = today.add(const Duration(days: 1)); d.isBefore(end); d = d.add(const Duration(days: 1))) {
      bal -= rate;
      for (final b in activeBills) {
        bal -= b.dueBetween(d, d.add(const Duration(days: 1))).length * b.amount;
      }
      if (zero == null && bal < 0) zero = d;
    }
    return (endBalance: bal, zeroDay: zero, dailyRate: rate);
  }

  /// Mô phỏng 6 tháng tới khi thêm một khoản trả góp: số dư cuối mỗi tháng.
  List<({DateTime month, int balance, int net})> installmentPlan({int newMonthly = 0, int months = 0}) {
    final cur = currentPeriod;
    final incomes = <int>[], spends = <int>[];
    for (var i = 1; i <= 3; i++) {
      final d = DateTime(cur.year, cur.month - i);
      final inc = _periodIncome(d.year, d.month), sp = _periodSpent(d.year, d.month);
      if (inc > 0 || sp > 0) {
        incomes.add(inc);
        spends.add(sp);
      }
    }
    final avgInc = incomes.isEmpty ? _periodIncome(cur.year, cur.month) : incomes.reduce((a, b) => a + b) ~/ incomes.length;
    final avgSp = spends.isEmpty ? _periodSpent(cur.year, cur.month) : spends.reduce((a, b) => a + b) ~/ spends.length;
    var bal = totalBalance;
    final out = <({DateTime month, int balance, int net})>[];
    for (var i = 1; i <= 6; i++) {
      final a = periodStart(cur.year, cur.month + i), b = periodEnd(cur.year, cur.month + i);
      var bills = 0;
      for (final x in activeBills) {
        bills += x.dueBetween(a, b).length * x.amount;
      }
      final net = avgInc - avgSp - bills - (i <= months ? newMonthly : 0);
      bal += net;
      out.add((month: a, balance: bal, net: net));
    }
    return out;
  }

  // ---------------- Khoản định kỳ sắp đến hạn ----------------

  List<Bill> get billsDueSoon {
    final limit = DateTime.now().add(const Duration(days: 3));
    return activeBills.where((b) => b.next.isBefore(limit)).toList();
  }

  // ---------------- Cất tiền dư cuối ngày ----------------

  /// Hôm qua còn dư bao nhiêu so với hạn mức ngày (chưa cất vào hũ).
  int get yesterdayLeftover {
    final limit = dailyAllowance;
    if (limit == null) return 0;
    final y = DateTime.now().subtract(const Duration(days: 1));
    if (sweptDays.contains(dayKey(y))) return 0;
    final spent = activeTxns
        .where((t) => !t.income && countsInTotals(t.categoryId) && t.date.year == y.year && t.date.month == y.month && t.date.day == y.day)
        .fold<int>(0, (s, t) => s + t.amount);
    final left = limit - spent;
    return left >= 5000 ? (left ~/ 1000) * 1000 : 0;
  }

  // ---------------- Quy đổi giờ làm việc ----------------

  /// Tiền đã cất vào các hũ mục tiêu (vẫn nằm trong ví nhưng không nên tiêu).
  /// Tiền đã cất cho mục tiêu nhưng vẫn nằm trong các ví đang theo dõi (mục tiêu có tài khoản tiết kiệm riêng
  /// thì tiền đã chuyển ra khỏi ví, không cần trừ thêm).
  int get lockedInGoals => activeGoals.where((g) => g.hold != 'bank').fold<int>(0, (s, g) => s + g.saved);

  /// Tiền đang nằm trong tài khoản tiết kiệm / hũ riêng của các mục tiêu.
  int get savedOutside => activeGoals.where((g) => g.hold == 'bank').fold<int>(0, (s, g) => s + g.saved);

  /// Số tiền thật sự được tiêu = tổng số dư − tiền đã cất trong hũ.
  int get spendableBalance => totalBalance - lockedInGoals;

  /// Thu nhập dùng cho "Quỹ tiêu thoải mái": người dùng tự nhập, hoặc lấy kỳ này / trung bình 3 kỳ trước (cái nào lớn hơn).
  int get plannedIncome {
    if (incomePlan > 0) return incomePlan;
    final cur = currentPeriod;
    final now = monthTxns(cur.year, cur.month).where((t) => t.income && countsInTotals(t.categoryId)).fold<int>(0, (s, t) => s + t.amount);
    final vals = <int>[];
    for (var i = 1; i <= 3; i++) {
      final d = DateTime(cur.year, cur.month - i);
      final v = monthTxns(d.year, d.month).where((t) => t.income && countsInTotals(t.categoryId)).fold<int>(0, (s, t) => s + t.amount);
      if (v > 0) vals.add(v);
    }
    final avg = vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) ~/ vals.length;
    return now > avg ? now : avg;
  }

  /// Quỹ "tiêu xài không áy náy": thu nhập − khoản cố định − tiết kiệm, chia đều cho số ngày còn lại của kỳ.
  ({int income, int fixed, int save, int pool, int daily, int spentToday, int leftToday})? get guiltFree {
    final income = plannedIncome;
    if (income <= 0) return null;
    final fixed = monthlyBills;
    final save = (income * savePct / 100).round();
    final pool = income - fixed - save;
    final cur = currentPeriod;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var before = 0, todaySpent = 0;
    for (final t in monthTxns(cur.year, cur.month)) {
      if (t.income || !countsInTotals(t.categoryId) || t.source == 'bill') continue;
      if (t.date.isBefore(today)) {
        before += t.amount;
      } else if (sameDay(t.date, now)) {
        todaySpent += t.amount;
      }
    }
    var daily = ((pool - before) / daysLeftInPeriod).floor();
    // không bao giờ gợi ý tiêu vào tiền đã cất trong hũ mục tiêu
    if (lockedInGoals > 0) {
      final cap = ((spendableBalance + todaySpent) / daysLeftInPeriod).floor();
      if (cap < daily) daily = cap;
    }
    final d = daily < 0 ? 0 : daily;
    return (income: income, fixed: fixed, save: save, pool: pool, daily: d, spentToday: todaySpent, leftToday: d - todaySpent);
  }

  int get effectiveHourlyWage {
    if (hourlyWage > 0) return hourlyWage;
    final cur = currentPeriod;
    final vals = <int>[];
    for (var i = 1; i <= 3; i++) {
      final d = DateTime(cur.year, cur.month - i);
      final v = monthTxns(d.year, d.month)
          .where((t) => t.income && countsInTotals(t.categoryId) && (t.categoryId == 'luong' || t.categoryId == 'thuong'))
          .fold<int>(0, (s, t) => s + t.amount);
      if (v > 0) vals.add(v);
    }
    if (vals.isEmpty) return 0;
    return (vals.reduce((a, b) => a + b) / vals.length / 176).round(); // 22 ngày x 8 giờ
  }

  /// "Món này bằng X giờ làm việc".
  String workHours(int price) {
    final w = effectiveHourlyWage;
    if (w <= 0) return '';
    final h = price / w;
    if (h < 1) return '${(h * 60).round()} phút làm việc';
    if (h < 8 * 3) return '${h.toStringAsFixed(h < 10 ? 1 : 0).replaceAll('.', ',').replaceAll(',0', '')} giờ làm việc';
    return '${(h / 8).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} ngày công';
  }

  /// Tổng tiền đã "giữ lại" nhờ bỏ món trong danh sách chờ.
  int get savedBySkipping => activeWishes.where((w) => w.status == 'skipped').fold(0, (s, w) => s + w.price);

  // ---------------- Sổ hiếu hỉ ----------------

  /// Theo từng người: mình đã đi bao nhiêu, họ đã mừng mình bao nhiêu.
  List<({String person, int given, int received, DateTime last})> giftPeople() {
    final m = <String, ({int given, int received, DateTime last})>{};
    for (final g in activeGifts) {
      final key = g.person.trim();
      final old = m[key] ?? (given: 0, received: 0, last: g.date);
      m[key] = (
        given: old.given + (g.given ? g.amount : 0),
        received: old.received + (g.given ? 0 : g.amount),
        last: g.date.isAfter(old.last) ? g.date : old.last,
      );
    }
    final out = [for (final e in m.entries) (person: e.key, given: e.value.given, received: e.value.received, last: e.value.last)];
    out.sort((a, b) => b.last.compareTo(a.last));
    return out;
  }

  /// Dịp sắp tới trong 14 ngày (theo ngày nhắc đã lưu).
  List<GiftEntry> get upcomingGiftEvents {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 14));
    return activeGifts.where((g) => g.remind != null && g.remind!.isAfter(now.subtract(const Duration(days: 1))) && g.remind!.isBefore(limit)).toList()
      ..sort((a, b) => a.remind!.compareTo(b.remind!));
  }

  // ---------------- Tổng kết tháng ----------------

  Wrapped wrapped(int y, int m) {
    final list = monthTxns(y, m).where((t) => countsInTotals(t.categoryId)).toList();
    final exp = list.where((t) => !t.income).toList();
    final inc = list.where((t) => t.income).fold<int>(0, (s, t) => s + t.amount);
    final total = exp.fold<int>(0, (s, t) => s + t.amount);
    final byCat = <String, int>{};
    final byPlace = <String, int>{};
    Txn? big;
    var late = 0;
    for (final t in exp) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
      final k = ruleKey(t.note);
      if (k.isNotEmpty) byPlace[k] = (byPlace[k] ?? 0) + 1;
      if (big == null || t.amount > big.amount) big = t;
      if (t.date.hour >= 22 || t.date.hour < 4) late++;
    }
    String? topCat;
    var topAmt = 0;
    byCat.forEach((k, v) {
      if (v > topAmt) {
        topAmt = v;
        topCat = k;
      }
    });
    String? place;
    var placeN = 0;
    byPlace.forEach((k, v) {
      if (v > placeN) {
        placeN = v;
        place = k;
      }
    });
    final share = total == 0 ? 0.0 : topAmt / total;
    String title;
    if (exp.isEmpty) {
      title = 'Tháng của sự tĩnh lặng';
    } else if (late >= 5) {
      title = 'Chiến thần săn sale đêm khuya';
    } else if (topCat == 'an_uong' && share > 0.35) {
      title = 'Tín đồ ẩm thực chính hiệu';
    } else if (topCat == 'mua_sam' && share > 0.3) {
      title = 'Thánh chốt đơn';
    } else if (topCat == 'di_lai' && share > 0.25) {
      title = 'Dân du mục thành phố';
    } else if (topCat == 'giao_duc') {
      title = 'Nhà đầu tư cho bản thân';
    } else if (inc > total) {
      title = 'Cao thủ giữ tiền';
    } else {
      title = 'Người cân bằng thu chi';
    }
    return Wrapped(
      period: periodLabel(y, m),
      income: inc,
      expense: total,
      count: exp.length,
      topCat: topCat,
      topCatAmount: topAmt,
      biggest: big,
      topPlace: place,
      topPlaceCount: placeN,
      title: title,
    );
  }
}
