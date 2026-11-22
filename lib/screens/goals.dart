import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models.dart';
import '../pro.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/bamboo.dart';
import 'simulate.dart';
import '../widgets/vicon.dart';

const _emojis = ['target', 'plane', 'laptop', 'moto', 'home', 'ring', 'study', 'safety', 'phone', 'gift'];

/// Hũ mục tiêu: mỗi mục tiêu là một cây tre lớn dần theo % tiền đã dành.
class GoalsScreen extends StatelessWidget {
  final bool embedded;
  const GoalsScreen({super.key, this.embedded = false});

  static Future<void> edit(BuildContext context, Goal? g) async {
    if (g == null && !await Pro.check(context, 'goals', count: StoreScope.read(context).activeGoals.length)) return;
    if (!context.mounted) return;
    final store = StoreScope.read(context);
    final name = TextEditingController(text: g?.name ?? '');
    final target = TextEditingController(text: g == null ? '' : groupDigits(g.target));
    var emoji = g?.emoji ?? _emojis.first;
    DateTime? deadline = g?.deadline;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(g == null ? 'Mục tiêu mới' : 'Sửa mục tiêu'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in _emojis)
                    ChoiceChip(label: Icon(goalIcon(e), size: 20), selected: emoji == e, onSelected: (_) => setS(() => emoji = e)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên mục tiêu (VD: Du lịch Đà Lạt)')),
                const SizedBox(height: 12),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(labelText: 'Số tiền cần', suffixText: '₫'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(PhosphorIconsRegular.calendarBlank),
                  title: Text(deadline == null ? 'Hạn (không bắt buộc)' : 'Hạn: ${dmy(deadline!)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: c,
                      initialDate: deadline ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setS(() => deadline = d);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    final t = parseMoneyInput(target.text);
    if (ok != true || name.text.trim().isEmpty || t <= 0) return;
    final goal = g ?? Goal(id: newId(), name: '', target: 0);
    goal
      ..name = name.text.trim()
      ..emoji = emoji
      ..target = t
      ..deadline = deadline;
    store.saveGoal(goal);
  }

  static Future<void> addMoney(BuildContext context, Goal g, {bool withdraw = false}) async {
    final store = StoreScope.read(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(withdraw ? 'Rút bớt từ "${g.name}"' : 'Bỏ thêm vào "${g.name}"'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(suffixText: '₫'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(withdraw ? 'Rút' : 'Bỏ vào')),
        ],
      ),
    );
    final v = parseMoneyInput(c.text);
    if (ok != true || v <= 0) return;
    final before = g.progress;
    g.saved = withdraw ? (g.saved - v < 0 ? 0 : g.saved - v) : g.saved + v;
    store.saveGoal(g);
    if (!withdraw && context.mounted && g.progress >= 1 && before < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chúc mừng! Bạn đã đạt mục tiêu "${g.name}"')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final goals = store.activeGoals;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Mục tiêu')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'goal',
        onPressed: () => edit(context, null),
        child: const Icon(PhosphorIconsRegular.plus),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                const BambooTree(progress: 0.3, height: 110),
                const SizedBox(height: 12),
                const Text('Trồng cây tre đầu tiên', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 6),
                Text('Mỗi mục tiêu (du lịch, laptop, quỹ dự phòng…) là một cây tre lớn dần theo số tiền bạn để dành.',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 14),
                FilledButton(onPressed: () => edit(context, null), child: const Text('Tạo mục tiêu')),
              ]),
            ),
          if (goals.isNotEmpty)
            Builder(builder: (context) {
              final saved = goals.fold<int>(0, (t, g) => t + g.saved);
              final r = store.savingRates;
              if (saved <= 0) return const SizedBox.shrink();
              final year = (saved * r.saving12 / 100).round();
              return Card(
                color: Brand.bamboo.withAlpha(28),
                child: ListTile(
                  leading: const VIcon(PhosphorIconsRegular.bank, color: Brand.bamboo),
                  title: Text('Gửi tiết kiệm ${money(saved)} đã tích lũy: thêm ~${money(year)}/năm',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Lãi tham khảo ${r.saving6}%/năm (6 tháng) · ${r.saving12}%/năm (12 tháng)'
                      '${r.note.isEmpty ? '' : ' · ${r.note}'}'),
                ),
              );
            }),
          for (final g in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => addMoney(context, g),
                  onLongPress: () => edit(context, g),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      BambooTree(progress: g.progress, height: 104),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(goalIcon(g.emoji), size: 22, color: Brand.bamboo),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(g.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    overflow: TextOverflow.ellipsis)),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') edit(context, g);
                                if (v == 'withdraw') addMoney(context, g, withdraw: true);
                                if (v == 'sim') {
                                  Pro.open(context, 'simulate', SimulateScreen(goalId: g.id));
                                }
                                if (v == 'del') store.deleteGoal(g.id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                PopupMenuItem(value: 'withdraw', child: Text('Rút bớt')),
                                PopupMenuItem(value: 'sim', child: Text('Mô phỏng tiết kiệm')),
                                PopupMenuItem(value: 'del', child: Text('Xóa')),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${money(g.saved)} / ${money(g.target)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 9,
                              color: g.progress >= 1 ? Brand.yellow : Brand.bamboo,
                              backgroundColor: Brand.bamboo.withAlpha(35),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_hint(g), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          if (goals.isNotEmpty)
            Text('Chạm vào cây để bỏ thêm tiền · giữ lâu để sửa',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  static String _hint(Goal g) {
    if (g.progress >= 1) return 'Đã đạt mục tiêu!';
    final left = g.target - g.saved;
    final pct = (g.progress * 100).floor();
    if (g.deadline == null) return '$pct% · còn ${money(left)}';
    final now = DateTime.now();
    final months = ((g.deadline!.year - now.year) * 12 + g.deadline!.month - now.month).clamp(1, 600);
    return '$pct% · cần để dành ${compactMoney((left / months).ceil())}/tháng đến ${dmy(g.deadline!)}';
  }
}
