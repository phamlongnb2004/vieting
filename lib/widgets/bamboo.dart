import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Cây tre lớn dần theo % tiền đã để dành cho mục tiêu: mỗi 1/8 quãng đường mọc thêm một đốt.
class BambooTree extends StatelessWidget {
  final double progress; // 0..1
  final double height;
  const BambooTree({super.key, required this.progress, this.height = 120});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(size: Size(height * 0.55, height), painter: _BambooPainter(v)),
      );
}

class _BambooPainter extends CustomPainter {
  final double p;
  _BambooPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // đất
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 5), width: w * 0.9, height: 10), Paint()..color = const Color(0xFF8D6E63).withAlpha(90));
    const maxNodes = 8;
    final nodes = max(1, (p * maxNodes).ceil());
    final segH = (h - 22) / maxNodes;
    final stalkW = w * 0.2;
    final x = w / 2 - stalkW / 2;
    final green = Paint()..color = Brand.bamboo;
    final light = Paint()..color = Brand.bambooLight;
    for (var i = 0; i < nodes; i++) {
      // đốt cuối mọc dần theo phần lẻ
      final frac = i == nodes - 1 ? ((p * maxNodes) - (nodes - 1)).clamp(0.25, 1.0) : 1.0;
      final top = h - 10 - segH * i - segH * frac;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, top, stalkW, segH * frac - 2), const Radius.circular(4));
      canvas.drawRRect(r, green);
      canvas.drawRect(Rect.fromLTWH(x + stalkW * 0.18, top + 3, stalkW * 0.16, max(0, segH * frac - 8)), light);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 2, top + segH * frac - 4, stalkW + 4, 4), const Radius.circular(2)),
        Paint()..color = const Color(0xFF2B6A2E),
      );
      // lá mọc ở các đốt chẵn
      if (i.isOdd || i == nodes - 1) {
        final left = i % 4 == 1;
        final y = top + 4;
        final path = Path()
          ..moveTo(left ? x : x + stalkW, y)
          ..quadraticBezierTo(left ? x - w * 0.35 : x + stalkW + w * 0.35, y - segH * 0.7, left ? x - w * 0.42 : x + stalkW + w * 0.42, y - segH * 0.2)
          ..quadraticBezierTo(left ? x - w * 0.2 : x + stalkW + w * 0.2, y + 2, left ? x : x + stalkW, y)
          ..close();
        canvas.drawPath(path, Paint()..color = Brand.bambooLight);
      }
    }
    if (p >= 1) {
      // đạt mục tiêu: ngôi sao vàng trên ngọn
      final c = Offset(w / 2, h - 10 - segH * maxNodes - 4);
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? 9.0 : 3.8;
        final a = -pi / 2 + i * pi / 5;
        final o = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
        if (i == 0) {
          star.moveTo(o.dx, o.dy);
        } else {
          star.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(star..close(), Paint()..color = Brand.yellow);
    }
  }

  @override
  bool shouldRepaint(covariant _BambooPainter old) => old.p != p;
}
