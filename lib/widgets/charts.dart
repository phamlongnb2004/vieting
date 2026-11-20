import 'dart:math';

import 'package:flutter/material.dart';

import '../util/format.dart';

class DonutSlice {
  final int value;
  final Color color;
  const DonutSlice(this.value, this.color);
}

/// Biểu đồ vòng chi tiêu theo danh mục.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double size;
  final Widget? center;
  const DonutChart({super.key, required this.slices, this.size = 150, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size.square(size),
          painter: _DonutPainter(slices, Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
        if (center != null) center!,
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final Color empty;
  _DonutPainter(this.slices, this.empty);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final total = slices.fold<int>(0, (s, e) => s + e.value);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * pi, false, p..color = empty);
      return;
    }
    var start = -pi / 2;
    const gap = 0.02;
    for (final s in slices) {
      final sweep = 2 * pi * s.value / total;
      final g = slices.length > 1 && sweep > gap * 2 ? gap : 0.0;
      canvas.drawArc(rect, start + g / 2, sweep - g, false, p..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/// Cột chi tiêu theo ngày.
class DayBars extends StatelessWidget {
  final List<({DateTime day, int expense})> data;
  final double height;
  const DayBars({super.key, required this.data, this.height = 130});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = data.fold<int>(0, (m, e) => max(m, e.expense));
    const short = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(d.expense > 0 ? compactMoney(d.expense) : '',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1),
                  const SizedBox(height: 3),
                  Container(
                    height: maxV == 0 ? 4 : max(4.0, (height - 42) * d.expense / maxV),
                    decoration: BoxDecoration(
                      color: sameDay(d.day, DateTime.now()) ? cs.primary : cs.primary.withAlpha(110),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(short[d.day.weekday - 1], style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ ngân sách.
class BudgetBar extends StatelessWidget {
  final int spent;
  final int limit;
  const BudgetBar({super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final color = ratio >= 1
        ? const Color(0xFFC1272C)
        : ratio >= 0.8
            ? const Color(0xFFEF8F00)
            : const Color(0xFF3E8E41);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: 9,
        color: color,
        backgroundColor: color.withAlpha(40),
      ),
    );
  }
}
