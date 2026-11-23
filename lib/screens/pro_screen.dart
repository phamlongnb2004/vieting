import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';

import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import '../widgets/vicon.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Màn giới thiệu VieTing Pro: quyền lợi, giá, nhập mã khuyến mãi.
/// Thanh toán qua App Store / Google Play sẽ nối vào khi app lên cửa hàng.
class ProScreen extends StatefulWidget {
  final String? reason;
  const ProScreen({super.key, this.reason});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  int _plan = 1;

  static const _perks = [
    (PhosphorIconsRegular.sparkle, 'AI thoải mái', 'Đọc ảnh hóa đơn & tách hóa đơn siêu thị không giới hạn, nhờ AI đọc tin MoMo / ZaloPay, 300 lượt trợ lý mỗi ngày'),
    (PhosphorIconsRegular.chartLineUp, 'Dự báo & đường băng', 'Biết trước cuối kỳ còn bao nhiêu, ngày nào chạm đáy ví, sống được bao lâu nếu mất thu nhập'),
    (PhosphorIconsRegular.calendarCheck, 'Kế hoạch không giới hạn', 'Khoản định kỳ, hũ mục tiêu, danh sách chờ mua, sổ chung không giới hạn'),
    (PhosphorIconsRegular.calculator, 'Mô phỏng', 'Trả góp hay trả thẳng, cắt giảm chi tiêu thì bao lâu đạt mục tiêu'),
    (PhosphorIconsRegular.envelopeSimple, 'Sổ hiếu hỉ', 'Ai mừng mình bao nhiêu, nhắc trước mỗi dịp'),
    (PhosphorIconsRegular.userSound, 'Thêm tính cách trợ lý', 'Mẹ khó tính, Chuyên gia tài chính (Nhẹ nhàng và Bạn thân Gen Z luôn miễn phí)'),
    (PhosphorIconsRegular.shareNetwork, 'Tổng kết mọi kỳ', 'Xem lại và chia sẻ thẻ tổng kết của tất cả các tháng'),
  ];

  static const _plans = [
    ('Tháng', 29000, '/tháng', ''),
    ('Năm', 249000, '/năm', 'Tiết kiệm 28%'),
    ('Trọn đời', 499000, ' một lần', ''),
  ];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final store = StoreScope.read(context);
    if (!store.loggedIn) {
      showToast(context, 'Đăng nhập (Cài đặt → Đăng nhập để đồng bộ) trước khi dùng mã');
      return;
    }
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final days = await store.redeem(_code.text.trim());
      if (!mounted) return;
      showToast(context, ' Đã mở Pro thêm $days ngày');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('VieTing Pro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Brand.red, Color(0xFF7A1418)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VieTing Pro', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                store.isPro
                    ? 'Bạn đang dùng Pro đến ${dmy(store.proUntil!)}. Cảm ơn bạn đã ủng hộ!'
                    : widget.reason != null
                        ? '${widget.reason}. Nâng cấp để dùng thoải mái.'
                        : 'Ghi chép luôn miễn phí. Pro dành cho ai muốn đi xa hơn.',
                style: const TextStyle(color: Colors.white),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          for (final p in _perks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: VIcon(p.$1, color: Brand.red),
              title: Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(p.$3),
            ),
          const Divider(height: 28),
          if (!store.isPro) ...[
            Row(children: [
              for (var i = 0; i < _plans.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < _plans.length - 1 ? 8 : 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _plan = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _plan == i ? Brand.red : cs.outlineVariant, width: _plan == i ? 2 : 1),
                        ),
                        child: Column(children: [
                          Text(_plans[i].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(compactMoney(_plans[i].$2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(_plans[i].$3, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          if (_plans[i].$4.isNotEmpty)
                            Text(_plans[i].$4, style: const TextStyle(fontSize: 11, color: Brand.bamboo, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => showToast(context, 'Thanh toán qua App Store / Google Play sẽ mở khi VieTing lên cửa hàng. Hiện bạn có thể dùng mã khuyến mãi.'),
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nâng cấp Pro')),
            ),
            const SizedBox(height: 18),
          ],
          Text('Có mã khuyến mãi?', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'VD: TET2027'),
                onSubmitted: (_) => _redeem(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: _busy ? null : _redeem, child: const Text('Dùng mã')),
          ]),
          const SizedBox(height: 16),
          Text(
            'Luôn miễn phí: ghi chép, tự đọc thông báo ngân hàng, ví, ngân sách, Quỹ tiêu thoải mái, widget, nhắc nhở, '
            'đổi giá ra giờ làm, mã PIN / vân tay, khoản riêng tư, xuất CSV. Tài khoản mới được dùng thử Pro 7 ngày.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
