# VieTing – quản lý chi tiêu (Android · iOS · Windows)

Tác giả: **Phạm Thành Long (thlong)**

App thật (Flutter, biên dịch ra mã máy, không phải web). Có tiền vào/ra là VieTing **tự đọc thông báo biến động số dư** của app ngân hàng / SMS, ghi thành giao dịch, xếp danh mục và khớp số dư ví.

| Thư mục | Nội dung |
|---|---|
| `lib/` | Code app dùng chung (Dart / Flutter) |
| `lib/parser/` | Bộ đọc thông báo ngân hàng (số tiền +/−, số dư, nội dung) |
| `android/app/src/main/kotlin/` | Dịch vụ đọc thông báo Android (Kotlin) |
| `test/` | Kiểm tra bộ đọc thông báo với mẫu của các ngân hàng |
| `server/` | Trang tải app + server đồng bộ (Cloudflare Workers + D1, miễn phí) |
| `tai-len-cloudflare.bat` | Đưa trang tải + file cài + server lên Cloudflare |
| `dat-khoa-gemini.bat` | Đặt khóa Gemini miễn phí cho trợ lý AI |
| `dat-google.bat` | Bật nút "Tiếp tục với Google" (Client ID + secret loại Web application) |
| `dat-email.bat` | Bật gửi mã "Quên mật khẩu" qua Gmail (mật khẩu ứng dụng) |
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
- **Trợ lý AI** (tab Trợ lý): hỏi về chi tiêu ("tháng này chi bao nhiêu?", "so với tháng trước?"), ghi giao dịch bằng một câu ("ăn phở 45k", "nhận lương 15tr"), đặt ngân sách; luôn hỏi lại trước khi ghi. Không có mạng/server vẫn ghi nhanh được.
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

## Trang tải + server đồng bộ (Cloudflare, miễn phí)
Một Worker trên Cloudflare lo cả **trang tải app** (`/tai-app`) lẫn **server đồng bộ** (`/api`). File cài không đưa lên GitHub.
1. Cài Node.js. Lần đầu bấm đúp `tai-len-cloudflare.bat`: nó tạo cơ sở dữ liệu D1 và in ra `database_id`. Dán ID đó vào `server/wrangler.jsonc`.
2. Chép file cài vào thư mục `dist\` (`VieTing.apk`, `VieTing-Setup.exe`, `VieTing-Windows-portable.zip`, `VieTing.ipa` – có file nào chép file đó).
3. Bấm đúp lại `tai-len-cloudflare.bat`. Trang tải: `https://vieting.<tài-khoản>.workers.dev/tai-app`, link cố định `/tai/android`, `/tai/windows`, `/tai/windows-portable`, `/tai/ios`.
4. Địa chỉ server đồng bộ (nhập vào app khi đăng nhập): `https://vieting.<tài-khoản>.workers.dev`. Hoặc đặt biến `SERVER_URL` (GitHub → Settings → Variables) để gắn sẵn vào app.

Cloudflare chỉ nhận file tối đa 25 MB nên `tools/pack-cloudflare.js` cắt file thành phần 20 MB, Worker ghép lại khi tải (có tải tiếp). Mỗi lần có bản mới: chép file vào `dist\` rồi chạy lại file .bat.

## Trang quản trị (/admin)

- Mở `https://<server>/admin`, đăng nhập bằng tài khoản VieTing có quyền admin.
- Lần đầu: đăng ký tài khoản trong app, rồi chạy `dat-admin.bat` và nhập email đó. Sau đó cấp quyền cho người khác ngay trên trang.
- Xem số người dùng, người đang dùng, đăng ký mới và giao dịch đồng bộ theo ngày, lượt dùng trợ lý AI.
- Quản lý tài khoản: khóa / mở khóa, đăng xuất mọi thiết bị, đặt lại mật khẩu, cấp / bỏ admin, xóa tài khoản và dữ liệu.
- Gửi thông báo hiện ở trang Tổng quan trong app.
- Có nhật ký thao tác. Vì quyền riêng tư, admin không xem được nội dung chi tiêu của người dùng.

## Trợ lý AI (miễn phí)
Chạy trên chính server Cloudflare ở trên, khóa AI chỉ nằm trên server:
- **Google Gemini** (miễn phí, tiếng Việt tốt nhất): lấy khóa ở https://aistudio.google.com/apikey rồi bấm đúp `dat-khoa-gemini.bat` và dán khóa. Đổi mô hình bằng biến `GEMINI_MODEL` trong `server/wrangler.jsonc`.
- **Cloudflare Workers AI** (miễn phí 10.000 neurons/ngày, không cần khóa): tự dùng khi chưa có khóa Gemini hoặc Gemini hết lượt.
- Mỗi người tối đa 80 câu hỏi/ngày (sửa `DAILY_LIMIT` trong `server/ai.js`).
- App gửi câu hỏi + tóm tắt chi tiêu (tổng thu chi, theo danh mục, ngân sách, 40 giao dịch gần nhất), không gửi nội dung thông báo ngân hàng gốc. Lưu ý: bản Gemini miễn phí có thể được Google dùng để cải thiện sản phẩm.

## Đưa lên CH Play / App Store
- **CH Play:** tài khoản nhà phát triển 25 USD (một lần). Nộp `VieTing.aab`. Quyền đọc thông báo cần: trang chính sách quyền riêng tư, màn hình giải thích (đã có trong app), khai báo Data safety.
- **App Store:** 99 USD/năm, dựng bằng Codemagic. Bản iOS không có tính năng đọc thông báo (giới hạn của Apple).

## Logo
`assets/branding/icon.png` (1024×1024, nền đỏ cờ) và `icon-foreground.png` (cho icon Android, nền đỏ #BB171E). Thay file rồi đẩy lên, GitHub Actions tự tạo lại icon cho mọi nền tảng.
