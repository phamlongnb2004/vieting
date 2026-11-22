import 'dart:convert';

import 'package:http/http.dart' as http;

import '../categories.dart';
import '../models.dart';
import '../parser/quick_add.dart';
import '../store.dart';
import '../util/format.dart';

class AssistantReply {
  final String text;
  final List<Map<String, dynamic>> actions;
  final bool offline;
  const AssistantReply(this.text, this.actions, {this.offline = false});
}

/// Gọi trợ lý AI qua server VieTing (/api/chat). Khóa AI nằm trên server, app chỉ gửi câu hỏi + tóm tắt chi tiêu.
class Assistant {
  static String _d(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
  static String _m(int v) => groupDigits(v);

  /// Tóm tắt dữ liệu chi tiêu gửi kèm câu hỏi (không gửi nội dung thông báo gốc).
  static String buildContext(AppStore s) {
    final now = DateTime.now();
    final cur = s.currentPeriod;
    final prev = DateTime(cur.year, cur.month - 1);
    final b = StringBuffer();
    b.writeln('Tổng số dư các ví: ${_m(s.totalBalance)} đ');
    b.writeln('Ví: ${s.activeWallets.map((w) => '${w.name} ${_m(s.walletBalance(w))} đ').join('; ')}');
    void month(String label, int y, int m) {
      final t = s.monthTotals(y, m);
      final cats = s.expenseByCategory(y, m).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      b.writeln('$label (${s.periodLabel(y, m)}): thu ${_m(t.income)} đ, chi ${_m(t.expense)} đ');
      if (cats.isNotEmpty) {
        b.writeln('  Chi theo danh mục: ${cats.map((e) => '${catById(e.key).name} ${_m(e.value)} đ').join('; ')}');
      }
    }

    month('Kỳ này', cur.year, cur.month);
    b.writeln('  Còn ${s.daysLeftInPeriod}/${s.periodDays(cur.year, cur.month)} ngày của kỳ (kỳ bắt đầu ngày ${s.cycleDay} hằng tháng)');
    month('Kỳ trước', prev.year, prev.month);
    final budgets = s.activeBudgets;
    if (budgets.isNotEmpty) {
      b.writeln('Ngân sách tháng: ${budgets.map((x) {
        final name = x.id == 'all' ? 'Tổng chi' : catById(x.id).name;
        return '$name đã chi ${_m(s.spentFor(x.id, cur.year, cur.month))} / hạn mức ${_m(x.limit)} đ';
      }).join('; ')}');
    } else {
      b.writeln('Chưa đặt ngân sách.');
    }
    final recent = s.activeTxns.take(40).toList();
    b.writeln('${recent.length} giao dịch gần nhất (ngày | số tiền | danh mục | ví | ghi chú):');
    for (final t in recent) {
      if (t.hidden) {
        b.writeln('${_d(t.date)} | ${t.income ? '+' : '-'}${_m(t.amount)} | Khoản riêng tư | - | -');
        continue;
      }
      final note = t.note.length > 50 ? '${t.note.substring(0, 50)}…' : t.note;
      b.writeln('${_d(t.date)} | ${t.income ? '+' : '-'}${_m(t.amount)} | ${catById(t.categoryId).name} | ${s.walletName(t.walletId)} | $note');
    }
    return b.toString();
  }

  static AssistantReply? _offline(String question, AppStore s, {String? why}) {
    final q = QuickAdd.parse(question, s.learnedRules);
    if (q == null) return null;
    final c = catById(q.categoryId);
    return AssistantReply(
      '${why != null ? '$why\n\n' : ''}Mình hiểu là ${q.income ? 'khoản thu' : 'khoản chi'} ${money(q.amount)} (${c.name}). Bấm "Ghi" để thêm nhé.',
      [
        {'type': 'add_txn', 'amount': q.amount, 'income': q.income, 'category': q.categoryId, 'note': q.note, 'date': ''}
      ],
      offline: true,
    );
  }

  static Future<AssistantReply> ask(AppStore s, String question) async {
    final base = s.serverUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      return _offline(question, s, why: 'Chưa nối server trợ lý AI nên mình chỉ ghi nhanh được thôi.') ??
          const AssistantReply(
              'Trợ lý AI chưa sẵn sàng trên bản app này. Trong lúc đó mình vẫn ghi nhanh được câu kiểu "phở 45k".',
              []);
    }
    final history = s.chat
        .where((m) => !m.error)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    if (history.isEmpty || history.last['text'] != question) history.add({'role': 'user', 'text': question});
    try {
      final res = await http
          .post(
            Uri.parse('$base/api/chat'),
            headers: {
              'content-type': 'application/json',
              if (s.token.isNotEmpty) 'authorization': 'Bearer ${s.token}',
            },
            body: jsonEncode({'messages': history, 'context': buildContext(s), 'today': _d(DateTime.now()), 'tone': s.aiTone, 'payday': s.cycleDay > 1 && DateTime.now().difference(s.periodStart(s.currentPeriod.year, s.currentPeriod.month)).inHours < 48}),
          )
          .timeout(const Duration(seconds: 45));
      Map<String, dynamic> body;
      try {
        body = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      } catch (_) {
        body = {'error': 'Server trả về dữ liệu lạ (${res.statusCode})'};
      }
      if (body['quota'] is Map) s.updateChatQuota(Map<String, dynamic>.from(body['quota'] as Map));
      if (res.statusCode != 200) {
        final err = (body['error'] ?? 'Lỗi server (${res.statusCode})').toString();
        return _offline(question, s, why: err) ?? AssistantReply(err, const []);
      }
      final acts = ((body['actions'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((a) => (a['type'] == 'add_txn' && a['amount'] is num) || (a['type'] == 'set_budget' && a['limit'] is num))
          .toList();
      return AssistantReply((body['reply'] ?? '').toString(), acts);
    } catch (_) {
      return _offline(question, s, why: 'Không kết nối được trợ lý AI.') ??
          const AssistantReply('Không kết nối được trợ lý AI. Kiểm tra mạng rồi thử lại nhé.', []);
    }
  }

  /// Câu mô tả một hành động để hiện trên thẻ xác nhận.
  static String describe(Map<String, dynamic> a) {
    if (a['type'] == 'add_txn') {
      final income = a['income'] == true;
      final c = catById((a['category'] ?? '') as String);
      final note = (a['note'] ?? '') as String;
      final date = DateTime.tryParse((a['date'] ?? '') as String);
      final when = date != null ? ' · ${two(date.day)}/${two(date.month)}' : '';
      return '${income ? 'Ghi khoản thu' : 'Ghi khoản chi'} ${money((a['amount'] as num).toInt())} · ${c.name}${note.isNotEmpty ? ' · $note' : ''}$when';
    }
    final id = (a['category'] ?? 'all') as String;
    final name = id == 'all' ? 'tổng chi' : catById(id).name;
    final limit = (a['limit'] as num).toInt();
    return limit <= 0 ? 'Bỏ ngân sách $name' : 'Đặt ngân sách $name ${money(limit)}/tháng';
  }

  static ChatMsg toMsg(AssistantReply r) => ChatMsg(role: 'model', text: r.text, actions: r.actions);
}
