import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../insights.dart';
import '../services/notify_bridge.dart';
import '../store.dart';
import '../util/format.dart';
import '../widgets/logo.dart';
import 'ios_shortcut.dart';
import 'lock.dart';
import 'login.dart';
import 'notify_log.dart';
import 'notify_setup.dart';
import 'paste.dart';
import 'wallets.dart';
import 'cleanup.dart';
import 'wrapped.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export(BuildContext context, AppStore store) async {
    final now = DateTime.now();
    final name = 'VieTing-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.csv';
    try {
      final dir = !kIsWeb && Platform.isWindows
          ? (await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory())
          : await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsString(store.exportCsv());
      if (!kIsWeb && Platform.isWindows) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu ${f.path}')));
        }
        return;
      }
      await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: 'Dữ liệu VieTing');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xuất được: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final isIos = !kIsWeb && Platform.isIOS;

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
            ),
            Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          group('Tài khoản & đồng bộ', [
            if (store.loggedIn) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(store.email),
                subtitle: Text(store.syncError ??
                    (store.lastSync > 0
                        ? 'Đồng bộ lần cuối: ${hm(DateTime.fromMillisecondsSinceEpoch(store.lastSync))} ${dmy(DateTime.fromMillisecondsSinceEpoch(store.lastSync))}'
                        : 'Chưa đồng bộ')),
                trailing: store.syncing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.sync), onPressed: () => store.sync()),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                subtitle: const Text('Dữ liệu vẫn giữ trên máy này'),
                onTap: store.logout,
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Đăng nhập để đồng bộ'),
                subtitle: const Text('Xem giao dịch trên điện thoại, iPhone và máy tính'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _go(context, const LoginScreen()),
              ),
          ]),
          if (kServerUrl.isEmpty) group('Nâng cao', [
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Địa chỉ server'),
              subtitle: Text(store.serverUrl.isEmpty ? 'Chưa nhập (cần cho trợ lý AI và đồng bộ)' : store.serverUrl),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final c = TextEditingController(text: store.serverUrl);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Địa chỉ server'),
                    content: SizedBox(
                      width: 360,
                      child: TextField(
                        controller: c,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(hintText: 'https://vieting.xxx.workers.dev'),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
                    ],
                  ),
                );
                if (ok == true) store.setServerUrl(c.text);
              },
            ),
          ]),
          group('Ví & tài khoản', [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Quản lý ví'),
              subtitle: Text('${store.activeWallets.length} ví · tổng ${money(store.totalBalance)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const WalletsScreen()),
            ),
          ]),
          group('Chi tiêu & trợ lý', [
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Ngày bắt đầu kỳ chi tiêu'),
              subtitle: Text(store.cycleDay == 1
                  ? 'Ngày 1 hằng tháng (theo tháng dương lịch)'
                  : 'Ngày ${store.cycleDay} hằng tháng (ngày nhận lương)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final d = await showDialog<int>(
                  context: context,
                  builder: (c) => SimpleDialog(
                    title: const Text('Kỳ chi tiêu bắt đầu ngày nào?'),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Text('Chọn ngày bạn nhận lương để ngân sách, hạn mức ngày và tổng kết tính từ ngày đó.'),
                      ),
                      SizedBox(
                        width: 320,
                        child: Wrap(alignment: WrapAlignment.center, children: [
                          for (var i = 1; i <= 28; i++)
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: ChoiceChip(label: Text('$i'), selected: store.cycleDay == i, onSelected: (_) => Navigator.pop(c, i)),
                            ),
                        ]),
                      ),
                    ],
                  ),
                );
                if (d != null) store.setCycleDay(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Giọng trợ lý'),
              subtitle: Text(switch (store.aiTone) {
                'funny' => 'Hài hước, cà khịa nhẹ',
                'strict' => 'Nghiêm khắc kiểu "mẹ mắng"',
                _ => 'Nhẹ nhàng, động viên',
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final t = await showDialog<String>(
                  context: context,
                  builder: (c) => SimpleDialog(title: const Text('Trợ lý nói chuyện kiểu gì?'), children: [
                    for (final o in const [
                      ('gentle', '🌿 Nhẹ nhàng', 'Động viên, không phán xét'),
                      ('funny', '😜 Hài hước', 'Cà khịa nhẹ như bạn thân'),
                      ('strict', '😤 Nghiêm khắc', 'Nhắc thẳng khi tiêu hoang'),
                    ])
                      ListTile(
                        title: Text(o.$2),
                        subtitle: Text(o.$3),
                        trailing: store.aiTone == o.$1 ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.pop(c, o.$1),
                      ),
                  ]),
                );
                if (t != null) store.setAiTone(t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Thu nhập mỗi giờ làm'),
              subtitle: Text(store.hourlyWage > 0
                  ? '${money(store.hourlyWage)}/giờ'
                  : store.effectiveHourlyWage > 0
                      ? 'Tự tính từ lương: ~${money(store.effectiveHourlyWage)}/giờ'
                      : 'Để quy đổi giá món đồ ra số giờ làm việc'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final c = TextEditingController(text: store.hourlyWage > 0 ? groupDigits(store.hourlyWage) : '');
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Bạn kiếm bao nhiêu mỗi giờ?'),
                    content: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(suffixText: '₫/giờ', helperText: 'Để trống = tự tính từ khoản lương (22 ngày × 8 giờ)'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
                    ],
                  ),
                );
                if (ok == true) store.setHourlyWage(parseMoneyInput(c.text));
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Tổng kết kỳ (Wrapped)'),
              subtitle: const Text('Thẻ tổng kết vui để chia sẻ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const WrappedScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Dọn dẹp 60 giây'),
              subtitle: const Text('Xếp lại khoản chưa phân loại, đối chiếu số dư'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const CleanupScreen()),
            ),
          ]),
          group('Tự động ghi giao dịch', [
            if (NotifyBridge.supported)
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Đọc thông báo ngân hàng'),
                subtitle: const Text('Tự ghi khi có biến động số dư'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _go(context, const NotifySetupScreen()),
              ),
            if (isIos)
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('Phím tắt iPhone (SMS ngân hàng)'),
                subtitle: const Text('iOS không cho đọc thông báo app khác'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _go(context, const IosShortcutScreen()),
              ),
            ListTile(
              leading: const Icon(Icons.content_paste_go),
              title: const Text('Dán thông báo / tin nhắn'),
              subtitle: const Text('Copy thông báo ngân hàng rồi dán vào đây'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const PasteScreen()),
            ),
            if (NotifyBridge.supported)
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Nhật ký thông báo'),
                subtitle: Text('${store.logs.length} thông báo gần đây'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _go(context, const NotifyLogScreen()),
              ),
          ]),
          group('Bảo mật & dữ liệu', [
            SwitchListTile(
              secondary: const Icon(Icons.pin_outlined),
              title: const Text('Khóa app bằng mã PIN'),
              subtitle: const Text('Tự khóa khi rời app quá 30 giây'),
              value: store.locked,
              onChanged: (v) async {
                if (v) {
                  final pin = await askNewPin(context);
                  if (pin != null) store.setPin(pin);
                } else {
                  store.setPin(null);
                }
              },
            ),
            if (store.locked)
              FutureBuilder<bool>(
                future: Biometric.available(),
                builder: (context, snap) => snap.data == true
                    ? SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Mở bằng vân tay / khuôn mặt'),
                        value: store.bioLock,
                        onChanged: (v) async {
                          if (!v) {
                            store.setBioLock(false);
                          } else if (await Biometric.authenticate()) {
                            store.setBioLock(true);
                          }
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Xuất dữ liệu (Excel / CSV)'),
              subtitle: const Text('Toàn bộ giao dịch, mở được bằng Excel / Google Sheets'),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _export(context, store),
            ),
          ]),
          group('Giao diện', [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Chế độ tối'),
              value: store.dark,
              onChanged: store.setDark,
            ),
          ]),
          const SizedBox(height: 10),
          const Center(child: Wordmark(fontSize: 22)),
          const SizedBox(height: 6),
          Center(
            child: Text('Phiên bản 0.1.0 · Tác giả: Phạm Thành Long (thlong)',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
