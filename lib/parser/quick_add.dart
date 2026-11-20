import '../categories.dart';
import '../util/text.dart';

/// Đọc nhanh câu ghi chép kiểu "phở 45k", "nhận lương 15tr", "+1tr2 bán đồ cũ" khi không có AI.
class QuickAdd {
  final int amount;
  final bool income;
  final String note;
  final String categoryId;
  const QuickAdd(this.amount, this.income, this.note, this.categoryId);

  static final _amountRe = RegExp(
      r'([+-])?\s*(\d+(?:[.,]\d+)*)\s*(?:(k|nghin|ngan|trieu|tr|cu|m|ty|ti|dong|vnd|d)(?![a-z]))?\s*(\d{1,3})?(?!\d)');

  static final _incomeWords = RegExp(r'\b(nhan|luong|thuong|duoc cho|duoc tang|ban do|ban hang|thu tien|hoan tien|tien lai)\b');

  /// Trả về null nếu không thấy số tiền hợp lý.
  static QuickAdd? parse(String text, Map<String, String> learned) {
    final f = fold(text);
    for (final m in _amountRe.allMatches(f)) {
      final numStr = m.group(2)!;
      final unit = m.group(3) ?? '';
      final tail = m.group(4);
      double base;
      final cleaned = numStr.replaceAll(RegExp(r'[.,](?=\d{3}\b)'), '');
      base = double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
      int amount;
      switch (unit) {
        case 'k':
        case 'nghin':
        case 'ngan':
          amount = (base * 1000).round();
        case 'tr':
        case 'trieu':
        case 'cu':
        case 'm':
          amount = (base * 1000000).round();
          // "1tr2" = 1.200.000, "1tr25" = 1.250.000
          if (tail != null) amount += (int.parse(tail.padRight(3, '0').substring(0, 3)) * 1000);
        case 'ty':
        case 'ti':
          amount = (base * 1000000000).round();
        default:
          amount = base.round();
      }
      if (amount <= 0) continue;
      if (unit.isEmpty && amount < 1000) continue; // "2 ly", "3 người"... không phải tiền
      final src = f.length == text.length ? text : f;
      final rest = ('${src.substring(0, m.start)} ${src.substring(m.end)}')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final income = m.group(1) == '+' || (m.group(1) != '-' && _incomeWords.hasMatch(f));
      final note = rest.isEmpty ? (income ? 'Khoản thu' : 'Khoản chi') : rest;
      return QuickAdd(amount, income, note, guessCategory(income, note, learned));
    }
    return null;
  }
}
