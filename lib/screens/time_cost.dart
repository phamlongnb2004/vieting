import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import '../widgets/logo.dart';

/// Đổi giá món đồ ra "giờ làm việc" + thẻ chia sẻ lên mạng xã hội.
class TimeCostScreen extends StatefulWidget {
  final String? name;
  final int? price;
  const TimeCostScreen({super.key, this.name, this.price});

  @override
  State<TimeCostScreen> createState() => _TimeCostScreenState();
}

class _TimeCostScreenState extends State<TimeCostScreen> {
  final _key = GlobalKey();
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _price = TextEditingController(text: widget.price == null ? '' : groupDigits(widget.price!));
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _setWage() async {
    final store = StoreScope.read(context);
    final c = TextEditingController(text: store.hourlyWage > 0 ? groupDigits(store.hourlyWage) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bạn kiếm bao nhiêu mỗi giờ?'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsFormatter()],
          decoration: const InputDecoration(suffixText: '₫/giờ', helperText: 'Lương tháng ÷ 176 giờ (22 ngày × 8 giờ)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok == true) store.setHourlyWage(parseMoneyInput(c.text));
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}vieting-gio-lam.png');
      await f.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')], text: 'Món này tốn bao nhiêu giờ làm của bạn? #VieTing');
    } catch (e) {
      if (mounted) showToast(context, 'Không chia sẻ được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final price = parseMoneyInput(_price.text);
    final wage = store.effectiveHourlyWage;
    final hours = price > 0 ? store.workHours(price) : '';
    final what = _name.text.trim().isEmpty ? 'Món này' : _name.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi giá ra giờ làm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Món đồ (VD: AirPods)')),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Giá', suffixText: '₫'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(PhosphorIconsRegular.timer),
            title: Text(wage > 0 ? 'Thu nhập: ${money(wage)}/giờ' : 'Chưa có thu nhập mỗi giờ'),
            subtitle: Text(store.hourlyWage > 0 ? 'Bạn tự nhập' : wage > 0 ? 'Tự tính từ khoản lương' : 'Bấm để nhập'),
            trailing: const Icon(PhosphorIconsRegular.pencilSimple),
            onTap: _setWage,
          ),
          const SizedBox(height: 10),
          if (hours.isNotEmpty) ...[
            Center(
              child: RepaintBoundary(
                key: _key,
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(colors: [Brand.navy, Color(0xFF243B7A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      CoinLogo(size: 26),
                      SizedBox(width: 8),
                      Text('VieTing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 20),
                    Text(what, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    Text(money(price), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text('tốn của mình', style: TextStyle(color: Colors.white70)),
                    Text(hours, style: const TextStyle(color: Brand.yellow, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 14),
                    const Text('Mua hay không mua?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    const Text('Đổi giá ra giờ làm trên VieTing', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _share,
              icon: const Icon(PhosphorIconsRegular.shareNetwork),
              label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Chia sẻ lên story')),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                wage <= 0 ? 'Nhập thu nhập mỗi giờ để quy đổi.' : 'Nhập giá món đồ để xem tốn bao nhiêu giờ làm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
