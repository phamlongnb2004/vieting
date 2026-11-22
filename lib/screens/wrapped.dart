import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../categories.dart';
import '../insights.dart';
import '../pro.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/logo.dart';

/// Thẻ tổng kết kỳ kiểu "Wrapped": đẹp, vui, chia sẻ lên story được.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  final _key = GlobalKey();
  late int _y, _m;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final s = StoreScope.read(context);
    final p = s.currentPeriod;
    // mặc định: kỳ trước (đã trọn vẹn); nếu chưa có dữ liệu thì kỳ này
    final prev = DateTime(p.year, p.month - 1);
    final hasPrev = s.monthTxns(prev.year, prev.month).isNotEmpty;
    _y = hasPrev ? prev.year : p.year;
    _m = hasPrev ? prev.month : p.month;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}vieting-tong-ket.png');
      await f.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')], sharePositionOrigin: shareOrigin(context), text: 'Tổng kết chi tiêu của mình trên VieTing');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không chia sẻ được: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final w = store.wrapped(_y, _m);
    Widget stat(String big, String small) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(big, style: const TextStyle(color: Brand.yellow, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
            Text(small, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng kết kỳ'),
        actions: [
          IconButton(
            onPressed: () async {
              if (!await Pro.check(context, 'wrapped')) return;
              if (!mounted) return;
              setState(() {
              final d = DateTime(_y, _m - 1);
              _y = d.year;
              _m = d.month;
              });
            },
            icon: const Icon(PhosphorIconsRegular.caretLeft),
          ),
          IconButton(
            onPressed: () => setState(() {
              final d = DateTime(_y, _m + 1);
              _y = d.year;
              _m = d.month;
            }),
            icon: const Icon(PhosphorIconsRegular.caretRight),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: RepaintBoundary(
              key: _key,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Brand.red, Color(0xFF7A1418), Brand.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CoinLogo(size: 30),
                    const SizedBox(width: 8),
                    const Text('VieTing Wrapped', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(w.period, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Danh hiệu của bạn', style: TextStyle(color: Colors.white70)),
                  Text(w.title, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 16),
                  stat(compactMoney(w.expense), 'đã chi qua ${w.count} lần quẹt / chuyển khoản'),
                  if (w.topCat != null)
                    stat('${catById(w.topCat!).name} · ${compactMoney(w.topCatAmount)}',
                        'chiếm ${w.expense == 0 ? 0 : (w.topCatAmount * 100 / w.expense).round()}% chi tiêu'),
                  if (w.topPlace != null && w.topPlaceCount >= 2) stat('"${w.topPlace}" × ${w.topPlaceCount}', 'chỗ quen thuộc nhất'),
                  if (w.biggest != null && !w.biggest!.hidden)
                    stat(compactMoney(w.biggest!.amount), 'khoản lớn nhất: ${catById(w.biggest!.categoryId).name}'),
                  if (w.income > 0) stat(compactMoney(w.income - w.expense), w.income >= w.expense ? 'để dành được' : 'chi vượt thu'),
                  const SizedBox(height: 10),
                  const Text('Tải VieTing – có tiền vào ra là ting', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Chia sẻ lên story')),
          ),
        ],
      ),
    );
  }
}
