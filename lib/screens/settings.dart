import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../config.dart';
import '../insights.dart';
import '../services/notify_bridge.dart';
import '../pro.dart';
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
import 'feedback.dart';
import 'pro_screen.dart';
import '../services/reminders.dart';
import '../ui_keys.dart';
import 'cleanup.dart';
import 'wrapped.dart';
import '../widgets/vicon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export(BuildContext context, AppStore store) async {
    final now = DateTime.now();
    final name = 'VieTing-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.csv';
    try {
      final desktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      final dir = desktop
          ? (await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory())
          : await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsString(store.exportCsv());
      if (desktop) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu ${f.path}')));
        }
        return;
      }
      if (!context.mounted) return;
      try {
        await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv', name: name)],
            subject: 'Dữ liệu VieTing', sharePositionOrigin: shareOrigin(context));
      } catch (_) {
        // máy không mở được bảng chia sẻ: chép nội dung CSV để dán vào Excel / Google Sheets
        await Clipboard.setData(ClipboardData(text: store.exportCsv()));
        if (context.mounted) showToast(context, 'Không mở được bảng chia sẻ, đã chép dữ liệu CSV, dán vào Excel / Google Sheets nhé');
      }
    } catch (e) {
      if (context.mounted) showToast(context, 'Không xuất được: $e');
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
              child: Text(title.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .8, color: cs.onSurfaceVariant)),
            ),
            Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          group('Tài khoản & đồng bộ', [
            if (store.loggedIn) ...[
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.user, size: 36),
                title: Text(store.email),
                subtitle: Text(store.syncError ??
                    (store.lastSync > 0
                        ? 'Đồng bộ lần cuối: ${hm(DateTime.fromMillisecondsSinceEpoch(store.lastSync))} ${dmy(DateTime.fromMillisecondsSinceEpoch(store.lastSync))}'
                        : 'Chưa đồng bộ')),
                trailing: store.syncing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: const Icon(PhosphorIconsRegular.arrowsClockwise), onPressed: () => store.sync()),
              ),
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.signOut, size: 36),
                title: const Text('Đăng xuất'),
                subtitle: const Text('Dữ liệu vẫn giữ trên máy này'),
                onTap: store.logout,
              ),
            ] else
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.cloudArrowUp, size: 36),
                title: const Text('Đăng nhập để đồng bộ'),
                subtitle: const Text('Xem giao dịch trên điện thoại, iPhone và máy tính'),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () => _go(context, const LoginScreen()),
              ),
          ]),
          if (kServerUrl.isEmpty) group('Nâng cao', [
            ListTile(
              leading: const VIcon(PhosphorIconsRegular.hardDrives, size: 36),
              title: const Text('Địa chỉ server'),
              subtitle: Text(store.serverUrl.isEmpty ? 'Chưa nhập (cần cho trợ lý AI và đồng bộ)' : store.serverUrl),
              trailing: const Icon(PhosphorIconsRegular.pencilSimple),
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
              leading: const VIcon(PhosphorIconsRegular.wallet, size: 36),
              title: const Text('Quản lý ví'),
              subtitle: Text('${store.activeWallets.length} ví · tổng ${money(store.totalBalance)}'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const WalletsScreen()),
            ),
          ]),
          group('Gói & hỗ trợ', [
            ListTile(
              leading: Icon(store.isPro ? PhosphorIconsFill.crown : PhosphorIconsRegular.crown,
                  color: store.isPro ? const Color(0xFFE0A800) : null),
              title: Text(store.isPro ? 'VieTing Pro' : 'Gói Miễn phí'),
              subtitle: Text(store.isPro
                  ? 'Đến ${dmy(store.proUntil!)} · 300 lượt trợ lý AI / ngày'
                  : 'Xem quyền lợi Pro · nhập mã khuyến mãi'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const ProScreen()),
            ),
            ListTile(
              leading: Badge(isLabelVisible: store.ticketsUnread > 0, label: Text('${store.ticketsUnread}'), child: const Icon(PhosphorIconsRegular.headset)),
              title: const Text('Góp ý & báo lỗi'),
              subtitle: const Text('Báo lỗi theo tính năng, xem phản hồi của VieTing'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const FeedbackScreen()),
            ),
          ]),
          group('Chi tiêu & trợ lý', [
            if (NotifyBridge.supported)
              SwitchListTile(
                secondary: const VIcon(PhosphorIconsRegular.bellRinging, size: 36),
                title: const Text('Nhắc nhở trên máy'),
                subtitle: const Text('Nhắc ghi chi tiêu buổi tối, khoản định kỳ sắp trừ tiền, món chờ mua… kể cả khi không mở app'),
                value: store.remindersOn,
                onChanged: (v) {
                  store.setRemindersOn(v);
                  Reminders.sync(store);
                  if (v) Reminders.test();
                },
              ),
            ListTile(
              leading: const VIcon(PhosphorIconsRegular.calendarCheck, size: 36),
              title: const Text('Ngày bắt đầu kỳ chi tiêu'),
              subtitle: Text(store.cycleDay == 1
                  ? 'Ngày 1 hằng tháng (theo tháng dương lịch)'
                  : 'Ngày ${store.cycleDay} hằng tháng (ngày nhận lương)'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
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
              leading: const VIcon(PhosphorIconsRegular.userSound, size: 36),
              title: const Text('Tính cách trợ lý'),
              subtitle: Text(switch (store.aiTone) {
                'funny' => 'Bạn thân Gen Z (cà khịa)',
                'strict' => 'Mẹ khó tính',
                'expert' => 'Chuyên gia tài chính',
                _ => 'Nhẹ nhàng, động viên',
              }),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () async {
                final t = await showDialog<String>(
                  context: context,
                  builder: (c) => SimpleDialog(title: const Text('Chọn tính cách cho trợ lý'), children: [
                    for (final o in const [
                      ('gentle', 'Nhẹ nhàng', 'Động viên, không phán xét'),
                      ('funny', 'Bạn thân Gen Z', 'Cà khịa cực mạnh, nói chuyện như bạn thân Gen Z'),
                      ('strict', 'Mẹ khó tính', 'Mắng thẳng khi lố tay'),
                      ('expert', 'Chuyên gia tài chính', 'Điềm tĩnh, nói bằng số liệu'),
                    ])
                      ListTile(
                        title: Text(o.$2),
                        subtitle: Text(o.$3),
                        trailing: store.aiTone == o.$1
                            ? const Icon(PhosphorIconsRegular.check)
                            : (o.$1 != 'gentle' && o.$1 != 'funny' && !store.isPro ? const Icon(PhosphorIconsRegular.lockSimple, size: 18) : null),
                        onTap: () => Navigator.pop(c, o.$1),
                      ),
                  ]),
                );
                if (t == null || !context.mounted) return;
                if (t != 'gentle' && t != 'funny' && !await Pro.check(context, 'tone')) return;
                store.setAiTone(t);
              },
            ),
            ListTile(
              leading: const VIcon(PhosphorIconsRegular.timer, size: 36),
              title: const Text('Thu nhập mỗi giờ làm'),
              subtitle: Text(store.hourlyWage > 0
                  ? '${money(store.hourlyWage)}/giờ'
                  : store.effectiveHourlyWage > 0
                      ? 'Tự tính từ lương: ~${money(store.effectiveHourlyWage)}/giờ'
                      : 'Để quy đổi giá món đồ ra số giờ làm việc'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
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
              leading: const VIcon(PhosphorIconsRegular.sparkle, size: 36),
              title: const Text('Tổng kết kỳ (Wrapped)'),
              subtitle: const Text('Thẻ tổng kết vui để chia sẻ'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const WrappedScreen()),
            ),
            ListTile(
              leading: const VIcon(PhosphorIconsRegular.broom, size: 36),
              title: const Text('Dọn dẹp 60 giây'),
              subtitle: const Text('Xếp lại khoản chưa phân loại, đối chiếu số dư'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const CleanupScreen()),
            ),
          ]),
          group('Tự động ghi giao dịch', [
            if (NotifyBridge.supported)
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.bellRinging, size: 36),
                title: const Text('Đọc thông báo ngân hàng'),
                subtitle: const Text('Tự ghi khi có biến động số dư'),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () => _go(context, const NotifySetupScreen()),
              ),
            if (isIos)
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.lightning, size: 36),
                title: const Text('Phím tắt iPhone (SMS ngân hàng)'),
                subtitle: const Text('iOS không cho đọc thông báo app khác'),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () => _go(context, const IosShortcutScreen()),
              ),
            ListTile(
              leading: const VIcon(PhosphorIconsRegular.clipboardText, size: 36),
              title: const Text('Dán thông báo / tin nhắn'),
              subtitle: const Text('Copy thông báo ngân hàng rồi dán vào đây'),
              trailing: const Icon(PhosphorIconsRegular.caretRight),
              onTap: () => _go(context, const PasteScreen()),
            ),
            if (NotifyBridge.supported)
              ListTile(
                leading: const VIcon(PhosphorIconsRegular.clockCounterClockwise, size: 36),
                title: const Text('Nhật ký thông báo'),
                subtitle: Text('${store.logs.length} thông báo gần đây'),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () => _go(context, const NotifyLogScreen()),
              ),
          ]),
          group('Bảo mật & dữ liệu', [
            SwitchListTile(
              secondary: const VIcon(PhosphorIconsRegular.password, size: 36),
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
                        secondary: const VIcon(PhosphorIconsRegular.fingerprint, size: 36),
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
              leading: const VIcon(PhosphorIconsRegular.table, size: 36),
              title: const Text('Xuất dữ liệu (Excel / CSV)'),
              subtitle: const Text('Toàn bộ giao dịch, mở được bằng Excel / Google Sheets'),
              trailing: const Icon(PhosphorIconsRegular.shareNetwork),
              onTap: () => _export(context, store),
            ),
          ]),
          group('Giao diện', [
            SwitchListTile(
              secondary: const VIcon(PhosphorIconsRegular.moon, size: 36),
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
