// Kiểm tra tài khoản trước khi chuyển tiền: quét QR, chọn ảnh QR hoặc nhập số tài khoản.
// Kết quả chỉ là phản ánh của người dùng đã được kiểm duyệt. Tác giả: Phạm Thành Long (thlong)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/scam.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/vietqr.dart';
import 'login.dart';

bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

String _bankName(String bin) => bin.isEmpty ? tr('Không rõ ngân hàng') : (bankByBin(bin)?.short ?? bin);

Future<void> _openUrl(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);

/// Đòi đăng nhập trước khi gửi báo cáo / khiếu nại / chặn.
bool _needLogin(BuildContext context, AppStore s) {
  if (s.loggedIn) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cần đăng nhập để dùng chức năng này')));
  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return true;
}

class ScamCheckScreen extends StatefulWidget {
  const ScamCheckScreen({super.key});

  @override
  State<ScamCheckScreen> createState() => _ScamCheckScreenState();
}

class _ScamCheckScreenState extends State<ScamCheckScreen> {
  final _acct = TextEditingController();
  String _bin = '';
  String _qrName = '';
  bool _busy = false;
  String? _error;
  ScamResult? _result;

  @override
  void dispose() {
    _acct.dispose();
    super.dispose();
  }

  void _apply(ScannedAccount a) {
    setState(() {
      _acct.text = a.acct;
      _bin = bankByBin(a.bin) != null ? a.bin : '';
      _qrName = a.name;
      _result = null;
      _error = null;
    });
    _check();
  }

