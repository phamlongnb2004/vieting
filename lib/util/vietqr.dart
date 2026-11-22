/// Tạo mã VietQR (chuẩn EMVCo / NAPAS 247) để chuyển khoản đúng số tiền + nội dung.
/// Mọi app ngân hàng Việt Nam quét được. Tác giả: Phạm Thành Long (thlong).
library;

class VnBank {
  final String bin;
  final String short;
  final String name;
  const VnBank(this.bin, this.short, this.name);
}

/// Mã BIN (NAPAS) của các ngân hàng phổ biến.
const kVnBanks = [
  VnBank('970436', 'Vietcombank', 'Ngoại thương Việt Nam'),
  VnBank('970415', 'VietinBank', 'Công thương Việt Nam'),
  VnBank('970418', 'BIDV', 'Đầu tư và Phát triển'),
  VnBank('970405', 'Agribank', 'Nông nghiệp và PTNT'),
  VnBank('970407', 'Techcombank', 'Kỹ thương Việt Nam'),
  VnBank('970422', 'MB', 'Quân đội'),
  VnBank('970416', 'ACB', 'Á Châu'),
  VnBank('970432', 'VPBank', 'Việt Nam Thịnh Vượng'),
  VnBank('970423', 'TPBank', 'Tiên Phong'),
  VnBank('970403', 'Sacombank', 'Sài Gòn Thương Tín'),
  VnBank('970441', 'VIB', 'Quốc tế'),
  VnBank('970437', 'HDBank', 'Phát triển TP.HCM'),
  VnBank('970443', 'SHB', 'Sài Gòn - Hà Nội'),
  VnBank('970448', 'OCB', 'Phương Đông'),
  VnBank('970426', 'MSB', 'Hàng Hải'),
  VnBank('970440', 'SeABank', 'Đông Nam Á'),
  VnBank('970449', 'LPBank', 'Lộc Phát'),
  VnBank('970431', 'Eximbank', 'Xuất Nhập khẩu'),
  VnBank('970429', 'SCB', 'Sài Gòn'),
  VnBank('970454', 'BVBank', 'Bản Việt (Timo)'),
  VnBank('970428', 'Nam A Bank', 'Nam Á'),
  VnBank('970409', 'Bac A Bank', 'Bắc Á'),
  VnBank('970425', 'ABBANK', 'An Bình'),
  VnBank('970427', 'VietABank', 'Việt Á'),
  VnBank('970412', 'PVcomBank', 'Đại Chúng'),
  VnBank('970400', 'Saigonbank', 'Sài Gòn Công Thương'),
  VnBank('546034', 'Cake', 'Cake by VPBank'),
  VnBank('546035', 'Ubank', 'Ubank by VPBank'),
];

VnBank? bankByBin(String bin) {
  for (final b in kVnBanks) {
    if (b.bin == bin) return b;
  }
  return null;
}

String _tlv(String id, String v) => '$id${v.length.toString().padLeft(2, '0')}$v';

int _crc16(String s) {
  var crc = 0xFFFF;
  for (final c in s.codeUnits) {
    crc ^= (c & 0xFF) << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

/// Bỏ dấu và ký tự lạ: nội dung chuyển khoản liên ngân hàng chỉ nhận chữ không dấu.
String plainMemo(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final lo = ch.toLowerCase();
    final i = from.indexOf(lo);
    var out = i >= 0 ? to[i] : ch;
    if (i >= 0 && ch != lo) out = out.toUpperCase();
    if (RegExp(r'[A-Za-z0-9 ]').hasMatch(out)) b.write(out);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Chuỗi dữ liệu mã VietQR chuyển tới [acct] tại ngân hàng [bin], kèm số tiền và nội dung.
String vietQrPayload({required String bin, required String acct, int amount = 0, String memo = ''}) {
  final account = _tlv('00', bin) + _tlv('01', acct.replaceAll(RegExp(r'\s+'), ''));
  final merchant = _tlv('00', 'A000000727') + _tlv('01', account) + _tlv('02', 'QRIBFTTA');
  final m = plainMemo(memo);
  var p = _tlv('00', '01') +
      _tlv('01', amount > 0 ? '12' : '11') +
      _tlv('38', merchant) +
      _tlv('53', '704') +
      (amount > 0 ? _tlv('54', '$amount') : '') +
      _tlv('58', 'VN') +
      (m.isEmpty ? '' : _tlv('62', _tlv('08', m.length > 50 ? m.substring(0, 50) : m)));
  p += '6304';
  return p + _crc16(p).toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Tìm mã "VT <mã quỹ 6 ký tự> <mã khoản 4 ký tự>" trong nội dung thông báo ngân hàng.
({String a, String b})? findVtMemo(String text, {String prefix = ''}) {
  final f = plainMemo(text).toUpperCase();
  final re = RegExp(prefix.isEmpty ? r'VT\s*([A-Z0-9]{6})\s*([A-Z0-9]{4})' : r'VT\s*' + prefix + r'\s*([A-Z0-9]{4})()');
  final m = re.firstMatch(f);
  if (m == null) return null;
  return (a: m.group(1)!, b: m.group(2) ?? '');
}
