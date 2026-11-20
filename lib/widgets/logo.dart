import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Đồng xu VieTing: viền đốt tre xanh, mặt đỏ cờ, ngôi sao vàng, sóng "ting".
class CoinLogo extends StatelessWidget {
  final double size;
  const CoinLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

Path starPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * 0.4;
    final a = -pi / 2 + i * pi / 5;
    final o = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  return p..close();
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s * 0.46, s * 0.54);
    final r = s * 0.42;
    // viền tre
    canvas.drawCircle(c, r, Paint()..color = Brand.bamboo);
    final node = Paint()
      ..color = const Color(0xFF2B6A2E)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * (r * 0.8), c + Offset(cos(a), sin(a)) * r, node);
    }
    canvas.drawCircle(
        c,
        r * 0.96,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..color = Brand.bambooLight.withAlpha(150));
    // mặt đỏ + sao
    canvas.drawCircle(c, r * 0.76, Paint()..color = Brand.red);
    canvas.drawPath(starPath(c, r * 0.5), Paint()..color = Brand.yellow);
    // sóng "ting"
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.05
      ..color = Brand.yellow;
    final wc = Offset(s * 0.80, s * 0.20);
    for (var i = 0; i < 2; i++) {
      final rr = s * (0.08 + i * 0.09);
      canvas.drawArc(Rect.fromCircle(center: wc, radius: rr), -pi * 0.85, pi * 0.7, false, wave);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chữ "VieTing": "Vie" màu cờ đỏ sao vàng, "Ting" màu tre.
class Wordmark extends StatelessWidget {
  final double fontSize;
  const Wordmark({super.key, this.fontSize = 26});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CoinLogo(size: fontSize * 1.35),
      SizedBox(width: fontSize * 0.25),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Brand.red, Color(0xFFE53935), Brand.yellow],
          stops: [0, 0.62, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
        child: Text('Vie', style: style),
      ),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Color(0xFF2B6A2E), Brand.bamboo, Brand.bambooLight, Brand.bamboo],
          stops: [0, 0.35, 0.55, 1],
        ).createShader(r),
        child: Text('Ting', style: style),
      ),
    ]);
  }
}
