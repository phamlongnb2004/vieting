import 'package:flutter/material.dart';

import '../categories.dart';
import '../services/notify_bridge.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/logo.dart';
import '../widgets/txn_tile.dart';
import 'edit_txn.dart';
import 'notify_setup.dart';
import 'paste.dart';

class OverviewScreen extends StatefulWidget {
  final VoidCallback onSeeAll;
  const OverviewScreen({super.key, required this.onSeeAll});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with WidgetsBindingObserver {
  bool? _notifyOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!NotifyBridge.supported) return;
    final v = await NotifyBridge.isEnabled();
    if (mounted) setState(() => _notifyOn = v);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final totals = store.monthTotals(now.year, now.month);
    final byCat = store.expenseByCategory(now.year, now.month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recent = store.activeTxns.take(6).toList();
    final budgets = store.activeBudgets;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(fontSize: 24),
        actions: [
          IconButton(
            tooltip: 'Dán thông báo ngân hàng',
            icon: const Icon(Icons.content_paste_go),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasteScreen())),
          ),
          if (store.loggedIn)
            IconButton(
              tooltip: 'Đồng bộ',
              icon: store.syncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              onPressed: store.syncing ? null : () => store.sync(),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          if (_notifyOn == false) ...[
            Card(
              color: Brand.yellow.withAlpha(60),
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: Brand.red),
                title: const Text('Bật tự ghi từ thông báo ngân hàng', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Có tiền vào/ra là VieTing tự ghi và tính số dư'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifySetupScreen()));
                  _check();
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          _BalanceCard(total: store.totalBalance, income: totals.income, expense: totals.expense, month: now.month),
          SectionTitle('Chi tiêu tháng ${now.month}'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: byCat.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text('Chưa có khoản chi nào trong tháng này',
                              style: TextStyle(color: cs.onSurfaceVariant))),
                    )
                  : Row(children: [
                      DonutChart(
                        size: 140,
                        slices: [
                          for (final e in byCat.take(6)) DonutSlice(e.value, catById(e.key).color),
                          if (byCat.length > 6)
                            DonutSlice(byCat.skip(6).fold<int>(0, (s, e) => s + e.value), Colors.grey),
                        ],
                        center: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('Đã chi', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          Text(compactMoney(totals.expense),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ]),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(children: [
                          for (final e in byCat.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: catById(e.key).color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(catById(e.key).name, overflow: TextOverflow.ellipsis)),
                                Text(compactMoney(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ]),
                            ),
                        ]),
                      ),
                    ]),
            ),
          ),
          const SectionTitle('7 ngày qua'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
              child: DayBars(data: store.dailyExpense(7)),
            ),
          ),
          if (budgets.isNotEmpty) ...[
            const SectionTitle('Ngân sách tháng này'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  for (final b in budgets.take(3)) ...[
                    Row(children: [
                      Expanded(
                          child: Text(b.id == 'all' ? 'Tổng chi tiêu' : catById(b.id).name,
                              style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${compactMoney(store.spentFor(b.id, now.year, now.month))} / ${compactMoney(b.limit)}'),
                    ]),
                    const SizedBox(height: 6),
                    BudgetBar(spent: store.spentFor(b.id, now.year, now.month), limit: b.limit),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
          ],
          SectionTitle('Giao dịch gần đây',
              trailing: TextButton(onPressed: widget.onSeeAll, child: const Text('Xem tất cả'))),
          Card(
            clipBehavior: Clip.antiAlias,
            child: recent.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Chưa có giao dịch. Bấm "Thêm" hoặc bật đọc thông báo ngân hàng.',
                          textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                : Column(children: [
                    for (final t in recent) TxnTile(txn: t, onTap: () => openEditTxn(context, t)),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int total;
  final int income;
  final int expense;
  final int month;
  const _BalanceCard({required this.total, required this.income, required this.expense, required this.month});

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String label, int v) => Expanded(
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12)),
                Text(money(v),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Brand.red, Color(0xFF8E1B1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Brand.red.withAlpha(70), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned(
          right: -6,
          top: -6,
          child: Icon(Icons.star_rounded, size: 70, color: Brand.yellow.withAlpha(80)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tổng số dư', style: TextStyle(color: Colors.white.withAlpha(220))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(money(total),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            stat(Icons.south_west, 'Thu tháng $month', income),
            const SizedBox(width: 12),
            stat(Icons.north_east, 'Chi tháng $month', expense),
          ]),
        ]),
      ]),
    );
  }
}
