import 'package:flutter/material.dart';

import 'screens/pro_screen.dart';
import 'store.dart';

/// Gói Pro: chức năng nào miễn phí, chức năng nào cần Pro. Tác giả: Phạm Thành Long (thlong)
///
/// Miễn phí mãi: ghi chép (tay, giọng nói, đọc thông báo ngân hàng, dán tin nhắn), ví, ngân sách,
/// Quỹ tiêu thoải mái, widget, nhắc nhở, giờ làm, bảo mật (PIN, vân tay, khoản riêng tư), xuất CSV.
class Pro {
  /// Số lượng được dùng miễn phí.
  static const freeLimits = {
    'bills': 3, // khoản định kỳ
    'goals': 3, // hũ mục tiêu
    'wishes': 3, // món đang chờ mua
    'groups': 1, // sổ chung
  };

  static const reasons = {
    'bills': 'Bản miễn phí được 3 khoản định kỳ',
    'goals': 'Bản miễn phí được 3 hũ mục tiêu',
    'wishes': 'Bản miễn phí được 3 món trong danh sách chờ',
    'groups': 'Bản miễn phí được 1 sổ chung',
    'gifts': 'Sổ hiếu hỉ là tính năng Pro',
    'installment': 'Mô phỏng trả góp là tính năng Pro',
    'simulate': 'Mô phỏng tương lai là tính năng Pro',
    'forecast': 'Dự báo cuối kỳ & đường băng sinh tồn là tính năng Pro',
    'wrapped': 'Xem tổng kết các kỳ cũ là tính năng Pro',
    'tone': 'Các tính cách trợ lý khác là tính năng Pro',
    'ai': 'Bạn đã dùng hết lượt AI miễn phí',
  };

  /// true nếu được dùng; không thì mở màn giới thiệu Pro (người dùng có thể nhập mã ngay tại đó).
  static Future<bool> check(BuildContext context, String feature, {int count = 0}) async {
    final s = StoreScope.read(context);
    if (s.isPro) return true;
    final lim = freeLimits[feature];
    if (lim != null && count < lim) return true;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProScreen(reason: reasons[feature])));
    return context.mounted && StoreScope.read(context).isPro;
  }

  /// Mở màn hình chức năng Pro (hoặc màn giới thiệu Pro nếu chưa có).
  static Future<void> open(BuildContext context, String feature, Widget screen) async {
    if (await check(context, feature) && context.mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }
}
