import 'package:flutter/material.dart';

import '../categories.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';

Future<void> openEditTxn(BuildContext context, Txn? txn,
    {int? presetAmount, bool presetIncome = false, String? presetNote}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditTxnScreen(
        txn: txn,
        presetAmount: presetAmount,
        presetIncome: presetIncome,
        presetNote: presetNote,
      ),
    ),
  );
}

class EditTxnScreen extends StatefulWidget {
  final Txn? txn;
  final int? presetAmount;
  final bool presetIncome;
  final String? presetNote;
  const EditTxnScreen({super.key, this.txn, this.presetAmount, this.presetIncome = false, this.presetNote});

  @override
  State<EditTxnScreen> createState() => _EditTxnScreenState();
}

class _EditTxnScreenState extends State<EditTxnScreen> {
  late bool _income;
  late String _cat;
  late String _wallet;
  late DateTime _date;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _originalCat;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    final store = StoreScope.read(context);
    _income = t?.income ?? widget.presetIncome;
    _cat = t?.categoryId ?? (_income ? 'nhan_tien' : 'an_uong');
    _originalCat = t?.categoryId;
    final wallets = store.activeWallets;
    _wallet = t?.walletId ?? (wallets.isNotEmpty ? wallets.first.id : 'cash');
    _date = t?.date ?? DateTime.now();
    final amt = t?.amount ?? widget.presetAmount;
    if (amt != null) _amount.text = groupDigits(amt);
    _note.text = t?.note ?? widget.presetNote ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day, tm?.hour ?? _date.hour, tm?.minute ?? _date.minute));
  }

  void _save() {
    final amount = parseMoneyInput(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập số tiền trước đã')));
      return;
    }
    final store = StoreScope.read(context);
    final t = widget.txn?.copy() ??
        Txn(id: newId(), amount: amount, income: _income, categoryId: _cat, walletId: _wallet, date: _date);
    t
      ..amount = amount
      ..income = _income
      ..categoryId = _cat
      ..walletId = _wallet
      ..date = _date
      ..note = _note.text.trim();
    // Người dùng sửa danh mục của giao dịch tự động -> ghi nhớ cho lần sau
    if (widget.txn != null && widget.txn!.auto && _originalCat != _cat && t.note.isNotEmpty) {
      store.learnCategory(t.note, _cat);
    }
    store.saveTxn(t);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true && mounted) {
      StoreScope.read(context).deleteTxn(widget.txn!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final wallets = store.activeWallets;
    if (!wallets.any((w) => w.id == _wallet) && wallets.isNotEmpty && store.wallets[_wallet] == null) {
      _wallet = wallets.first.id;
    }
    final color = _income ? Brand.income : Brand.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.txn == null ? 'Thêm giao dịch' : 'Sửa giao dịch'),
        actions: [
          if (widget.txn != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Khoản chi'), icon: Icon(Icons.north_east)),
              ButtonSegment(value: true, label: Text('Khoản thu'), icon: Icon(Icons.south_west)),
            ],
            selected: {_income},
            onSelectionChanged: (s) => setState(() {
              _income = s.first;
              if (catById(_cat).income != _income) _cat = _income ? 'nhan_tien' : 'an_uong';
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: widget.txn == null && widget.presetAmount == null,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: '₫',
              prefixText: _income ? '+ ' : '− ',
              prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in catsFor(_income))
              ChoiceChip(
                avatar: Icon(c.icon, size: 18, color: c.color),
                label: Text(c.name),
                selected: _cat == c.id,
                onSelected: (_) => setState(() => _cat = c.id),
              ),
          ]),
          const SizedBox(height: 18),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Ví / tài khoản'),
                trailing: DropdownButton<String>(
                  value: wallets.any((w) => w.id == _wallet) ? _wallet : null,
                  hint: Text(store.walletName(_wallet)),
                  underline: const SizedBox(),
                  items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
                  onChanged: (v) => setState(() => _wallet = v ?? _wallet),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Thời gian'),
                trailing: Text('${hm(_date)} · ${dmy(_date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: _pickDate,
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.notes)),
          ),
          if (widget.txn != null && widget.txn!.raw.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.notifications_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Đọc từ ${widget.txn!.source == 'shortcut' ? 'Phím tắt iPhone' : 'thông báo'}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  Text(widget.txn!.raw, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (widget.txn!.balanceAfter != null) ...[
                    const SizedBox(height: 6),
                    Text('Số dư sau giao dịch: ${money(widget.txn!.balanceAfter!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Lưu')),
          ),
        ],
      ),
    );
  }
}
