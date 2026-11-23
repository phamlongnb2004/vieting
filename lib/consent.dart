import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'store.dart';
import 'theme.dart';
import 'ui_keys.dart';

/// Công bố rõ ràng + xin đồng ý trước khi truy cập / gửi dữ liệu nhạy cảm (chính sách Dữ liệu người dùng của Google Play).
/// Người dùng phải bấm "Đồng ý"; đóng hộp thoại hay bấm quay lại đều tính là KHÔNG đồng ý.
/// Tác giả: Phạm Thành Long (thlong)
class Consent {
  static String get privacyUrl => '${kServerUrl.replaceAll(RegExp(r'/+$'), '')}/chinh-sach-rieng-tu';
  static String get deleteUrl => '${kServerUrl.replaceAll(RegExp(r'/+$'), '')}/xoa-tai-khoan';

  static Future<void> openPrivacy() => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication);
  static Future<void> openDelete() => launchUrl(Uri.parse(deleteUrl), mode: LaunchMode.externalApplication);

  static const _texts = {
    'notify': (
      'Cho phép đọc thông báo ngân hàng?',
      'VieTing đọc thông báo trên điện thoại của bạn, kể cả khi app đang đóng, để tự ghi giao dịch từ thông báo '
          'biến động số dư của ngân hàng và ví điện tử.\n\n'
          '• Chỉ thông báo có số tiền được xử lý; tin nhắn, mã OTP và thông báo khác bị bỏ qua ngay trên máy.\n'
          '• Nội dung thông báo có số tiền được lưu kèm giao dịch trong sổ của bạn, và được đồng bộ lên server VieTing nếu bạn đăng nhập.\n'
          '• Không chia sẻ cho bên nào khác. Tắt được bất cứ lúc nào trong Cài đặt của điện thoại.',
      'Đồng ý, tiếp tục',
    ),
    'ai': (
      'Gửi dữ liệu cho trợ lý AI?',
      'Để trả lời, đọc hóa đơn và tách giao dịch, VieTing gửi tin nhắn, ảnh hoặc đoạn văn bản bạn đưa vào, kèm bản tóm tắt '
          'sổ chi tiêu (số dư, các khoản gần đây), tới server VieTing rồi tới dịch vụ AI của Google (Gemini) và Cloudflare.\n\n'
          '• Chỉ gửi khi bạn dùng tính năng AI.\n'
          '• VieTing dùng gói Gemini không trả phí: Google có thể dùng nội dung này để cải thiện sản phẩm và người của Google có thể xem.\n'
          '• Đừng gửi mật khẩu, mã OTP hay số thẻ cho trợ lý.',
      'Đồng ý dùng AI',
    ),
  };

  static bool given(AppStore s, String key) => (s.consents[key] ?? 0) > 0;

  /// Hiện công bố ngay trước khi truy cập dữ liệu. Trả về true khi người dùng bấm đồng ý (hoặc đã đồng ý trước đó).
  static Future<bool> ensure(AppStore s, String key, {BuildContext? context}) async {
    if (given(s, key)) return true;
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final t = _texts[key]!;
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(t.$1),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: openPrivacy,
                child: const Text('Xem chính sách quyền riêng tư'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không đồng ý')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.red),
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.$3),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      s.setConsent(key, true);
      return true;
    }
    return false;
  }
}
