import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
    final name = TextEditingController(text: 'Quỹ nhà mình');
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

  Future<void> _showQr(Space sp, SpaceEntry e) async {
    final store = StoreScope.read(context);
    await showVietQrSheet(
      context,
      title: 'Chuyển ${compactMoney(e.amount)} cho thủ quỹ ${sp.nameOf(sp.holder)}',
      bin: sp.bankBin,
      acct: sp.bankAcct,
      owner: sp.bankOwner,
      amount: e.amount,
      memo: _memo(sp, e, sp.nameOf(store.myUserId)),
      hint: 'Giữ nguyên nội dung chuyển khoản. Khi tiền về tài khoản thủ quỹ, khoản này chuyển từ "Chờ xác nhận" sang "Đã nhận" '
          '(máy Android của thủ quỹ tự khớp, iPhone thì thủ quỹ bấm xác nhận). Chưa xác nhận thì chưa cộng vào quỹ.',
      primary: 'Đã chuyển xong',
      secondary: 'Đóng',
    );
  }

  /// Chụp / chọn ảnh chứng từ, AI đọc số tiền, so với số đã khai rồi gửi cho cả nhóm xem.
  Future<void> _attachProof(Space sp, SpaceEntry e) async {
    final store = StoreScope.read(context);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(PhosphorIconsRegular.camera),
            title: const Text('Chụp bill / hóa đơn'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.image),
            title: const Text('Chọn ảnh chuyển khoản / hóa đơn'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1100, maxHeight: 1100, imageQuality: 62);
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    await _run(() async {
      final ai = await Spaces.readAmount(store, bytes);
      await Spaces.attachProof(store, sp, e, base64Encode(bytes), ai);
      if (!mounted) return;
      if (ai == null) {
        showToast(context, 'Đã gửi ảnh. AI chưa đọc được số tiền, cả nhóm tự xem ảnh nhé.');
      } else if (e.proofOff) {
        showToast(context, 'AI đọc được ${money(ai)}, lệch với số khai ${money(e.amount)}. Cả nhóm sẽ thấy cờ cảnh báo, sửa lại số nếu bạn nhập nhầm.');
      } else {
        showToast(context, 'AI đọc được ${money(ai)}, khớp số đã khai.');
      }
    });
  }

  Future<void> _addEntry(String type) async {
    final store = StoreScope.read(context);
    final sp = _sp;
    if (sp == null) return;
    final amount = TextEditingController();
    final note = TextEditingController();
    var cat = 'an_uong';
    var ask = false;
    var proof = type == 'spend';
    final wallets = store.activeWallets;
    String? wallet = type == 'contrib' && wallets.isNotEmpty ? wallets.first.id : null;
    final iAmHolder = sp.holder == store.myUserId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final v = parseMoneyInput(amount.text);
          final big = type == 'spend' && sp.approveOver > 0 && v > sp.approveOver && sp.members.length > 1;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type == 'contrib' ? 'Nộp tiền vào quỹ' : 'Chi từ quỹ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (type == 'contrib' && sp.holder != 0 && !iAmHolder)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        sp.hasBank
                            ? 'Bước sau có mã QR chuyển thẳng cho thủ quỹ ${sp.nameOf(sp.holder)}. Tiền về thật mới được cộng vào quỹ.'
                            : 'Thủ quỹ ${sp.nameOf(sp.holder)} cần xác nhận đã nhận thì khoản này mới được cộng vào quỹ.',
                        style: TextStyle(fontSize: 12.5, color: Theme.of(c).colorScheme.onSurfaceVariant)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  autofocus: true,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đính kèm ảnh bill / chuyển khoản'),
                    subtitle: const Text('AI đọc số tiền trên ảnh và so với số bạn khai'),
                    value: proof,
                    onChanged: (v) => setS(() => proof = v),
                  ),
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
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(type == 'contrib' ? 'Nộp quỹ' : (big || ask ? 'Gửi đề xuất chi' : 'Ghi khoản chi')),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    final v = parseMoneyInput(amount.text);
    if (ok != true || v <= 0 || !mounted) return;
    final e = SpaceEntry(
      id: newId(),
      by: store.myUserId,
      type: type,
      amount: v,
      note: note.text.trim(),
      category: type == 'spend' ? cat : '',
      date: DateTime.now(),
      tag: type == 'contrib' && sp.holder != 0 && !iAmHolder ? _tag() : '',
      ask: type == 'spend' && (ask || (sp.approveOver > 0 && v > sp.approveOver)),
    );
    try {
      await Spaces.add(store, sp, e, personalWallet: wallet);
      if (!mounted) return;
      final st = sp.statusOf(e);
      if (st == 'pending' && sp.hasBank) {
        await _showQr(sp, e);
      } else if (st == 'pending') {
        showToast(context, 'Đã ghi ${money(v)}, chờ thủ quỹ ${sp.nameOf(sp.holder)} xác nhận đã nhận.');
      } else if (st == 'await') {
        showToast(context, 'Đã gửi đề xuất chi ${money(v)}. Có người duyệt là trừ vào quỹ.');
      } else {
        final low = type == 'spend' && sp.balance < 0;
        showToast(
            context,
            type == 'contrib'
                ? 'Đã nộp ${money(v)}, cả nhóm thấy ngay. Quỹ giờ có ${money(sp.balance)}'
                : low
                    ? 'Đã ghi. Quỹ đang âm ${money(-sp.balance)}, hú cả nhóm nộp thêm thôi!'
                    : 'Đã ghi chi ${money(v)}. Quỹ còn ${money(sp.balance)}');
      }
      if (proof && mounted) await _attachProof(sp, e);
    } catch (err) {
      if (mounted) showToast(context, 'Đã lưu trên máy, sẽ gửi lên khi có mạng: ${_err(err)}');
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
              const SizedBox(height: 8),
              Text('Đổi thủ quỹ, số tài khoản hay mức duyệt đều được ghi vào nhật ký và báo lên máy cả nhóm.',
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
      () => Spaces.settings(store, sp, holder: holder, bank: bank, clearBank: bank == null, approveOver: parseMoneyInput(approve.text)),
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
                        ? 'Ảnh chứng từ: AI đọc được ${money(e.proofAi!)}, lệch ${money((e.proofAi! - e.amount).abs())} so với số khai.'
                        : 'Ảnh chứng từ: AI đọc được ${money(e.proofAi!)}, khớp số khai.',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _ProofImage(store: store, sp: sp, e: e),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (st == 'pending' && me == sp.holder) ...[
                FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Brand.bamboo),
                    onPressed: () => Navigator.pop(c, 'confirm'),
                    icon: const Icon(PhosphorIconsRegular.check),
                    label: const Text('Đã nhận tiền')),
                OutlinedButton(onPressed: () => Navigator.pop(c, 'reject'), child: const Text('Chưa thấy tiền')),
              ],
              if ((st == 'rejected') && me == sp.holder)
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
        await _showQr(sp, e);
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

  static String _markText(String k) => switch (k) {
        'confirm' => 'đã nhận tiền',
        'reject' => 'chưa nhận được tiền',
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
          if (e.proofOff) const _Pill(text: 'Ảnh lệch số', color: Brand.red),
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
          IconButton(tooltip: 'Mời thành viên', onPressed: _invite, icon: const Icon(PhosphorIconsRegular.userPlus)),
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
