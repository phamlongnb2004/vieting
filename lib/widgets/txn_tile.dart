import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../categories.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../screens/lock.dart';

class CatAvatar extends StatelessWidget {
  final Cat cat;
  final double size;
  const CatAvatar({super.key, required this.cat, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.34),
          gradient: LinearGradient(
            colors: [cat.color.withAlpha(46), cat.color.withAlpha(22)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cat.color.withAlpha(40)),
        ),
        child: Icon(cat.icon, color: cat.color, size: size * 0.52),
      );
}

class TxnTile extends StatelessWidget {
  final Txn txn;
  final VoidCallback? onTap;
  const TxnTile({super.key, required this.txn, this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final masked = txn.hidden && !store.revealHidden;
    final cat = masked ? catById('khac_chi') : catById(txn.categoryId);
    final cs = Theme.of(context).colorScheme;
    final subtitle = masked
        ? '${hm(txn.date)} · chạm để mở khóa'
        : [
            hm(txn.date),
            store.walletName(txn.walletId),
            if (txn.note.isNotEmpty) txn.note,
          ].join(' · ');
    return ListTile(
      onTap: masked
          ? () async {
              if (await unlockHidden(context)) store.setRevealHidden(true);
            }
          : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: masked
          ? Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(13)),
              child: const Icon(PhosphorIconsRegular.lockSimple),
            )
          : CatAvatar(cat: cat),
      title: Row(children: [
        Flexible(
            child: Text(masked ? 'Khoản riêng tư' : cat.name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (txn.auto && !masked) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Brand.bamboo.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: const Text('tự động', style: TextStyle(fontSize: 10, color: Brand.bamboo, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Text(
        money(txn.signed, signed: true),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: txn.income ? Brand.income : cs.onSurface,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}
