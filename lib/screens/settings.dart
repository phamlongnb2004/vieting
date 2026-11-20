import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notify_bridge.dart';
import '../store.dart';
import '../util/format.dart';
import '../widgets/logo.dart';
import 'ios_shortcut.dart';
import 'login.dart';
import 'notify_log.dart';
import 'notify_setup.dart';
import 'paste.dart';
import 'wallets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
          group('Trợ lý AI & server', [
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
