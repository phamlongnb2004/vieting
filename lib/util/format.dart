import 'package:flutter/services.dart';

String groupDigits(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// 1234567 -> "1.234.567 ₫"
String money(int v, {bool signed = false}) {
  final sign = v < 0 ? '−' : (signed && v > 0 ? '+' : '');
  return '$sign${groupDigits(v)} ₫';
}

/// 1250000 -> "1,25 tr"
String compactMoney(int v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  String trim(double x) {
    var s = x.toStringAsFixed(x >= 100 ? 0 : (x >= 10 ? 1 : 2));
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  if (a >= 1000000000) return '$sign${trim(a / 1e9)} tỷ';
  if (a >= 1000000) return '$sign${trim(a / 1e6)} tr';
  if (a >= 1000) return '$sign${trim(a / 1e3)}k';
  return '$sign$a';
}

String two(int n) => n.toString().padLeft(2, '0');

const weekdayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

String dmy(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return 'Hôm nay';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
  return '${weekdayNames[d.weekday - 1]}, ${dmy(d)}';
}

String monthLabel(int year, int month) => 'Tháng $month/$year';

/// Ô nhập tiền: chỉ nhận số, tự thêm dấu chấm ngăn cách hàng nghìn.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;
    final text = groupDigits(int.parse(trimmed));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

int parseMoneyInput(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? 0 : int.parse(d);
}
