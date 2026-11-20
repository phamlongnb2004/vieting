import 'package:flutter_test/flutter_test.dart';
import 'package:vieting/categories.dart';
import 'package:vieting/parser/bank_parser.dart';
import 'package:vieting/parser/banks.dart';

void main() {
  void expectTxn(String text, {required bool income, required int amount, int? balance}) {
    final p = BankParser.parse(text);
    expect(p, isNotNull, reason: text);
    expect(p!.income, income, reason: text);
    expect(p.amount, amount, reason: text);
    expect(p.balance, balance, reason: text);
  }

  group('Đọc thông báo ngân hàng', () {
    test('Vietcombank', () {
      expectTxn(
          'Số dư TK VCB 1234567890 -50,000 VND lúc 20-11-2026 15:20:11. Số dư 1,234,567 VND. Ref MBVCB.123.NGUYEN VAN A chuyen tien',
          income: false,
          amount: 50000,
          balance: 1234567);
    });
    test('MB Bank', () {
      expectTxn('TK 03xxx|GD: -50,000VND 20/11/26 15:20 |SD: 1,234,567VND|ND: thanh toan',
          income: false, amount: 50000, balance: 1234567);
    });
    test('Techcombank nhiều dòng', () {
      expectTxn('Tài khoản 1903xxxx\nSố tiền: +5,000,000 VND\nSố dư: 6,000,000 VND\nNội dung: LUONG T11',
          income: true, amount: 5000000, balance: 6000000);
    });
    test('BIDV', () {
      expectTxn('TK1234 tai BIDV +500,000VND vao 15:20 20/11/2026. So du:1,000,000VND. ND: abc',
          income: true, amount: 500000, balance: 1000000);
    });
    test('TPBank', () {
      expectTxn('(TPBank): 20/11/26;15:20 TK: xxxx PS:-50,000VND SD: 1,000,000VND ND: highlands',
          income: false, amount: 50000, balance: 1000000);
    });
    test('VPBank số dư có phần lẻ', () {
      expectTxn('TK 1234 | -1.250.000 VND | 20/11 15:20 | SD 1.000.000,00 VND | ND: tien nha',
          income: false, amount: 1250000, balance: 1000000);
    });
    test('Biến động số dư có .00', () {
      expectTxn('Biến động số dư: TK ...789 +200,000.00 VND lúc 08:00. SD: 2,300,000.00 VND',
          income: true, amount: 200000, balance: 2300000);
    });
    test('MoMo nhận tiền (không có dấu)', () {
      expectTxn('Bạn vừa nhận 50.000đ từ NGUYEN VAN A', income: true, amount: 50000);
    });
    test('Thanh toán không dấu +/-', () {
      expectTxn('Thanh toán thành công 125.000đ tại Circle K', income: false, amount: 125000);
    });
    test('Tiêu đề "số dư" + số tài khoản không bị nhầm là số dư', () {
      expectTxn('Thông báo biến động số dư\nTK 123456789: +50,000 VND. ND: tra tien an', income: true, amount: 50000);
    });
    test('Bỏ qua OTP và quảng cáo', () {
      expect(BankParser.parse('Ma OTP cua ban la 123456'), isNull);
      expect(BankParser.parse('Giam 50% cho don tu 100.000d, khuyen mai hom nay'), isNull);
      expect(BankParser.parse('Hẹn gặp lúc 20-11-2026'), isNull);
    });
    test('Nội dung giao dịch', () {
      final p = BankParser.parse('TK 03xxx|GD: -50,000VND 20/11/26 15:20 |SD: 1,234,567VND|ND: thanh toan HIGHLANDS COFFEE');
      expect(p!.note, 'thanh toan HIGHLANDS COFFEE');
    });
  });

  group('Danh mục', () {
    test('Từ khóa', () {
      expect(guessCategory(false, 'thanh toan HIGHLANDS COFFEE', {}), 'an_uong');
      expect(guessCategory(false, 'GRAB*TRANSPORT', {}), 'di_lai');
      expect(guessCategory(false, 'Thanh toan Shopee', {}), 'mua_sam');
      expect(guessCategory(false, 'NGUYEN VAN A chuyen tien', {}), 'chuyen_di');
      expect(guessCategory(true, 'NGUYEN THI THUONG chuyen tien', {}), 'nhan_tien');
    });
    test('Học từ người dùng', () {
      final key = ruleKey('NGUYEN VAN A chuyen tien 123');
      expect(guessCategory(false, 'NGUYEN VAN A chuyen tien 456', {key: 'nha_o'}), 'nha_o');
    });
  });

  group('Ngân hàng', () {
    test('Nhận diện gói app và SMS', () {
      expect(identifyBank('com.VCB', 'Vietcombank', '')!.id, 'vcb');
      expect(identifyBank('com.google.android.apps.messaging', 'Tin nhắn', 'MBBANK')!.id, 'mb');
      expect(identifyBank('com.example.chat', 'Chat', 'Bạn bè'), isNull);
    });
  });
}
