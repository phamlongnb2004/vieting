import 'package:flutter/material.dart';

import '../categories.dart';
import '../insights.dart';
import '../services/notify_bridge.dart';
import '../pro.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/logo.dart';
import '../widgets/txn_tile.dart';
import 'edit_txn.dart';
import 'goals.dart';
import 'habits.dart';
import 'notify_setup.dart';
import 'paste.dart';
import 'bills.dart';
import 'cleanup.dart';
import 'gifts.dart';
import 'wrapped.dart';
import '../widgets/nudge.dart';

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
    final per = store.currentPeriod;
    final totals = store.monthTotals(per.year, per.month);
    final byCat = store.expenseByCategory(per.year, per.month).entries.toList()
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
          if (store.notice != null && (store.notice!['id'] as num?)?.toInt() != store.noticeSeen) ...[
            Card(
              color: switch (store.notice!['level']) {
                'warning' => const Color(0xFFFFF1D6),
                'success' => Brand.bamboo.withAlpha(35),
                _ => Brand.navy.withAlpha(25),
              },
              child: ListTile(
                leading: Icon(
                  switch (store.notice!['level']) {
                    'warning' => Icons.warning_amber_rounded,
                    'success' => Icons.celebration_outlined,
                    _ => Icons.campaign_outlined,
                  },
                  color: Brand.navy,
                ),
                title: Text('${store.notice!['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: '${store.notice!['body'] ?? ''}'.isEmpty ? null : Text('${store.notice!['body']}'),
                trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Ẩn', onPressed: store.dismissNotice),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _BalanceCard(total: store.totalBalance, income: totals.income, expense: totals.expense, label: store.cycleDay == 1 ? 'tháng ${now.month}' : 'kỳ này'),
          const SizedBox(height: 12),
          _GuiltFreeCard(store: store),
          _TodayRow(store: store),
          const SizedBox(height: 4),
          _Alerts(store: store),
          _ForecastCard(store: store),
          SectionTitle(store.cycleDay == 1 ? 'Chi tiêu tháng ${now.month}' : 'Chi tiêu kỳ ${store.periodLabel(per.year, per.month)}'),
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
                      Text('${compactMoney(store.spentFor(b.id, per.year, per.month))} / ${compactMoney(b.limit)}'),
                    ]),
                    const SizedBox(height: 6),
                    BudgetBar(spent: store.spentFor(b.id, per.year, per.month), limit: b.limit),
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
  final String label;
  const _BalanceCard({required this.total, required this.income, required this.expense, required this.label});

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
            stat(Icons.south_west, 'Thu $label', income),
            const SizedBox(width: 12),
            stat(Icons.north_east, 'Chi $label', expense),
          ]),
        ]),
      ]),
    );
  }
}


/// Hôm nay còn chi được bao nhiêu, chuỗi ngày, mục tiêu gần nhất.
class _TodayRow extends StatelessWidget {
  final AppStore store;
  const _TodayRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final allowance = store.dailyAllowance;
    final spentToday = store.activeTxns
        .where((t) => !t.income && countsInTotals(t.categoryId) && sameDay(t.date, now))
        .fold<int>(0, (s, t) => s + t.amount);
    final goals = store.activeGoals.where((g) => g.progress < 1).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    Widget tile(String emoji, String top, String bottom, VoidCallback onTap) => Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(top, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(bottom, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        );
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Row(children: [
      tile(
        '🗓️',
        allowance == null ? compactMoney(spentToday) : compactMoney(allowance - spentToday),
        allowance == null ? 'đã chi hôm nay' : (allowance - spentToday >= 0 ? 'còn chi được hôm nay' : 'đã lố hôm nay'),
        () => open(const HabitsScreen()),
      ),
      const SizedBox(width: 8),
      tile('🔥', '${store.streak} ngày', 'giữ ngân sách liên tiếp', () => open(const HabitsScreen())),
      const SizedBox(width: 8),
      tile(
        goals.isEmpty ? '🎋' : goals.first.emoji,
        goals.isEmpty ? 'Mục tiêu' : '${(goals.first.progress * 100).floor()}%',
        goals.isEmpty ? 'trồng cây tre đầu tiên' : goals.first.name,
        () => open(const GoalsScreen()),
      ),
    ]);
  }
}


