import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../categories.dart';
import '../models.dart';
import '../services/spaces.dart';
import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';
import '../util/vietqr.dart';
import '../widgets/vicon.dart';
import '../widgets/vietqr_sheet.dart';
import 'login.dart';

/// Quỹ chung: kết nối tài khoản vợ chồng / bạn bè / phòng trọ, cùng nộp quỹ và chi từ quỹ.
class SpacesScreen extends StatefulWidget {
  final bool embedded;
  const SpacesScreen({super.key, this.embedded = false});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final store = StoreScope.read(context);
    if (!store.loggedIn) return;
    setState(() => _loading = true);
    try {
      await Spaces.refreshList(store);
      for (final sp in store.spaces.values.toList()) {
        await Spaces.sync(store, sp);
      }
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: tr('Quỹ nhà mình'));
    final target = TextEditingController();
    final nick = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tạo quỹ chung'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên quỹ (VD: Quỹ nhà mình, Quỹ đi Đà Lạt)')),
            const SizedBox(height: 10),
            TextField(
              controller: target,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(labelText: 'Mục tiêu (không bắt buộc)', suffixText: '₫'),
            ),
            const SizedBox(height: 10),
            TextField(controller: nick, decoration: const InputDecoration(labelText: 'Tên của bạn trong quỹ (VD: Chồng, Long)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final sp = await Spaces.create(store, name.text.trim(), target: parseMoneyInput(target.text), nick: nick.text.trim());
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceDetailScreen(spaceId: sp.id, justCreated: true)));
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _join() async {
    final store = StoreScope.read(context);
    final code = TextEditingController();
    final nick = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vào quỹ bằng mã mời'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(labelText: 'Mã mời 6 ký tự', hintText: 'VD: K7M2QX'),
            ),
            const SizedBox(height: 10),
            TextField(controller: nick, decoration: const InputDecoration(labelText: 'Tên của bạn trong quỹ (VD: Vợ, Lan)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vào quỹ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final sp = await Spaces.join(store, code.text.trim(), nick: nick.text.trim());
      if (!mounted) return;
      showToast(context, 'Đã vào "${sp.name}"');
      Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceDetailScreen(spaceId: sp.id)));
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final list = store.spaces.values.toList();
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Quỹ chung')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Brand.navy, Color(0xFF2A4A9A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(PhosphorIconsFill.handshake, color: Brand.yellow),
                  SizedBox(width: 8),
                  Text('Quỹ chung', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text('Kết nối tài khoản với người thương, bạn cùng phòng hay hội bạn. Ai nộp quỹ, ai chi gì đều hiện ngay trên máy của cả nhóm.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                if (!store.loggedIn)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.navy),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    icon: const Icon(PhosphorIconsRegular.user),
                    label: const Text('Đăng nhập để dùng'),
                  )
                else
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.navy),
                        onPressed: _create,
                        icon: const Icon(PhosphorIconsRegular.plus),
                        label: const Text('Tạo quỹ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                        onPressed: _join,
                        icon: const Icon(PhosphorIconsRegular.key),
                        label: const Text('Nhập mã mời'),
                      ),
                    ),
                  ]),
              ]),
            ),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (store.loggedIn && list.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Chưa có quỹ chung nào. Tạo quỹ rồi gửi mã mời cho người kia, hoặc nhập mã họ gửi cho bạn.',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            for (final sp in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                    leading: const VIcon(PhosphorIconsRegular.piggyBank, color: Brand.navy),
                    title: Text(sp.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${sp.members.length} thành viên · ${sp.members.map((m) => m.name).join(', ')}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(compactMoney(sp.balance),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sp.balance < 0 ? Brand.red : Brand.income)),
                      Text('trong quỹ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceDetailScreen(spaceId: sp.id))),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SpaceDetailScreen extends StatefulWidget {
  final int spaceId;
  final bool justCreated;
  const SpaceDetailScreen({super.key, required this.spaceId, this.justCreated = false});

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  bool _busy = false;
  bool _showRemoved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      if (widget.justCreated) _invite();
    });
  }

  Space? get _sp => StoreScope.read(context).spaces[widget.spaceId];

  String _err(Object e) => '$e'.replaceFirst('Exception: ', '');

  Future<void> _run(Future<void> Function() f, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted && ok != null) showToast(context, ok);
    } catch (e) {
      if (mounted) showToast(context, _err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final sp = _sp;
    if (sp == null) return;
    await _run(() => Spaces.sync(StoreScope.read(context), sp));
  }

  Future<void> _invite() async {
    final sp = _sp;
    if (sp == null) return;
    final msg = 'Vào quỹ chung "${sp.name}" với mình trên VieTing nha! Mở app → Kế hoạch → Quỹ chung → Nhập mã mời: ${sp.code}';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mời vào quỹ'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Gửi mã này cho vợ / chồng / bạn bè. Họ nhập mã trong app VieTing là vào được quỹ.'),
          const SizedBox(height: 16),
          SelectableText(sp.code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6, color: Brand.red)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: sp.code));
              Navigator.pop(c);
              showToast(context, 'Đã chép mã ${sp.code}');
            },
            icon: const Icon(PhosphorIconsRegular.copy),
            label: const Text('Chép mã'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(c);
              Share.share(msg, sharePositionOrigin: shareOrigin(context));
            },
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            label: const Text('Gửi lời mời'),
          ),
        ],
      ),
    );
  }

  static String _tag() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _memo(Space sp, SpaceEntry e, String myName) => 'VT ${sp.code} ${e.tag} ${plainMemo(myName).toUpperCase()}';

  Future<bool?> _showQr(Space sp, SpaceEntry e, {bool again = false}) {
    final store = StoreScope.read(context);
    return showVietQrSheet(
      context,
      title: 'Chuyển ${compactMoney(e.amount)} cho thủ quỹ ${sp.nameOf(sp.holder)}',
      bin: sp.bankBin,
      acct: sp.bankAcct,
      owner: sp.bankOwner,
      amount: e.amount,
      memo: _memo(sp, e, sp.nameOf(store.myUserId)),
      hint: 'Giữ nguyên nội dung chuyển khoản. Chuyển xong chụp màn hình rồi gửi ảnh ở bước sau. Khi tiền về tài khoản thủ quỹ, '
          'khoản này chuyển từ "Chờ xác nhận" sang "Đã nhận" (Android của thủ quỹ tự khớp, iPhone thì thủ quỹ bấm xác nhận).',
      primary: again ? 'Đóng' : 'Đã chuyển, gửi ảnh',
      secondary: again ? 'Đóng' : 'Hủy',
    );
  }

  /// Chọn nguồn ảnh rồi lấy ảnh chứng từ (đã nén cho nhẹ).
  Future<Uint8List?> _pickProof({String title = 'Ảnh chứng từ'}) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(14), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.camera),
            title: const Text('Chụp ảnh (bill, hóa đơn, tiền mặt giao tay)'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.image),
            title: const Text('Chọn ảnh chụp màn hình chuyển khoản'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return null;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1100, maxHeight: 1100, imageQuality: 62);
    if (x == null) return null;
    return x.readAsBytes();
  }

  /// Đổi / thêm ảnh chứng từ cho khoản đã ghi (AI kiểm tra lại từ đầu).
  Future<void> _attachProof(Space sp, SpaceEntry e) async {
    final store = StoreScope.read(context);
    final bytes = await _pickProof();
    if (bytes == null || !mounted) return;
    await _run(() async {
      ProofCheck? chk;
      try {
        chk = await Spaces.verify(store, sp, recId: e.id, bytes: bytes, type: e.type, amount: e.amount, tag: e.tag);
      } catch (_) {}
      final ok = chk?.okFor(e.amount) ?? false;
      e
        ..proofOk = ok
        ..proofWhy = ok ? '' : (chk?.whyFor(e.amount) ?? 'AI chưa kiểm tra được ảnh');
      await Spaces.attachProof(store, sp, e, base64Encode(bytes), chk?.amount);
      if (!mounted) return;
      showToast(context, ok ? 'AI đã kiểm tra: ảnh khớp khoản này.' : 'Ảnh không khớp: ${e.proofWhy}. Khoản này cần người khác duyệt.');
    });
  }

  /// Ảnh không khớp: cho xem lý do, sửa lại hoặc vẫn gửi (khoản sẽ cần người khác duyệt).
  /// retry: true → "Chọn ảnh khác" trả false, "Bỏ" trả null.
  Future<bool?> _confirmBadProof(BuildContext ctx, String why, {bool retry = false}) => showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: const Text('Ảnh chứng từ không khớp'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in why.split('; '))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(PhosphorIconsFill.xCircle, size: 16, color: Brand.red),
                  const SizedBox(width: 6),
                  Expanded(child: Text(w)),
                ]),
              ),
            const SizedBox(height: 8),
            const Text('Vẫn gửi thì khoản này bị gắn cờ, cả nhóm thấy lý do và cần một người khác duyệt mới được tính vào quỹ.',
                style: TextStyle(fontSize: 12.5)),
          ]),
          actions: [
            if (retry) TextButton(onPressed: () => Navigator.pop(d), child: const Text('Bỏ')),
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(retry ? 'Chọn ảnh khác' : 'Sửa lại')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.red), onPressed: () => Navigator.pop(d, true), child: const Text('Vẫn gửi')),
          ],
        ),
      );


  Future<void> _addEntry(String type) async {
    final store = StoreScope.read(context);
    final sp = _sp;
    if (sp == null) return;
    final amount = TextEditingController();
    final note = TextEditingController();
    var cat = 'an_uong';
    var ask = false;
    Uint8List? img;
    ProofCheck? chk;
    String? chkErr;
    var reading = false;
    var open = true;
    final wallets = store.activeWallets;
    String? wallet = type == 'contrib' && wallets.isNotEmpty ? wallets.first.id : null;
    final iAmHolder = sp.holder == store.myUserId;
    // nộp cho thủ quỹ có tài khoản: chuyển khoản bằng mã QR trước, rồi gửi ảnh chuyển khoản
    final qrMode = type == 'contrib' && sp.holder != 0 && !iAmHolder && sp.hasBank;
    final recId = newId();
    final tag = type == 'contrib' && sp.holder != 0 && !iAmHolder ? _tag() : '';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final v = parseMoneyInput(amount.text);
          final big = type == 'spend' && sp.approveOver > 0 && v > sp.approveOver && sp.members.length > 1;
          final cs = Theme.of(c).colorScheme;
          Future<void> pick() async {
            final b = await _pickProof(title: type == 'contrib' ? 'Ảnh chứng từ nộp quỹ' : 'Ảnh bill / chuyển khoản');
            if (b == null || !open) return;
            setS(() {
              img = b;
              chk = null;
              chkErr = null;
              reading = true;
            });
            ProofCheck? r;
            String? err;
            try {
              r = await Spaces.verify(store, sp, recId: recId, bytes: b, type: type, amount: parseMoneyInput(amount.text), tag: tag);
            } catch (e) {
              err = _err(e);
            }
            if (!open) return;
            setS(() {
              reading = false;
              chk = r;
              chkErr = err;
              if (r?.amount != null && parseMoneyInput(amount.text) <= 0) amount.text = groupDigits(r!.amount!);
            });
          }

          final checks = chk?.forAmount(v) ?? const <({String id, bool ok, String text})>[];
          final off = chk != null && !chk!.okFor(v);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type == 'contrib' ? 'Nộp tiền vào quỹ' : 'Chi từ quỹ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      qrMode && sp.linked
                          ? 'Bước sau có mã QR chuyển thẳng vào tài khoản quỹ. Quỹ đã nối ngân hàng: tiền về là ngân hàng tự xác nhận, không cần ảnh.'
                          : qrMode
                          ? 'Bước sau có mã QR chuyển thẳng cho thủ quỹ ${sp.nameOf(sp.holder)}, chuyển xong gửi ảnh chuyển khoản. Tiền về thật mới được cộng vào quỹ.'
                          : type == 'contrib' && sp.holder != 0 && !iAmHolder
                              ? 'Cần ảnh chứng từ, và thủ quỹ ${sp.nameOf(sp.holder)} xác nhận đã nhận thì khoản này mới được cộng vào quỹ.'
                              : 'Mỗi khoản đều cần ảnh chứng từ để cả nhóm cùng xem.',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 12),
                if (!qrMode) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: pick,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: img == null ? Brand.red.withAlpha(120) : Brand.bamboo.withAlpha(140), width: 1.4),
                        color: (img == null ? Brand.red : Brand.bamboo).withAlpha(14),
                      ),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img == null
                              ? Container(
                                  width: 56,
                                  height: 56,
                                  color: Brand.red.withAlpha(25),
                                  child: const Icon(PhosphorIconsRegular.camera, color: Brand.red),
                                )
                              : Image.memory(img!, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(img == null ? 'Thêm ảnh chứng từ (bắt buộc)' : 'Đã có ảnh · chạm để đổi',
                                style: TextStyle(fontWeight: FontWeight.w800, color: img == null ? Brand.red : null)),
                            const SizedBox(height: 2),
                            Text(
                              img == null
                                  ? (type == 'contrib' ? 'Ảnh chuyển khoản, hoặc ảnh lúc giao tiền mặt' : 'Bill, hóa đơn hoặc ảnh chuyển khoản')
                                  : reading
                                      ? 'AI đang kiểm tra ảnh…'
                                      : chk == null
                                          ? 'AI chưa kiểm tra được${chkErr == null ? '' : ' ($chkErr)'}. Gửi vẫn được nhưng cần người khác duyệt'
                                          : off
                                              ? 'Ảnh KHÔNG khớp khoản này'
                                              : 'AI đã kiểm tra: ảnh khớp',
                              style: TextStyle(fontSize: 12.5, color: off ? Brand.red : cs.onSurfaceVariant, fontWeight: off ? FontWeight.w700 : null),
                            ),
                          ]),
                        ),
                        if (reading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ]),
                    ),
                  ),
                  if (checks.isNotEmpty && !reading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final k in checks)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(k.ok ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.xCircle, size: 16, color: k.ok ? Brand.bamboo : Brand.red),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(k.text,
                                      style: TextStyle(fontSize: 12.5, color: k.ok ? null : Brand.red, fontWeight: k.ok ? null : FontWeight.w600))),
                            ]),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: amount,
                  autofocus: qrMode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  onChanged: (_) => setS(() {}),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: type == 'contrib' ? Brand.income : Brand.red),
                  decoration: const InputDecoration(hintText: '0', suffixText: '₫'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: type == 'contrib' ? 'Ghi chú (VD: góp tháng 11)' : 'Chi cho gì (VD: đi chợ, tiền điện)'),
                ),
                if (type == 'spend') ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final x in catsFor(false).where((x) => countsInTotals(x.id)).take(9))
                      ChoiceChip(
                        avatar: Icon(x.icon, size: 16, color: x.color),
                        label: Text(x.name),
                        selected: cat == x.id,
                        onSelected: (_) => setS(() => cat = x.id),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  if (sp.members.length > 1)
                    big
                        ? Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Brand.yellow.withAlpha(45), borderRadius: BorderRadius.circular(12)),
                            child: Text('Khoản trên ${compactMoney(sp.approveOver)}: cần một người khác trong quỹ duyệt mới được trừ vào quỹ.',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          )
                        : SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hỏi ý cả nhóm trước'),
                            subtitle: const Text('Ghi thành đề xuất, có người duyệt mới trừ vào quỹ'),
                            value: ask,
                            onChanged: (v) => setS(() => ask = v),
                          ),
                ],
                if (type == 'contrib' && wallets.isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trừ tiền từ ví của tôi'),
                    subtitle: Text(wallet == null ? 'Không ghi vào sổ cá nhân' : 'Ghi chuyển tiền từ ví "${store.walletName(wallet!)}" (không tính là tiêu)'),
                    value: wallet != null,
                    onChanged: (v) => setS(() => wallet = v ? wallets.first.id : null),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: type == 'contrib' ? Brand.bamboo : Brand.red),
                    onPressed: v > 0 && (qrMode || (img != null && !reading))
                        ? () async {
                            if (!qrMode && (chk == null || off)) {
                              final go = await _confirmBadProof(c, chk?.whyFor(v) ?? 'AI chưa kiểm tra được ảnh');
                              if (go != true || !c.mounted) return;
                            }
                            Navigator.pop(c, true);
                          }
                        : null,
                    child: Text(qrMode
                        ? 'Tiếp: lấy mã QR'
                        : img == null
                            ? 'Cần ảnh chứng từ'
                            : reading
                                ? 'Đang kiểm tra ảnh…'
                                : type == 'contrib'
                                    ? 'Nộp quỹ'
                                    : (big || ask ? 'Gửi đề xuất chi' : 'Ghi khoản chi')),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    open = false;
    final v = parseMoneyInput(amount.text);
    if (ok != true || v <= 0 || !mounted) return;
    final e = SpaceEntry(
      id: recId,
      by: store.myUserId,
      type: type,
      amount: v,
      note: note.text.trim(),
      category: type == 'spend' ? cat : '',
      date: DateTime.now(),
      tag: tag,
      ask: type == 'spend' && (ask || (sp.approveOver > 0 && v > sp.approveOver)),
    );
    if (qrMode) {
      // chuyển khoản trước, rồi bắt buộc gửi ảnh chuyển khoản mới ghi khoản
      final done = await _showQr(sp, e);
      if (!mounted) return;
      if (done != true) {
        showToast(context, 'Chưa ghi khoản nào. Chuyển xong bấm Nộp quỹ lại nhé.');
        return;
      }
      if (sp.linked) {
        // quỹ đã nối ngân hàng: chính ngân hàng là chứng từ, không cần ảnh
        await _run(() => Spaces.add(store, sp, e, personalWallet: wallet),
            ok: 'Đã ghi ${money(v)}. Tiền về tài khoản quỹ là ngân hàng tự xác nhận, cả nhóm được báo.');
        return;
      }
      while (mounted) {
        final b = await _pickProof(title: 'Gửi ảnh chụp màn hình chuyển khoản');
        if (!mounted) return;
        if (b == null) {
          final again = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Chưa có ảnh chuyển khoản'),
              content: const Text('Cần ảnh chụp màn hình chuyển khoản để cả nhóm đối chiếu. Không có ảnh thì khoản này chưa được ghi.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bỏ')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chọn ảnh')),
              ],
            ),
          );
          if (again != true) {
            if (mounted) showToast(context, 'Chưa ghi khoản nào.');
            return;
          }
          continue;
        }
        setState(() => _busy = true);
        try {
          chk = await Spaces.verify(store, sp, recId: recId, bytes: b, type: type, amount: v, tag: tag);
        } catch (_) {
          chk = null;
        }
        if (!mounted) return;
        setState(() => _busy = false);
        if (chk != null && chk!.okFor(v)) {
          img = b;
          break;
        }
        final go = await _confirmBadProof(context, chk?.whyFor(v) ?? 'AI chưa kiểm tra được ảnh', retry: true);
        if (!mounted) return;
        if (go == true) {
          img = b;
          break;
        }
        if (go == null) {
          showToast(context, 'Chưa ghi khoản nào.');
          return;
        }
      }
    }
    if (img == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Spaces.uploadProof(store, sp, e.id, base64Encode(img!));
      final okP = chk?.okFor(v) ?? false;
      e
        ..img = true
        ..proofAi = chk?.amount
        ..proofOk = okP
        ..proofWhy = okP ? '' : (chk?.whyFor(v) ?? 'AI chưa kiểm tra được ảnh');
      await Spaces.add(store, sp, e, personalWallet: wallet);
      if (!mounted) return;
      final st = sp.statusOf(e);
      final proofNote = e.proofOff ? ' Ảnh chứng từ không khớp nên cần người khác duyệt.' : '';
      if (st == 'pending') {
        showToast(context, 'Đã gửi ${money(v)} kèm ảnh, chờ thủ quỹ ${sp.nameOf(sp.holder)} xác nhận đã nhận.$proofNote');
      } else if (st == 'await') {
        showToast(context, 'Đã gửi đề xuất chi ${money(v)} kèm ảnh. Có người duyệt là trừ vào quỹ.$proofNote');
      } else {
        final low = type == 'spend' && sp.balance < 0;
        showToast(
            context,
            (type == 'contrib'
                    ? 'Đã nộp ${money(v)} kèm ảnh. Quỹ giờ có ${money(sp.balance)}'
                    : low
                        ? 'Đã ghi. Quỹ đang âm ${money(-sp.balance)}, hú cả nhóm nộp thêm thôi!'
                        : 'Đã ghi chi ${money(v)} kèm ảnh. Quỹ còn ${money(sp.balance)}') +
                proofNote);
      }
    } catch (err) {
      if (mounted) showToast(context, 'Chưa gửi được (cần mạng để tải ảnh chứng từ): ${_err(err)}');
      sp.entries.remove(e.id);
      store.spacesChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settings(Space sp) async {
    final store = StoreScope.read(context);
    final canEdit = store.myUserId == sp.owner || store.myUserId == sp.holder;
    var holder = sp.holder;
    var bin = sp.bankBin;
    final acct = TextEditingController(text: sp.bankAcct);
    final owner = TextEditingController(text: sp.bankOwner);
    final approve = TextEditingController(text: sp.approveOver > 0 ? groupDigits(sp.approveOver) : '');
    final maxHold = TextEditingController(text: sp.maxHold > 0 ? groupDigits(sp.maxHold) : '');
    var rotate = sp.rotateDays;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tiền quỹ để ở đâu?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  'VieTing không giữ tiền: tiền nằm trong tài khoản của thủ quỹ (hoặc tài khoản chung). '
                  'Chọn thủ quỹ thì mọi khoản nộp phải được thủ quỹ xác nhận đã nhận mới cộng vào quỹ.',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(c).colorScheme.onSurfaceVariant)),
              if (!canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Chỉ người tạo quỹ hoặc thủ quỹ được đổi phần này.', style: TextStyle(color: Brand.red.withAlpha(220))),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: holder,
                decoration: const InputDecoration(labelText: 'Thủ quỹ (người giữ tiền)'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Không có, ai khai nấy chịu')),
                  for (final m in sp.members) DropdownMenuItem(value: m.id, child: Text(m.id == store.myUserId ? '${m.name} (bạn)' : m.name)),
                ],
                onChanged: canEdit ? (v) => setS(() => holder = v ?? 0) : null,
              ),
              if (holder != 0) ...[
                const SizedBox(height: 14),
                const Text('Tài khoản nhận tiền quỹ', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                IgnorePointer(ignoring: !canEdit, child: BankPicker(bin: bin, onChanged: (v) => setS(() => bin = v))),
                const SizedBox(height: 8),
                TextField(controller: acct, enabled: canEdit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tài khoản')),
                const SizedBox(height: 8),
                TextField(
                  controller: owner,
                  enabled: canEdit,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Tên chủ tài khoản (không dấu)'),
                ),
                const SizedBox(height: 4),
                Text('Có tài khoản thì người nộp được mã VietQR chuyển đúng số tiền + nội dung riêng, máy Android của thủ quỹ tự xác nhận khi tiền về.',
                    style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: approve,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(
                    labelText: 'Khoản chi trên mức này cần người khác duyệt', hintText: 'VD: 500.000 · để trống = không cần', suffixText: '₫'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: maxHold,
                enabled: canEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(
                    labelText: 'Trần tiền một người được giữ', hintText: 'VD: 10.000.000 · vượt thì nhắc chia bớt', suffixText: '₫'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: const [0, 30, 60, 90].contains(rotate) ? rotate : 0,
                decoration: const InputDecoration(labelText: 'Nhắc đổi thủ quỹ'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Không nhắc')),
                  DropdownMenuItem(value: 30, child: Text('Mỗi 30 ngày')),
                  DropdownMenuItem(value: 60, child: Text('Mỗi 60 ngày')),
                  DropdownMenuItem(value: 90, child: Text('Mỗi 90 ngày')),
                ],
                onChanged: canEdit ? (v) => setS(() => rotate = v ?? 0) : null,
              ),
              const SizedBox(height: 8),
              Text('Đổi thủ quỹ thì người mới phải xác nhận đã nhận đủ tiền bàn giao. Đổi thủ quỹ, số tài khoản hay mức duyệt đều được ghi vào nhật ký và báo lên máy cả nhóm.',
                  style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              if (canEdit)
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu'))),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final bank = holder != 0 && bin.isNotEmpty && acct.text.trim().isNotEmpty
        ? {'bin': bin, 'name': bankByBin(bin)?.short ?? bin, 'acct': acct.text.trim(), 'owner': plainMemo(owner.text).toUpperCase()}
        : null;
    await _run(
      () => Spaces.settings(store, sp,
          holder: holder,
          bank: bank,
          clearBank: bank == null,
          approveOver: parseMoneyInput(approve.text),
          maxHold: parseMoneyInput(maxHold.text),
          rotateDays: rotate),
      ok: 'Đã lưu, cả nhóm sẽ được báo',
    );
  }

  Future<void> _reconcile(Space sp) async {
    final store = StoreScope.read(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đối chiếu số dư quỹ'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sp.hasBank
              ? 'Mở app ngân hàng xem tài khoản ${sp.bankName} ${sp.bankAcct} đang có bao nhiêu tiền quỹ.'
              : 'Đếm số tiền quỹ đang thật sự có (tài khoản / tiền mặt).'),
          const SizedBox(height: 6),
          Text('Sổ đang ghi ${money(sp.balance)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'Số dư thật', suffixText: '₫'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi cả nhóm')),
        ],
      ),
    );
    if (ok != true || !mounted || c.text.trim().isEmpty) return;
    final actual = parseMoneyInput(c.text);
    final gap = actual - sp.balance;
    await _run(() => Spaces.reconcile(store, sp, actual),
        ok: gap == 0 ? 'Khớp từng đồng! Cả nhóm đã được báo.' : 'Lệch ${money(gap.abs())}. Đã báo cả nhóm để cùng soát lại.');
  }

  Future<void> _openLog(Space sp) async {
    final store = StoreScope.read(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _SpaceLogScreen(store: store, sp: sp)));
  }

  Future<void> _entrySheet(Space sp, SpaceEntry e) async {
    final store = StoreScope.read(context);
    final me = store.myUserId;
    final st = sp.statusOf(e);
    final mine = e.by == me;
    final cs = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${e.type == 'contrib' ? '+' : '−'}${money(e.amount)}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: e.type == 'contrib' ? Brand.income : Brand.red)),
              ),
              _StatusChip(status: st, del: e.del),
            ]),
            Text(
                '${e.type == 'contrib' ? 'Nộp quỹ' : 'Chi'} · ${sp.nameOf(e.by)} · ${dmy(e.date)} ${hm(e.date)}${e.note.isEmpty ? '' : '\n${e.note}'}',
                style: TextStyle(color: cs.onSurfaceVariant)),
            if (e.marks.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final m in e.marks.entries)
                Text('${sp.nameOf(m.key)}: ${_markText(m.value)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (e.hasProof) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: (e.proofOff ? Brand.red : Brand.bamboo).withAlpha(28), borderRadius: BorderRadius.circular(12)),
                child: Text(
                    e.proofOff
                        ? 'Ảnh chứng từ KHÔNG khớp: ${e.proofWhy.isNotEmpty ? e.proofWhy : 'AI đọc được ${money(e.proofAi ?? 0)}, khác số khai'}'
                        : e.proofOk == true
                            ? 'AI đã kiểm tra ảnh chứng từ: đúng loại, đúng số tiền${e.type == 'contrib' && sp.hasBank ? ', đúng người nhận và nội dung' : ''}, chưa dùng cho khoản khác.'
                            : 'Có ảnh chứng từ (chưa được AI kiểm tra).',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _ProofImage(store: store, sp: sp, e: e),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (st == 'pending' && me == sp.holder && !sp.linked) ...[
                FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Brand.bamboo),
                    onPressed: () => Navigator.pop(c, 'confirm'),
                    icon: const Icon(PhosphorIconsRegular.check),
                    label: const Text('Đã nhận tiền')),
                OutlinedButton(onPressed: () => Navigator.pop(c, 'reject'), child: const Text('Chưa thấy tiền')),
              ],
              if ((st == 'rejected') && me == sp.holder && !sp.linked)
                OutlinedButton(onPressed: () => Navigator.pop(c, 'confirm'), child: const Text('Giờ đã nhận được')),
              if ((st == 'await' || st == 'denied' || (st == 'ok' && sp.needsApproval(e))) && !mine) ...[
                if (e.marks[me] != 'approve')
                  FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Brand.bamboo),
                      onPressed: () => Navigator.pop(c, 'approve'),
                      icon: const Icon(PhosphorIconsRegular.thumbsUp),
                      label: const Text('Duyệt')),
                if (e.marks[me] != 'deny') OutlinedButton(onPressed: () => Navigator.pop(c, 'deny'), child: const Text('Không đồng ý')),
              ],
              if (mine && st == 'pending' && sp.hasBank)
                OutlinedButton.icon(onPressed: () => Navigator.pop(c, 'qr'), icon: const Icon(PhosphorIconsRegular.qrCode), label: const Text('Mở lại mã QR')),
              if (mine && !e.del) ...[
                OutlinedButton.icon(
                    onPressed: () => Navigator.pop(c, 'proof'),
                    icon: const Icon(PhosphorIconsRegular.camera),
                    label: Text(e.hasProof ? 'Đổi ảnh chứng từ' : 'Thêm ảnh chứng từ')),
                OutlinedButton.icon(onPressed: () => Navigator.pop(c, 'edit'), icon: const Icon(PhosphorIconsRegular.pencilSimple), label: const Text('Sửa')),
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Brand.red),
                    onPressed: () => Navigator.pop(c, 'del'),
                    icon: const Icon(PhosphorIconsRegular.trash),
                    label: const Text('Xóa')),
              ],
            ]),
            if (mine && !e.del)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Sửa hay xóa đều được ghi vào nhật ký và báo cho cả nhóm. Sửa số tiền thì phải xác nhận / duyệt lại.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
          ]),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'confirm' || 'reject' || 'approve' || 'deny':
        await _run(() => Spaces.mark(store, sp, e, action), ok: 'Đã gửi, người ghi khoản sẽ được báo');
      case 'qr':
        await _showQr(sp, e, again: true);
      case 'proof':
        await _attachProof(sp, e);
      case 'edit':
        final a = TextEditingController(text: groupDigits(e.amount));
        final n = TextEditingController(text: e.note);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sửa khoản'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: a, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(suffixText: '₫')),
              const SizedBox(height: 8),
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Ghi chú')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
            ],
          ),
        );
        final v = parseMoneyInput(a.text);
        if (ok == true && v > 0 && mounted) await _run(() => Spaces.edit(store, sp, e, amount: v, note: n.text.trim()), ok: 'Đã sửa, cả nhóm được báo');
      case 'del':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa khoản này?'),
            content: Text('${money(e.amount)} · ${e.note}\nKhoản bị xóa vẫn hiện mờ trong lịch sử để cả nhóm biết.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
            ],
          ),
        );
        if (ok == true && mounted) await _run(() => Spaces.remove(store, sp, e));
    }
  }

  // ---------------- Chứng minh tiền quỹ có thật ----------------

  String _ago(int ms) {
    final m = ((nowMs() - ms) / 60000).floor();
    if (m < 1) return 'vừa xong';
    if (m < 60) return '$m phút trước';
    if (m < 1440) return '${m ~/ 60} giờ trước';
    return '${m ~/ 1440} ngày trước';
  }

  List<Widget> _trustCards(Space sp, AppStore store, ColorScheme cs) {
    final me = store.myUserId;
    final out = <Widget>[];
    Widget card(Color color, IconData icon, String title, String sub, {List<Widget> actions = const []}) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: color.withAlpha(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VIcon(icon, color: color, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ]),
                if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 6, children: actions)),
              ]),
            ),
          ),
        );

    // 1) Ngân hàng
    if (sp.holder != 0) {
      if (sp.linked && sp.bankError.isNotEmpty) {
        out.add(card(Brand.red, PhosphorIconsFill.warningCircle, 'Mất kết nối ngân hàng', '${sp.bankError}. Số dư quỹ tạm thời không được ngân hàng xác thực.',
            actions: [if (me == sp.holder) OutlinedButton(onPressed: () => _linkBank(sp), child: const Text('Nối lại'))]));
      } else if (sp.linked) {
        final bal = sp.bankBalance;
        final short = bal != null && bal < sp.balance;
        out.add(card(
          short ? Brand.red : Brand.income,
          short ? PhosphorIconsFill.warningCircle : PhosphorIconsFill.shieldCheck,
          bal == null
              ? 'Đã nối ngân hàng, chờ giao dịch đầu tiên'
              : short
                  ? 'Tài khoản quỹ chỉ còn ${money(bal)}, THIẾU ${money(sp.balance - bal)}'
                  : 'Số dư xác thực bởi ngân hàng: ${money(bal)}',
          bal == null
              ? 'Tiền vào / ra tài khoản ${sp.bankName} ${sp.bankAcct} sẽ được ngân hàng báo thẳng về VieTing.'
              : short
                  ? 'Sổ quỹ phải có ${money(sp.balance)} mà tài khoản không đủ: tiền quỹ đã bị chuyển đi. Xem giao dịch ngân hàng để biết chuyển cho ai.'
                  : 'Đủ so với sổ ${money(sp.balance)} · cập nhật ${_ago(sp.bankBalanceAt)}. Tiền ra khỏi tài khoản quỹ báo ngay cho cả nhóm.',
          actions: [
            OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _BankTxnsScreen(store: store, sp: sp))),
                icon: const Icon(PhosphorIconsRegular.bank, size: 16),
                label: const Text('Giao dịch ngân hàng')),
            if (me == sp.holder || me == sp.owner)
              TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Ngắt kết nối ngân hàng?'),
                        content: const Text('Cả nhóm sẽ được báo, và số dư quỹ không còn được ngân hàng xác thực.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Thôi')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ngắt')),
                        ],
                      ),
                    );
                    if (ok == true) await _run(() => Spaces.bankUnlink(store, sp));
                  },
                  child: const Text('Ngắt')),
          ],
        ));
      } else if (me == sp.holder) {
        out.add(card(
          Brand.navy,
          PhosphorIconsRegular.plugsConnected,
          'Nối tài khoản quỹ với ngân hàng',
          'Cách mạnh nhất để cả nhóm tin: tiền vào được ngân hàng tự xác nhận, tiền ra báo ngay cho mọi người, số dư là số thật. Miễn phí qua SePay.',
          actions: [FilledButton(onPressed: sp.hasBank ? () => _linkBank(sp) : () => _settings(sp), child: Text(sp.hasBank ? 'Nối ngân hàng' : 'Nhập tài khoản quỹ trước'))],
        ));
      } else {
        out.add(card(
          const Color(0xFFEF8F00),
          PhosphorIconsRegular.shieldWarning,
          'Số dư chưa được ngân hàng xác thực',
          'Thủ quỹ chưa nối tài khoản với ngân hàng. Bạn có thể yêu cầu thủ quỹ chứng minh số dư ngay bây giờ.',
          actions: [if (!sp.challengeOpen) OutlinedButton(onPressed: () => _startChallenge(sp), child: const Text('Yêu cầu chứng minh số dư'))],
        ));
      }
    }

    // 2) Thử thách số dư
    final c = sp.challenge;
    if (c != null) {
      final by = ((c['by'] as num?) ?? 0).toInt();
      final exp = ((c['exp'] as num?) ?? 0).toInt();
      final at = ((c['at'] as num?) ?? 0).toInt();
      final passed = c['passed'] == true;
      final failed = c['failed'] == true || (!passed && nowMs() > exp);
      final witness = c['witness'] is Map ? Map<String, dynamic>.from(c['witness'] as Map) : null;
      final recent = nowMs() - at < 2 * 86400000;
      if (sp.challengeOpen && me == sp.holder) {
        final left = ((exp - nowMs()) / 60000).ceil();
        out.add(card(Brand.red, PhosphorIconsFill.timer, '${sp.nameOf(by)} yêu cầu bạn chứng minh số dư (còn $left phút)',
            'Chuyển 1.000 ₫ từ tài khoản quỹ với mã ${c['code']}, rồi gọi video mở app ngân hàng cho ${sp.nameOf(by)} xem số dư.',
            actions: [FilledButton(onPressed: () => _answerChallenge(sp), child: const Text('Chuyển 1.000 ₫ (mã QR)'))]));
      } else if (sp.challengeOpen && me == by) {
        out.add(card(const Color(0xFFEF8F00), PhosphorIconsFill.timer, 'Đang chờ thủ quỹ chứng minh (mã ${c['code']})',
            '${Platform.isAndroid ? 'Khi tài khoản của bạn nhận 1.000 ₫ có mã này, VieTing tự xác nhận. ' : ''}Sau đó gọi video, nhờ thủ quỹ mở app ngân hàng và nhập số dư bạn thấy.',
            actions: [
              OutlinedButton(onPressed: () => _run(() => Spaces.challengeDone(store, sp, 'transfer'), ok: 'Đã ghi: thủ quỹ đang giữ đúng tài khoản'), child: const Text('Tôi đã nhận 1.000 ₫ đúng mã')),
              OutlinedButton(onPressed: () => _witness(sp), child: const Text('Nhập số dư đã xem')),
            ]));
      } else if (passed && recent) {
        final how = switch (c['how']) {
          'bank' => 'Ngân hàng xác nhận',
          'auto' => 'Thông báo ngân hàng trên máy ${sp.nameOf(by)} xác nhận',
          _ => '${sp.nameOf(by)} xác nhận',
        };
        final seen = witness == null ? '' : ' · số dư tận mắt xem: ${money(((witness['actual'] as num?) ?? 0).toInt())}';
        out.add(card(Brand.income, PhosphorIconsFill.sealCheck, 'Thủ quỹ đã chứng minh giữ đúng tài khoản quỹ',
            '$how khoản 1.000 ₫ mã ${c['code']}$seen',
            actions: [
              if (me == by && witness == null) OutlinedButton(onPressed: () => _witness(sp), child: const Text('Nhập số dư đã xem')),
            ]));
      } else if (failed && recent) {
        out.add(card(Brand.red, PhosphorIconsFill.xCircle, 'Thủ quỹ KHÔNG chứng minh được số dư', 'Yêu cầu của ${sp.nameOf(by)} (mã ${c['code']}) đã quá 10 phút mà chưa có tiền chuyển đúng mã.',
            actions: [if (me != sp.holder) OutlinedButton(onPressed: () => _startChallenge(sp), child: const Text('Yêu cầu lại'))]));
      }
    }

    // 3) Bàn giao, trần tiền giữ, nhắc đổi thủ quỹ
    final ho = sp.handover;
    if (ho != null) {
      final to = ((ho['to'] as num?) ?? 0).toInt();
      final from = ((ho['from'] as num?) ?? 0).toInt();
      final amt = ((ho['amount'] as num?) ?? 0).toInt();
      out.add(card(const Color(0xFFEF8F00), PhosphorIconsRegular.handshake,
          to == me ? 'Xác nhận nhận bàn giao từ ${sp.nameOf(from)}' : 'Đang bàn giao quỹ: ${sp.nameOf(from)} → ${sp.nameOf(to)}',
          'Số phải bàn giao: ${money(amt)}. Người nhận nhập số tiền thật đã nhận, lệch là cả nhóm thấy ngay.',
          actions: [if (to == me) FilledButton(onPressed: () => _handover(sp, amt), child: const Text('Nhập số đã nhận'))]));
    }
    if (sp.maxHold > 0 && sp.balance > sp.maxHold && sp.holder != 0) {
      out.add(card(const Color(0xFFEF8F00), PhosphorIconsRegular.scales, 'Thủ quỹ đang giữ ${money(sp.balance)}, vượt trần ${money(sp.maxHold)}',
          'Nên chia bớt ${money(sp.balance - sp.maxHold)} cho người thứ hai giữ hoặc gửi tiết kiệm, để không ai giữ quá nhiều một mình.'));
    }
    if (sp.rotateDays > 0 && sp.holder != 0 && sp.holderSince > 0 && nowMs() - sp.holderSince > sp.rotateDays * 86400000) {
      out.add(card(Brand.navy, PhosphorIconsRegular.arrowsClockwise, 'Đến lúc đổi thủ quỹ',
          '${sp.nameOf(sp.holder)} đã giữ quỹ hơn ${sp.rotateDays} ngày. Đổi người trong "Thủ quỹ & tài khoản nhận", người mới xác nhận đã nhận đủ tiền.',
          actions: [if (me == sp.holder || me == sp.owner) OutlinedButton(onPressed: () => _settings(sp), child: const Text('Đổi thủ quỹ'))]));
    }
    return out;
  }

  Future<void> _linkBank(Space sp) async {
    final store = StoreScope.read(context);
    final token = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nối tài khoản quỹ với ngân hàng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tài khoản: ${sp.bankName} ${sp.bankAcct} (${sp.bankOwner})', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final (i, t) in const [
              'Đăng ký miễn phí tại my.sepay.vn và liên kết đúng tài khoản ngân hàng ở trên (làm theo hướng dẫn của SePay, có xác thực OTP).',
              'Trong SePay, vào phần cài đặt công ty → API Keys, tạo một khóa API.',
              'Dán khóa vào ô bên dưới. Khóa chỉ được lưu trên server VieTing để đọc giao dịch, không ai trong nhóm xem được.',
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 11, backgroundColor: Brand.navy, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t)),
                ]),
              ),
            const SizedBox(height: 8),
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Khóa API SePay'), obscureText: true),
            const SizedBox(height: 8),
            Text(
                'Nên dùng một tài khoản (hoặc tài khoản phụ) chỉ để giữ tiền quỹ. Nếu tài khoản có cả tiền riêng, VieTing chỉ cảnh báo khi số dư thấp hơn số quỹ phải có.',
                style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Nối ngân hàng'))),
          ]),
        ),
      ),
    );
    if (ok != true || token.text.trim().isEmpty || !mounted) return;
    await _run(() async {
      final note = await Spaces.bankLink(store, sp, token.text.trim());
      if (mounted) showToast(context, note.isEmpty ? 'Đã nối ngân hàng. Cả nhóm được báo.' : 'Đã nối ngân hàng. $note');
    });
  }

  Future<void> _startChallenge(Space sp) async {
    final store = StoreScope.read(context);
    var bin = '';
    final acct = TextEditingController();
    final owner = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Yêu cầu chứng minh số dư', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Thủ quỹ ${sp.nameOf(sp.holder)} có 10 phút để chuyển 1.000 ₫ từ tài khoản quỹ sang tài khoản của bạn với một mã ngẫu nhiên. '
                  'Thông báo ngân hàng trên máy BẠN là bằng chứng, thủ quỹ không sửa được. Sau đó gọi video để xem số dư thật.',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(c).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              const Text('Tài khoản của bạn (để nhận 1.000 ₫)', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              BankPicker(bin: bin, onChanged: (v) => setS(() => bin = v)),
              const SizedBox(height: 8),
              TextField(controller: acct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tài khoản')),
              const SizedBox(height: 8),
              TextField(controller: owner, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Tên chủ tài khoản')),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gửi yêu cầu (10 phút)'))),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || bin.isEmpty || acct.text.trim().isEmpty || !mounted) return;
    await _run(
        () => Spaces.challenge(store, sp, {'bin': bin, 'name': bankByBin(bin)?.short ?? bin, 'acct': acct.text.trim(), 'owner': plainMemo(owner.text).toUpperCase()}),
        ok: 'Đã gửi. Máy thủ quỹ được báo, còn 10 phút.');
  }

  Future<void> _answerChallenge(Space sp) async {
    final c = sp.challenge;
    if (c == null) return;
    final bk = Map<String, dynamic>.from((c['bank'] as Map?) ?? const {});
    final by = ((c['by'] as num?) ?? 0).toInt();
    await showVietQrSheet(
      context,
      title: 'Chuyển 1.000 ₫ cho ${sp.nameOf(by)} từ TÀI KHOẢN QUỸ',
      bin: '${bk['bin'] ?? ''}',
      acct: '${bk['acct'] ?? ''}',
      owner: '${bk['owner'] ?? ''}',
      amount: 1000,
      memo: 'VT KT ${c['code']}',
      hint: 'Phải chuyển từ tài khoản quỹ ${sp.bankName} ${sp.bankAcct}, giữ nguyên nội dung. Chuyển xong gọi video cho ${sp.nameOf(by)}, mở app ngân hàng cho xem số dư.',
      primary: 'Đã chuyển',
      secondary: 'Đóng',
    );
  }

  Future<void> _witness(Space sp) async {
    final store = StoreScope.read(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Số dư bạn tận mắt thấy'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trong cuộc gọi video, thủ quỹ mở app ngân hàng tài khoản ${sp.bankAcct.isEmpty ? 'quỹ' : sp.bankAcct}. Nhập đúng số dư bạn thấy. Sổ đang ghi ${money(sp.balance)}.'),
          const SizedBox(height: 10),
          TextField(
              controller: c, autofocus: true, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(suffixText: '₫')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Gửi cả nhóm')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty || !mounted) return;
    final v = parseMoneyInput(c.text);
    await _run(() => Spaces.challengeDone(store, sp, 'witness', actual: v),
        ok: v >= sp.balance ? 'Đủ tiền, cả nhóm đã được báo.' : 'Thiếu ${money(sp.balance - v)}. Cả nhóm đã được báo.');
  }

  Future<void> _handover(Space sp, int amount) async {
    final store = StoreScope.read(context);
    final c = TextEditingController(text: groupDigits(amount));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Bạn đã nhận bao nhiêu?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phải bàn giao ${money(amount)}. Kiểm tra tài khoản / tiền mặt rồi nhập số thật đã nhận.'),
          const SizedBox(height: 10),
          TextField(controller: c, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(suffixText: '₫')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => Spaces.handover(store, sp, parseMoneyInput(c.text)), ok: 'Đã xác nhận bàn giao, cả nhóm được báo');
  }

  static String _markText(String k) => switch (k) {
        'confirm' => 'đã nhận tiền',
        'reject' => 'chưa nhận được tiền',
        'bank' => 'ngân hàng xác nhận tiền đã về tài khoản quỹ',
        'sent' => 'máy người nộp báo ngân hàng đã trừ tiền',
        'approve' => 'đồng ý',
        'deny' => 'không đồng ý',
        _ => k,
      };

  Widget _entryTile(Space sp, SpaceEntry e, ColorScheme cs) {
    final st = sp.statusOf(e);
    final dim = e.del || st == 'rejected' || st == 'denied';
    return Opacity(
      opacity: dim ? .5 : 1,
      child: ListTile(
        leading: VIcon(
          e.type == 'contrib' ? PhosphorIconsRegular.arrowDownLeft : (e.category.isEmpty ? PhosphorIconsRegular.arrowUpRight : catById(e.category).icon),
          color: e.type == 'contrib' ? Brand.income : (e.category.isEmpty ? Brand.red : catById(e.category).color),
          size: 38,
        ),
        title: Text(e.note.isEmpty ? (e.type == 'contrib' ? 'Nộp quỹ' : catById(e.category).name) : e.note,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: e.del ? TextDecoration.lineThrough : null)),
        subtitle: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
          Text('${sp.nameOf(e.by)} · ${dmy(e.date)} ${hm(e.date)}'),
          if (e.del || st != 'ok') _StatusChip(status: st, del: e.del, small: true),
          if (e.hasProof && !e.proofOff) const Icon(PhosphorIconsFill.receipt, size: 14, color: Brand.bamboo),
          if (e.proofOff) const _Pill(text: 'Ảnh không khớp', color: Brand.red),
          if (sp.bankConfirmed(e)) const _Pill(text: 'Ngân hàng xác nhận', color: Brand.income),
          if (e.marks[e.by] == 'sent' && !sp.bankConfirmed(e)) const _Pill(text: 'Máy người nộp đã báo trừ tiền', color: Brand.navy),
          if (!e.hasProof && !e.del && !sp.bankConfirmed(e)) const _Pill(text: 'Không có ảnh', color: Color(0xFFEF8F00)),
        ]),
        trailing: Text('${e.type == 'contrib' ? '+' : '−'}${money(e.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                decoration: dim ? TextDecoration.lineThrough : null,
                color: e.type == 'contrib' ? Brand.income : cs.onSurface)),
        onTap: () => _entrySheet(sp, e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final sp = store.spaces[widget.spaceId];
    if (sp == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Quỹ không còn')));
    final per = sp.perMember();
    final n = sp.members.isEmpty ? 1 : sp.members.length;
    final fair = sp.contributed ~/ n;
    final list = sp.active;
    final todo = sp.todoFor(store.myUserId);
    final rc = sp.recon;
    return Scaffold(
      appBar: AppBar(
        title: Text(sp.name),
        actions: [
          IconButton(tooltip: tr('Mời thành viên'), onPressed: _invite, icon: const Icon(PhosphorIconsRegular.userPlus)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'settings') await _settings(sp);
              if (v == 'recon') await _reconcile(sp);
              if (v == 'log') await _openLog(sp);
              if (v == 'rename' && context.mounted) {
                final c = TextEditingController(text: sp.name);
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Đổi tên quỹ'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Lưu')),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty && context.mounted) await _run(() => Spaces.update(store, sp, name: name));
              }
              if (v == 'leave' && context.mounted) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Rời quỹ?'),
                    content: const Text('Bạn sẽ không xem được quỹ này nữa. Người cuối cùng rời đi thì quỹ bị xóa.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rời quỹ')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await Spaces.leave(store, sp);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Thủ quỹ & tài khoản nhận')),
              PopupMenuItem(value: 'recon', child: Text('Đối chiếu số dư thật')),
              PopupMenuItem(value: 'log', child: Text('Nhật ký quỹ')),
              PopupMenuItem(value: 'rename', child: Text('Đổi tên quỹ')),
              PopupMenuItem(value: 'leave', child: Text('Rời quỹ')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(colors: [Brand.navy, Color(0xFF2A4A9A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Đang có trong quỹ', style: TextStyle(color: Colors.white70)),
                Text(money(sp.balance),
                    style: TextStyle(color: sp.balance < 0 ? const Color(0xFFFFB4B4) : Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
                if (sp.pendingIn > 0)
                  Text('+ ${compactMoney(sp.pendingIn)} đang chờ thủ quỹ xác nhận', style: const TextStyle(color: Brand.yellow, fontWeight: FontWeight.w600)),
                if (sp.target > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (sp.balance / sp.target).clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      color: Brand.yellow,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Mục tiêu ${money(sp.target)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
                const SizedBox(height: 12),
                Text('Đã nộp ${compactMoney(sp.contributed)} · đã chi ${compactMoney(sp.spent)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _settings(sp),
                  child: Row(children: [
                    Icon(sp.holder == 0 ? PhosphorIconsRegular.warningCircle : PhosphorIconsFill.shieldCheck,
                        size: 16, color: sp.holder == 0 ? Brand.yellow : const Color(0xFF9BE39F)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sp.holder == 0
                            ? 'Chưa có thủ quỹ: số liệu theo lời khai. Chạm để chọn'
                            : 'Thủ quỹ ${sp.nameOf(sp.holder)}${sp.hasBank ? ' · ${sp.bankName} ${sp.bankAcct}' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Brand.bamboo),
                  onPressed: () => _addEntry('contrib'),
                  icon: const Icon(PhosphorIconsRegular.arrowDownLeft),
                  label: const Text('Nộp quỹ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _addEntry('spend'),
                  icon: const Icon(PhosphorIconsRegular.arrowUpRight),
                  label: const Text('Chi từ quỹ'),
                ),
              ),
            ]),
            ..._trustCards(sp, store, cs),
            if (todo.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                color: Brand.yellow.withAlpha(40),
                child: Column(children: [
                  ListTile(
                    leading: const VIcon(PhosphorIconsFill.bellRinging, color: Brand.navy),
                    title: Text('Cần bạn xử lý (${todo.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Xác nhận tiền đã về hoặc duyệt khoản chi của người khác'),
                  ),
                  for (final e in todo.take(5)) _entryTile(sp, e, cs),
                ]),
              ),
            ],
            if (rc != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: VIcon(rc.actual == rc.book ? PhosphorIconsRegular.sealCheck : PhosphorIconsRegular.scales,
                      color: rc.actual == rc.book ? Brand.income : Brand.red),
                  title: Text(
                      rc.actual == rc.book
                          ? 'Đối chiếu gần nhất: khớp ${money(rc.actual)}'
                          : 'Đối chiếu gần nhất: ${rc.actual > rc.book ? 'dư' : 'thiếu'} ${money((rc.actual - rc.book).abs())}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${sp.nameOf(rc.by)} · ${dmy(DateTime.fromMillisecondsSinceEpoch(rc.at))} · số dư thật ${money(rc.actual)}'),
                  trailing: TextButton(onPressed: () => _reconcile(sp), child: const Text('Đối chiếu')),
                ),
              ),
            ] else if (sp.holder != 0 && sp.holder == store.myUserId && list.length >= 3) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const VIcon(PhosphorIconsRegular.scales, color: Brand.navy),
                  title: const Text('Đối chiếu số dư thật', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Nhập số tiền quỹ đang có trong tài khoản, cả nhóm thấy sổ có khớp không'),
                  onTap: () => _reconcile(sp),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('THÀNH VIÊN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .8, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                for (final m in sp.members)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (m.id == store.myUserId ? Brand.red : Brand.navy).withAlpha(30),
                      child: Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w800, color: m.id == store.myUserId ? Brand.red : Brand.navy)),
                    ),
                    title: Text('${m.id == store.myUserId ? '${m.name} (bạn)' : m.name}${m.id == sp.holder ? ' · thủ quỹ' : ''}'),
                    subtitle: Text('Nộp ${compactMoney(per[m.id]?.contrib ?? 0)} · chi ${compactMoney(per[m.id]?.spent ?? 0)}'),
                    trailing: n > 1 && sp.contributed > 0
                        ? Text(
                            (per[m.id]?.contrib ?? 0) >= fair ? 'Đủ phần' : 'Thiếu ${compactMoney(fair - (per[m.id]?.contrib ?? 0))}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: (per[m.id]?.contrib ?? 0) >= fair ? Brand.income : const Color(0xFFEF8F00)),
                          )
                        : null,
                  ),
                if (sp.members.length < 2)
                  ListTile(
                    leading: const VIcon(PhosphorIconsRegular.userPlus, size: 36),
                    title: const Text('Mời người thứ hai vào quỹ'),
                    subtitle: Text('Mã mời: ${sp.code}'),
                    onTap: _invite,
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Text('LỊCH SỬ QUỸ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .8, color: cs.onSurfaceVariant)),
              ),
              TextButton.icon(
                onPressed: () => _openLog(sp),
                icon: const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 16),
                label: const Text('Nhật ký'),
              ),
            ]),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Chưa có khoản nào. Ai nộp trước người đó là main character!',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            if (list.isNotEmpty)
              Card(child: Column(children: [for (final e in list.take(100)) _entryTile(sp, e, cs)])),
            if (sp.removed.isNotEmpty) ...[
              TextButton(
                onPressed: () => setState(() => _showRemoved = !_showRemoved),
                child: Text(_showRemoved ? 'Ẩn khoản đã xóa' : 'Xem ${sp.removed.length} khoản đã xóa'),
              ),
              if (_showRemoved) Card(child: Column(children: [for (final e in sp.removed.take(50)) _entryTile(sp, e, cs)])),
            ],
            const SizedBox(height: 8),
            Text('Chạm vào một khoản để xem chi tiết, ảnh chứng từ, xác nhận hoặc duyệt. Kéo xuống để cập nhật.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool del;
  final bool small;
  const _StatusChip({required this.status, this.del = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (text, color) = del
        ? ('Đã xóa', const Color(0xFF9E9E9E))
        : switch (status) {
            'pending' => ('Chờ xác nhận', const Color(0xFFEF8F00)),
            'rejected' => ('Chưa nhận được', Brand.red),
            'await' => ('Chờ duyệt', const Color(0xFFEF8F00)),
            'denied' => ('Bị từ chối', Brand.red),
            _ => ('Đã nhận', Brand.income),
          };
    return _Pill(text: text, color: color);
  }
}

class _ProofImage extends StatefulWidget {
  final AppStore store;
  final Space sp;
  final SpaceEntry e;
  const _ProofImage({required this.store, required this.sp, required this.e});

  @override
  State<_ProofImage> createState() => _ProofImageState();
}

class _ProofImageState extends State<_ProofImage> {
  Uint8List? _img;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Spaces.proof(widget.store, widget.sp, widget.e).then((b) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (b != null) {
          try {
            _img = base64Decode(b);
          } catch (_) {}
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2));
    if (_img == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: Image.memory(_img!, fit: BoxFit.contain)),
      ),
    );
  }
}

class _SpaceLogScreen extends StatefulWidget {
  final AppStore store;
  final Space sp;
  const _SpaceLogScreen({required this.store, required this.sp});

  @override
  State<_SpaceLogScreen> createState() => _SpaceLogScreenState();
}

class _SpaceLogScreenState extends State<_SpaceLogScreen> {
  List<({int at, int by, String action, String text})>? _log;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Spaces.log(widget.store, widget.sp);
      if (mounted) setState(() => _log = l);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  static const _warn = {'delete', 'edit', 'flag', 'reject', 'deny', 'settings'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký quỹ')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _log == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: [
                    Text('Mọi lần ghi, sửa, xóa, xác nhận, duyệt và đối chiếu đều nằm ở đây. Không ai xóa được nhật ký.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    for (final l in _log!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: VIcon(
                          switch (l.action) {
                            'contrib' => PhosphorIconsRegular.arrowDownLeft,
                            'spend' => PhosphorIconsRegular.arrowUpRight,
                            'delete' => PhosphorIconsRegular.trash,
                            'edit' => PhosphorIconsRegular.pencilSimple,
                            'confirm' || 'approve' || 'proof' => PhosphorIconsRegular.sealCheck,
                            'recon' => PhosphorIconsRegular.scales,
                            'settings' => PhosphorIconsRegular.gear,
                            _ => PhosphorIconsRegular.info,
                          },
                          color: _warn.contains(l.action) ? Brand.red : Brand.navy,
                          size: 36,
                        ),
                        title: Text(l.text, style: TextStyle(fontWeight: _warn.contains(l.action) ? FontWeight.w700 : FontWeight.w500)),
                        subtitle: Text(() {
                          final d = DateTime.fromMillisecondsSinceEpoch(l.at);
                          return '${dmy(d)} ${hm(d)}';
                        }()),
                      ),
                  ],
                ),
    );
  }
}

