import 'package:flutter_test/flutter_test.dart';
import 'package:vieting/models.dart';

void main() {
  test('Sổ chung: tính ai nợ ai', () {
    final g = Group(id: 'g', name: 'Đà Lạt', members: ['Tôi', 'Lan', 'Minh']);
    g.expenses.add(GroupExpense(id: '1', desc: 'Phòng', amount: 900000, payer: 'Tôi', shares: {'Tôi': 300000, 'Lan': 300000, 'Minh': 300000}, date: DateTime(2026)));
    g.expenses.add(GroupExpense(id: '2', desc: 'Ăn', amount: 300000, payer: 'Lan', shares: {'Tôi': 100000, 'Lan': 100000, 'Minh': 100000}, date: DateTime(2026)));
    final b = g.balances();
    expect(b['Tôi'], 500000);
    expect(b['Lan'], -100000);
    expect(b['Minh'], -400000);
    final s = g.settle();
    expect(s.length, 2);
    expect(s[0].from, 'Minh');
    expect(s[0].to, 'Tôi');
    expect(s[0].amount, 400000);
    expect(s[1].from, 'Lan');
    expect(s[1].amount, 100000);
  });

  test('Mục tiêu: % tiến độ', () {
    final g = Goal(id: 'x', name: 'Laptop', target: 20000000, saved: 5000000);
    expect(g.progress, 0.25);
  });
}
