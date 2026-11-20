import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import 'edit_txn.dart';

class NotifyLogScreen extends StatelessWidget {
  const NotifyLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final logs = store.logs;
    (String, Color, IconData) look(String s) => switch (s) {
          'added' => ('Đã ghi', Brand.bamboo, Icons.check_circle),
          'duplicate' => ('Trùng, bỏ qua', Colors.blueGrey, Icons.copy_all),
          'skipped' => ('App lạ, chưa ghi', const Color(0xFFEF8F00), Icons.help_outline),
          _ => ('Không có số tiền', Colors.grey, Icons.block),
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký thông báo')),
      body: logs.isEmpty
          ? Center(child: Text('Chưa có thông báo nào', style: TextStyle(color: cs.onSurfaceVariant)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final l = logs[i];
                final (label, color, icon) = look(l.status);
                final txn = l.txnId != null ? store.txns[l.txnId] : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${hm(l.notice.time)} ${dmy(l.notice.time)}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 6),
                      Text(l.notice.appName.isEmpty ? l.notice.package : l.notice.appName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(l.notice.full, maxLines: 4, overflow: TextOverflow.ellipsis),
                      if (txn != null && !txn.deleted)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => openEditTxn(context, txn),
                            child: Text('${money(txn.signed, signed: true)} · Sửa'),
                          ),
                        ),
                      if (l.status == 'skipped')
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () {
                              final n = store.allowApp(l.notice.package);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Đã cho phép app này · ghi thêm $n giao dịch')));
                            },
                            child: const Text('Đây là ngân hàng của tôi'),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
