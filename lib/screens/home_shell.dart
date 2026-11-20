import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/notify_bridge.dart';
import '../store.dart';
import '../util/format.dart';
import 'budgets.dart';
import 'edit_txn.dart';
import 'overview.dart';
import 'settings.dart';
import 'transactions.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<Uri>? _linkSub;
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifyBridge.listen(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _linkSub = AppLinks().uriLinkStream.listen(_onLink, onError: (_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _drain();
      final store = StoreScope.read(context);
      if (store.loggedIn) store.sync();
    }
  }

  /// Lấy các thông báo ngân hàng Android đã bắt được và ghi thành giao dịch.
  Future<void> _drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      final items = await NotifyBridge.drain();
      if (!mounted || items.isEmpty) return;
      final store = StoreScope.read(context);
      final added = <Txn>[];
      for (final n in items) {
        final r = store.ingest(n);
        if (r.status == 'added') added.add(r.txn!);
      }
      if (added.isNotEmpty && mounted) {
        final msg = added.length == 1
            ? 'Đã ghi ${money(added.first.signed, signed: true)} · ${store.walletName(added.first.walletId)}'
            : 'Đã tự ghi ${added.length} giao dịch từ thông báo ngân hàng';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          action: added.length == 1
              ? SnackBarAction(label: 'Sửa', onPressed: () => openEditTxn(context, added.first))
              : null,
        ));
      }
    } finally {
      _draining = false;
    }
  }

  /// vieting://add?text=... (Phím tắt iPhone)  hoặc  vieting://add?amount=50000&type=chi&note=...
  void _onLink(Uri uri) {
    if (!mounted || uri.host != 'add') return;
    final store = StoreScope.read(context);
    final text = uri.queryParameters['text'];
    if (text != null && text.trim().isNotEmpty) {
      final r = store.ingest(
        RawNotice(
          package: 'shortcut',
          appName: uri.queryParameters['bank'] ?? '',
          title: uri.queryParameters['bank'] ?? '',
          text: text,
          time: DateTime.now(),
        ),
        source: 'shortcut',
      );
      final msg = switch (r.status) {
        'added' => 'Đã ghi ${money(r.txn!.signed, signed: true)}',
        _ => 'Không đọc được số tiền trong tin nhắn',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    final amount = int.tryParse(uri.queryParameters['amount'] ?? '');
    if (amount != null && amount > 0) {
      final income = (uri.queryParameters['type'] ?? '').toLowerCase().startsWith('thu');
      openEditTxn(context, null, presetAmount: amount, presetIncome: income, presetNote: uri.queryParameters['note']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewScreen(onSeeAll: () => setState(() => _tab = 1)),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const SettingsScreen(),
    ];
    const items = [
      (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Tổng quan'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'Giao dịch'),
      (Icons.savings_outlined, Icons.savings, 'Ngân sách'),
      (Icons.settings_outlined, Icons.settings, 'Cài đặt'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final fab = _tab < 2
        ? FloatingActionButton.extended(
            onPressed: () => openEditTxn(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm'),
          )
        : null;

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _tab,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              for (final it in items)
                NavigationRailDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: pages[_tab]),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      body: pages[_tab],
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final it in items) NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: it.$3),
        ],
      ),
    );
  }
}
