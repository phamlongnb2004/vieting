import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models.dart';
import '../store.dart';
import '../util/format.dart';
import 'overview.dart' show fixBalanceGap;

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  static const _colors = [0xFF3E8E41, 0xFF152758, 0xFFC1272C, 0xFFA50064, 0xFFE8710A, 0xFF00897B, 0xFF6D4C41];

  Future<void> _edit(BuildContext context, Wallet? w) async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: w?.name ?? '');
    final bal = TextEditingController(text: w != null ? groupDigits(store.walletBalance(w)) : '');
    var kind = w?.kind ?? 'cash';
    var color = w?.color ?? _colors.first;
    var negative = w != null && store.walletBalance(w) < 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(w == null ? 'Thêm ví' : 'Sửa ví'),
          content: SizedBox(width: 360, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên ví')),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Tiền mặt')),
                  ButtonSegment(value: 'bank', label: Text('Ngân hàng')),
                  ButtonSegment(value: 'ewallet', label: Text('Ví ĐT')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setS(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bal,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(labelText: 'Số dư hiện tại', suffixText: '₫'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: negative,
                onChanged: (v) => setS(() => negative = v ?? false),
                title: const Text('Số dư âm (đang nợ)'),
              ),
              Wrap(spacing: 8, children: [
                for (final col in _colors)
                  GestureDetector(
                    onTap: () => setS(() => color = col),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(col),
                      child: color == col ? const Icon(PhosphorIconsRegular.check, color: Colors.white, size: 16) : null,
                    ),
                  ),
              ]),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final wallet = w ?? Wallet(id: newId(), name: name.text.trim());
    wallet
      ..name = name.text.trim()
      ..kind = kind
      ..color = color;
    final v = parseMoneyInput(bal.text);
    store.saveWallet(wallet, currentBalance: negative ? -v : v);
  }

  /// Mở app ngân hàng xem số dư thật, nhập vào: lệch thì ghi khoản thiếu hoặc chỉnh sổ.
  Future<void> _reconcile(BuildContext context, Wallet w) async {
    final store = StoreScope.read(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đối chiếu "${w.name}"'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sổ đang ghi ${money(store.walletBalance(w))}. Mở app ngân hàng / ví (hoặc đếm tiền mặt) rồi nhập số dư thật.'),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'Số dư thật', suffixText: '₫'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('So sánh')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty || !context.mounted) return;
    final gap = store.reconcileWallet(w, parseMoneyInput(c.text));
    if (gap.abs() < 1000) {
      if (gap != 0) store.reconcileWallet(w, parseMoneyInput(c.text), fix: true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khớp rồi, sổ sạch sẽ!')));
      return;
    }
    await fixBalanceGap(context, store, w, gap, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _delete(BuildContext context, Wallet w) async {
    final store = StoreScope.read(context);
    if (store.walletHasTxns(w.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ví này còn giao dịch. Xóa hoặc chuyển các giao dịch sang ví khác trước.')));
      return;
    }
    store.deleteWallet(w.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wallets = store.activeWallets;
    return Scaffold(
      appBar: AppBar(title: const Text('Ví & tài khoản')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(PhosphorIconsRegular.plus)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final w in wallets)
                ListTile(
                  leading: CircleAvatar(backgroundColor: Color(w.color), child: Icon(w.icon, color: Colors.white)),
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(w.bankId.isNotEmpty ? 'Tự cập nhật từ thông báo' : _kindName(w.kind)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(money(store.walletBalance(w)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    PopupMenuButton<String>(
                      onSelected: (v) => switch (v) {
                        'edit' => _edit(context, w),
                        'recon' => _reconcile(context, w),
                        _ => _delete(context, w),
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'recon', child: Text('Đối chiếu với số dư thật')),
                        PopupMenuItem(value: 'edit', child: Text('Sửa / chỉnh số dư')),
                        PopupMenuItem(value: 'del', child: Text('Xóa ví')),
                      ],
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            'Ví ngân hàng được tạo tự động khi VieTing đọc thông báo đầu tiên của ngân hàng đó, '
            'và số dư được khớp theo số dư ngân hàng báo về.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _kindName(String k) => switch (k) { 'bank' => 'Ngân hàng', 'ewallet' => 'Ví điện tử', _ => 'Tiền mặt' };
}
