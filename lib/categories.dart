import 'package:flutter/material.dart';

import 'util/text.dart';

class Cat {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool income;
  final List<String> keywords;
  /// Tiền đi qua tay (chi hộ, chuyển giữa ví...): không tính vào thu / chi thật.
  final bool neutral;
  const Cat(this.id, this.name, this.icon, this.color, this.income, this.keywords, {this.neutral = false});
}

const List<Cat> kCategories = [
  // ----- Chi -----
  Cat('an_uong', 'Ăn uống', Icons.restaurant, Color(0xFFE8710A), false, [
    'an uong', 'grabfood', 'grab food', 'shopeefood', 'shopee food', 'baemin', 'highlands', 'starbucks',
    'phuc long', 'the coffee house', 'katinat', 'cong ca phe', 'cafe', 'ca phe', 'coffee', 'tra sua', 'com',
    'pho', 'bun', 'banh mi', 'kfc', 'lotteria', 'jollibee', 'mcdonald', 'pizza', 'nha hang', 'quan an',
    'an trua', 'an sang', 'an toi', 'do an', 'lau', 'tra chanh'
  ]),
  Cat('di_lai', 'Đi lại', Icons.directions_car, Color(0xFF1E88E5), false, [
    'grab', 'be group', 'xanh sm', 'gsm', 'gojek', 'taxi', 'xang', 'petrolimex', 'pvoil', 'vetc', 'epass',
    'gui xe', 've xe', 'vietjet', 'vietnam airlines', 'bamboo airways', 'vexere', 'do xang', 'sua xe'
  ]),
  Cat('mua_sam', 'Mua sắm', Icons.shopping_bag, Color(0xFFD81B60), false, [
    'shopee', 'lazada', 'tiki', 'tiktok shop', 'sendo', 'winmart', 'vinmart', 'bach hoa xanh', 'coopmart',
    'circle k', 'circlek', 'gs25', '7 eleven', '7-eleven', 'familymart', 'aeon', 'lotte mart', 'go mall', 'mua sam',
    'dien may xanh', 'the gioi di dong', 'fpt shop', 'cellphones', 'uniqlo', 'quan ao', 'sieu thi'
  ]),
  Cat('hoa_don', 'Hóa đơn', Icons.receipt_long, Color(0xFF6D4C41), false, [
    'tien dien', 'evn', 'tien nuoc', 'internet', 'cuoc', 'fpt telecom', 'viettel', 'vnpt', 'mobifone',
    'vinaphone', 'nap tien dien thoai', 'topup', 'hoa don', 'truyen hinh', 'wifi'
  ]),
  Cat('nha_o', 'Nhà ở', Icons.home, Color(0xFF8E24AA), false, [
    'tien nha', 'thue nha', 'tien phong', 'tien tro', 'phi quan ly', 'chung cu', 'phong tro'
  ]),
  Cat('giai_tri', 'Giải trí', Icons.movie, Color(0xFF00897B), false, [
    'cgv', 'lotte cinema', 'bhd', 'galaxy cinema', 'netflix', 'spotify', 'youtube', 'steam', 'garena', 'game',
    'apple com', 'google play', 'app store', 'karaoke', 'du lich', 'khach san', 'agoda', 'booking', 'traveloka'
  ]),
  Cat('suc_khoe', 'Sức khỏe', Icons.local_hospital, Color(0xFFE53935), false, [
    'nha thuoc', 'pharmacity', 'long chau', 'an khang', 'benh vien', 'phong kham', 'bao hiem', 'nha khoa',
    'gym', 'fitness', 'thuoc'
  ]),
  Cat('giao_duc', 'Giáo dục', Icons.school, Color(0xFF3949AB), false, [
    'hoc phi', 'khoa hoc', 'mua sach', 'fahasa', 'udemy', 'coursera', 'hoc them'
  ]),
  Cat('gia_dinh', 'Gia đình & quà', Icons.family_restroom, Color(0xFFF4511E), false, [
    'gui me', 'gui bo', 'bieu', 'cho con', 'sinh nhat', 'dam cuoi', 'mung cuoi', 'li xi', 'qua tang'
  ]),
  Cat('chuyen_di', 'Chuyển khoản đi', Icons.send, Color(0xFF546E7A), false, []),
  Cat('chi_ho', 'Chi hộ / ứng trước', Icons.handshake_outlined, Color(0xFF90A4AE), false, ['chi ho', 'ung truoc', 'tra ho', 'mua ho'], neutral: true),
  Cat('chuyen_vi', 'Chuyển sang ví/thẻ khác', Icons.swap_horiz, Color(0xFF90A4AE), false, ['chuyen sang the', 'nap vi', 'chuyen tien sang tai khoan'], neutral: true),
  Cat('khac_chi', 'Chi khác', Icons.more_horiz, Color(0xFF757575), false, []),
  // ----- Thu -----
  Cat('luong', 'Lương', Icons.payments, Color(0xFF2E7D32), true, ['tien luong', 'tra luong', 'luong thang', 'salary', 'payroll']),
  Cat('thuong', 'Thưởng', Icons.card_giftcard, Color(0xFF43A047), true, ['tien thuong', 'thuong tet', 'bonus']),
  Cat('dau_tu', 'Lãi & đầu tư', Icons.trending_up, Color(0xFF00838F), true, [
    'tien lai', 'lai tiet kiem', 'tra lai', 'co tuc', 'interest', 'dividend', 'tat toan'
  ]),
  Cat('nhan_tien', 'Nhận chuyển khoản', Icons.call_received, Color(0xFF388E3C), true, []),
  Cat('khac_thu', 'Thu khác', Icons.attach_money, Color(0xFF7CB342), true, ['hoan tien', 'refund']),
  Cat('thu_ho', 'Nhận lại tiền chi hộ', Icons.handshake, Color(0xFF90A4AE), true, ['tra lai tien', 'hoan ung'], neutral: true),
  Cat('nhan_vi', 'Nhận từ ví/thẻ khác', Icons.swap_horiz, Color(0xFF90A4AE), true, [], neutral: true),
];

