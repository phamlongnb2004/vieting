import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../store.dart';

/// Kiểu hiệu ứng lấy từ mã thời tiết hiện tại.
enum WxFx { none, clearDay, clearNight, partlyDay, partlyNight, cloudy, fog, lightRain, rain, heavyRain, thunder, snow }

WxFx wxFxOf(String sym) {
  if (sym.isEmpty) return WxFx.none;
  final night = sym.endsWith('_night') || sym.endsWith('_polartwilight');
  final s = sym.replaceAll(RegExp(r'_(day|night|polartwilight)$'), '');
  if (s.contains('thunder')) return WxFx.thunder;
  if (s.contains('snow') || s.contains('sleet')) return WxFx.snow;
  if (s.startsWith('heavyrain')) return WxFx.heavyRain;
  if (s.startsWith('lightrain')) return WxFx.lightRain;
  if (s.contains('rain')) return WxFx.rain;
  if (s == 'fog') return WxFx.fog;
  if (s == 'cloudy') return WxFx.cloudy;
  if (s == 'partlycloudy' || s == 'fair') return night ? WxFx.partlyNight : WxFx.partlyDay;
  if (s == 'clearsky') return night ? WxFx.clearNight : WxFx.clearDay;
  return WxFx.none;
}

/// Kiểu hiệu ứng đang áp dụng cho trang Tổng quan (none nếu tắt, chưa có dữ liệu hoặc dữ liệu quá cũ).
WxFx currentWxFx(Store s) {
  if (!s.weatherOn || !s.weatherFx) return WxFx.none;
  final w = s.weather;
  if (w == null) return WxFx.none;
  if (DateTime.now().millisecondsSinceEpoch - s.weatherAt > 12 * 3600 * 1000) return WxFx.none;
  final cur = w['current'];
  if (cur is! Map) return WxFx.none;
  return wxFxOf('${cur['sym'] ?? ''}');
}

/// Shader GPU vẽ mây thể tích, mưa nhiều lớp, nắng, sao, chớp; nạp một lần cho cả app.
ui.FragmentProgram? _program;
bool _programTried = false;
Future<void> _loadProgram() async {
  if (_programTried) return;
  _programTried = true;
  try {
    _program = await ui.FragmentProgram.fromAsset('shaders/weather.frag');
  } catch (_) {
    _program = null; // máy không hỗ trợ thì dùng bản vẽ dự phòng
  }
}

/// Hiệu ứng thời tiết động phía sau nội dung trang Tổng quan (mưa rơi, mây trôi, nắng, sao, sấm chớp...).
/// Lấy theo giờ hiện tại của dự báo đã tải; tắt được trong Cài đặt > Thời tiết.
class WeatherFxLayer extends StatefulWidget {
  const WeatherFxLayer({super.key, this.force});

  /// Chỉ dùng để xem thử một kiểu cụ thể.
  final WxFx? force;

  @override
  State<WeatherFxLayer> createState() => _WeatherFxLayerState();
}

