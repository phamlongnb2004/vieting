import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../models.dart';
import '../pro.dart';
import '../services/goal_money.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/bamboo.dart';
import 'simulate.dart';
import '../widgets/vicon.dart';
import '../widgets/vietqr_sheet.dart';

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
    var hold = g?.hold ?? 'app';
    var bin = g?.bin ?? '';
    final holdName = TextEditingController(text: g?.holdName ?? '');
    final acct = TextEditingController(text: g?.acct ?? '');
    final owner = TextEditingController(text: g?.owner ?? '');
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
                  leading: const VIcon(PhosphorIconsRegular.calendarBlank, size: 36),
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
                const SizedBox(height: 4),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tiền để dành nằm ở đâu?', style: TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'app', label: Text('Trong ví')),
                    ButtonSegment(value: 'bank', label: Text('TK riêng')),
                    ButtonSegment(value: 'cash', label: Text('Tiền mặt')),
                  ],
                  selected: {hold},
                  onSelectionChanged: (v) => setS(() => hold = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (hold) {
                    'bank' => 'Tốt nhất: chuyển hẳn sang tài khoản tiết kiệm / Hũ / Túi riêng. VieTing tạo mã QR có nội dung riêng, '
                        'trên Android tự xác nhận khi thông báo ngân hàng báo tiền đã đi.',
                    'cash' => 'Rút tiền mặt để riêng (phong bì, két). Mỗi tháng VieTing nhắc bạn đếm lại cho khớp.',
                    _ => 'Tiền vẫn nằm chung trong ví, VieTing chỉ "khóa" phần này khỏi số có thể tiêu. Dễ tiêu lấn nhất.',
                  },
                  style: TextStyle(fontSize: 12.5, color: Theme.of(c).colorScheme.onSurfaceVariant),
                ),
                if (hold != 'app') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: holdName,
                    decoration: InputDecoration(labelText: hold == 'bank' ? 'Tên (VD: Hũ Du lịch Techcombank)' : 'Để ở đâu (VD: phong bì tủ áo)'),
                  ),
                ],
                if (hold == 'bank') ...[
                  const SizedBox(height: 8),
                  BankPicker(bin: bin, onChanged: (v) => setS(() => bin = v)),
                  const SizedBox(height: 8),
                  TextField(controller: acct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tài khoản tiết kiệm / Hũ')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: owner,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Tên chủ tài khoản (không dấu)'),
                  ),
                ],
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
      ..deadline = deadline
      ..hold = hold
      ..holdName = holdName.text.trim()
      ..bin = hold == 'bank' ? bin : ''
      ..acct = hold == 'bank' ? acct.text.replaceAll(RegExp(r'\s+'), '') : ''
      ..owner = hold == 'bank' ? owner.text.trim().toUpperCase() : '';
    if (goal.hasQr) GoalMoney.ensureCode(store, goal);
    store.saveGoal(goal);
  }

  static Future<int?> _askAmount(BuildContext context, String title, {String? help}) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(suffixText: '₫'),
            ),
            if (help != null) ...[
              const SizedBox(height: 8),
              Text(help, style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tiếp')),
        ],
      ),
    );
    final v = parseMoneyInput(c.text);
    return ok == true && v > 0 ? v : null;
  }

  /// Chọn ví bị trừ tiền khi chuyển sang tài khoản tiết kiệm (mặc định: ví ngân hàng đầu tiên).
  static String? _defaultWallet(AppStore store) {
    final ws = store.activeWallets;
    if (ws.isEmpty) return null;
    return (ws.where((w) => w.kind == 'bank').firstOrNull ?? ws.first).id;
  }

  static Future<String?> _pickWallet(BuildContext context, String title) async {
    final store = StoreScope.read(context);
    final ws = store.activeWallets;
    if (ws.length <= 1) return ws.isEmpty ? null : ws.first.id;
    return showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(14), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          for (final w in ws)
            ListTile(
              leading: Icon(w.icon, color: Color(w.color)),
              title: Text(w.name),
              trailing: Text(money(store.walletBalance(w))),
              onTap: () => Navigator.pop(c, w.id),
            ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.prohibit),
            title: const Text('Tiền từ nơi khác (không trừ ví nào)'),
            onTap: () => Navigator.pop(c, ''),
          ),
        ]),
      ),
    );
  }

  static Future<void> addMoney(BuildContext context, Goal g, {bool withdraw = false}) async {
    if (withdraw) return _withdraw(context, g);
    final store = StoreScope.read(context);
    final v = await _askAmount(context, 'Bỏ thêm vào "${g.name}"',
        help: g.hasQr ? 'Bước sau VieTing tạo mã QR chuyển sang ${g.holdName.isEmpty ? 'tài khoản tiết kiệm' : g.holdName}.' : null);
    if (v == null || !context.mounted) return;
    if (g.hold != 'bank' && v > store.spendableBalance) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Số dư không đủ'),
          content: Text('Bạn chỉ còn ${money(store.spendableBalance < 0 ? 0 : store.spendableBalance)} chưa cất vào hũ nào. '
              'Vẫn ghi ${money(v)} vào "${g.name}"? (Hãy chắc là bạn có số tiền này, VD vừa nhận lương chưa ghi.)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn ghi')),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    }
    final before = g.progress;
    if (g.hasQr) {
      GoalMoney.ensureCode(store, g);
      final m = GoalMoney.deposit(store, g, v, confirmed: false);
      if (!context.mounted) return;
      final done = await showVietQrSheet(
        context,
        title: 'Chuyển ${compactMoney(v)} sang "${g.holdName.isEmpty ? g.name : g.holdName}"',
        bin: g.bin,
        acct: g.acct,
        owner: g.owner,
        amount: v,
        memo: GoalMoney.memo(g),
        hint: Platform.isAndroid
            ? 'Giữ nguyên nội dung chuyển khoản. Khi thông báo ngân hàng báo tiền đã đi, VieTing tự đánh dấu "Đã cất". '
                'Chuyển xong có thể bấm "Tôi đã chuyển" luôn.'
            : 'Quét mã bằng app ngân hàng, chuyển xong quay lại bấm "Tôi đã chuyển".',
      );
      if (!context.mounted) return;
      if (done == true) {
        final w = await _pickWallet(context, 'Tiền đi từ ví nào?');
        if (!context.mounted) return;
        final from = w ?? _defaultWallet(store);
        GoalMoney.confirm(store, g, m, fromWallet: from == null || from.isEmpty ? null : from);
        showToast(context, 'Đã cất ${money(v)} vào "${g.name}"');
      } else {
        showToast(context, 'Khoản ${money(v)} đang "Chờ xác nhận". Chuyển xong thì bấm "Tôi đã chuyển" trên thẻ mục tiêu.');
      }
    } else {
      String? from;
      if (g.hold == 'bank') {
        from = await _pickWallet(context, 'Tiền đi từ ví nào?');
        if (!context.mounted) return;
        if (from == '') from = null;
      }
      GoalMoney.deposit(store, g, v, fromWallet: from);
      if (!context.mounted) return;
      showToast(
          context,
          g.hold == 'bank'
              ? 'Đã cất ${money(v)} vào "${g.name}"'
              : 'Đã khóa ${money(v)} cho "${g.name}". Số tiền có thể tiêu giờ còn ${money(store.spendableBalance)}.');
    }
    if (g.progress >= 1 && before < 1 && context.mounted) showToast(context, 'Chúc mừng! Bạn đã đạt mục tiêu "${g.name}"');
  }

  static Future<void> _withdraw(BuildContext context, Goal g) async {
    final store = StoreScope.read(context);
    final c = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final v = parseMoneyInput(c.text);
          final rate = GoalMoney.dailyRate(g);
          final days = rate > 0 && v > 0 ? (v / rate).ceil() : 0;
          return AlertDialog(
            title: Text('Rút từ "${g.name}"'),
            content: SizedBox(
              width: 340,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đang có ${money(g.saved)}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  onChanged: (_) => setS(() {}),
                  decoration: const InputDecoration(labelText: 'Rút bao nhiêu', suffixText: '₫'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reason,
                  onChanged: (_) => setS(() {}),
                  decoration: const InputDecoration(labelText: 'Lý do (bắt buộc)', hintText: 'VD: sửa xe gấp, đóng học'),
                ),
                if (days > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Brand.red.withAlpha(22), borderRadius: BorderRadius.circular(12)),
                    child: Text('Rút ${compactMoney(v)} làm mục tiêu lùi khoảng $days ngày (theo tốc độ để dành 90 ngày qua).',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi, giữ lại')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.red),
                onPressed: v > 0 && reason.text.trim().length >= 2 ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Rút'),
              ),
            ],
          );
        },
      ),
    );
    final v = parseMoneyInput(c.text);
    if (ok != true || v <= 0 || !context.mounted) return;
    // xác nhận lần hai: chặn rút theo cảm hứng
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chắc chưa?'),
        content: Text('Rút ${money(v > g.saved ? g.saved : v)} khỏi "${g.name}" vì "${reason.text.trim()}". '
            'Khoản rút được lưu vào lịch sử của mục tiêu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để mình nghĩ lại')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chắc rồi')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    String? to;
    if (g.hold == 'bank') {
      to = await _pickWallet(context, 'Tiền rút về ví nào?');
      if (!context.mounted) return;
      if (to == '') to = null;
    }
    GoalMoney.withdraw(store, g, v, reason.text.trim(), toWallet: to);
  }

  static Future<void> reconcile(BuildContext context, Goal g) async {
    final store = StoreScope.read(context);
    final v = await _askAmount(context, 'Đối chiếu "${g.name}"',
        help: g.hold == 'bank'
            ? 'Mở app ngân hàng xem ${g.holdName.isEmpty ? 'tài khoản tiết kiệm' : g.holdName} đang có bao nhiêu. Sổ đang ghi ${money(g.saved)}.'
            : 'Đếm lại ${g.holdName.isEmpty ? 'tiền để riêng' : g.holdName}. Sổ đang ghi ${money(g.saved)}.');
    if (v == null || !context.mounted) return;
    final gap = v - g.saved;
    GoalMoney.reconcile(store, g, v);
    showToast(context, gap == 0 ? 'Khớp từng đồng, quá đỉnh!' : 'Đã chỉnh sổ theo số thật (${gap > 0 ? 'dư' : 'thiếu'} ${money(gap.abs())}).');
  }

  static void history(BuildContext context, Goal g) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (c, ctl) => ListView(controller: ctl, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Text('Lịch sử "${g.name}"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (g.moves.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Chưa có lần nào', style: TextStyle(color: cs.onSurfaceVariant))),
          for (final m in g.moves.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: VIcon(m.amount >= 0 ? PhosphorIconsRegular.arrowDownLeft : PhosphorIconsRegular.arrowUpRight,
                  color: m.status == 'pending' ? Brand.yellow : (m.amount >= 0 ? Brand.income : Brand.red), size: 36),
              title: Text('${m.amount >= 0 ? '+' : '−'}${money(m.amount.abs())}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text([
                dmy(DateTime.fromMillisecondsSinceEpoch(m.at)),
                if (m.status == 'pending') 'chờ xác nhận',
                if (m.reason.isNotEmpty) m.reason,
              ].join(' · ')),
            ),
        ]),
      ),
    );
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
          if (store.lockedInGoals > 0)
            Card(
              color: Brand.navy.withAlpha(20),
              child: ListTile(
                leading: const VIcon(PhosphorIconsFill.lockSimple),
                title: Text('Đang khóa ${money(store.lockedInGoals)} trong hũ', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Tiền vẫn nằm trong ví nhưng không tính vào số "có thể tiêu" và hạn mức mỗi ngày. '
                    'Có thể tiêu: ${money(store.spendableBalance)}. Chi lấn vào tiền hũ, VieTing sẽ nhắc ngay. '
                    'Muốn chắc ăn hơn: sửa mục tiêu, chọn "TK riêng" để chuyển hẳn tiền sang tài khoản tiết kiệm.'),
              ),
            ),
          if (store.savedOutside > 0)
            Card(
              color: Brand.bamboo.withAlpha(22),
              child: ListTile(
                leading: const VIcon(PhosphorIconsFill.bank, color: Brand.bamboo),
                title: Text('${money(store.savedOutside)} đã nằm ở tài khoản riêng', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Tiền đã chuyển ra khỏi ví tiêu hằng ngày, muốn tiêu cũng phải rút ra và ghi lý do.'),
              ),
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
                                if (v == 'recon') reconcile(context, g);
                                if (v == 'hist') history(context, g);
                                if (v == 'sim') {
                                  Pro.open(context, 'simulate', SimulateScreen(goalId: g.id));
                                }
                                if (v == 'del') store.deleteGoal(g.id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                PopupMenuItem(value: 'withdraw', child: Text('Rút bớt')),
                                PopupMenuItem(value: 'hist', child: Text('Lịch sử bỏ vào / rút ra')),
                                PopupMenuItem(value: 'recon', child: Text('Đối chiếu số dư thật')),
                                PopupMenuItem(value: 'sim', child: Text('Mô phỏng tiết kiệm')),
                                PopupMenuItem(value: 'del', child: Text('Xóa')),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${money(g.saved)} / ${money(g.target)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (g.separate)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _Badge(
                                icon: g.hold == 'bank' ? PhosphorIconsFill.bank : PhosphorIconsFill.envelopeSimple,
                                text: g.holdName.isNotEmpty ? g.holdName : (g.hold == 'bank' ? 'Có tài khoản riêng' : 'Tiền mặt để riêng'),
                                color: Brand.bamboo,
                              ),
                            ),
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
                          for (final m in g.pending)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                              decoration: BoxDecoration(color: Brand.yellow.withAlpha(45), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Expanded(
                                    child: Text('Chờ xác nhận ${compactMoney(m.amount)}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                                TextButton(
                                  onPressed: () async {
                                    final again = await showVietQrSheet(context,
                                        title: 'Chuyển ${compactMoney(m.amount)} sang "${g.holdName.isEmpty ? g.name : g.holdName}"',
                                        bin: g.bin,
                                        acct: g.acct,
                                        owner: g.owner,
                                        amount: m.amount,
                                        memo: GoalMoney.memo(g),
                                        secondary: 'Hủy khoản này');
                                    if (!context.mounted) return;
                                    if (again == true) {
                                      final w = await _pickWallet(context, 'Tiền đi từ ví nào?');
                                      if (!context.mounted) return;
                                      GoalMoney.confirm(store, g, m, fromWallet: w == null || w.isEmpty ? null : w);
                                    } else if (again == false) {
                                      GoalMoney.cancel(store, g, m);
                                    }
                                  },
                                  child: const Text('Mở'),
                                ),
                              ]),
                            ),
                          if (GoalMoney.needsRecon(g))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: ActionChip(
                                avatar: const Icon(PhosphorIconsRegular.scales, size: 16),
                                label: const Text('Đã 30 ngày, đối chiếu số dư'),
                                onPressed: () => reconcile(context, g),
                              ),
                            ),
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

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Badge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}