/// Các thẻ nhắc nhẹ trong ngày: khoản định kỳ sắp đến hạn, dịp hiếu hỉ, cất tiền dư, dọn dẹp Chủ nhật, tổng kết kỳ.
class _Alerts extends StatelessWidget {
  final AppStore store;
  const _Alerts({required this.store});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = <Widget>[];
    Widget card(IconData icon, Color color, String title, String sub, {VoidCallback? onTap, Widget? trailing}) => Card(
          color: color.withAlpha(28),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub),
            onTap: onTap,
            trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
          ),
        );
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    for (final b in store.billsDueSoon.take(2)) {
      final days = DateTime(b.next.year, b.next.month, b.next.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      items.add(card(
        Icons.autorenew,
        const Color(0xFFEF8F00),
        '${b.name} ${days <= 0 ? 'đến hạn hôm nay' : 'còn $days ngày nữa trừ tiền'}',
        '${money(b.amount)} · còn dùng không? Không thì hủy kịp nhé',
        onTap: () => open(const BillsScreen()),
        trailing: TextButton(
          onPressed: () {
            final t = store.payBill(b);
            showNudges(store.nudgesFor(t));
          },
          child: const Text('Đã trả'),
        ),
      ));
    }
    for (final g in store.upcomingGiftEvents.take(1)) {
      items.add(card(Icons.redeem, Brand.red, 'Sắp tới dịp của ${g.person}', 'Ngày ${dmy(g.remind!)} · xem lần trước đi bao nhiêu',
          onTap: () => open(const GiftsScreen())));
    }
    final left = store.yesterdayLeftover;
    if (left > 0) {
      final goals = store.activeGoals.where((g) => g.progress < 1).toList();
      items.add(card(
        Icons.savings_outlined,
        Brand.bamboo,
        'Hôm qua còn dư ${money(left)} 🎉',
        goals.isEmpty ? 'Tạo một hũ mục tiêu để cất tiền dư mỗi ngày' : 'Cất vào hũ "${goals.first.name}" cho cây tre lớn thêm?',
        onTap: goals.isEmpty ? () => open(const GoalsScreen()) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (goals.isNotEmpty)
            TextButton(
              onPressed: () {
                final g = goals.first;
                g.saved += left;
                store.saveGoal(g);
                store.markSwept(now.subtract(const Duration(days: 1)));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cất ${money(left)} vào "${g.name}" 🎋')));
              },
              child: const Text('Cất'),
            ),
          IconButton(
            tooltip: 'Bỏ qua',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => store.markSwept(now.subtract(const Duration(days: 1))),
          ),
        ]),
      ));
    }
    if (now.weekday == DateTime.sunday && !store.sweptDays.contains('clean-${store.dayKey(now)}')) {
      items.add(card(Icons.cleaning_services_outlined, Brand.navy, 'Dọn dẹp tài chính 60 giây', 'Chủ nhật rồi: xếp lại vài khoản, đối chiếu số dư',
          onTap: () {
        store.markSwept(DateTime(0), key: 'clean-${store.dayKey(now)}');
        open(const CleanupScreen());
      }));
    }
    final per = store.currentPeriod;
    final prev = DateTime(per.year, per.month - 1);
    if (store.periodStart(per.year, per.month).add(const Duration(days: 5)).isAfter(now) && store.monthTxns(prev.year, prev.month).length >= 5) {
      items.add(card(Icons.auto_awesome, const Color(0xFF8E24AA), 'Tổng kết kỳ trước đã có!', 'Xem danh hiệu của bạn và chia sẻ lên story',
          onTap: () => open(const WrappedScreen())));
    }
    if (store.isSkipDay(now)) {
      items.add(card(Icons.celebration_outlined, Brand.yellow, 'Hôm nay là ngày ngoại lệ', 'Cứ vui vẻ, chuỗi ngày của bạn không bị mất 💛'));
    }
    return Column(children: items);
  }
}

