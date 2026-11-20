/// Cấu hình chung của VieTing.
/// Địa chỉ server (Cloudflare) được gắn sẵn vào app lúc dựng, người dùng không phải nhập.
/// Đổi ở đây hoặc dựng với --dart-define=SERVER_URL=https://...
const String kServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: kDefaultServerUrl);

/// Địa chỉ server mặc định sau khi đưa lên Cloudflare (tai-len-cloudflare.bat in ra địa chỉ này).
const String kDefaultServerUrl = 'https://vieting.phamthanhlong-contact.workers.dev';
