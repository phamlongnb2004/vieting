import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../categories.dart';
import '../insights.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/txn_tile.dart';
import 'edit_txn.dart';
import 'wallets.dart';
import '../widgets/vicon.dart';

/// "Dọn dẹp tài chính" 60 giây mỗi Chủ nhật: xếp lại khoản chưa phân loại, đối chiếu số dư, nhìn lại tuần.
class CleanupScreen extends StatelessWidget {
  const CleanupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = store.activeTxns.where((t) => t.date.isAfter(weekAgo)).toList();
    final unsorted = store.activeTxns
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 31))) && (t.categoryId == 'khac_chi' || t.categoryId == 'khac_thu'))
        .take(20)
        .toList();
    final spentWeek = week.where((t) => !t.income && countsInTotals(t.categoryId)).fold<int>(0, (s, t) => s + t.amount);
    final f = store.forecast;
    return Scaffold(
      appBar: AppBar(title: const Text('Dọn dẹp 60 giây')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Brand.bamboo.withAlpha(30),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tuần qua', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text('Chi ${money(spentWeek)} qua ${week.where((t) => !t.income).length} khoản.'),
                Text('Dự báo cuối kỳ còn ${money(f.endBalance)}${f.zeroDay != null ? ' · có thể chạm đáy ví ngày ${dmy(f.zeroDay!)}' : ''}.'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _Step(n: 1, title: 'Xếp lại khoản chưa phân loại (${unsorted.length})'),
          if (unsorted.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text('Gọn gàng rồi', style: TextStyle(color: cs.onSurfaceVariant)))
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [for (final t in unsorted) TxnTile(txn: t, onTap: () => openEditTxn(context, t))]),
            ),
          const SizedBox(height: 16),
          _Step(n: 2, title: 'Đối chiếu số dư thực tế'),
          Card(
            child: Column(children: [
              for (final w in store.activeWallets)
                ListTile(
                  leading: Icon(w.icon, color: Color(w.color)),
                  title: Text(w.name),
                  trailing: Text(money(store.walletBalance(w)), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.pencilSimple, size: 36),
                title: const Text('Lệch với app ngân hàng / ví thật? Chỉnh số dư'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _Step(n: 3, title: 'Mục tiêu tuần mới'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: (context) {
                final allowance = store.dailyAllowance;
                if (allowance == null) {
                  return Text('Đặt ngân sách tổng ở tab Kế hoạch để có hạn mức mỗi ngày.', style: TextStyle(color: cs.onSurfaceVariant));
                }
                return Text('Tuần này giữ mỗi ngày dưới ${money(allowance)} là đúng kế hoạch. '
                    'Chuỗi hiện tại: ${store.streak} ngày.');
              }),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xong! Sổ sách tuần này gọn gàng')));
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Xong')),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  const _Step({required this.n, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          CircleAvatar(radius: 13, backgroundColor: Brand.red, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}
