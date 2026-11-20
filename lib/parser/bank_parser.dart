import '../util/text.dart';

/// Kết quả đọc một thông báo biến động số dư.
class ParsedTxn {
  final bool income;
  final int amount;
  final int? balance;
  final String note;
  const ParsedTxn({required this.income, required this.amount, this.balance, required this.note});

  int get signed => income ? amount : -amount;

  @override
  String toString() => 'ParsedTxn(${income ? '+' : '-'}$amount, balance: $balance, note: $note)';
}

/// Đọc số tiền +/−, số dư và nội dung từ thông báo của các ngân hàng / ví Việt Nam.
/// Không cần mẫu riêng cho từng ngân hàng: dựa vào dấu +/−, từ khóa "số dư / SD",
/// đơn vị VND/đ và các từ "nhận / thanh toán / ghi có / ghi nợ"...
class BankParser {
  static const _num = r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)';
  static const _cur = r'\s*(?:vnd|d\b|₫|dong\b)';
  static final _sepNum = RegExp(r'^\d{1,3}(?:[.,]\d{3})+');

  static final _balance = RegExp(
      r'(?:so du(?: kha dung| cuoi| hien tai| tk| tai khoan)?|\bsd(?:tk)?\b|balance|\bbal\b)\s*[:=]?\s*' +
          _num +
          r'(' +
          _cur +
          r')?');
  static final _signed = RegExp(r'(?<![\w.,])([+-])\s?' + _num + r'(' + _cur + r')?');
  static final _plain = RegExp(r'(?<![\w.,])' + _num + _cur);

  static final _skip = RegExp(
      r'\botp\b|ma xac thuc|ma xac nhan|mat khau|khuyen mai|uu dai|giam gia|voucher|dang nhap|hoan thanh dang ky');

  static const _incomeWords = [
    'nhan', 'ghi co', 'credit', 'tien vao', 'cong tien', 'duoc cong', 'hoan tien', 'refund', 'received', 'nap tien vao vi'
  ];
  static const _expenseWords = [
    'thanh toan', 'tru tien', 'bi tru', 'da tru', 'ghi no', 'debit', 'chuyen tien', 'chuyen khoan', 'rut tien',
    'tien ra', 'mua ', 'payment', 'chi tieu', 'spent', 'phi '
  ];

  static final _noteRe = RegExp(
      r'(?:\bND|N[ộo]i dung(?: GD| giao dịch)?|Noi dung|N\.dung|M[ôo] t[ảa]|Description|Desc|\bRef)\s*[:.]?\s*([^|\n]+)',
      caseSensitive: false);
  static final _partyRe = RegExp(r'(?:\btừ|\btu|\btới|\btoi|\bđến|\bden|\btại|\btai)\s+([^\n.|,;]{2,60})',
      caseSensitive: false);

  /// Đổi "1.234.567", "200,000.00", "1.000.000,00" -> số nguyên đồng.
  static int toInt(String raw) {
    var s = raw;
    final dec = RegExp(r'^(.*\d)[.,](\d{1,2})$').firstMatch(s);
    if (dec != null) {
      final head = dec.group(1)!;
      if (head.contains(RegExp(r'[.,]')) || dec.group(2)!.length == 2) s = head;
    }
    return int.tryParse(s.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
  }

  static int _firstIndex(String f, List<String> words) {
    var best = -1;
    for (final w in words) {
      final i = f.indexOf(w);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  static ParsedTxn? parse(String text) {
    final f = fold(text);
    if (_skip.hasMatch(f) && !f.contains('so du') && !RegExp(r'\bsd\b').hasMatch(f)) return null;

    // 1) Số dư (lấy ra rồi che đi để không nhầm với số tiền giao dịch)
    int? balance;
    var rest = f;
    for (final m in _balance.allMatches(f)) {
      final raw = m.group(1)!;
      if (m.group(2) == null && !_sepNum.hasMatch(raw)) continue; // có thể là số tài khoản
      balance = toInt(raw);
      rest = f.replaceRange(m.start, m.end, ' ' * (m.end - m.start));
      break;
    }

    // 2) Số tiền có dấu + / −
    bool? income;
    var amount = 0;
    for (final m in _signed.allMatches(rest)) {
      final raw = m.group(2)!;
      if (m.group(3) == null && !_sepNum.hasMatch(raw)) continue;
      final v = toInt(raw);
      if (v <= 0) continue;
      income = m.group(1) == '+';
      amount = v;
      break;
    }

    // 3) Không có dấu: số tiền kèm đơn vị + từ khóa nhận / chi
    if (income == null) {
      final m = _plain.firstMatch(rest);
      if (m == null) return null;
      amount = toInt(m.group(1)!);
      if (amount <= 0) return null;
      final kf = f.replaceAll('xac nhan', '');
      final i = _firstIndex(kf, _incomeWords);
      final e = _firstIndex(kf, _expenseWords);
      if (i < 0 && e < 0) return null;
      if (i >= 0 && (e < 0 || i < e)) {
        income = true;
      } else {
        income = false;
      }
    }

    return ParsedTxn(income: income, amount: amount, balance: balance, note: extractNote(text));
  }

  static String extractNote(String text) {
    final m = _noteRe.firstMatch(text);
    String note;
    if (m != null) {
      note = m.group(1)!;
    } else {
      final p = _partyRe.firstMatch(text);
      if (p != null) {
        note = p.group(0)!;
      } else {
        note = text.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => text);
      }
    }
    note = note.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.;,]+$'), '');
    if (note.length > 140) note = '${note.substring(0, 140)}…';
    return note;
  }
}