  Future<void> _scanCamera() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (raw == null || !mounted) return;
    final a = parseVietQr(raw);
    if (a == null) {
      setState(() => _error = tr('Mã QR này không phải mã chuyển khoản ngân hàng'));
      return;
    }
    _apply(a);
  }

  Future<void> _scanImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctl = MobileScannerController(autoStart: false);
    try {
      final cap = await ctl.analyzeImage(x.path);
      final raw = cap?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
      final a = raw == null ? null : parseVietQr(raw);
      if (!mounted) return;
      if (a == null) {
        setState(() {
          _busy = false;
          _error = tr(raw == null ? 'Không tìm thấy mã QR trong ảnh' : 'Mã QR này không phải mã chuyển khoản ngân hàng');
        });
        return;
      }
      setState(() => _busy = false);
      _apply(a);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = tr('Không đọc được ảnh, thử ảnh rõ hơn');
        });
      }
    } finally {
      ctl.dispose();
    }
  }

  Future<void> _check() async {
    final acct = _acct.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    if (acct.length < 4) {
      setState(() => _error = tr('Nhập số tài khoản cần kiểm tra'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ScamApi.check(StoreScope.read(context), acct, _bin);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra tài khoản'),
        actions: [
          if (s.loggedIn)
            IconButton(
              tooltip: tr('Báo cáo của tôi'),
              icon: const Icon(PhosphorIconsRegular.clipboardText),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyScamReportsScreen())),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text('Kiểm tra xem số tài khoản đã bị người dùng VieTing báo cáo lừa đảo hay chưa, trước khi bạn chuyển tiền.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          if (_mobile) ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _scanCamera,
                  icon: const Icon(PhosphorIconsBold.qrCode),
                  label: const Text('Quét mã QR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _scanImage,
                  icon: const Icon(PhosphorIconsBold.image),
                  label: const Text('Chọn ảnh QR'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('hoặc nhập tay', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
          ],
          _BankPicker(value: _bin, onChanged: (v) => setState(() => _bin = v)),
          const SizedBox(height: 10),
          TextField(
            controller: _acct,
            keyboardType: TextInputType.text,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z ]'))],
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _check(),
            onChanged: (_) {
              if (_qrName.isNotEmpty || _result != null) {
                setState(() {
                  _qrName = '';
                  _result = null;
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Số tài khoản',
              prefixIcon: Icon(PhosphorIconsRegular.hash),
              border: OutlineInputBorder(),
            ),
          ),
          if (_qrName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(PhosphorIconsRegular.userCircle, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text('Tên trong mã QR: $_qrName', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _check,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Kiểm tra'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 18),
            _ResultView(result: _result!, qrName: _qrName, onChanged: _check),
          ],
          const SizedBox(height: 22),
          _ToolLinks(acct: _acct.text, bin: _bin),
        ],
      ),
    );
  }
}

class _BankPicker extends StatelessWidget {
  const _BankPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('bank-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Ngân hàng',
        prefixIcon: Icon(PhosphorIconsRegular.bank),
        border: OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text('Không rõ / mọi ngân hàng')),
        for (final b in kVnBanks) DropdownMenuItem(value: b.bin, child: Text('${b.short} · ${b.name}', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.qrName, required this.onChanged});
  final ScamResult result;
  final String qrName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (result.count == 0) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(PhosphorIconsFill.info, color: cs.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('Chưa có thông tin nào', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 8),
          Text('VieTing chưa có báo cáo nào đã được kiểm duyệt cho số tài khoản ${result.acct}.'),
          const SizedBox(height: 6),
          Text('Chưa có báo cáo không có nghĩa là tài khoản an toàn. Hãy kiểm tra kỹ tên người nhận trong app ngân hàng và tra thêm ở Tín nhiệm mạng bên dưới.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(PhosphorIconsFill.warningOctagon, color: Colors.white, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Cảnh báo: ${result.count} báo cáo lừa đảo',
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Số tài khoản ${result.acct} đã bị ${result.people} người dùng báo cáo, đã được VieTing kiểm duyệt.',
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Đây là phản ánh của người dùng, không phải kết luận của VieTing hay cơ quan chức năng. Hãy xem kỹ bằng chứng bên dưới để tự cân nhắc.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
        ]),
      ),
      if (qrName.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Tên trong mã QR bạn quét: $qrName', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      ],
      const SizedBox(height: 12),
      for (final r in result.reports) _ReportCard(r: r, onChanged: onChanged),
    ]);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.r, required this.onChanged});
  final ScamReport r;
  final VoidCallback onChanged;

  Future<void> _menu(BuildContext context, String v) async {
    final s = StoreScope.read(context);
    if (_needLogin(context, s)) return;
    final msg = ScaffoldMessenger.of(context);
    try {
      if (v == 'flag') {
        final reason = await _ask(context, 'Báo nội dung sai', 'Cho chúng tôi biết vì sao báo cáo này sai hoặc vi phạm (thông tin sai, lộ thông tin cá nhân, xúc phạm…)');
        if (reason == null) return;
        await ScamApi.flag(s, r.id, reason);
        msg.showSnackBar(SnackBar(content: Text('Đã gửi, chúng tôi sẽ xem xét lại báo cáo này')));
      } else if (v == 'block') {
        await ScamApi.block(s, r.id);
        msg.showSnackBar(SnackBar(content: Text('Đã chặn người báo cáo này, bạn sẽ không thấy báo cáo của họ nữa')));
        onChanged();
      }
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _Chip(kScamChannels[r.channel] ?? 'Khác', cs.errorContainer, cs.onErrorContainer),
                _Chip(_bankName(r.bin), cs.surfaceContainerHighest, cs.onSurfaceVariant),
              ]),
            ),
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
              onSelected: (v) => _menu(context, v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'flag', child: Text('Báo nội dung sai / vi phạm')),
                PopupMenuItem(value: 'block', child: Text('Chặn người báo cáo này')),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.holder.isNotEmpty) _Line(PhosphorIconsRegular.userCircle, 'Tên chủ tài khoản theo báo cáo: ${r.holder}'),
              if (r.amount > 0) _Line(PhosphorIconsRegular.money, 'Số tiền bị mất: ${money(r.amount)}'),
              if (r.happened.isNotEmpty) _Line(PhosphorIconsRegular.calendarBlank, 'Ngày xảy ra: ${_fmtDate(r.happened)}'),
              _Line(PhosphorIconsRegular.clock, 'Báo cáo ngày ${dmy(DateTime.fromMillisecondsSinceEpoch(r.at))}'),
              const SizedBox(height: 8),
              Text(r.body, style: const TextStyle(height: 1.4)),
              if (r.photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: r.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _Evidence(id: r.photos[i]),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

String _fmtDate(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : dmy(d);
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

Uint8List? _decode(String b64) {
  try {
    return base64Decode(b64.contains(',') ? b64.split(',').last : b64);
  } catch (_) {
    return null;
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.read(context);
    return FutureBuilder<String>(
      future: ScamApi.photo(s, id),
      builder: (context, snap) {
        final bytes = snap.hasData ? _decode(snap.data!) : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 96,
            height: 96,
            child: bytes == null
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: snap.hasError
                          ? const Icon(PhosphorIconsRegular.imageBroken)
                          : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                : GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _PhotoView(bytes: bytes)),
                    ),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
          ),
        );
      },
    );
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Ảnh bằng chứng')),
        body: InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(bytes))),
      );
}

