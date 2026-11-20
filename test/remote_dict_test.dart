import 'package:flutter_test/flutter_test.dart';
import 'package:vieting/categories.dart';

void main() {
  test('Từ điển admin cập nhật được dùng để đoán danh mục', () {
    setRemoteDict([('đổ xăng A95', 'di_lai'), ('tóp tóp', 'mua_sam'), ('x', 'an_uong'), ('abc', 'khong_co')]);
    expect(remoteDict.length, 2);
    expect(guessCategory(false, 'Đổ xăng a95 Petrolimex', {}), 'di_lai');
    expect(guessCategory(false, 'chốt đơn TÓP TÓP', {}), 'mua_sam');
    setRemoteDict([]);
  });
}
