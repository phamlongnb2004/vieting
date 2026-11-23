import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../store.dart';
import '../theme.dart';
import '../ui_keys.dart';
import '../util/format.dart';

const kFeatures = {
  'doc_thong_bao': 'Đọc thông báo ngân hàng',
  'giong_noi': 'Nhập bằng giọng nói',
  'hoa_don': 'Chụp hóa đơn',
  'tro_ly': 'Trợ lý AI',
  'dong_bo': 'Đồng bộ / đăng nhập',
  'so_chung': 'Sổ chung / ví nhóm',
  'ngan_sach': 'Ngân sách & mục tiêu',
  'giao_dien': 'Giao diện',
  'thanh_toan': 'Gói Pro / thanh toán',
  'khac': 'Khác / góp ý chung',
};

const _status = {
  'open': ('Đã nhận', Color(0xFF8A8A8A)),
  'doing': ('Đang xử lý', Brand.navy),
  'fixed': ('Đã sửa', Brand.bamboo),
  'closed': ('Đã đóng', Color(0xFF8A8A8A)),
};

/// Góp ý & báo lỗi: gửi theo tính năng, xem phản hồi của đội VieTing.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _body = TextEditingController();
  final _contact = TextEditingController();
  String _feature = 'khac';
  bool _sending = false;
  List<Map<String, dynamic>>? _mine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _body.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await StoreScope.read(context).myTickets();
      if (mounted) setState(() => _mine = t);
    } catch (_) {
      if (mounted) setState(() => _mine = []);
    }
  }

  Future<void> _send() async {
    final store = StoreScope.read(context);
    if (_body.text.trim().length < 5) {
      showToast(context, 'Viết thêm chút nội dung nhé');
      return;
    }
    setState(() => _sending = true);
    try {
      final platform = kIsWeb ? 'web' : Platform.operatingSystem;
      await store.sendTicket(_feature, _body.text.trim(), contact: _contact.text.trim(), app: 'VieTing 0.1 · $platform');
      _body.clear();
      if (!mounted) return;
      showToast(context, store.loggedIn ? 'Đã gửi! Phản hồi sẽ hiện ở đây và báo lên máy bạn.' : 'Đã gửi, cảm ơn bạn!');
      _load();
    } catch (e) {
      if (mounted) showToast(context, 'Chưa gửi được: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Góp ý & báo lỗi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _feature,
            decoration: const InputDecoration(labelText: 'Tính năng'),
            items: [for (final e in kFeatures.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _feature = v ?? _feature),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'Bạn gặp lỗi gì / muốn góp ý gì?',
              hintText: 'VD: Đọc giọng nói "năm mươi nghìn" thành 15.000đ',
              alignLabelWithHint: true,
            ),
          ),
          if (!store.loggedIn)
            TextField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Liên hệ (email / Zalo, không bắt buộc)',
                helperText: 'Đăng nhập để xem phản hồi ngay trong app',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(PhosphorIconsRegular.paperPlaneRight),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Gửi')),
          ),
          if (store.loggedIn) ...[
            const SizedBox(height: 24),
            Text('Đã gửi', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            const SizedBox(height: 6),
            if (_mine == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (_mine!.isEmpty)
              Text('Chưa có góp ý nào.', style: TextStyle(color: cs.onSurfaceVariant))
            else
              for (final t in _mine!)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(kFeatures[t['feature']] ?? '${t['feature']}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_status[t['status']]?.$2 ?? Brand.navy).withAlpha(30),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(_status[t['status']]?.$1 ?? '${t['status']}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _status[t['status']]?.$2)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('${t['body']}'),
                      Text(dmy(DateTime.fromMillisecondsSinceEpoch(((t['created'] as num?) ?? 0).toInt())),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      if ('${t['reply'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Brand.bamboo.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                          child: Text('VieTing: ${t['reply']}'),
                        ),
                      ],
                    ]),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