class _BankTxnsScreen extends StatefulWidget {
  final AppStore store;
  final Space sp;
  const _BankTxnsScreen({required this.store, required this.sp});

  @override
  State<_BankTxnsScreen> createState() => _BankTxnsScreenState();
}

class _BankTxnsScreenState extends State<_BankTxnsScreen> {
  List<({String dir, int amount, String content, int? balance, int at, String rec})>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Spaces.bankTxns(widget.store, widget.sp);
      if (mounted) setState(() => _list = l);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sp = widget.sp;
    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch ngân hàng')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                    Text('Đọc thẳng từ ngân hàng (qua SePay) cho tài khoản ${sp.bankName} ${sp.bankAcct}. Không ai trong nhóm sửa được.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    if (_list!.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Chưa có giao dịch nào', textAlign: TextAlign.center)),
                    for (final t in _list!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: VIcon(t.dir == 'in' ? PhosphorIconsRegular.arrowDownLeft : PhosphorIconsRegular.arrowUpRight,
                            color: t.dir == 'in' ? Brand.income : Brand.red, size: 36),
                        title: Text(t.content.isEmpty ? (t.dir == 'in' ? 'Tiền vào' : 'Tiền ra') : t.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          () {
                            final d = DateTime.fromMillisecondsSinceEpoch(t.at);
                            return '${dmy(d)} ${hm(d)}';
                          }(),
                          if (t.balance != null) 'số dư ${compactMoney(t.balance!)}',
                          if (t.rec.isNotEmpty) 'khớp khoản nộp ${sp.nameOf(sp.entries[t.rec]?.by ?? -1)}',
                        ].join(' · ')),
                        trailing: Text('${t.dir == 'in' ? '+' : '−'}${money(t.amount)}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: t.dir == 'in' ? Brand.income : Brand.red)),
                      ),
                  ]),
                ),
    );
  }
}
