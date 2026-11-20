import 'package:flutter/material.dart';

import '../categories.dart';
import '../insights.dart';
import '../models.dart';
import '../parser/quick_add.dart';
import '../services/receipt.dart';
import '../services/voice.dart';
import '../store.dart';
import '../widgets/nudge.dart';
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
  String _tag = '';
  bool _listening = false;
  bool _reading = false;
  String _heard = '';

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
    _tag = t?.tag ?? '';
  }

  /// Điền form từ câu nói / ảnh hóa đơn / gợi ý.
  void _fill({required int amount, required bool income, required String cat, String? note, DateTime? date, String? wallet}) {
    setState(() {
      _income = income;
      _amount.text = groupDigits(amount);
      _cat = catById(cat).income == income ? cat : (income ? 'khac_thu' : 'khac_chi');
      if (note != null && note.isNotEmpty) _note.text = note;
      if (date != null) _date = date;
      if (wallet != null && StoreScope.read(context).wallets[wallet] != null) _wallet = wallet;
    });
  }

  Future<void> _voice() async {
    if (_listening) {
      await Voice.stop();
      setState(() => _listening = false);
      return;
    }
    final store = StoreScope.read(context);
    setState(() {
      _listening = true;
      _heard = '';
    });
    final ok = await Voice.listen(
      onText: (t) {
        if (mounted) setState(() => _heard = t);
      },
      onDone: (t) {
        if (!mounted) return;
        setState(() => _listening = false);
        final q = QuickAdd.parse(t, store.learnedRules);
        if (q == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chưa nghe ra số tiền trong: "$t"')));
          return;
        }
        _fill(amount: q.amount, income: q.income, cat: q.categoryId, note: q.note);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máy chưa cho dùng micro / nhận giọng nói. Kiểm tra quyền micro của VieTing.')));
    }
  }

  Future<void> _receipt(bool camera) async {
    setState(() => _reading = true);
    final r = await Receipt.pickAndRead(StoreScope.read(context), camera: camera);
    if (!mounted) return;
    setState(() => _reading = false);
    if (r == null) return;
    if (r.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error!)));
      return;
    }
    final a = r.action!;
    _fill(
      amount: (a['amount'] as num).toInt(),
      income: a['income'] == true,
      cat: (a['category'] ?? 'khac_chi') as String,
      note: (a['note'] ?? '') as String,
      date: DateTime.tryParse((a['date'] ?? '') as String) == null
          ? null
          : (() {
              final d = DateTime.parse(a['date'] as String);
              return DateTime(d.year, d.month, d.day, _date.hour, _date.minute);
            })(),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đọc hóa đơn, kiểm tra lại rồi bấm Lưu')));
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
      ..note = _note.text.trim()
      ..tag = _income ? '' : _tag;
    // Người dùng sửa danh mục của giao dịch tự động -> ghi nhớ cho lần sau
    if (widget.txn != null && widget.txn!.auto && _originalCat != _cat && t.note.isNotEmpty) {
      store.learnCategory(t.note, _cat);
    }
    store.saveTxn(t);
    final nudges = widget.txn == null ? store.nudgesFor(t) : const <Nudge>[];
    Navigator.pop(context);
    showNudges(nudges);
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
          if (widget.txn == null) ...[
            // Nhập nhanh: nói, chụp hóa đơn / QR, chọn ảnh
            Row(children: [
              if (Voice.supported)
                Expanded(
                  child: _QuickBtn(
                    icon: _listening ? Icons.stop_circle : Icons.mic,
                    label: _listening ? 'Đang nghe…' : 'Nói',
                    active: _listening,
                    onTap: _voice,
                  ),
                ),
              if (Voice.supported) const SizedBox(width: 8),
              Expanded(
                child: _QuickBtn(
                  icon: Icons.document_scanner_outlined,
                  label: _reading ? 'Đang đọc…' : 'Chụp hóa đơn',
                  active: _reading,
                  onTap: _reading ? null : () => _receipt(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickBtn(
                  icon: Icons.qr_code_2,
                  label: 'Ảnh CK / QR',
                  onTap: _reading ? null : () => _receipt(false),
                ),
              ),
            ]),
            if (_listening || _heard.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_heard.isEmpty ? 'Nói kiểu: "ăn phở 45 nghìn", "nhận lương 15 triệu"' : '"$_heard"',
                    style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.normal)),
              ),
            Builder(builder: (context) {
              final sugg = store.suggestionsAt(DateTime.now());
              if (sugg.isEmpty) return const SizedBox(height: 12);
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hay chi vào giờ này', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final g in sugg)
                      ActionChip(
                        avatar: Icon(catById(g.categoryId).icon, size: 18, color: catById(g.categoryId).color),
                        label: Text('${g.note} · ${compactMoney(g.amount)}'),
                        onPressed: () =>
                            _fill(amount: g.amount, income: false, cat: g.categoryId, note: g.note, wallet: g.walletId),
                      ),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],
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
          if (!_income) ...[
            const SizedBox(height: 16),
            const Text('Vì sao chi khoản này?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final tg in kTags)
                FilterChip(
                  avatar: Icon(tg.icon, size: 18, color: tg.color),
                  label: Text(tg.name),
                  selected: _tag == tg.id,
                  onSelected: (v) => setState(() => _tag = v ? tg.id : ''),
                ),
            ]),
          ],
          const SizedBox(height: 18),
          Card(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Ví / tài khoản', style: TextStyle(fontSize: 15)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final w in wallets)
                      ChoiceChip(
                        avatar: Icon(w.icon, size: 16, color: Color(w.color)),
                        label: Text(w.name),
                        selected: _wallet == w.id,
                        onSelected: (_) => setState(() => _wallet = w.id),
                      ),
                  ]),
                ]),
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


class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _QuickBtn({required this.icon, required this.label, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? Brand.red : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Icon(icon, color: active ? Colors.white : Brand.red),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