Cat catById(String id) =>
    kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.firstWhere((c) => c.id == 'khac_chi'));

List<Cat> catsFor(bool income) => kCategories.where((c) => c.income == income).toList();

final Map<String, List<RegExp>> _kwRe = {
  for (final c in kCategories) c.id: [for (final k in c.keywords) RegExp('\\b${RegExp.escape(k)}\\b')]
};

/// Khóa ghi nhớ: 3 từ đầu của nội dung đã bỏ dấu (bỏ số), dùng để học danh mục người dùng chọn.
String ruleKey(String note) {
  final f = fold(note).replaceAll(RegExp(r'[^a-z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return f.split(' ').where((w) => w.length > 1).take(3).join(' ');
}

/// Đoán danh mục: ưu tiên luật đã học, rồi từ khóa, cuối cùng là mặc định.
String guessCategory(bool income, String text, Map<String, String> learned) {
  final key = ruleKey(text);
  if (key.isNotEmpty && learned.containsKey(key)) {
    final id = learned[key]!;
    if (catById(id).income == income) return id;
  }
  final f = fold(text);
  for (final c in kCategories) {
    if (c.income != income) continue;
    for (final re in _kwRe[c.id]!) {
      if (re.hasMatch(f)) return c.id;
    }
  }
  if (income) return 'nhan_tien';
  if (f.contains('chuyen')) return 'chuyen_di';
  return 'khac_chi';
}


/// Khoản có tính vào thu / chi thật không (loại trừ tiền đi qua tay).
bool countsInTotals(String categoryId) => !catById(categoryId).neutral;

/// Danh mục chi "thiết yếu" dùng để tính "sống được bao lâu".
const Set<String> kEssentialCats = {'an_uong', 'di_lai', 'hoa_don', 'nha_o', 'suc_khoe', 'giao_duc', 'gia_dinh'};
