import 'package:flutter/material.dart';

import '../categories.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/txn_tile.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  Future<void> _edit(BuildContext context, String? id) async {
    final store = StoreScope.read(context);
    String selected = id ?? 'all';
    final ctrl = TextEditingController(text: id != null ? groupDigits(store.budgets[id]?.limit ?? 0) : '');
    final res = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(id == null ? 'Thêm ngân sách tháng' : 'Sửa ngân sách'),
          content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (id == null)
              DropdownButton<String>(
                isExpanded: true,
                value: selected,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Tổng chi tiêu')),
                  for (final cat in catsFor(false)) DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                ],
                onChanged: (v) => setS(() => selected = v ?? selected),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(labelText: 'Hạn mức mỗi tháng', suffixText: '₫'),
            ),
          ])),
          actions: [
            if (id != null) TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('Bỏ ngân sách')),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, parseMoneyInput(ctrl.text)), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (res != null) store.setBudget(id ?? selected, res);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final budgets = store.activeBudgets;
    final cs = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(Icons.add)),
      body: budgets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.savings_outlined, size: 64, color: Brand.bamboo),
                  const SizedBox(height: 12),
                  const Text('Đặt hạn mức chi tiêu mỗi tháng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('VieTing sẽ báo khi bạn chi gần chạm hạn mức.',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => _edit(context, null), child: const Text('Thêm ngân sách')),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                Text('${monthLabel(now.year, now.month)} · còn $daysLeft ngày',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                for (final b in budgets) ...[
                  Builder(builder: (context) {
                    final spent = store.spentFor(b.id, now.year, now.month);
                    final left = b.limit - spent;
                    final perDay = left > 0 ? left ~/ daysLeft : 0;
                    final cat = b.id == 'all' ? null : catById(b.id);
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _edit(context, b.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (cat != null)
                                CatAvatar(cat: cat, size: 36)
                              else
                                const Icon(Icons.account_balance_wallet, color: Brand.red, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(cat?.name ?? 'Tổng chi tiêu',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              Text('${money(spent)} / ${compactMoney(b.limit)}'),
                            ]),
                            const SizedBox(height: 12),
                            BudgetBar(spent: spent, limit: b.limit),
                            const SizedBox(height: 8),
                            Text(
                              left >= 0
                                  ? 'Còn ${money(left)} · nên chi tối đa ${money(perDay)}/ngày'
                                  : 'Đã vượt ${money(-left)}',
                              style: TextStyle(
                                  color: left >= 0 ? cs.onSurfaceVariant : Brand.red, fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}
