import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../models.dart';
import '../pro.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/vicon.dart';

/// Sổ hiếu hỉ: ai mừng mình bao nhiêu, mình đi lại bao nhiêu, nhắc khi sắp tới dịp.
class GiftsScreen extends StatelessWidget {
  final bool embedded;
  const GiftsScreen({super.key, this.embedded = false});

  static Future<void> edit(BuildContext context, GiftEntry? g, {String? person}) async {
    if (g == null && !await Pro.check(context, 'gifts')) return;
    if (!context.mounted) return;
    final store = StoreScope.read(context);
    final who = TextEditingController(text: g?.person ?? person ?? '');
    final amount = TextEditingController(text: g == null ? '' : groupDigits(g.amount));
    final note = TextEditingController(text: g?.note ?? '');
    var event = g?.event ?? 'cuoi';
    var given = g?.given ?? true;
    var date = g?.date ?? DateTime.now();
    DateTime? remind = g?.remind;
    var record = g == null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(g == null ? 'Ghi hiếu hỉ' : 'Sửa'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Mình mừng')),
                    ButtonSegment(value: false, label: Text('Họ mừng mình')),
                  ],
                  selected: {given},
                  onSelectionChanged: (s) => setS(() => given = s.first),
                ),
                const SizedBox(height: 10),
                TextField(controller: who, decoration: const InputDecoration(labelText: 'Người (VD: Anh Nam phòng kế toán)')),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final e in kGiftEvents.entries)
                    ChoiceChip(label: Text(e.value), selected: event == e.key, onSelected: (_) => setS(() => event = e.key)),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(labelText: 'Số tiền', suffixText: '₫'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const VIcon(PhosphorIconsRegular.calendarBlank, size: 36),
                  title: Text('Ngày: ${dmy(date)}'),
                  onTap: () async {
                    final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => date = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const VIcon(PhosphorIconsRegular.bell, size: 36),
                  title: Text(remind == null ? 'Nhắc dịp sắp tới của người này (không bắt buộc)' : 'Nhắc: ${dmy(remind!)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: c,
                        initialDate: remind ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 1500)));
                    if (d != null) setS(() => remind = d);
                  },
                ),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú')),
                if (g == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: record,
                    onChanged: (v) => setS(() => record = v ?? false),
                    title: Text(given ? 'Ghi luôn thành khoản chi (Gia đình & quà)' : 'Ghi luôn thành khoản thu'),
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
    if (ok != true || who.text.trim().isEmpty || v <= 0) return;
    final e = g ?? GiftEntry(id: newId(), person: '', amount: 0, date: date);
    e
      ..person = who.text.trim()
      ..event = event
      ..given = given
      ..amount = v
      ..date = date
      ..note = note.text.trim()
      ..remind = remind;
    store.saveGift(e);
    if (record) {
      final wallets = store.activeWallets;
      store.saveTxn(Txn(
        id: newId(),
        amount: v,
        income: !given,
        categoryId: given ? 'gia_dinh' : 'khac_thu',
        walletId: wallets.any((w) => w.id == 'cash') ? 'cash' : wallets.first.id,
        date: date,
        note: '${kGiftEvents[event]} ${e.person}',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final people = store.giftPeople();
    final upcoming = store.upcomingGiftEvents;
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Sổ hiếu hỉ')),
      floatingActionButton: FloatingActionButton(heroTag: 'gift', onPressed: () => edit(context, null), child: const Icon(PhosphorIconsRegular.gift)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          for (final u in upcoming)
            Card(
              color: Brand.yellow.withAlpha(50),
              child: ListTile(
                leading: const Icon(PhosphorIconsFill.bellRinging, color: Color(0xFFEF8F00)),
                title: Text('${dmy(u.remind!)}: dịp của ${u.person}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_hint(store, u.person)),
              ),
            ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const VIcon(PhosphorIconsRegular.envelopeSimple, color: Brand.red, size: 64),
                const SizedBox(height: 8),
                const Text('Sổ hiếu hỉ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 6),
                Text('Ghi ai đã mừng mình bao nhiêu (cưới, đầy tháng, tân gia…) và mình đã đi lại bao nhiêu, để lần sau đi cho phải phép.',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
          for (final p in people)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                title: Text(p.person, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Mình đi ${compactMoney(p.given)} · họ mừng ${compactMoney(p.received)}'),
                children: [
                  for (final g in store.activeGifts.where((x) => x.person.trim() == p.person))
                    ListTile(
                      dense: true,
                      title: Text('${kGiftEvents[g.event] ?? g.event} · ${dmy(g.date)}'),
                      subtitle: g.note.isEmpty ? null : Text(g.note),
                      trailing: Text('${g.given ? '−' : '+'}${money(g.amount)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: g.given ? cs.onSurface : Brand.income)),
                      onTap: () => edit(context, g),
                      onLongPress: () => store.deleteGift(g.id),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton.icon(
                      onPressed: () => edit(context, null, person: p.person),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Thêm dịp cho người này'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hint(AppStore store, String person) {
    for (final p in store.giftPeople()) {
      if (p.person == person.trim() && p.received > 0) {
        return 'Trước đây họ mừng mình ${money(p.received)}, mình đã đi ${money(p.given)}.';
      }
    }
    return 'Chuẩn bị phong bì nhé.';
  }
}
