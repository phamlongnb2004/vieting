import 'package:flutter_test/flutter_test.dart';
import 'package:vieting/parser/quick_add.dart';

void main() {
  void check(String s, int amount, bool income) {
    final q = QuickAdd.parse(s, {});
    expect(q, isNotNull, reason: s);
    expect(q!.amount, amount, reason: s);
    expect(q.income, income, reason: s);
  }

  test('Ghi nhanh bằng lời', () {
    check('phở 45k', 45000, false);
    check('ăn phở 45.000', 45000, false);
    check('nhận lương 15tr', 15000000, true);
    check('+1tr2 bán đồ cũ', 1200000, true);
    check('2 ly cafe 60k', 60000, false);
    check('đổ xăng 80 nghìn', 80000, false);
    check('tiền nhà 3,5 triệu', 3500000, false);
    check('1tr25 sửa xe', 1250000, false);
    expect(QuickAdd.parse('tháng này chi bao nhiêu?', {}), isNull);
    expect(QuickAdd.parse('mua 2 cái áo', {}), isNull);
  });

  test('Danh mục đoán theo nội dung', () {
    expect(QuickAdd.parse('highlands 55k', {})!.categoryId, 'an_uong');
    expect(QuickAdd.parse('grab 42k', {})!.categoryId, 'di_lai');
  });
}
