import 'dart:convert';

import 'package:http/http.dart' as http;
import '../consent.dart';
import 'package:image_picker/image_picker.dart';

import '../store.dart';
import '../util/format.dart';

/// Kết quả đọc ảnh hóa đơn / ảnh chuyển khoản.
class ReceiptResult {
  final Map<String, dynamic>? action; // add_txn
  final String? error;
  const ReceiptResult({this.action, this.error});
}

/// Chụp hoặc chọn ảnh hóa đơn / ảnh chuyển khoản / mã QR, gửi AI trên server đọc số tiền.
class Receipt {
  static Future<ReceiptResult?> pickAndRead(AppStore s, {required bool camera}) async {
    if (!await Consent.ensure(s, 'ai')) return const ReceiptResult(error: 'Cần đồng ý gửi ảnh cho AI để đọc hóa đơn');
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (x == null) return null; // người dùng hủy
    final bytes = await x.readAsBytes();
    final base = s.serverUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return const ReceiptResult(error: 'App chưa nối server AI');
    final now = DateTime.now();
    try {
      final res = await http
          .post(
            Uri.parse('$base/api/receipt'),
            headers: {
              'content-type': 'application/json',
              if (s.token.isNotEmpty) 'authorization': 'Bearer ${s.token}',
            },
            body: jsonEncode({
              'image': base64Encode(bytes),
              'mime': x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
              'today': '${now.year}-${two(now.month)}-${two(now.day)}',
            }),
          )
          .timeout(const Duration(seconds: 60));
      final body = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      if (res.statusCode != 200) return ReceiptResult(error: (body['error'] ?? 'Lỗi server').toString());
      if (body['found'] != true) return ReceiptResult(error: (body['reason'] ?? 'Không đọc được số tiền').toString());
      return ReceiptResult(action: body);
    } catch (_) {
      return const ReceiptResult(error: 'Không kết nối được AI đọc ảnh');
    }
  }
}
