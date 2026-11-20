import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Logo VieTing (flat vector): chữ V ghép từ 2 thân tre, sao vàng, sóng "ting", nền đỏ cờ.
class CoinLogo extends StatelessWidget {
  final double size;
  const CoinLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _VLogoPainter());
}

Path starPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * 0.42;
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

class _VLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22)),
      Paint()..color = Brand.red,
    );
    const cream = Color(0xFFFFF8EC);
    final bottom = Offset(s * 0.5, s * 0.80);
    final tops = [Offset(s * 0.25, s * 0.34), Offset(s * 0.75, s * 0.34)];
    final stalk = Paint()
      ..color = cream
      ..strokeWidth = s * 0.17
      ..strokeCap = StrokeCap.round;
    final band = Paint()
      ..color = Brand.red
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.butt;
    for (final t in tops) {
      canvas.drawLine(t, bottom, stalk);
    }
    for (final t in tops) {
      final d = bottom - t;
      final len = d.distance;
      final dir = d / len;
      final normal = Offset(-dir.dy, dir.dx) * (s * 0.09);
      for (final k in [0.33, 0.66]) {
        final c = t + d * k;
        canvas.drawLine(c - normal, c + normal, band);
      }
    }
    canvas.drawPath(starPath(Offset(s * 0.47, s * 0.28), s * 0.12), Paint()..color = Brand.yellow);
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.045
      ..color = Brand.yellow;
    final wc = Offset(s * 0.60, s * 0.25);
    for (final r in [s * 0.10, s * 0.17]) {
      canvas.drawArc(Rect.fromCircle(center: wc, radius: r), -pi * 0.42, pi * 0.34, false, wave);
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