Future<String?> _ask(BuildContext context, String title, String hint) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Gửi')),
      ],
    ),
  );
  c.dispose();
  return (r == null || r.isEmpty) ? null : r;
}

class _ToolLinks extends StatelessWidget {
  const _ToolLinks({required this.acct, required this.bin});
  final String acct, bin;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    void go(Widget w) {
      if (_needLogin(context, s)) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        onPressed: () => go(ScamReportScreen(acct: acct, bin: bin)),
        icon: const Icon(PhosphorIconsRegular.megaphone),
        label: const Text('Báo cáo tài khoản lừa đảo'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => go(ScamAppealScreen(acct: acct, bin: bin)),
        icon: const Icon(PhosphorIconsRegular.scales),
        label: const Text('Tôi là chủ tài khoản, báo cáo sai'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => _openUrl('https://tinnhiemmang.vn/tra-cuu-tai-khoan'),
        icon: const Icon(PhosphorIconsRegular.arrowSquareOut),
        label: const Text('Tra thêm trên Tín nhiệm mạng (NCSC)'),
      ),
    ]);
  }
}

// ---------------- Quét QR bằng camera ----------------
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _ctl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét mã QR chuyển khoản'),
        actions: [
          IconButton(icon: const Icon(PhosphorIconsRegular.flashlight), onPressed: () => _ctl.toggleTorch()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctl,
          onDetect: (cap) {
            if (_done) return;
            final raw = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (raw == null) return;
            _done = true;
            Navigator.pop(context, raw);
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Text('Đưa mã QR chuyển khoản vào khung',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      ]),
    );
  }
}

// ---------------- Gửi báo cáo ----------------
class ScamReportScreen extends StatefulWidget {
  const ScamReportScreen({super.key, this.acct = '', this.bin = ''});
  final String acct, bin;

  @override
  State<ScamReportScreen> createState() => _ScamReportScreenState();
}

class _ScamReportScreenState extends State<ScamReportScreen> {
  late final _acct = TextEditingController(text: widget.acct);
  final _holder = TextEditingController();
  final _amount = TextEditingController();
  final _body = TextEditingController();
  late String _bin = widget.bin;
  String _channel = 'mua_ban';
  DateTime? _happened;
  final List<Uint8List> _photos = [];
  bool _agree = false;
  bool _busy = false;

  @override
  void dispose() {
    _acct.dispose();
    _holder.dispose();
    _amount.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (x == null) return;
    final b = await x.readAsBytes();
    if (mounted) setState(() => _photos.add(b));
  }

