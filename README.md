# VieTing – quản lý chi tiêu (Android · iOS · Windows)

Tác giả: **Phạm Thành Long (thlong)**

App thật (Flutter, biên dịch ra mã máy, không phải web). Có tiền vào/ra là VieTing **tự đọc thông báo biến động số dư** của app ngân hàng / SMS, ghi thành giao dịch, xếp danh mục và khớp số dư ví.

| Thư mục | Nội dung |
|---|---|
| `lib/` | Code app dùng chung (Dart / Flutter) |
| `lib/parser/` | Bộ đọc thông báo ngân hàng (số tiền +/−, số dư, nội dung) |
| `android/app/src/main/kotlin/` | Dịch vụ đọc thông báo Android (Kotlin) |
| `test/` | Kiểm tra bộ đọc thông báo với mẫu của các ngân hàng |
| `server/` | Server đồng bộ (Cloudflare Workers + D1, miễn phí) |
| `installer/` | Bộ cài Windows (Inno Setup) |
| `tools/` | Tạo thư mục nền tảng + gắn cấu hình |
| `.github/workflows/build.yml` | GitHub Actions tự dựng APK/AAB + bộ cài Windows |
| `codemagic.yaml` | Dựng iOS trên Codemagic (không cần Mac) |

## Tính năng bản 0.1
- Tổng quan: tổng số dư, thu/chi tháng, biểu đồ chi theo danh mục, chi 7 ngày, ngân sách.
- Giao dịch: theo tháng, gom theo ngày, tìm kiếm, lọc thu/chi, vuốt để xóa (có hoàn tác).
- Ngân sách tháng theo danh mục hoặc tổng, gợi ý mức chi mỗi ngày.
- Nhiều ví: tiền mặt, ngân hàng, ví điện tử. Ví ngân hàng tự tạo và tự khớp số dư từ thông báo.
- **Android:** tự đọc thông báo ngân hàng/SMS (Vietcombank, MB, Techcombank, BIDV, VietinBank, Agribank, VPBank, TPBank, ACB, MoMo, ZaloPay…), chống ghi trùng, bỏ qua OTP/quảng cáo/chat, nhật ký thông báo.
- Tự đoán danh mục theo nội dung (Highlands → Ăn uống, Grab → Đi lại…) và **học** khi bạn sửa danh mục.
- **iOS:** Apple không cho đọc thông báo app khác → dùng Phím tắt (SMS ngân hàng) qua link `vieting://add?text=...`, hoặc Dán thông báo.
- Đăng nhập (tùy chọn) để đồng bộ giữa điện thoại, iPhone, máy tính. Sáng/tối.

## Dựng app
Mỗi lần đẩy code lên `main`, GitHub Actions tự dựng. Tải file: **Actions → lần chạy mới nhất → Artifacts**:
- `VieTing-Android`: `VieTing.apk` (cài thẳng) + `VieTing.aab` (nộp CH Play)
- `VieTing-Windows`: `VieTing-Setup.exe` + bản portable `.zip`

Đẩy tag `v0.1.0` (`git tag v0.1.0 && git push --tags`) thì file cài được đăng luôn vào mục **Releases**.

**iOS:** Codemagic → Add application → chọn kho `vieting` → workflow **iOS IPA chưa ký** → tải `VieTing.ipa`, cài bằng Sideloadly / AltStore. Lên App Store dùng workflow **iOS lên App Store** (cần tài khoản Apple Developer 99 USD/năm).

### Khóa ký Android (bắt buộc để cài đè bản mới và lên CH Play)
Vào kho GitHub → Settings → Secrets and variables → Actions → New repository secret, thêm 4 secret:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
Giữ kỹ file khóa `.jks`: mất là không cập nhật được app trên CH Play nữa.

### Dựng trên máy mình
Cài Flutter, rồi:
```
bash tools/setup-platforms.sh
flutter run            # chạy thử
flutter build apk      # Android
flutter build windows  # Windows
```

## Server đồng bộ (tùy chọn)
1. Cài Node.js. Bấm đúp `server\trien-khai-server.bat`. Lần đầu nó tạo cơ sở dữ liệu D1 và in ra `database_id`.
2. Dán ID đó vào `server/wrangler.jsonc`, chạy lại file `.bat`.
3. Địa chỉ server: `https://vieting.<tài-khoản>.workers.dev`. Nhập vào app khi đăng nhập, hoặc đặt biến `SERVER_URL` (GitHub → Settings → Variables) để gắn sẵn vào app.

## Đưa lên CH Play / App Store
- **CH Play:** tài khoản nhà phát triển 25 USD (một lần). Nộp `VieTing.aab`. Quyền đọc thông báo cần: trang chính sách quyền riêng tư, màn hình giải thích (đã có trong app), khai báo Data safety.
- **App Store:** 99 USD/năm, dựng bằng Codemagic. Bản iOS không có tính năng đọc thông báo (giới hạn của Apple).

## Logo
`assets/branding/icon.png` (1024×1024, nền đỏ cờ) và `icon-foreground.png` (cho icon Android, nền đỏ #BB171E). Thay file rồi đẩy lên, GitHub Actions tự tạo lại icon cho mọi nền tảng.
