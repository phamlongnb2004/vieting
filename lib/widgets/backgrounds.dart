import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';

import '../store.dart';
import '../theme.dart';

/// Hình nền cho app và widget: các nền vẽ sẵn mang màu VieTing + ảnh người dùng tự chọn.
/// Tác giả: Phạm Thành Long (thlong)
class BgPreset {
  final String id;
  final String name;
  final List<Color> colors;
  final bool dark;
  const BgPreset(this.id, this.name, this.colors, {this.dark = false});
}

const kBgPresets = <BgPreset>[
  BgPreset('tre', 'Rừng tre', [Color(0xFFE8F3DC), Color(0xFFB9DB9A), Color(0xFF6FAE3B)]),
  BgPreset('co', 'Đỏ VieTing', [Color(0xFFD4343A), Color(0xFFC1272C), Color(0xFF7C1216)], dark: true),
  BgPreset('dem', 'Đêm sao', [Color(0xFF2A4A9A), Color(0xFF152758), Color(0xFF0B1533)], dark: true),
  BgPreset('hoang_hon', 'Hoàng hôn', [Color(0xFFFFCF70), Color(0xFFF26B3A), Color(0xFF8E2A55)], dark: true),
  BgPreset('bien', 'Biển xanh', [Color(0xFFD6F3F4), Color(0xFF7CC8D8), Color(0xFF2B6CB0)]),
  BgPreset('hoa_dao', 'Hoa đào Tết', [Color(0xFFFFF0F3), Color(0xFFFFC7D4), Color(0xFFF48FB1)]),
  BgPreset('giay', 'Giấy dó', [Color(0xFFFFFBF2), Color(0xFFF3E9D6), Color(0xFFE6D5B8)]),
];

BgPreset? presetById(String id) {
  for (final p in kBgPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// Nền vẽ sẵn (dùng cả cho ô xem trước).
class PresetBackground extends StatelessWidget {
  final BgPreset p;
  const PresetBackground(this.p, {super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: p.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: CustomPaint(painter: _Deco(p.id), size: Size.infinite),
      );
}

class _Deco extends CustomPainter {
  final String id;
  _Deco(this.id);

  void _bamboo(Canvas c, Size s, Color color, {double from = .62}) {
    final paint = Paint()..color = color;
    final gap = Paint()..color = Colors.black.withAlpha(22);
    final w = s.width * .05;
    for (var i = 0; i < 4; i++) {
      final x = s.width * (from + i * .1);
      final top = s.height * (.08 + .1 * i);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x, top, x + w, s.height * 1.05), Radius.circular(w / 2)), paint);
      for (var y = top + s.height * .14; y < s.height; y += s.height * .16) {
        c.drawRect(Rect.fromLTWH(x, y, w, w * .18), gap);
      }
      // lá tre
      final leaf = Path()
        ..moveTo(x + w, top + s.height * .2)
        ..quadraticBezierTo(x + w * 4, top + s.height * .16, x + w * 6, top + s.height * .24)
        ..quadraticBezierTo(x + w * 3.4, top + s.height * .25, x + w, top + s.height * .2);
      c.drawPath(leaf, paint);
    }
  }

  void _star(Canvas c, Offset o, double r, Color color) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * .42;
      final a = (-90 + k * 36) * pi / 180;
      final p = Offset(o.dx + rr * cos(a), o.dy + rr * sin(a));
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  @override
  void paint(Canvas c, Size s) {
    final rnd = Random(7);
    switch (id) {
      case 'tre':
        _bamboo(c, s, const Color(0xFF3E8E41).withAlpha(55));
        _bamboo(c, s, const Color(0xFF3E8E41).withAlpha(30), from: -.08);
      case 'co':
        _bamboo(c, s, Colors.white.withAlpha(26));
        _star(c, Offset(s.width * .86, s.height * .1), s.shortestSide * .07, Brand.yellow);
      case 'dem':
        final p = Paint();
        for (var i = 0; i < 90; i++) {
          p.color = Colors.white.withAlpha(40 + rnd.nextInt(140));
          c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height), .6 + rnd.nextDouble() * 1.6, p);
        }
        c.drawCircle(Offset(s.width * .82, s.height * .12), s.shortestSide * .08, Paint()..color = const Color(0xFFFFF3C4).withAlpha(220));
      case 'hoang_hon':
        c.drawCircle(Offset(s.width * .72, s.height * .3), s.shortestSide * .22, Paint()..color = const Color(0xFFFFF3C4).withAlpha(90));
        final hill = Path()
          ..moveTo(0, s.height * .78)
          ..quadraticBezierTo(s.width * .35, s.height * .66, s.width * .7, s.height * .8)
          ..quadraticBezierTo(s.width * .88, s.height * .86, s.width, s.height * .78)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height);
        c.drawPath(hill, Paint()..color = const Color(0xFF3A0F2E).withAlpha(120));
      case 'bien':
        for (var i = 0; i < 5; i++) {
          final y = s.height * (.55 + i * .1);
          final wave = Path()..moveTo(0, y);
          for (var x = 0.0; x <= s.width; x += s.width / 6) {
            wave.quadraticBezierTo(x + s.width / 12, y - 14, x + s.width / 6, y);
          }
          c.drawPath(wave, Paint()
            ..color = Colors.white.withAlpha(70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
        }
      case 'hoa_dao':
        for (var i = 0; i < 26; i++) {
          final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
          final r = 6 + rnd.nextDouble() * 12;
          final petal = Paint()..color = const Color(0xFFF06292).withAlpha(50 + rnd.nextInt(60));
          for (var k = 0; k < 5; k++) {
            final a = k * 2 * pi / 5 + i;
            c.drawCircle(o + Offset(cos(a), sin(a)) * r * .55, r * .5, petal);
          }
          c.drawCircle(o, r * .22, Paint()..color = const Color(0xFFFFCD00).withAlpha(150));
        }
      case 'giay':
        final p = Paint()..color = const Color(0xFF8D6E63).withAlpha(14);
        for (var i = 0; i < 160; i++) {
          c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height), rnd.nextDouble() * 2.2, p);
        }
        _bamboo(c, s, Brand.red.withAlpha(16), from: .7);
    }
  }

  @override
  bool shouldRepaint(_Deco o) => o.id != id;
}

/// Bọc toàn app: vẽ hình nền đã chọn phía sau, phủ một lớp màu nền để chữ vẫn dễ đọc.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (s.appBg.isEmpty) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Brand.night : Brand.paper;
    Widget bg;
    double alpha = s.appBgDim;
    if (s.appBg == 'photo') {
      final f = File(s.appBgPhoto);
      if (s.appBgPhoto.isEmpty || !f.existsSync()) return child;
      bg = Image.file(f, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      final p = presetById(s.appBg);
      if (p == null) return child;
      bg = PresetBackground(p);
      // nền tối thì phủ đậm hơn khi app đang ở giao diện sáng để chữ không chìm
      if (p.dark && !dark) alpha = max(alpha, .45);
    }
    return Stack(children: [
      Positioned.fill(child: bg),
      Positioned.fill(child: ColoredBox(color: base.withAlpha((alpha.clamp(0.0, .9) * 255).round()))),
      child,
    ]);
  }
}
