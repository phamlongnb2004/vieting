import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../pro.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';

/// Sổ chung cho cặp đôi / gia đình / nhóm đi chơi: ai trả bao nhiêu, ai nợ ai.
class GroupsScreen extends StatelessWidget {
  final bool embedded;
  const GroupsScreen({super.key, this.embedded = false});

  static Future<Group?> editGroup(BuildContext context, Group? g) async {
    final name = TextEditingController(text: g?.name ?? '');
    final members = TextEditingController(text: g?.members.join(', ') ?? 'Tôi, ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(g == null ? 'Sổ chung mới' : 'Sửa sổ chung'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên (VD: Đi Đà Lạt, Nhà mình)')),
            const SizedBox(height: 12),
            TextField(
              controller: members,
              decoration: const InputDecoration(labelText: 'Thành viên, cách nhau dấu phẩy', hintText: 'Tôi, Lan, Minh'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return null;
    final list = members.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (name.text.trim().isEmpty || list.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần tên sổ và ít nhất 2 thành viên')));
      return null;
    }
    final group = g ?? Group(id: newId(), name: '', members: []);
    group
      ..name = name.text.trim()
      ..members = list;
    StoreScope.read(context).saveGroup(group);
    return group;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final groups = store.activeGroups;
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Sổ chung')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'group',
        onPressed: () async {
          if (!await Pro.check(context, 'groups', count: store.activeGroups.length)) return;
          if (!context.mounted) return;
          final g = await editGroup(context, null);
          if (g != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)));
          }
        },
        child: const Icon(Icons.group_add),
      ),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.groups_2_outlined, size: 64, color: Brand.bamboo),
                  const SizedBox(height: 10),
                  const Text('Sổ chung minh bạch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('Cho cặp đôi, gia đình hay nhóm đi du lịch: ghi ai trả, chia cho ai, app tự tính ai nợ ai để chốt sổ nhanh.',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Brand.bamboo, child: Icon(Icons.groups, color: Colors.white)),
                        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${g.members.length} người · ${g.expenses.length} khoản · tổng ${compactMoney(g.total)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id))),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  Future<void> _addExpense(BuildContext context, Group g, [GroupExpense? old]) async {
    final store = StoreScope.read(context);
    final desc = TextEditingController(text: old?.desc ?? '');
    final amount = TextEditingController(text: old == null ? '' : groupDigits(old.amount));
    var payer = old?.payer ?? g.members.first;
    final chosen = <String>{...(old?.shares.keys ?? g.members)};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(old == null ? 'Thêm khoản chi chung' : 'Sửa khoản chi'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Nội dung (VD: Tiền phòng)')),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(labelText: 'Số tiền', suffixText: '₫'),
                ),
                const SizedBox(height: 12),
                const Text('Ai trả?', style: TextStyle(fontWeight: FontWeight.w700)),
                Wrap(spacing: 6, children: [
                  for (final m in g.members)
                    ChoiceChip(label: Text(m), selected: payer == m, onSelected: (_) => setS(() => payer = m)),
                ]),
                const SizedBox(height: 10),
                const Text('Chia đều cho', style: TextStyle(fontWeight: FontWeight.w700)),
                Wrap(spacing: 6, children: [
                  for (final m in g.members)
                    FilterChip(
                      label: Text(m),
                      selected: chosen.contains(m),
                      onSelected: (v) => setS(() => v ? chosen.add(m) : chosen.remove(m)),
                    ),
                ]),
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
    final v = parseMoneyInput(amount.text);
    if (ok != true || v <= 0 || chosen.isEmpty) return;
    // chia đều, phần lẻ dồn cho người đầu
    final people = g.members.where(chosen.contains).toList();
    final each = v ~/ people.length;
    final shares = {for (final m in people) m: each};
    shares[people.first] = shares[people.first]! + (v - each * people.length);
    final e = GroupExpense(
      id: old?.id ?? newId(),
      desc: desc.text.trim().isEmpty ? 'Khoản chi' : desc.text.trim(),
      amount: v,
      payer: payer,
      shares: shares,
      date: old?.date ?? DateTime.now(),
    );
    if (old != null) g.expenses.removeWhere((x) => x.id == old.id);
    g.expenses.insert(0, e);
    store.saveGroup(g);
  }

  String _summary(Group g) {
    final b = StringBuffer('📒 ${g.name} – tổng ${money(g.total)}\n');
    g.balances().forEach((m, v) => b.writeln('• $m: ${v >= 0 ? 'được nhận lại ${money(v)}' : 'cần trả ${money(-v)}'}'));
    final s = g.settle();
    if (s.isNotEmpty) {
      b.writeln('\nChốt sổ:');
      for (final x in s) {
        b.writeln('→ ${x.from} chuyển ${x.to}: ${money(x.amount)}');
      }
    }
    b.write('\n(Tính bằng VieTing)');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.groups[groupId];
    final cs = Theme.of(context).colorScheme;
    if (g == null || g.deleted) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Sổ đã bị xóa')));
    }
    final bal = g.balances();
    final settle = g.settle();
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          IconButton(
            tooltip: 'Chia sẻ tóm tắt',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Share.share(_summary(g)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') await GroupsScreen.editGroup(context, g);
              if (v == 'del' && context.mounted) {
                store.deleteGroup(g.id);
                Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa tên / thành viên')),
              PopupMenuItem(value: 'del', child: Text('Xóa sổ')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExpense(context, g),
        icon: const Icon(Icons.add),
        label: const Text('Khoản chi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tổng chi chung: ${money(g.total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                for (final m in g.members)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      CircleAvatar(radius: 13, backgroundColor: Brand.bamboo.withAlpha(40), child: Text(m.characters.first, style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m)),
                      Text(
                        (bal[m] ?? 0) >= 0 ? '+${money(bal[m] ?? 0)}' : money(bal[m] ?? 0),
                        style: TextStyle(fontWeight: FontWeight.w700, color: (bal[m] ?? 0) >= 0 ? Brand.income : Brand.expense),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (settle.isNotEmpty)
            Card(
              color: Brand.yellow.withAlpha(45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Chốt sổ (ít lần chuyển nhất)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final x in settle)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('${x.from} → ${x.to}: ${money(x.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          if (g.expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Chưa có khoản chi nào. Bấm "Khoản chi" để thêm.',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final e in g.expenses)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Brand.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) {
                g.expenses.removeWhere((x) => x.id == e.id);
                store.saveGroup(g);
              },
              child: ListTile(
                title: Text(e.desc, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${e.payer} trả · chia ${e.shares.length} người · ${dmy(e.date)}'),
                trailing: Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _addExpense(context, g, e),
              ),
            ),
        ],
      ),
    );
  }
}
