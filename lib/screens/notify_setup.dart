import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import '../consent.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../parser/banks.dart';
import '../services/notify_bridge.dart';
import '../store.dart';
import '../theme.dart';
import 'notify_log.dart';

/// Hướng dẫn + bật quyền đọc thông báo (Android).
class NotifySetupScreen extends StatefulWidget {
  const NotifySetupScreen({super.key});

  @override
  State<NotifySetupScreen> createState() => _NotifySetupScreenState();
}

class _NotifySetupScreenState extends State<NotifySetupScreen> with WidgetsBindingObserver {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await NotifyBridge.isEnabled();
    if (mounted) setState(() => _on = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget step(int n, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 13, backgroundColor: Brand.red, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Đọc thông báo ngân hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: (_on ? Brand.bamboo : Brand.red).withAlpha(28),
            child: ListTile(
              leading: Icon(_on ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.bellSlash,
                  color: _on ? Brand.bamboo : Brand.red, size: 32),
              title: Text(_on ? 'Đang bật' : 'Chưa bật', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_on
                  ? 'Thông báo biến động số dư sẽ được tự ghi thành giao dịch.'
                  : 'Bật quyền để VieTing tự ghi các khoản tiền vào / ra.'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (await Consent.ensure(StoreScope.read(context), 'notify', context: context)) await NotifyBridge.openSettings();
            },
            icon: const Icon(PhosphorIconsRegular.gear),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Mở cài đặt quyền truy cập thông báo')),
          ),
          const SizedBox(height: 20),
          step(1, 'Bấm nút trên', 'Điện thoại mở trang "Truy cập thông báo" (Notification access).'),
          step(2, 'Chọn VieTing và bật', 'Xác nhận "Cho phép". Quay lại app, trạng thái sẽ chuyển sang "Đang bật".'),
          step(3, 'Bật thông báo biến động số dư trong app ngân hàng',
              'VieTing đọc nội dung thông báo app ngân hàng / SMS gửi tới máy, nên ngân hàng phải gửi thông báo.'),
          Card(
            color: Brand.yellow.withAlpha(50),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Không bật được, báo "Cài đặt bị hạn chế"?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Android 13 trở lên chặn quyền này với app cài từ file APK. Mở Thông tin ứng dụng → '
                    'bấm ⋮ (góc trên) → "Cho phép cài đặt bị hạn chế", rồi bật lại. Bản tải từ CH Play không bị chặn.'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: NotifyBridge.openAppDetails, child: const Text('Mở thông tin ứng dụng')),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(PhosphorIconsRegular.lockSimple, size: 18),
                  SizedBox(width: 6),
                  Text('Quyền riêng tư', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'VieTing chỉ giữ thông báo có số tiền (VND, đ, số dư…), bỏ qua tin nhắn chat, mã OTP và quảng cáo. '
                  'Mọi xử lý diễn ra ngay trên điện thoại; nội dung chỉ lên server nếu bạn đăng nhập đồng bộ.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Ngân hàng & ví nhận diện sẵn', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in supportedBankNames) Chip(label: Text(n), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          Text('Ngân hàng khác vẫn đọc được: thông báo có số dư sẽ tự ghi, hoặc vào Nhật ký để cho phép app đó.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifyLogScreen())),
            icon: const Icon(PhosphorIconsRegular.clockCounterClockwise),
            label: const Text('Xem nhật ký thông báo'),
          ),
        ],
      ),
    );
  }
}
