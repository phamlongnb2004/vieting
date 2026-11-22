import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../categories.dart';
import '../models.dart';
import '../parser/bank_parser.dart';
import '../pro.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/txn_tile.dart';
import 'edit_txn.dart';

/// Dán nội dung thông báo / SMS ngân hàng để ghi nhanh (dùng được trên mọi máy, kể cả iPhone và PC).
class PasteScreen extends StatefulWidget {
  const PasteScreen({super.key});

  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> {
  final _ctrl = TextEditingController();
  String? _wallet;

  @override
  void initState() {
    super.initState();
    _paste();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _ai = false;

  Future<void> _paste({bool force = false}) async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    final looksMoney = RegExp(r'\d[\d.,]*\s*(vnd|đ|d\b|₫)|[+-]\s?\d', caseSensitive: false).hasMatch(t);
    if (t.isNotEmpty && (force || BankParser.parse(t) != null || looksMoney) && mounted) setState(() => _ctrl.text = t);
  }

  Future<void> _askAi() async {
    final store = StoreScope.read(context);
    setState(() => _ai = true);
    try {
      final list = await store.aiParse(_ctrl.text);
      if (!mounted) return;
      if (list.isEmpty) {
        showToast(context, 'AI cũng không thấy giao dịch nào trong nội dung này');
        return;
      }
      final added = store.addParsed(list, walletId: _wallet);
      if (!mounted) return;
      if (added.length == 1) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EditTxnScreen(txn: added.first)));
      } else {
        Navigator.pop(context);
        showToast(null, 'Đã ghi ${added.length} giao dịch từ nội dung dán');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.replaceFirst('Exception: ', '');
      if (msg.contains('Pro')) {
        Pro.check(context, 'ai');
      } else {
        showToast(context, msg);
      }
    } finally {
      if (mounted) setState(() => _ai = false);
    }
  }

  void _add() {
    final store = StoreScope.read(context);
    final r = store.ingest(
      RawNotice(package: 'paste', appName: '', title: '', text: _ctrl.text, time: DateTime.now()),
      source: 'paste',
      walletId: _wallet,
    );
    if (r.txn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy số tiền trong nội dung')));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EditTxnScreen(txn: r.txn)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = _ctrl.text.trim().isEmpty ? null : BankParser.parse(_ctrl.text);
    final wallets = store.activeWallets;

    return Scaffold(
      appBar: AppBar(title: const Text('Dán thông báo ngân hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'VD: TK 1234 -50,000VND lúc 15:20. SD: 1,234,567VND. ND: thanh toan highlands',
              suffixIcon: IconButton(icon: const Icon(PhosphorIconsRegular.clipboard), onPressed: () => _paste(force: true)),
            ),
          ),
          const SizedBox(height: 16),
          if (p != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(money(p.signed, signed: true),
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900, color: p.income ? Brand.income : Brand.expense)),
                  const SizedBox(height: 6),
                  Row(children: [
                    CatAvatar(cat: catById(guessCategory(p.income, p.note, store.learnedRules)), size: 30),
                    const SizedBox(width: 8),
                    Text(catById(guessCategory(p.income, p.note, store.learnedRules)).name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  if (p.balance != null) ...[
                    const SizedBox(height: 6),
                    Text('Số dư: ${money(p.balance!)}'),
                  ],
                  const SizedBox(height: 6),
                  Text(p.note, style: TextStyle(color: cs.onSurfaceVariant)),
                  const Divider(height: 24),
                  Row(children: [
                    const Text('Ghi vào ví: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _wallet,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Tự chọn theo ngân hàng')),
                          for (final w in wallets) DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
                        ],
                        onChanged: (v) => setState(() => _wallet = v),
                      ),
                    ),
                  ]),
                ]),
              ),
            )
          else if (_ctrl.text.trim().isNotEmpty) ...[
            Text('Bộ đọc có sẵn chưa hiểu mẫu tin này.', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _ai ? null : _askAi,
              icon: _ai
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(PhosphorIconsRegular.sparkle),
              label: const Text('Nhờ AI đọc (MoMo, ZaloPay, nhiều tin một lúc…)'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: p == null ? null : _add,
            icon: const Icon(PhosphorIconsRegular.plus),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Thêm giao dịch')),
          ),
        ],
      ),
    );
  }
}
