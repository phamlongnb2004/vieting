import 'package:flutter_test/flutter_test.dart';
import 'package:vieting/util/format.dart';
import 'package:vieting/util/text.dart';

void main() {
  test('Định dạng tiền', () {
    expect(money(1234567), '1.234.567 ₫');
    expect(money(-50000), '−50.000 ₫');
    expect(money(50000, signed: true), '+50.000 ₫');
    expect(compactMoney(1250000), '1,25 tr');
    expect(compactMoney(950000), '950k');
    expect(parseMoneyInput('1.250.000'), 1250000);
  });

  test('Bỏ dấu tiếng Việt', () {
    expect(fold('Số dư TK: Đã NHẬN'), 'so du tk: da nhan');
  });
}
