import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// iOS không cho app đọc thông báo của app khác. Cách thay thế: Phím tắt (Shortcuts)
/// tự chạy khi có SMS của ngân hàng và gửi nội dung vào VieTing qua đường link vieting://add?text=...
class IosShortcutScreen extends StatelessWidget {
  const IosShortcutScreen({super.key});

  static const link = 'vieting://add?text=';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 13, backgroundColor: Brand.red, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Phím tắt iPhone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Brand.yellow.withAlpha(50),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Apple không cho bất kỳ app nào đọc thông báo của app ngân hàng. Nếu bạn nhận SMS biến động số dư, '
                'Phím tắt có thể tự gửi tin nhắn đó vào VieTing. Nếu chỉ nhận thông báo app ngân hàng, hãy copy '
                'thông báo rồi dùng "Dán thông báo", hoặc đăng nhập đồng bộ để xem giao dịch điện thoại Android ghi được.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Ghi 1 chạm không cần mở app', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text('VieTing có sẵn 2 tác vụ "Ghi khoản chi" và "Ghi khoản thu" trong app Phím tắt (iOS 16+). '
              'Khi chạy, iPhone hiện ô nhập số tiền nhỏ trên đỉnh màn hình; lần mở VieTing tiếp theo khoản đó tự vào sổ.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          step(1, 'Gõ 2 lần vào mặt lưng: Cài đặt → Trợ năng → Cảm ứng → Chạm vào mặt sau → Chạm hai lần → chọn phím tắt "Ghi khoản chi" của VieTing.'),
          step(2, 'Nút Tác vụ (iPhone 15 Pro trở lên): Cài đặt → Nút Tác vụ → Phím tắt → chọn "Ghi khoản chi".'),
          step(3, 'Hoặc nói với Siri: "VieTing ghi chi", hoặc thêm phím tắt ra màn hình chính.'),
          const SizedBox(height: 16),
          const Text('Cài tự động hóa (iOS 17 trở lên)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          step(1, 'Mở app Phím tắt (Shortcuts) → tab Tự động hóa → bấm + → chọn "Tin nhắn".'),
          step(2, 'Ở "Người gửi" chọn tên ngân hàng (VD: Vietcombank, MBBANK…). Chọn "Chạy ngay lập tức".'),
          step(3, 'Thêm tác vụ "Mã hóa URL" (URL Encode) với đầu vào là "Tin nhắn" (Shortcut Input → Nội dung).'),
          step(4, 'Thêm tác vụ "Mở URL" với nội dung: link bên dưới + kết quả "Văn bản được mã hóa URL".'),
          step(5, 'Lưu lại. Khi có SMS ngân hàng, iPhone tự mở VieTing và ghi giao dịch.'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const SelectableText(link, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              subtitle: const Text('Có thể thêm &bank=Vietcombank để gắn đúng ví'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy link')));
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ghi tay nhanh bằng Phím tắt: vieting://add?amount=50000&type=chi&note=cafe',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
