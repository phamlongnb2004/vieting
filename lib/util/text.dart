// Bỏ dấu tiếng Việt + chữ thường để so khớp từ khóa trong thông báo ngân hàng.

const Map<String, String> _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _map = () {
  final m = <int, String>{};
  _groups.forEach((base, chars) {
    for (final r in chars.runes) {
      m[r] = base;
    }
  });
  return m;
}();

/// "Số dư TK" -> "so du tk"
String fold(String input) {
  final lower = input.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    if (r >= 0x0300 && r <= 0x036F) continue; // dấu dạng tổ hợp (NFD)
    final mapped = _map[r];
    if (mapped != null) {
      b.write(mapped);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}
