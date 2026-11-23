import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import '../widgets/backgrounds.dart';
import 'calendar.dart';
import '../services/weather.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../models.dart';
import '../widgets/nudge.dart';
import '../services/notify_bridge.dart';
import '../services/quick_queue.dart';
import '../services/reminders.dart';
import '../services/goal_money.dart';
import '../services/spaces.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import 'assistant.dart';
import 'plan.dart';
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
  AppStore? _store;
  Timer? _remindTimer;

  void _onStore() {
    _remindTimer?.cancel();
    _remindTimer = Timer(const Duration(seconds: 3), () {
      final s = _store;
      if (s != null) Reminders.sync(s);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifyBridge.listen(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drain();
      _store = StoreScope.read(context)..addListener(_onStore);
      _store!.fetchConfig().whenComplete(_onStore);
      _store!.fetchProfile();
      Weather.refresh(_store!);
    });
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _linkSub = AppLinks().uriLinkStream.listen(_onLink, onError: (_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _store?.removeListener(_onStore);
    _remindTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _drain();
      final store = StoreScope.read(context);
      if (store.loggedIn) store.sync();
      store.fetchConfig().whenComplete(_onStore);
      Weather.refresh(store);
    }
  }

  /// Lấy các thông báo ngân hàng Android đã bắt được và ghi thành giao dịch.
  Future<void> _drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      final items = await NotifyBridge.drain();
      if (!mounted) return;
      final store = StoreScope.read(context);
      final added = <Txn>[...await QuickQueue.drain(store)];
      if (!mounted) return;
      for (final n in items) {
        final r = store.ingest(n);
        if (r.status == 'added') added.add(r.txn!);
      }
      if (added.isEmpty) return;
      // Tiền chuyển sang hũ mục tiêu ("VTG <mã>") và tiền nộp quỹ chung về tài khoản thủ quỹ ("VT <mã quỹ>")
      final matched = <String>[];
      for (final t in added) {
        final g = GoalMoney.autoMatch(store, t);
        if (g != null) matched.add('Đã cất ${money(t.amount)} vào "${g.name}"');
      }
      for (final t in added.where((t) => t.income).toList()) {
        final hit = await Spaces.autoConfirm(store, amount: t.amount, text: '${t.raw} ${t.note}');
        if (hit != null) {
          t
            ..categoryId = 'chuyen_vi'
            ..note = 'Nhận quỹ "${hit.sp.name}" · ${hit.sp.nameOf(hit.e.by)}';
          store.saveTxn(t);
          matched.add('${hit.sp.nameOf(hit.e.by)} đã nộp ${money(t.amount)} vào "${hit.sp.name}". Đã tự xác nhận');
        }
      }
      for (final t in added) {
        final ev = await Spaces.autoEvidence(store, income: t.income, amount: t.amount, text: '${t.raw} ${t.note}');
        if (ev != null) matched.add(ev);
      }
      if (!mounted) return;
      if (matched.isNotEmpty) {
        showToast(context, matched.join('\n'));
        return;
      }
      final nudges = [for (final t in added) ...store.nudgesFor(t)];
      if (nudges.isNotEmpty) {
        showNudges(nudges);
        return;
      }
      if (added.isNotEmpty && mounted) {
        final msg = added.length == 1
            ? 'Đã ghi ${money(added.first.signed, signed: true)} · ${store.walletName(added.first.walletId)}'
            : 'Đã tự ghi ${added.length} giao dịch';
        showToast(context, msg,
            actionLabel: added.length == 1 ? 'Sửa' : null,
            onAction: added.length == 1 ? () => openEditTxn(context, added.first) : null);
      }
    } finally {
      _draining = false;
    }
  }

  /// vieting://add?text=... (Phím tắt iPhone)  hoặc  vieting://add?amount=50000&type=chi&note=...
  void _onLink(Uri uri) {
    if (!mounted) return;
    if (uri.host == 'calendar') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
      return;
    }
    if (uri.host != 'add') return;
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
      showToast(context, msg);
      return;
    }
    final amount = int.tryParse(uri.queryParameters['amount'] ?? '');
    final income = (uri.queryParameters['type'] ?? '').toLowerCase().startsWith('thu');
    if (amount != null && amount > 0) {
      openEditTxn(context, null, presetAmount: amount, presetIncome: income, presetNote: uri.queryParameters['note']);
    } else {
      // vieting://add (nút + trên widget, phím tắt): mở ô ghi nhanh
      openEditTxn(context, null, presetIncome: income);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewScreen(onSeeAll: () => setState(() => _tab = 1)),
      const TransactionsScreen(),
      const AssistantScreen(),
      const PlanScreen(),
      const SettingsScreen(),
    ];
    const items = [
      (PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour, 'Tổng quan'),
      (PhosphorIconsRegular.receipt, PhosphorIconsFill.receipt, 'Giao dịch'),
      (PhosphorIconsRegular.sparkle, PhosphorIconsFill.sparkle, 'Trợ lý'),
      (PhosphorIconsRegular.plant, PhosphorIconsFill.plant, 'Kế hoạch'),
      (PhosphorIconsRegular.gearSix, PhosphorIconsFill.gearSix, 'Cài đặt'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final fab = _tab < 2
        ? FloatingActionButton.extended(
            onPressed: () => openEditTxn(context, null),
            icon: const Icon(PhosphorIconsBold.plus),
            label: const Text('Ghi khoản'),
          )
        : null;

    if (wide) {
      return _withBg(context, Scaffold(
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
      ));
    }
    return _withBg(context, Scaffold(
      body: pages[_tab],
      floatingActionButton: fab,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final it in items) NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: tr(it.$3)),
        ],
      ),
      ),
    ));
  }

  /// Hình nền người dùng chọn: chỉ áp cho 5 trang chính, các màn mở thêm giữ nền đặc để không lộ trang bên dưới.
  Widget _withBg(BuildContext context, Widget scaffold) {
    final store = StoreScope.of(context);
    if (store.appBg.isEmpty) return scaffold;
    final t = Theme.of(context);
    return AppBackground(
      child: Theme(
        data: t.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: t.appBarTheme.copyWith(backgroundColor: Colors.transparent),
        ),
        child: scaffold,
      ),
    );
  }
}
