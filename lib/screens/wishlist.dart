import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../models.dart';
import '../pro.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../theme.dart';
import '../util/format.dart';
import 'edit_txn.dart';
import 'goals.dart';
import 'time_cost.dart';
import '../widgets/vicon.dart';

/// Danh sách chờ 48 giờ: "làm nguội" trước khi mua món không thiết yếu.
/// Món đã mua thì theo dõi giá chia theo số lần dùng (cost-per-use).
class WishlistScreen extends StatelessWidget {
  final bool embedded;
  const WishlistScreen({super.key, this.embedded = false});

  static Future<void> add(BuildContext context) async {
    final waiting = StoreScope.read(context).activeWishes.where((w) => w.status == 'waiting').length;
    if (!await Pro.check(context, 'wishes', count: waiting)) return;
    if (!context.mounted) return;
    final store = StoreScope.read(context);
    final name = TextEditingController();
    final price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final p = parseMoneyInput(price.text);
          final hours = p > 0 ? store.workHours(p) : '';
          return AlertDialog(
            title: const Text('Muốn mua gì?'),
            content: SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Món đồ (VD: Túi xách)')),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  onChanged: (_) => setS(() {}),
                  decoration: const InputDecoration(labelText: 'Giá', suffixText: '₫'),
                ),
                if (hours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Món này tốn của bạn $hours', style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.red)),
                ],
                const SizedBox(height: 8),
                const Text('Món sẽ nằm trong danh sách chờ 48 giờ, sau đó VieTing hỏi lại bạn còn muốn mua không.'),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cho vào danh sách chờ')),
            ],
          );
        },
      ),
    );
    final p = parseMoneyInput(price.text);
    if (ok != true || name.text.trim().isEmpty || p <= 0) return;
    store.saveWish(Wish(id: newId(), name: name.text.trim(), price: p));
  }

  static Future<void> decide(BuildContext context, Wish w) async {
    final store = StoreScope.read(context);
    final buy = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('48 giờ rồi, còn muốn mua "${w.name}"?'),
        content: Text('Giá ${money(w.price)}${store.workHours(w.price).isNotEmpty ? ' · bằng ${store.workHours(w.price)}' : ''}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi, không mua')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vẫn mua')),
        ],
      ),
    );
    if (buy == null || !context.mounted) return;
    w
      ..status = buy ? 'bought' : 'skipped'
      ..decidedAt = DateTime.now();
    store.saveWish(w);
    if (buy) {
      await openEditTxn(context, null, presetAmount: w.price, presetNote: w.name);
    } else {
      final goals = store.activeGoals.where((g) => g.progress < 1).toList();
      if (goals.isNotEmpty && context.mounted) {
        showToast(context, 'Giữ lại được ${money(w.price)}! Cất vào hũ "${goals.first.name}"?',
            actionLabel: 'Cất', onAction: () => GoalsScreen.addMoney(context, goals.first), duration: const Duration(seconds: 6));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final all = store.activeWishes;
    final waiting = all.where((w) => w.status == 'waiting').toList();
    final bought = all.where((w) => w.status == 'bought').toList();
    final skipped = store.savedBySkipping;
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Danh sách chờ')),
      floatingActionButton: FloatingActionButton(heroTag: 'wish', onPressed: () => add(context), child: const Icon(PhosphorIconsRegular.shoppingCartSimple)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            child: ListTile(
              leading: const VIcon(PhosphorIconsRegular.hourglassMedium),
              title: const Text('Đổi giá ra giờ làm việc', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Xem món đồ tốn bao nhiêu giờ làm, chia sẻ lên story'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeCostScreen())),
            ),
          ),
          if (skipped > 0)
            Card(
              color: Brand.bamboo.withAlpha(30),
              child: ListTile(
                leading: const VIcon(PhosphorIconsRegular.snowflake, color: Brand.bamboo),
                title: Text('Đã giữ lại ${money(skipped)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('nhờ "làm nguội" 48 giờ rồi không mua'),
              ),
            ),
          const SizedBox(height: 6),
          Text('Đang chờ 48 giờ', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          if (waiting.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Định mua món không thiết yếu? Cho vào đây trước, 48 giờ sau mới quyết.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final w in waiting)
            Card(
              child: ListTile(
                leading: Icon(w.ready ? PhosphorIconsRegular.alarm : PhosphorIconsRegular.snowflake, color: w.ready ? const Color(0xFFEF8F00) : Brand.navy),
                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  money(w.price),
                  if (store.workHours(w.price).isNotEmpty) store.workHours(w.price),
                  w.ready ? 'đã đủ 48 giờ' : 'còn ${w.readyAt.difference(DateTime.now()).inHours + 1} giờ',
                ].join(' · ')),
                trailing: w.ready
                    ? FilledButton(onPressed: () => decide(context, w), child: const Text('Quyết'))
                    : IconButton(
                        icon: const Icon(PhosphorIconsRegular.trash),
                        onPressed: () {
                          w.status = 'skipped';
                          w.decidedAt = DateTime.now();
                          store.saveWish(w);
                        },
                      ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Đồ đã mua: đáng tiền không?', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          if (bought.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Món mua qua danh sách chờ sẽ hiện ở đây. Mỗi lần dùng bấm +1 để xem giá mỗi lần dùng.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final w in bought)
            Card(
              child: ListTile(
                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${money(w.price)} · dùng ${w.uses} lần · ${money(w.costPerUse)}/lần'),
                trailing: IconButton.filledTonal(
                  icon: const Icon(PhosphorIconsRegular.plusCircle),
                  onPressed: () {
                    w.uses++;
                    store.saveWish(w);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
