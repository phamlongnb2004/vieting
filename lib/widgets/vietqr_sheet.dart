import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import '../util/vietqr.dart';

/// Ô chọn ngân hàng (mã NAPAS) cho tài khoản nhận tiền.
class BankPicker extends StatelessWidget {
  final String bin;
  final ValueChanged<String> onChanged;
  const BankPicker({super.key, required this.bin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: bin.isEmpty ? null : bin,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Ngân hàng'),
      items: [
        for (final b in kVnBanks)
          DropdownMenuItem(value: b.bin, child: Text('${b.short} · ${b.name}', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

/// Bảng mã VietQR: quét bằng app ngân hàng bất kỳ là điền sẵn số tài khoản, số tiền, nội dung.
/// Trả về true khi người dùng bấm nút chính (VD "Tôi đã chuyển").
Future<bool?> showVietQrSheet(
  BuildContext context, {
  required String title,
  required String bin,
  required String acct,
  required String owner,
  required int amount,
  required String memo,
  String? hint,
  String primary = 'Tôi đã chuyển',
  String secondary = 'Để sau',
}) {
  final bank = bankByBin(bin);
  final data = vietQrPayload(bin: bin, acct: acct, amount: amount, memo: memo);
  final m = plainMemo(memo);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Brand.navy.withAlpha(40)),
            ),
            child: Column(children: [
              QrImageView(
                data: data,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Brand.navy),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Brand.navy),
              ),
              const SizedBox(height: 6),
              Text('VietQR · NAPAS 247', style: TextStyle(fontSize: 11, color: Brand.navy.withAlpha(150), fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          Text(money(amount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Brand.red)),
          const SizedBox(height: 8),
          _row(context, 'Ngân hàng', bank?.short ?? bin),
          _row(context, 'Số tài khoản', acct, copy: true),
          if (owner.isNotEmpty) _row(context, 'Chủ tài khoản', owner),
          _row(context, 'Nội dung', m, copy: true, strong: true),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Brand.yellow.withAlpha(40), borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(PhosphorIconsRegular.info, size: 18, color: Brand.navy),
                const SizedBox(width: 8),
                Expanded(child: Text(hint, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(secondary))),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.bamboo),
                onPressed: () => Navigator.pop(c, true),
                child: Text(primary),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

Widget _row(BuildContext context, String k, String v, {bool copy = false, bool strong = false}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 110, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
      Expanded(child: Text(v, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: strong ? Brand.red : null))),
      if (copy)
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tr('Chép'),
          icon: const Icon(PhosphorIconsRegular.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: v));
            showToast(context, 'Đã chép $k');
          },
        ),
    ]),
  );
}
