import 'dart:io';

import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:vieting/i18n.dart';

import '../insights.dart';
import '../services/notify_bridge.dart';
import '../services/reminders.dart';
import '../services/weather.dart';
import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import '../util/lunar.dart';
import '../widgets/backgrounds.dart';

/// Hình nền app + chủ đề widget màn hình chính. Tác giả: Phạm Thành Long (thlong)
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const widgetThemes = [
    ('red', 'Đỏ VieTing'),
    ('navy', 'Đêm sao'),
    ('bamboo', 'Rừng tre'),
    ('sunset', 'Hoàng hôn'),
    ('paper', 'Giấy sáng'),
    ('glass', 'Kính mờ'),
    ('photo', 'Ảnh của bạn'),
  ];

  /// Chọn ảnh, chép vào thư mục riêng của app (ảnh tạm của bộ chọn ảnh có thể bị xóa).
  static Future<String?> _pick(String prefix, String old) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(path);
    if (old.isNotEmpty && old != path) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget head(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: cs.onSurfaceVariant)),
        );

    Widget bgTile(String id, String name, Widget preview) {
      final on = s.appBg == id;
      return GestureDetector(
        onTap: () async {
          if (id == 'photo') {
            final p = await _pick('bg', s.appBgPhoto);
            if (p == null) return;
            s.setAppBg(bg: 'photo', photo: p);
          } else {
            s.setAppBg(bg: id);
          }
        },
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 84,
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: on ? Brand.red : cs.outlineVariant, width: on ? 3 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
          const SizedBox(height: 6),
          SizedBox(width: 88, child: Text(name, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w500))),
        ]),
      );
    }

    final photoPrev = s.appBgPhoto.isNotEmpty && File(s.appBgPhoto).existsSync()
        ? Image.file(File(s.appBgPhoto), fit: BoxFit.cover)
        : Container(color: cs.surfaceContainerHighest, child: const Icon(PhosphorIconsRegular.imageSquare, size: 30));

    return Scaffold(
      appBar: AppBar(title: const Text('Hình nền & widget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          head(tr('HÌNH NỀN APP')),
          SizedBox(
            height: 176,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              bgTile('', 'Mặc định', Container(color: Theme.of(context).brightness == Brightness.dark ? Brand.night : Brand.paper)),
              const SizedBox(width: 10),
              bgTile('photo', 'Ảnh của bạn', photoPrev),
              for (final p in kBgPresets) ...[const SizedBox(width: 10), bgTile(p.id, p.name, PresetBackground(p))],
            ]),
          ),
          if (s.appBg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(PhosphorIconsRegular.drop, size: 18),
              const SizedBox(width: 8),
              const Text('Độ mờ để chữ dễ đọc'),
              Expanded(
                child: Slider(value: s.appBgDim.clamp(0.0, .9), min: 0, max: .9, onChanged: (v) => s.setAppBg(dim: v)),
              ),
            ]),
            Text('Hình nền hiện ở 5 trang chính. Ảnh của bạn chỉ lưu trên máy này.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
          head(tr('WIDGET MÀN HÌNH CHÍNH')),
          if (!NotifyBridge.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Widget hiện có trên Android. Bản iPhone và Windows sẽ có sau.', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          _WidgetPreview(s: s),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (id, name) in widgetThemes)
              ChoiceChip(
                label: Text(name),
                selected: s.widgetTheme == id,
                onSelected: (_) async {
                  var photo = s.widgetPhoto;
                  if (id == 'photo') {
                    final p = await _pick('widget', s.widgetPhoto);
                    if (p == null) return;
                    photo = p;
                  }
                  s.setWidgetStyle(theme: id, photo: photo);
                  await Reminders.setWidgetStyle(id, photo, s.widgetDim);
                  await Reminders.updateWidget(s);
                  if (context.mounted) showToast(context, 'Đã đổi nền widget');
                },
              ),
          ]),
          if (s.widgetTheme == 'photo') ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(PhosphorIconsRegular.drop, size: 18),
              const SizedBox(width: 8),
              const Text('Độ tối của ảnh'),
              Expanded(
                child: Slider(
                  value: s.widgetDim.clamp(0.0, .85),
                  min: 0,
                  max: .85,
                  onChanged: (v) => s.setWidgetStyle(dim: v),
                  onChangeEnd: (v) => Reminders.setWidgetStyle('photo', s.widgetPhoto, v),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(PhosphorIconsRegular.info, size: 20),
                  SizedBox(width: 8),
                  Text('Cách thêm widget', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Text('1. Giữ ngón tay vào chỗ trống trên màn hình chính\n'
                    '2. Chọn "Tiện ích" (Widgets) rồi tìm VieTing\n'
                    '3. Kéo "VieTing · Chi tiêu hôm nay" hoặc "VieTing · Lịch âm dương" ra màn hình\n'
                    '4. Giữ widget để kéo to / nhỏ tùy ý',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bản xem trước 2 widget đúng với chủ đề đang chọn.
class _WidgetPreview extends StatelessWidget {
  final AppStore s;
  const _WidgetPreview({required this.s});

  (Decoration, bool, Color) _bg() {
    switch (s.widgetTheme) {
      case 'navy':
        return (const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A4A9A), Brand.navy, Color(0xFF0B1533)])), true, Brand.yellow);
      case 'bamboo':
        return (const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6FAE3B), Brand.bamboo, Color(0xFF1F5E22)])), true, Brand.yellow);
      case 'sunset':
        return (const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFB547), Color(0xFFF26B3A), Brand.red, Color(0xFF5B1A4A)])), true, Brand.yellow);
      case 'paper':
        return (const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFFDF7), Brand.paper])), false, Brand.red);
      case 'glass':
        return (BoxDecoration(color: const Color(0xFF12110F).withAlpha(150)), true, Brand.yellow);
      case 'photo':
        final f = File(s.widgetPhoto);
        if (s.widgetPhoto.isNotEmpty && f.existsSync()) {
          return (
            BoxDecoration(
              image: DecorationImage(
                image: FileImage(f),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withAlpha((s.widgetDim * 255).round()), BlendMode.darken),
              ),
            ),
            true,
            Brand.yellow
          );
        }
    }
    return (const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD4343A), Brand.red, Color(0xFF7C1216)])), true, Brand.yellow);
  }

  @override
  Widget build(BuildContext context) {
    final (deco, dark, accent) = _bg();
    final fg = dark ? Colors.white : Brand.ink;
    final sub = dark ? Colors.white.withAlpha(200) : const Color(0xFF6E6A63);
    final g = s.guiltFree;
    final now = DateTime.now();
    final l = toLunar(now);
    final hol = holidayOf(now, l);
    final c = s.weather?['current'];
    final wx = c is Map ? '${c['temp']}° ${tr(wxLook('${c['sym']}').$2)}' : '';
    Widget brand() => Text.rich(TextSpan(children: [
          TextSpan(text: 'Vie', style: TextStyle(color: fg)),
          TextSpan(text: 'Ting', style: TextStyle(color: accent)),
        ]), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13));
    BoxDecoration box() => (deco as BoxDecoration).copyWith(
        borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))]);
    const wd = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final over = g != null && g.leftToday < 0;
    final pct = g == null || g.daily <= 0 ? 0.0 : (g.spentToday / g.daily).clamp(0.0, 1.0);
    return Column(children: [
      // Widget chi tiêu
      Container(
        height: 150,
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: box(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            brand(),
            const SizedBox(width: 6),
            Expanded(child: Text('· ${now.day}/${now.month}', style: TextStyle(color: sub, fontSize: 11))),
            Text(wx, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(over ? 'Hôm nay đã vượt' : 'Hôm nay còn được tiêu', style: TextStyle(color: sub, fontSize: 12)),
                Text(g == null ? '—' : money(over ? -g.leftToday : g.leftToday),
                    style: TextStyle(color: over ? (dark ? Brand.yellow : Brand.red) : (dark ? fg : Brand.bamboo), fontSize: 26, fontWeight: FontWeight.w900)),
              ]),
            ),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? Colors.white : Brand.red),
              child: Text('+', style: TextStyle(color: dark ? Brand.red : Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: dark ? Colors.white.withAlpha(70) : const Color(0xFFEAE2D5),
              color: pct > .8 ? const Color(0xFFFF9F1C) : (dark ? Brand.yellow : Brand.bamboo),
            ),
          ),
          const SizedBox(height: 6),
          Text(s.personaLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      // Widget lịch
      Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: box(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${tr('THÁNG')} ${now.month} · ${now.year}',
                    style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1))),
            brand(),
          ]),
          Expanded(
            child: Row(children: [
              Text('${now.day}', style: TextStyle(color: fg, fontSize: 50, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(wd[now.weekday - 1], style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('${tr('Âm:')} ${l.dayLabel} ${tr('tháng')} ${l.month}', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${tr('Ngày')} ${l.dayName} · ${tr('Năm')} ${l.yearName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sub, fontSize: 11)),
                ]),
              ),
            ]),
          ),
          if (hol != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(color: Brand.yellow, borderRadius: BorderRadius.circular(20)),
              child: Text('★ ${tr(hol)}', style: const TextStyle(color: Brand.redDeep, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          Row(children: [
            Expanded(child: Text('${tr('Đã tiêu hôm nay')} ${compactMoney(g?.spentToday ?? 0)}', style: TextStyle(color: sub, fontSize: 11.5))),
            Text(wx, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    ]);
  }
}
