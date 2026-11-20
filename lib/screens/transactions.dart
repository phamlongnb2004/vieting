import 'package:flutter/material.dart';

import '../categories.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/text.dart';
import '../widgets/txn_tile.dart';
import 'edit_txn.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late int _year;
  late int _month;
  int _filter = 0; // 0 tất cả, 1 chi, 2 thu
  String _query = '';

  @override
  void initState() {
    super.initState();
    final p = StoreScope.read(context).currentPeriod;
    _year = p.year;
    _month = p.month;
  }

  void _shift(int d) {
    setState(() {
      final m = DateTime(_year, _month + d);
      _year = m.year;
      _month = m.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final q = fold(_query.trim());
    final list = store.monthTxns(_year, _month).where((t) {
      if (_filter == 1 && t.income) return false;
      if (_filter == 2 && !t.income) return false;
      if (q.isEmpty) return true;
      if (t.hidden && !store.revealHidden) return false;
      return fold('${t.note} ${catById(t.categoryId).name} ${store.walletName(t.walletId)} ${t.amount}').contains(q);
    }).toList();
    final totals = store.monthTotals(_year, _month);

    // gom theo ngày
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Text(store.periodLabel(_year, _month), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm nội dung, danh mục, số tiền…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (i, label) in const [(0, 'Tất cả'), (1, 'Chi'), (2, 'Thu')]) ...[
              ChoiceChip(label: Text(label), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('+${compactMoney(totals.income)}', style: const TextStyle(color: Brand.income, fontWeight: FontWeight.w700)),
              Text('−${compactMoney(totals.expense)}', style: const TextStyle(color: Brand.expense, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Không có giao dịch', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                        child: Row(children: [
                          Expanded(
                              child: Text(dayLabel(e.key),
                                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
                          Text(
                            money(e.value.fold<int>(0, (s, t) => s + t.signed), signed: true),
                            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (final t in e.value)
                            Dismissible(
                              key: ValueKey(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Brand.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                store.deleteTxn(t.id);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Đã xóa giao dịch'),
                                  action: SnackBarAction(label: 'Hoàn tác', onPressed: () => store.restoreTxn(t.id)),
                                ));
                              },
                              child: TxnTile(txn: t, onTap: () => openEditTxn(context, t)),
                            ),
                        ]),
                      ),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}
