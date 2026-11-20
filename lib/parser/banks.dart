import '../util/text.dart';

class BankInfo {
  final String id;
  final String name;
  const BankInfo(this.id, this.name);
}

/// Ngân hàng / ví điện tử: tên gói app Android + từ khóa nhận diện (tên app, tên người gửi SMS).
class _Bank {
  final String id;
  final String name;
  final List<String> packages;
  final List<String> keys;
  const _Bank(this.id, this.name, this.packages, this.keys);
}

const List<_Bank> _banks = [
  _Bank('vcb', 'Vietcombank', ['com.VCB'], ['vietcombank', 'vcb']),
  _Bank('mb', 'MB Bank', ['com.mbmobile'], ['mbbank', 'mb bank', 'mbmobile']),
  _Bank('tcb', 'Techcombank', ['vn.com.techcombank.bb.app'], ['techcombank', 'tcb']),
  _Bank('bidv', 'BIDV', ['com.vnpay.bidv'], ['bidv']),
  _Bank('vtb', 'VietinBank', ['com.vietinbank.ipay'], ['vietinbank', 'ipay']),
  _Bank('agri', 'Agribank', ['com.vnpay.Agribank3g'], ['agribank']),
  _Bank('vpb', 'VPBank', ['com.vnpay.vpbankonline', 'com.vpbank.neo'], ['vpbank']),
  _Bank('tpb', 'TPBank', ['com.tpb.mb.gprsandroid'], ['tpbank', 'tpb']),
  _Bank('acb', 'ACB', ['mobile.acb.com.vn'], ['acb']),
  _Bank('stb', 'Sacombank', ['com.sacombank.ewallet'], ['sacombank']),
  _Bank('hdb', 'HDBank', ['com.vnpay.hdbank'], ['hdbank']),
  _Bank('vib', 'VIB', ['com.vib.myvib2'], ['myvib', 'vib']),
  _Bank('shb', 'SHB', ['vn.shb.mbanking'], ['shb']),
  _Bank('ocb', 'OCB', ['vn.com.ocb.awe'], ['ocb']),
  _Bank('msb', 'MSB', ['vn.com.msb.smartBanking'], ['msb']),
  _Bank('seab', 'SeABank', ['vn.com.seabank.mb1'], ['seabank']),
  _Bank('lpb', 'LPBank', ['vn.com.lpb.lienviet24h'], ['lpbank', 'lienvietpostbank']),
  _Bank('eib', 'Eximbank', ['com.vnpay.eximbankomni'], ['eximbank']),
  _Bank('cake', 'Cake', ['xyz.be.cake'], ['cake by vpbank', 'cake']),
  _Bank('timo', 'Timo', ['io.lifestyle.plus'], ['timo']),
  _Bank('momo', 'MoMo', ['com.mservice.momotransfer'], ['momo']),
  _Bank('zalopay', 'ZaloPay', ['vn.com.vng.zalopay'], ['zalopay']),
  _Bank('vtmoney', 'Viettel Money', ['com.bplus.vtpay'], ['viettel money', 'viettelmoney']),
  _Bank('shopeepay', 'ShopeePay', ['com.shopeepay.vn'], ['shopeepay']),
];

/// App tin nhắn SMS: người gửi (tiêu đề thông báo) là tên ngân hàng.
const Set<String> smsPackages = {
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.mms',
  'com.android.messaging',
  'com.oneplus.mms',
  'com.coloros.mms',
  'com.miui.mms',
};

/// App chat / mua sắm: dễ có số tiền trong tin nhắn hoặc quảng cáo, không tự ghi.
const Set<String> ignoredPackages = {
  'com.zing.zalo',
  'com.facebook.orca',
  'com.facebook.katana',
  'com.facebook.mlite',
  'org.telegram.messenger',
  'com.whatsapp',
  'com.viber.voip',
  'com.discord',
  'com.instagram.android',
  'com.google.android.gm',
  'com.ss.android.ugc.trill',
  'com.zhiliaoapp.musically',
  'com.shopee.vn',
  'com.lazada.android',
  'vn.tiki.app.tikiandroid',
  'vn.thlong.vieting',
};

List<String> get supportedBankNames => _banks.map((b) => b.name).toList();

BankInfo? _byKey(String text) {
  final f = ' ${fold(text)} ';
  for (final b in _banks) {
    for (final k in b.keys) {
      if (RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(f)) return BankInfo(b.id, b.name);
    }
  }
  return null;
}

/// Xác định ngân hàng từ gói app, tên app hoặc người gửi SMS.
BankInfo? identifyBank(String package, String appName, String title) {
  for (final b in _banks) {
    if (b.packages.contains(package)) return BankInfo(b.id, b.name);
  }
  if (smsPackages.contains(package)) return _byKey(title);
  return _byKey(package.replaceAll('.', ' ')) ?? _byKey(appName);
}
