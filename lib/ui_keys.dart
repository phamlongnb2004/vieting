import 'dart:async';
import 'package:flutter/material.dart';

/// Khóa toàn cục để hiện thông báo (SnackBar) / hộp thoại từ bất kỳ đâu, kể cả sau khi đóng màn hình.
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


/// Thanh báo ngắn ở đáy màn hình, luôn tự tắt sau vài giây (kể cả khi có nút "Sửa" / "Hoàn tác")
/// và có nút ✕ để tắt ngay. Flutter mới giữ mãi các SnackBar có nút hành động nếu không đóng thủ công.
void showToast(BuildContext? context, String text,
    {String? actionLabel, VoidCallback? onAction, Duration duration = const Duration(seconds: 4)}) {
  final m = (context != null ? ScaffoldMessenger.maybeOf(context) : null) ?? messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  final c = m.showSnackBar(SnackBar(
    content: Text(text),
    duration: duration,
    showCloseIcon: true,
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
  var done = false;
  c.closed.then((_) => done = true);
  Timer(duration, () {
    if (done) return;
    try {
      c.close();
    } catch (_) {}
  });
}

/// Vùng gốc cho bảng chia sẻ. iPad và iOS mới bắt buộc có vùng này, thiếu là lỗi
/// "PlatformException ... sharePositionOrigin must be set".
Rect shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.size.width > 0 && box.size.height > 0) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.maybeOf(context)?.size ?? const Size(400, 800);
  return Rect.fromLTWH(size.width / 2 - 1, size.height / 2 - 1, 2, 2);
}
