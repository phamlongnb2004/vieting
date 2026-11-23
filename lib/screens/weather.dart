import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:vieting/i18n.dart';

import '../services/weather.dart';
import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';

/// Ô thời tiết nhỏ ở góc trang chủ. Bấm vào mở màn Thời tiết.
class WeatherChip extends StatelessWidget {
  const WeatherChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (!s.weatherOn) return const SizedBox.shrink();
    final c = s.weather?['current'];
    final hasAlert = Weather.alerts(s).any((a) => ((a['level'] as num?) ?? 0) >= 2);
    final cs = Theme.of(context).colorScheme;
    final (icon, _) = c is Map ? wxLook('${c['sym']}') : (PhosphorIconsRegular.cloudSun, '');
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openWeather(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasAlert ? Brand.red.withAlpha(28) : cs.surfaceContainerHighest.withAlpha(140),
          borderRadius: BorderRadius.circular(20),
          border: hasAlert ? Border.all(color: Brand.red.withAlpha(120)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(hasAlert ? PhosphorIconsFill.warning : icon, size: 18, color: hasAlert ? Brand.red : cs.onSurface),
          const SizedBox(width: 5),
          Text(c is Map ? '${c['temp']}°' : (s.weatherLoc.isEmpty ? 'Thời tiết' : '…'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}

Future<void> openWeather(BuildContext context) async {
  final s = StoreScope.read(context);
  if (s.weatherLoc.isEmpty) {
    final ok = await pickWeatherPlace(context);
    if (!ok || !context.mounted) return;
  }
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
}

/// Chọn "Vị trí của tôi" hoặc một trong 34 tỉnh / thành. Trả về true nếu đã chọn.
Future<bool> pickWeatherPlace(BuildContext context) async {
  final s = StoreScope.read(context);
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _PlacePicker(current: s.weatherLoc),
  );
  if (id == null || !context.mounted) return false;
  if (id == 'device') {
    final pos = await Weather.devicePos(s, ask: true, context: context);
    if (pos == null) {
      if (context.mounted) showToast(context, 'Chưa lấy được vị trí. Bật định vị hoặc chọn tỉnh / thành bằng tay.');
      return false;
    }
  }
  s.setWeather(loc: id, on: true);
  final err = await Weather.refresh(s, force: true);
  if (err != null && context.mounted) showToast(context, err);
  return true;
}

class _PlacePicker extends StatefulWidget {
  final String current;
  const _PlacePicker({required this.current});
  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String q = '';

  String _fold(String x) {
    const a = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const b = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final l = x.toLowerCase();
    final o = StringBuffer();
    for (final ch in l.split('')) {
      final i = a.indexOf(ch);
      o.write(i >= 0 ? b[i] : ch);
    }
    return o.toString();
  }

  @override
  Widget build(BuildContext context) {
    final list = kVnPlaces.where((p) => q.isEmpty || _fold('${p.vi} ${p.en}').contains(_fold(q))).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
                hintText: 'Tìm tỉnh, thành phố…', prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass), isDense: true),
          ),
        ),
        ListTile(
          leading: const Icon(PhosphorIconsRegular.crosshair, color: Brand.red),
          title: const Text('Vị trí của tôi', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Dùng vị trí gần đúng của điện thoại'),
          trailing: widget.current == 'device' ? const Icon(PhosphorIconsRegular.check) : null,
          onTap: () => Navigator.pop(context, 'device'),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('34 TỈNH, THÀNH PHỐ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ),
        Expanded(
          child: ListView(children: [
            for (final p in list)
              ListTile(
                dense: true,
                leading: const Icon(PhosphorIconsRegular.mapPin, size: 20),
                title: Text(p.name),
                trailing: widget.current == p.id ? const Icon(PhosphorIconsRegular.check) : null,
                onTap: () => Navigator.pop(context, p.id),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Thẻ cảnh báo thời tiết xấu trên trang chủ.
class WeatherAlertCard extends StatelessWidget {
  const WeatherAlertCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (!s.weatherOn || !s.weatherAlertsOn) return const SizedBox.shrink();
    final list = Weather.alerts(s).where((a) => ((a['level'] as num?) ?? 0) >= 2).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final a = list.first;
    final (icon, title, tip, color) = alertLook(a);
    final st = DateTime.fromMillisecondsSinceEpoch((a['start'] as num).toInt());
    final now = DateTime.now();
    final when = st.isBefore(now)
        ? tr('Đang diễn ra')
        : '${tr('Từ')} ${st.hour.toString().padLeft(2, '0')}:00${Weather.sameDayAs(st, now) ? ' ${tr('hôm nay')}' : ' ${st.day}/${st.month}'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: color.withAlpha(26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withAlpha(110))),
        child: ListTile(
          leading: Icon(icon, color: color, size: 30),
          title: Text('${tr(title)} · $when', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          subtitle: Text('${Weather.placeName(s)}. ${tr(tip)}'),
          trailing: const Icon(PhosphorIconsRegular.caretRight),
          onTap: () => openWeather(context),
        ),
      ),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _loading = false;
  String? _err;
  (String, List<String>)? _advice;
  bool _adviceBusy = false;
  String? _adviceErr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(force: false));
  }

  Future<void> _refresh({bool force = true}) async {
    setState(() {
      _loading = true;
      _err = null;
    });
    final e = await Weather.refresh(StoreScope.read(context), force: force, ask: true, context: context);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _err = e;
    });
  }

  Future<void> _ask() async {
    setState(() {
      _adviceBusy = true;
      _adviceErr = null;
    });
    try {
      final a = await Weather.advice(StoreScope.read(context));
      if (mounted) setState(() => _advice = a);
    } catch (e) {
      if (mounted) setState(() => _adviceErr = '$e');
    } finally {
      if (mounted) setState(() => _adviceBusy = false);
    }
  }

  String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:00';
  }

  String _dow(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    if (Weather.sameDayAs(d, now)) return tr('Hôm nay');
    if (Weather.sameDayAs(d, now.add(const Duration(days: 1)))) return tr('Ngày mai');
    const vi = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${tr(vi[d.weekday - 1])} ${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final w = s.weather;
    final c = w?['current'];
    final hourly = ((w?['hourly'] as List?) ?? const []).whereType<Map>().toList();
    final daily = ((w?['daily'] as List?) ?? const []).whereType<Map>().toList();
    final alerts = Weather.alerts(s);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thời tiết'),
        actions: [
          IconButton(
            tooltip: tr('Đổi nơi xem'),
            icon: const Icon(PhosphorIconsRegular.mapPin),
            onPressed: () async {
              await pickWeatherPlace(context);
              if (mounted) setState(() => _advice = null);
            },
          ),
          IconButton(
            tooltip: tr('Cập nhật'),
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            // Hiện tại
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Brand.navy, Color(0xFF2A4A9A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: c is! Map
                  ? Text(_err ?? (_loading ? 'Đang tải dự báo…' : 'Chưa có dữ liệu'), style: const TextStyle(color: Colors.white))
                  : Builder(builder: (_) {
                      final (icon, label) = wxLook('${c['sym']}');
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(PhosphorIconsFill.mapPin, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text(Weather.placeName(s), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text('${c['temp']}°', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1)),
                          const SizedBox(width: 14),
                          Icon(icon, color: Brand.yellow, size: 52),
                          const SizedBox(width: 10),
                          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 16, runSpacing: 6, children: [
                          _mini(PhosphorIconsRegular.drop, '${c['hum']}%'),
                          _mini(PhosphorIconsRegular.wind, '${((c['wind'] as num) * 3.6).round()} km/h'),
                          if (c['pop'] != null) _mini(PhosphorIconsRegular.umbrella, '${(c['pop'] as num).round()}%'),
                        ]),
                      ]);
                    }),
            ),
            if (_err != null && c is Map) ...[
              const SizedBox(height: 8),
              Text(_err!, style: TextStyle(color: cs.error, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            // Cảnh báo
            for (final a in alerts) _alertTile(a),
            // AI gợi ý
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(PhosphorIconsFill.sparkle, color: Brand.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_advice?.$1.isNotEmpty == true ? _advice!.$1 : 'AI gợi ý theo thời tiết',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  ]),
                  const SizedBox(height: 8),
                  if (_advice != null)
                    for (final t in _advice!.$2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('•  ', style: TextStyle(fontWeight: FontWeight.w800)),
                          Expanded(child: Text(t)),
                        ]),
                      )
                  else ...[
                    Text('Nên mang gì, tránh gì, và mẹo giữ ví trong thời tiết này.', style: TextStyle(color: cs.onSurfaceVariant)),
                    if (_adviceErr != null) Text(_adviceErr!, style: TextStyle(color: cs.error, fontSize: 12)),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _adviceBusy || w == null ? null : _ask,
                      icon: _adviceBusy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(PhosphorIconsRegular.sparkle),
                      label: const Text('Hỏi AI nên làm gì'),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // 24 giờ tới
            if (hourly.isNotEmpty) ...[
              Text('24 GIỜ TỚI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: hourly.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final h = hourly[i];
                    final (icon, _) = wxLook('${h['sym']}');
                    final rain = (h['rain'] as num?)?.toDouble() ?? 0;
                    return Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(120), borderRadius: BorderRadius.circular(16)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(i == 0 ? tr('Bây giờ') : _hm((h['t'] as num).toInt()), style: const TextStyle(fontSize: 12)),
                        Icon(icon, size: 24),
                        Text('${h['temp']}°', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(rain > 0 ? '${rain.toStringAsFixed(rain < 1 ? 1 : 0)}mm' : '', style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8))),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 7 ngày
            if (daily.isNotEmpty) ...[
              Text('CÁC NGÀY TỚI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Card(
                child: Column(children: [
                  for (final d in daily)
                    Builder(builder: (_) {
                      final (icon, label) = wxLook('${d['sym']}');
                      final rain = (d['rain'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        dense: true,
                        leading: Icon(icon),
                        title: Text(_dow('${d['date']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(rain >= 1 ? '${tr(label)} · ${rain.round()} mm' : label),
                        trailing: Text('${d['min']}° / ${d['max']}°', style: const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    }),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhắc khi sắp có mưa to, dông, bão'),
              subtitle: const Text('Hiện trên trang chủ và gửi thông báo về điện thoại khoảng 2 giờ trước'),
              value: s.weatherAlertsOn,
              onChanged: (v) {
                s.setWeather(alerts: v);
              },
            ),
            const SizedBox(height: 6),
            Text('Dữ liệu thời tiết: MET Norway (CC BY 4.0). Cảnh báo do VieTing tự tính từ dự báo, chỉ để tham khảo; '
                'khi có bão hãy theo dõi thêm bản tin của Trung tâm Dự báo Khí tượng Thủy văn Quốc gia.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _mini(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]);

  Widget _alertTile(Map<String, dynamic> a) {
    final (icon, title, tip, color) = alertLook(a);
    final st = DateTime.fromMillisecondsSinceEpoch((a['start'] as num).toInt());
    final en = DateTime.fromMillisecondsSinceEpoch((a['end'] as num).toInt());
    String f(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00 ${d.day}/${d.month}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withAlpha(110))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              Text('${f(st)} → ${f(en)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(tip),
            ]),
          ),
        ]),
      ),
    );
  }
}
