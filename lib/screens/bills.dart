import 'package:flutter/material.dart';

import '../categories.dart';
import '../insights.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/nudge.dart';

/// Khoản định kỳ: gói đăng ký (Netflix, Spotify, gym...) và trả góp. Nhắc trước 3 ngày.
class BillsScreen extends StatelessWidget {
  final bool embedded;
  const BillsScreen({super.key, this.embedded = false});

  static const _presets = [
    ('Netflix', 260000, 'giai_tri'),
    ('Spotify', 59000, 'giai_tri'),
    ('YouTube Premium', 79000, 'giai_tri'),
    ('iCloud', 45000, 'hoa_don'),
    ('Google One', 45000, 'hoa_don'),
    ('Gym', 500000, 'suc_khoe'),
    ('Internet', 220000, 'hoa_don'),
    ('Tiền nhà', 3000000, 'nha_o'),
  ];

  static Future<void> edit(BuildContext context, Bill? b, {bool installment = false}) async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: b?.name ?? '');
    final amount = TextEditingController(text: b == null ? '' : groupDigits(b.amount));
    final left = TextEditingController(text: b?.remaining?.toString() ?? (installment ? '6' : ''));
    var cycle = b?.cycle ?? 'month';
    var cat = b?.categoryId ?? (installment ? 'mua_sam' : 'hoa_don');
    var next = b?.next ?? DateTime.now().add(const Duration(days: 30));
    var isInst = b?.isInstallment ?? installment;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(b == null ? (isInst ? 'Thêm khoản trả góp' : 'Thêm gói định kỳ') : 'Sửa khoản định kỳ'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (b == null && !isInst)
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final p in _presets)
                      ActionChip(
                        label: Text(p.$1),
                        onPressed: () => setS(() {
                          name.text = p.$1;
                          amount.text = groupDigits(p.$2);
                          cat = p.$3;
                        }),
                      ),
                  ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Là trả góp (có số kỳ)'),
                  value: isInst,
                  onChanged: (v) => setS(() => isInst = v),
                ),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên (VD: Netflix, Trả góp iPhone)')),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(labelText: 'Số tiền mỗi kỳ', suffixText: '₫'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Tuần')),
                    ButtonSegment(value: 'month', label: Text('Tháng')),
                    ButtonSegment(value: 'year', label: Text('Năm')),
                  ],
                  selected: {cycle},
                  onSelectionChanged: (s) => setS(() => cycle = s.first),
                ),
                if (isInst) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: left,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Còn bao nhiêu kỳ'),
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text('Kỳ tới: ${dmy(next)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: c,
                      initialDate: next,
                      firstDate: DateTime.now().subtract(const Duration(days: 60)),
                      lastDate: DateTime.now().add(const Duration(days: 800)),
                    );
                    if (d != null) setS(() => next = d);
                  },
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: cat,
                  items: [for (final x in catsFor(false)) DropdownMenuItem(value: x.id, child: Text(x.name))],
                  onChanged: (v) => setS(() => cat = v ?? cat),
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
    final v = parseMoneyInput(amount.text);
    if (ok != true || name.text.trim().isEmpty || v <= 0) return;
    final bill = b ?? Bill(id: newId(), name: '', amount: 0, next: next);
    bill
      ..name = name.text.trim()
      ..amount = v
      ..cycle = cycle
      ..next = next
      ..categoryId = cat
      ..remaining = isInst ? (int.tryParse(left.text.trim()) ?? 1) : null;
    store.saveBill(bill);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final list = store.activeBills;
    final now = DateTime.now();
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Khoản định kỳ')),
      floatingActionButton: FloatingActionButton(heroTag: 'bill', onPressed: () => edit(context, null), child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            color: Brand.navy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.autorenew, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Định kỳ tốn khoảng ${money(store.monthlyBills)}/tháng · ${compactMoney(store.monthlyBills * 12)}/năm',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Thêm Netflix, Spotify, iCloud, gym, tiền nhà hay khoản trả góp. VieTing nhắc trước 3 ngày để bạn kịp hủy gói không dùng.',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final b in list)
            Card(
              child: ListTile(
                onTap: () => edit(context, b),
                leading: CircleAvatar(
                  backgroundColor: catById(b.categoryId).color.withAlpha(35),
                  child: Icon(b.isInstallment ? Icons.credit_score : Icons.autorenew, color: catById(b.categoryId).color),
                ),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  '${money(b.amount)}/${b.cycle == 'year' ? 'năm' : b.cycle == 'week' ? 'tuần' : 'tháng'}',
                  'kỳ tới ${dmy(b.next)}',
                  if (b.isInstallment) 'còn ${b.remaining} kỳ',
                ].join(' · ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (b.next.isBefore(now.add(const Duration(days: 3))))
                    const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.notifications_active, color: Color(0xFFEF8F00), size: 20)),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pay') {
                        final t = store.payBill(b);
                        showNudges(store.nudgesFor(t));
                      }
                      if (v == 'skip') {
                        b.next = b.after(b.next);
                        store.saveBill(b);
                      }
                      if (v == 'del') store.deleteBill(b.id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pay', child: Text('Đã trả kỳ này (ghi giao dịch)')),
                      PopupMenuItem(value: 'skip', child: Text('Bỏ qua kỳ này')),
                      PopupMenuItem(value: 'del', child: Text('Đã hủy / xóa')),
                    ],
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate_outlined, color: Brand.bamboo),
              title: const Text('Thử trả góp trước khi mua', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Xem 6 tháng tới tháng nào bị âm tiền'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallmentSimScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trả góp hay trả thẳng: mô phỏng dòng tiền 6 tháng tới khi thêm một khoản trả góp.
class InstallmentSimScreen extends StatefulWidget {
  const InstallmentSimScreen({super.key});

  @override
  State<InstallmentSimScreen> createState() => _InstallmentSimScreenState();
}

class _InstallmentSimScreenState extends State<InstallmentSimScreen> {
  final _price = TextEditingController(text: groupDigits(12000000));
  double _months = 6;
  final _fee = TextEditingController(text: '0');

  @override
  void dispose() {
    _price.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final price = parseMoneyInput(_price.text);
    final feePct = double.tryParse(_fee.text.replaceAll(',', '.')) ?? 0;
    final total = (price * (1 + feePct / 100)).round();
    final perMonth = _months <= 0 ? 0 : (total / _months).ceil();
    final base = store.installmentPlan();
    final plan = store.installmentPlan(newMonthly: perMonth, months: _months.round());
    final firstNeg = plan.where((p) => p.balance < 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Trả góp hay trả thẳng?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Giá món đồ', suffixText: '₫'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Phí chuyển đổi trả góp (%)', helperText: 'Trả góp 0% thường vẫn có phí chuyển đổi 1–3%'),
          ),
          const SizedBox(height: 12),
          Text('Trả trong ${_months.round()} tháng · ${money(perMonth)}/tháng', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _months, min: 3, max: 24, divisions: 21, label: '${_months.round()} tháng', onChanged: (v) => setState(() => _months = v)),
          if (total > price)
            Text('Tổng phải trả ${money(total)} (đắt hơn trả thẳng ${money(total - price)})', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          Card(
            color: firstNeg.isEmpty ? Brand.bamboo.withAlpha(30) : const Color(0xFFEF8F00).withAlpha(40),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                firstNeg.isEmpty
                    ? 'Với thu chi trung bình hiện tại, 6 tháng tới bạn vẫn dương tiền khi thêm khoản này 👍'
                    : 'Tháng ${firstNeg.first.month.month}/${firstNeg.first.month.year} có thể bị âm ${money(-firstNeg.first.balance)}. Cân nhắc kéo dài kỳ hạn hoặc để dành thêm trước khi mua nhé.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(children: [
              const ListTile(
                dense: true,
                title: Text('Tháng', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text('Số dư dự kiến (không / có trả góp)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (var i = 0; i < plan.length; i++)
                ListTile(
                  dense: true,
                  title: Text('${plan[i].month.month}/${plan[i].month.year}'),
                  trailing: Text.rich(TextSpan(children: [
                    TextSpan(text: '${compactMoney(base[i].balance)}  →  ', style: TextStyle(color: cs.onSurfaceVariant)),
                    TextSpan(
                      text: compactMoney(plan[i].balance),
                      style: TextStyle(fontWeight: FontWeight.w800, color: plan[i].balance < 0 ? const Color(0xFFEF8F00) : Brand.income),
                    ),
                  ])),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Dựa trên thu chi trung bình 3 kỳ gần nhất và các khoản định kỳ đã thêm.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: price <= 0
                ? null
                : () async {
                    final b = Bill(
                      id: newId(),
                      name: 'Trả góp',
                      amount: perMonth,
                      next: DateTime.now().add(const Duration(days: 30)),
                      remaining: _months.round(),
                      categoryId: 'mua_sam',
                    );
                    await BillsScreen.edit(context, b, installment: true);
                  },
            icon: const Icon(Icons.add),
            label: const Text('Đã quyết mua trả góp: thêm vào khoản định kỳ'),
          ),
        ],
      ),
    );
  }
}
