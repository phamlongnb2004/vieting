import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../categories.dart';
import '../models.dart';
import '../parser/bank_parser.dart';
import '../store.dart';
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

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    if (t.isNotEmpty && BankParser.parse(t) != null && mounted) setState(() => _ctrl.text = t);
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
              suffixIcon: IconButton(icon: const Icon(Icons.content_paste), onPressed: _paste),
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
          else if (_ctrl.text.trim().isNotEmpty)
            Text('Chưa đọc được số tiền. Nội dung cần có số tiền kèm VND/đ hoặc dấu +/−.',
                style: TextStyle(color: cs.error)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: p == null ? null : _add,
            icon: const Icon(Icons.add),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Thêm giao dịch')),
          ),
        ],
      ),
    );
  }
}
