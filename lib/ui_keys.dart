import 'package:flutter/material.dart';

/// Khóa toàn cục để hiện thông báo (SnackBar) / hộp thoại từ bất kỳ đâu, kể cả sau khi đóng màn hình.
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