/// Dự báo cuối kỳ + "đường băng sinh tồn".
class _ForecastCard extends StatelessWidget {
  final AppStore store;
  const _ForecastCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (store.activeTxns.length < 3) return const SizedBox.shrink();
    if (!store.isPro) {
      return Card(
        child: ListTile(
          leading: const Text('🔮', style: TextStyle(fontSize: 24)),
          title: const Text('Dự báo cuối kỳ & đường băng sinh tồn', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Biết trước ngày nào chạm đáy ví · Pro'),
          trailing: const Icon(Icons.lock_outline),
          onTap: () => Pro.check(context, 'forecast'),
        ),
      );
    }
    final f = store.forecast;
    final runway = store.runwayDays;
    final bad = f.zeroDay != null || f.endBalance < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔮 Dự báo cuối kỳ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(compactMoney(f.endBalance),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: bad ? const Color(0xFFEF8F00) : Brand.income)),
              Text(
                f.zeroDay != null ? 'tiêu như hiện tại có thể hết tiền ngày ${dmy(f.zeroDay!)}' : 'tiêu ~${compactMoney(f.dailyRate)}/ngày như hiện tại',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          if (runway != null) ...[
            Container(width: 1, height: 48, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🛟 Đường băng sinh tồn', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(runway >= 365 ? '> 1 năm' : '$runway ngày', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('sống được nếu mất thu nhập (chỉ chi thiết yếu)', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}


/// Quỹ "tiêu xài không áy náy": số tiền còn được tiêu hôm nay, to rõ, kèm 1 câu theo tính cách trợ lý.
class _GuiltFreeCard extends StatelessWidget {
  final AppStore store;
  const _GuiltFreeCard({required this.store});

  static Future<void> setup(BuildContext context) async {
    final store = StoreScope.read(context);
    final inc = TextEditingController(text: store.incomePlan > 0 ? groupDigits(store.incomePlan) : '');
    var pct = store.savePct.toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final income = parseMoneyInput(inc.text) > 0 ? parseMoneyInput(inc.text) : store.plannedIncome;
          final save = (income * pct / 100).round();
          final pool = income - store.monthlyBills - save;
          return AlertDialog(
            title: const Text('Quỹ tiêu thoải mái'),
            content: SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Đầu kỳ trừ sẵn khoản cố định và tiền tiết kiệm, phần còn lại chia đều mỗi ngày. Tiêu trong hạn mức thì không cần áy náy.'),
                const SizedBox(height: 12),
                TextField(
                  controller: inc,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  onChanged: (_) => setS(() {}),
                  decoration: InputDecoration(
                    labelText: 'Thu nhập mỗi kỳ',
                    suffixText: '₫',
                    helperText: store.plannedIncome > 0 && store.incomePlan == 0 ? 'Để trống = tự tính (${compactMoney(store.plannedIncome)})' : 'Lương + thu nhập đều đặn',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Trích tiết kiệm ${pct.round()}% = ${money(save)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(value: pct, min: 0, max: 50, divisions: 50, label: '${pct.round()}%', onChanged: (v) => setS(() => pct = v)),
                Text('Khoản cố định (tab Kế hoạch → Định kỳ): ${money(store.monthlyBills)}'),
                const Divider(),
                Text('Còn ${money(pool)} để tiêu thoải mái trong kỳ', style: TextStyle(fontWeight: FontWeight.w800, color: pool < 0 ? Brand.red : Brand.bamboo)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
            ],
          );
        },
      ),
    );
    if (ok == true) store.setGuiltFree(income: parseMoneyInput(inc.text), pct: pct.round());
  }

  @override
  Widget build(BuildContext context) {
    final g = store.guiltFree;
    final cs = Theme.of(context).colorScheme;
    if (g == null) {
      return Card(
        child: ListTile(
          leading: const Text('💛', style: TextStyle(fontSize: 26)),
          title: const Text('Mỗi ngày được tiêu bao nhiêu?', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Nhập thu nhập, VieTing trừ sẵn tiền cố định + tiết kiệm rồi chia hạn mức từng ngày'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setup(context),
        ),
      );
    }
    final over = g.leftToday < 0;
    final ratio = g.daily <= 0 ? 1.0 : (g.spentToday / g.daily).clamp(0.0, 1.0);
    return Card(
      color: over ? const Color(0xFFFFF1D6) : Brand.bamboo.withAlpha(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setup(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(over ? 'Hôm nay đã vượt' : 'Hôm nay còn được tiêu thoải mái',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            Text(money(over ? -g.leftToday : g.leftToday),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: over ? Brand.red : Brand.bamboo, height: 1.15)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: over ? Brand.red : Brand.bamboo,
                backgroundColor: cs.surface.withAlpha(160),
              ),
            ),
            const SizedBox(height: 6),
            Text('Hạn mức ngày ${compactMoney(g.daily)} · đã trừ cố định ${compactMoney(g.fixed)} + tiết kiệm ${compactMoney(g.save)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(store.personaLine, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