class _WeatherFxLayerState extends State<WeatherFxLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6);
    if (!_programTried) {
      _loadProgram().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  WxFx _kind(Store s) => widget.force ?? currentWxFx(s);

  @override
  Widget build(BuildContext context) {
    final kind = _kind(StoreScope.of(context));
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final run = kind != WxFx.none && !still;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
    if (kind == WxFx.none) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _program != null ? _ShaderPainter(_program!.fragmentShader(), kind, dark, _t) : _FxPainter(kind, dark, _t),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _P {
  _P(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        s = r.nextDouble(),
        z = r.nextDouble();
  final double x, y, s, z; // vị trí, tốc độ, độ sâu (0..1)
}

final List<_P> _pts = () {
  final r = math.Random(7);
  return List.generate(220, (_) => _P(r));
}();

class _FxPainter extends CustomPainter {
  _FxPainter(this.kind, this.dark, this.t) : super(repaint: t);

  final WxFx kind;
  final bool dark;
  final ValueNotifier<double> t;

  /// Hiệu ứng đậm ở trên, nhạt dần xuống dưới để không lấn nội dung.
  double _fade(double y, double h) => (1 - 0.7 * (y / h).clamp(0.0, 1.0));

  @override
  void paint(Canvas c, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final time = t.value;
    _sky(c, size);
    switch (kind) {
      case WxFx.clearDay:
        _sun(c, size, time, 1);
        _clouds(c, size, time, 1, 0.5);
      case WxFx.partlyDay:
        _sun(c, size, time, 0.75);
        _clouds(c, size, time, 4, 0.8);
      case WxFx.clearNight:
        _stars(c, size, time, 60);
        _moon(c, size);
      case WxFx.partlyNight:
        _stars(c, size, time, 35);
        _moon(c, size);
        _clouds(c, size, time, 3, 0.6);
      case WxFx.cloudy:
        _clouds(c, size, time, 7, 1);
      case WxFx.fog:
        _clouds(c, size, time, 4, 0.7);
        _fog(c, size, time);
      case WxFx.lightRain:
        _clouds(c, size, time, 5, 0.9);
        _rain(c, size, time, 55, 0.8);
      case WxFx.rain:
        _clouds(c, size, time, 6, 1);
        _rain(c, size, time, 110, 1);
      case WxFx.heavyRain:
        _clouds(c, size, time, 7, 1.1);
        _rain(c, size, time, 200, 1.25);
      case WxFx.thunder:
        _clouds(c, size, time, 7, 1.2);
        _rain(c, size, time, 170, 1.2);
        _lightning(c, size, time);
      case WxFx.snow:
        _clouds(c, size, time, 5, 0.9);
        _snow(c, size, time);
      case WxFx.none:
        break;
    }
  }

  Color get _cloudColor => dark ? const Color(0xFFB8C2D6) : const Color(0xFF8A9BB5);

  void _sky(Canvas c, Size s) {
    final top = switch (kind) {
      WxFx.clearDay => const Color(0xFF4FA3E8),
      WxFx.partlyDay => const Color(0xFF6BAADF),
      WxFx.clearNight || WxFx.partlyNight => const Color(0xFF1B2A5A),
      WxFx.cloudy || WxFx.fog => const Color(0xFF8994A6),
      WxFx.lightRain || WxFx.rain || WxFx.snow => const Color(0xFF5F6F88),
      WxFx.heavyRain || WxFx.thunder => const Color(0xFF3A4458),
      WxFx.none => Colors.transparent,
    };
    final a = dark ? 0.42 : 0.26;
    final rect = Offset.zero & Size(s.width, math.min(s.height, 420));
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top.withValues(alpha: a), top.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  void _sun(Canvas c, Size s, double time, double k) {
    final o = Offset(s.width - 54, 40);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFE08A).withValues(alpha: 0.75 * k),
        const Color(0xFFFFC94D).withValues(alpha: 0.25 * k),
        const Color(0xFFFFC94D).withValues(alpha: 0),
      ], stops: const [0, 0.35, 1]).createShader(Rect.fromCircle(center: o, radius: 190));
    c.drawCircle(o, 190, glow);
    // Tia nắng xoay chậm, sáng lên tắt xuống nhẹ nhàng
    final rays = Paint()..style = PaintingStyle.fill;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(time * 0.05);
    for (var i = 0; i < 12; i++) {
      final pulse = 0.5 + 0.5 * math.sin(time * 0.9 + i * 1.7);
      rays.color = const Color(0xFFFFE7A3).withValues(alpha: (0.10 + 0.10 * pulse) * k);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(220, -9)
        ..lineTo(220, 9)
        ..close();
      c.drawPath(path, rays);
      c.rotate(math.pi * 2 / 12);
    }
    c.restore();
    c.drawCircle(o, 24, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.9 * k));
  }

  void _moon(Canvas c, Size s) {
    final o = Offset(s.width - 56, 46);
    c.drawCircle(
      o,
      110,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFDDE6FF).withValues(alpha: 0.35),
          const Color(0xFFDDE6FF).withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: o, radius: 110)),
    );
    final moon = Path()..addOval(Rect.fromCircle(center: o, radius: 18));
    final bite = Path()..addOval(Rect.fromCircle(center: o + const Offset(9, -6), radius: 16));
    c.drawPath(Path.combine(PathOperation.difference, moon, bite), Paint()..color = const Color(0xFFF4F1DE));
  }

  void _stars(Canvas c, Size s, double time, int n) {
    final p = Paint();
    for (var i = 0; i < n; i++) {
      final q = _pts[i];
      final y = q.y * math.min(s.height, 360);
      final tw = 0.5 + 0.5 * math.sin(time * (1 + q.s * 2) + i);
      p.color = Colors.white.withValues(alpha: (0.25 + 0.6 * tw) * _fade(y, 360) * (dark ? 1 : 0.8));
      c.drawCircle(Offset(q.x * s.width, y), 0.7 + q.z * 1.2, p);
    }
  }

  void _clouds(Canvas c, Size s, double time, int n, double k) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (var i = 0; i < n; i++) {
      final q = _pts[100 + i];
      final cw = 170 + q.z * 170;
      final speed = 6 + q.s * 10; // px/giây
      final span = s.width + cw * 2;
      final x = ((q.x * span + time * speed) % span) - cw;
      final y = 10 + q.y * 170;
      p.color = _cloudColor.withValues(alpha: (0.16 + 0.14 * q.z) * k * _fade(y, s.height));
      final r = Rect.fromLTWH(x, y, cw, cw * 0.34);
      c.drawOval(r, p);
      c.drawOval(Rect.fromLTWH(x + cw * 0.22, y - cw * 0.12, cw * 0.48, cw * 0.32), p);
    }
  }

  void _fog(Canvas c, Size s, double time) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    for (var i = 0; i < 5; i++) {
      final y = 40.0 + i * 70;
      final dx = math.sin(time * 0.15 + i) * 60;
      p.color = (dark ? const Color(0xFFCBD2DE) : const Color(0xFFAEB7C6)).withValues(alpha: 0.22 * _fade(y, s.height));
      c.drawRect(Rect.fromLTWH(-80 + dx, y, s.width + 160, 34), p);
    }
  }

  void _rain(Canvas c, Size s, double time, int n, double k) {
    final base = dark ? const Color(0xFFDCE6F5) : const Color(0xFF3F6496);
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const slant = 0.18; // mưa hơi xiên
    for (var i = 0; i < n; i++) {
      final q = _pts[i % _pts.length];
      final depth = 0.4 + 0.6 * q.z;
      final speed = (520 + 420 * q.s) * k * depth; // px/giây
      final len = (10 + 14 * depth) * k;
      final span = s.height + len + 40;
      final y = ((q.y * span + time * speed) % span) - len - 20;
      final x = (q.x * (s.width + 60)) - 30 + y * slant;
      p
        ..strokeWidth = 0.8 + 0.9 * depth
        ..color = base.withValues(alpha: (0.16 + 0.32 * depth) * _fade(y, s.height));
      c.drawLine(Offset(x, y), Offset(x + len * slant, y + len), p);
    }
  }

  void _snow(Canvas c, Size s, double time) {
    final p = Paint();
    for (var i = 0; i < 90; i++) {
      final q = _pts[i];
      final depth = 0.4 + 0.6 * q.z;
      final speed = 25 + 45 * q.s * depth;
      final span = s.height + 20;
      final y = ((q.y * span + time * speed) % span) - 10;
      final x = q.x * s.width + math.sin(time * (0.6 + q.s) + i) * 14;
      p.color = (dark ? Colors.white : const Color(0xFF9FB3CF)).withValues(alpha: (0.45 + 0.4 * depth) * _fade(y, s.height));
      c.drawCircle(Offset(x, y), 1.2 + 2.2 * depth, p);
    }
  }

  void _lightning(Canvas c, Size s, double time) {
    // Mỗi chu kỳ 7 giây có một lần chớp (2 nháy liên tiếp), vị trí đổi theo chu kỳ
    const cycle = 7.0;
    final n = (time / cycle).floor();
    final ph = time - n * cycle;
    double flash = 0;
    if (ph < 0.12) {
      flash = 1 - ph / 0.12;
    } else if (ph > 0.22 && ph < 0.5) {
      flash = 1 - (ph - 0.22) / 0.28;
    }
    if (flash <= 0) return;
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white.withValues(alpha: (dark ? 0.22 : 0.35) * flash));
    if (ph < 0.12 || (ph > 0.22 && ph < 0.32)) {
      final r = math.Random(n);
      var x = s.width * (0.2 + 0.6 * r.nextDouble());
      var y = 0.0;
      final path = Path()..moveTo(x, y);
      while (y < 230) {
        x += (r.nextDouble() - 0.5) * 46;
        y += 18 + r.nextDouble() * 22;
        path.lineTo(x, y);
      }
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFFBFD7FF).withValues(alpha: 0.35 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.white.withValues(alpha: 0.9 * flash),
      );
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.kind != kind || old.dark != dark;
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter(this.shader, this.kind, this.dark, this.t) : super(repaint: t);

  final ui.FragmentShader shader;
  final WxFx kind;
  final bool dark;
  final ValueNotifier<double> t;

  static const _mode = {
    WxFx.clearDay: 1.0,
    WxFx.clearNight: 2.0,
    WxFx.partlyDay: 3.0,
    WxFx.partlyNight: 4.0,
    WxFx.cloudy: 5.0,
    WxFx.fog: 6.0,
    WxFx.lightRain: 7.0,
    WxFx.rain: 8.0,
    WxFx.heavyRain: 9.0,
    WxFx.thunder: 10.0,
    WxFx.snow: 11.0,
  };

  @override
  void paint(Canvas c, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t.value % 3600)
      ..setFloat(3, _mode[kind] ?? 0)
      ..setFloat(4, dark ? 1 : 0);
    c.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => old.kind != kind || old.dark != dark || old.shader != shader;
}
