import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:vieting/i18n.dart';

import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/lunar.dart';

/// Lịch âm dương kèm chi tiêu từng ngày. Tác giả: Phạm Thành Long (thlong)
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _sel = DateTime.now();

  static const _wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // chi tiêu theo ngày trong tháng đang xem
    final spent = <int, int>{};
    final earned = <int, int>{};
    for (final t in s.activeTxns) {
      if (t.date.year != _month.year || t.date.month != _month.month) continue;
      if (t.income) {
        earned[t.date.day] = (earned[t.date.day] ?? 0) + t.amount;
      } else {
        spent[t.date.day] = (spent[t.date.day] ?? 0) + t.amount;
      }
    }
    final maxSpent = spent.values.fold<int>(0, (a, b) => b > a ? b : a);
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final selL = toLunar(_sel);
    final selHol = holidayOf(_sel, selL);
    final dayTx = s.activeTxns.where((t) => sameDay(t.date, _sel)).toList();
    final dayOut = dayTx.where((t) => !t.income).fold<int>(0, (a, t) => a + t.amount);
    final dayIn = dayTx.where((t) => t.income).fold<int>(0, (a, t) => a + t.amount);
    final monthL = toLunar(first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _month = DateTime(now.year, now.month);
              _sel = now;
            }),
            child: const Text('Hôm nay'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
        children: [
          // Thẻ ngày đang chọn
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Column(children: [
                Text('${_sel.day}', style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w900, height: 1)),
                Text('${tr('Tháng')} ${_sel.month}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(weekdayName(_sel), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${tr('Âm lịch')}: ${selL.day}/${selL.month}${selL.leap ? ' ${tr('nhuận')}' : ''} ${tr('năm')} ${selL.yearName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('${tr('Ngày')} ${selL.dayName} · ${tr('tháng')} ${selL.monthName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (selHol != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Brand.yellow, borderRadius: BorderRadius.circular(20)),
                      child: Text('★ $selHol', style: const TextStyle(color: Brand.redDeep, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Đầu tháng
          Row(children: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.caretLeft),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Column(children: [
                Text('${tr('Tháng')} ${_month.month}, ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('${tr('Năm')} ${monthL.yearName}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.caretRight),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ]),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              child: Column(children: [
                Row(children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(tr(_wd[i]),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == 6 ? Brand.red : cs.onSurfaceVariant)),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                for (var r = 0; r < rows; r++)
                  Row(children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Builder(builder: (_) {
                          final idx = r * 7 + c - lead + 1;
                          if (idx < 1 || idx > days) return const SizedBox(height: 62);
                          final d = DateTime(_month.year, _month.month, idx);
                          final l = toLunar(d);
                          final hol = holidayOf(d, l) != null;
                          final isToday = sameDay(d, now);
                          final isSel = sameDay(d, _sel);
                          final out = spent[idx] ?? 0;
                          final heat = maxSpent == 0 ? 0.0 : out / maxSpent;
                          return GestureDetector(
                            onTap: () => setState(() => _sel = d),
                            child: Container(
                              height: 62,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? Brand.red
                                    : out > 0
                                        ? Brand.red.withAlpha((18 + heat * 50).round())
                                        : null,
                                borderRadius: BorderRadius.circular(14),
                                border: isToday && !isSel ? Border.all(color: Brand.red, width: 1.6) : null,
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text('$idx',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: isSel ? Colors.white : (c == 6 || hol ? Brand.red : null),
                                    )),
                                Text(l.day == 1 ? '${l.day}/${l.month}' : '${l.day}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: l.day == 1 || l.day == 15 ? FontWeight.w800 : FontWeight.w500,
                                      color: isSel ? Colors.white70 : (l.day == 1 || l.day == 15 ? Brand.red : cs.onSurfaceVariant),
                                    )),
                                if (out > 0)
                                  Text(compactMoney(out),
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: isSel ? Colors.white : Brand.redDeep)),
                              ]),
                            ),
                          );
                        }),
                      ),
                  ]),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('Số nhỏ dưới mỗi ngày là ngày âm lịch; ô càng đỏ là ngày tiêu càng nhiều.',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          // Chi tiêu ngày đã chọn
          Card(
            child: Column(children: [
              ListTile(
                title: Text(fullDate(_sel), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(dayTx.isEmpty ? 'Không có giao dịch' : '${tr('Chi')} ${money(dayOut)}${dayIn > 0 ? ' · ${tr('Thu')} ${money(dayIn)}' : ''}'),
              ),
              for (final t in dayTx.take(12))
                ListTile(
                  dense: true,
                  leading: Icon(t.income ? PhosphorIconsRegular.arrowDownLeft : PhosphorIconsRegular.arrowUpRight,
                      color: t.income ? Brand.income : Brand.expense),
                  title: Text(t.note.isEmpty ? (t.income ? 'Thu' : 'Chi') : t.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(money(t.signed, signed: true),
                      style: TextStyle(fontWeight: FontWeight.w800, color: t.income ? Brand.income : null)),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  static String weekdayName(DateTime d) {
    const vi = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return tr(vi[d.weekday - 1]);
  }

  static String fullDate(DateTime d) => '${weekdayName(d)}, ${d.day}/${d.month}/${d.year}';
}