  Future<void> _send() async {
    final s = StoreScope.read(context);
    final msg = ScaffoldMessenger.of(context);
    String? err;
    final acct = _acct.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    if (acct.length < 4) {
      err = 'Nhập số tài khoản bị báo cáo';
    } else if (_body.text.trim().length < 20) {
      err = 'Mô tả sự việc cụ thể hơn (ít nhất 20 ký tự)';
    } else if (_photos.isEmpty) {
      err = 'Cần ít nhất 1 ảnh bằng chứng';
    } else if (!_agree) {
      err = 'Bạn cần đánh dấu cam kết trước khi gửi';
    }
    if (err != null) {
      msg.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ScamApi.report(
        s,
        bin: _bin,
        acct: acct,
        holder: _holder.text.trim(),
        channel: _channel,
        body: _body.text.trim(),
        amount: parseMoneyInput(_amount.text),
        happened: _happened == null ? '' : '${_happened!.year}-${two(_happened!.month)}-${two(_happened!.day)}',
        photos: [for (final p in _photos) base64Encode(p)],
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(PhosphorIconsFill.checkCircle, color: Brand.bamboo, size: 40),
          title: const Text('Đã gửi báo cáo'),
          content: const Text(
              'Báo cáo sẽ hiện cho người khác sau khi được kiểm duyệt. Bạn xem trạng thái trong mục Báo cáo của tôi.\n\nNếu bạn đã bị mất tiền, hãy báo ngay cho ngân hàng và công an nơi gần nhất.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo lừa đảo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: Text(
                'Chỉ báo cáo sự việc có thật bạn trực tiếp gặp. Báo cáo được kiểm duyệt trước khi hiện; tên của bạn không bao giờ được hiện. Báo cáo sai sự thật có thể bị xử lý theo pháp luật.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 14),
          _BankPicker(value: _bin, onChanged: (v) => setState(() => _bin = v)),
          const SizedBox(height: 10),
          TextField(
            controller: _acct,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z ]'))],
            decoration: const InputDecoration(labelText: 'Số tài khoản *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Tên chủ tài khoản (nếu biết)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _channel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Hình thức lừa đảo', border: OutlineInputBorder()),
            items: [for (final e in kScamChannels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _channel = v ?? 'khac'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền bị mất (₫)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _happened ?? DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _happened = d);
                },
                icon: const Icon(PhosphorIconsRegular.calendarBlank),
                label: Text(_happened == null ? 'Ngày xảy ra' : dmy(_happened!)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Mô tả sự việc *',
              hintText: 'Bạn gặp người này ở đâu, họ hứa gì, bạn chuyển bao nhiêu, sau đó chuyện gì xảy ra…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text('Ảnh bằng chứng * (tối đa 5)', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Ảnh chuyển khoản, đoạn chat, bài đăng… Thông tin cá nhân không liên quan sẽ được che trước khi hiện.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_photos[i], width: 90, height: 90, fit: BoxFit.cover)),
                Positioned(
                  right: 2,
                  top: 2,
                  child: InkWell(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            if (_photos.length < 5) ...[
              _AddTile(icon: PhosphorIconsRegular.image, label: 'Thư viện', onTap: () => _addPhoto(ImageSource.gallery)),
              if (_mobile) _AddTile(icon: PhosphorIconsRegular.camera, label: 'Chụp', onTap: () => _addPhoto(ImageSource.camera)),
            ],
          ]),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _agree,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _agree = v ?? false),
            title: Text(
              'Tôi cam kết thông tin và ảnh là thật, không chỉnh sửa, và chịu trách nhiệm trước pháp luật về báo cáo này. Tôi đồng ý Điều khoản dịch vụ của VieTing.',
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openUrl('${s.serverUrl.replaceAll(RegExp(r'/+$'), '')}${isEn ? '/terms' : '/dieu-khoan'}'),
              child: const Text('Đọc Điều khoản dịch vụ'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

// ---------------- Khiếu nại của chủ tài khoản ----------------
class ScamAppealScreen extends StatefulWidget {
  const ScamAppealScreen({super.key, this.acct = '', this.bin = ''});
  final String acct, bin;

  @override
  State<ScamAppealScreen> createState() => _ScamAppealScreenState();
}

class _ScamAppealScreenState extends State<ScamAppealScreen> {
  late final _acct = TextEditingController(text: widget.acct);
  final _contact = TextEditingController();
  final _body = TextEditingController();
  late String _bin = widget.bin;
  bool _busy = false;

  @override
  void dispose() {
    _acct.dispose();
    _contact.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = StoreScope.read(context);
    final msg = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ScamApi.appeal(s, bin: _bin, acct: _acct.text, contact: _contact.text.trim(), body: _body.text.trim());
      msg.showSnackBar(SnackBar(content: Text('Đã gửi khiếu nại, chúng tôi sẽ xem xét và trả lời trong mục Báo cáo của tôi')));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Khiếu nại báo cáo sai')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text('Nếu bạn là chủ tài khoản và cho rằng báo cáo về tài khoản của mình là sai, hãy trình bày ở đây. Chúng tôi có thể liên hệ để xin thêm giấy tờ chứng minh bạn là chủ tài khoản. Khiếu nại hợp lệ sẽ được ẩn báo cáo.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          _BankPicker(value: _bin, onChanged: (v) => setState(() => _bin = v)),
          const SizedBox(height: 10),
          TextField(controller: _acct, decoration: const InputDecoration(labelText: 'Số tài khoản của bạn', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Số điện thoại hoặc email liên hệ', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Vì sao báo cáo là sai', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
  }
}

// ---------------- Báo cáo của tôi ----------------
class MyScamReportsScreen extends StatelessWidget {
  const MyScamReportsScreen({super.key});

  static const _st = {
    'pending': ('Chờ duyệt', Brand.navy),
    'approved': ('Đã duyệt, đang hiện', Brand.bamboo),
    'rejected': ('Không được duyệt', Brand.red),
    'hidden': ('Đã ẩn', Colors.grey),
    'open': ('Đang xem xét', Brand.navy),
    'accepted': ('Đã chấp nhận', Brand.bamboo),
  };

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.read(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo của tôi')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ScamApi.mine(s),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(snap.error.toString().replaceFirst('Exception: ', '')));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final reps = (snap.data!['reports'] as List? ?? const []).cast<Map>();
          final aps = (snap.data!['appeals'] as List? ?? const []).cast<Map>();
          if (reps.isEmpty && aps.isEmpty) return Center(child: Text('Bạn chưa gửi báo cáo hay khiếu nại nào'));
          Widget tile(Map r, {bool appeal = false}) {
            final st = _st['${r['status']}'] ?? ('${r['status']}', Colors.grey);
            final note = '${(appeal ? r['reply'] : r['note']) ?? ''}';
            return Card(
              child: ListTile(
                leading: Icon(appeal ? PhosphorIconsRegular.scales : PhosphorIconsRegular.megaphone),
                title: Text('${_bankName('${r['bin'] ?? ''}')} · ${r['acct']}'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dmy(DateTime.fromMillisecondsSinceEpoch((r['created'] as num).toInt()))),
                  if (note.isNotEmpty) Text(note),
                ]),
                trailing: Text(st.$1, style: TextStyle(color: st.$2, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            );
          }

          return ListView(padding: const EdgeInsets.all(12), children: [
            if (reps.isNotEmpty) Padding(padding: const EdgeInsets.all(6), child: Text('Báo cáo', style: const TextStyle(fontWeight: FontWeight.w800))),
            for (final r in reps) tile(r),
            if (aps.isNotEmpty) Padding(padding: const EdgeInsets.all(6), child: Text('Khiếu nại', style: const TextStyle(fontWeight: FontWeight.w800))),
            for (final a in aps) tile(a, appeal: true),
          ]);
        },
      ),
    );
  }
}
