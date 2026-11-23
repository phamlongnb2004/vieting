// Chính sách quyền riêng tư và xóa tài khoản, song ngữ Việt / Anh, theo chính sách Dữ liệu người dùng của Google Play.
//   /chinh-sach-rieng-tu (vi) · /privacy (en) · /xoa-tai-khoan (vi) · /delete-account (en) · POST /api/account/delete
// Trang công khai, không cần đăng nhập.
// Tác giả: Phạm Thành Long (thlong)

const UPDATED = { vi: '23/11/2026', en: 23 + ' November 2026' };
const ICON = {
  shield: '<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6l8-3z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
  ban: '<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>',
  bank: '<path d="M3 10l9-6 9 6"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 018 0v4"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
};
const svg = (k, s = 22) =>
  `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICON[k]}</svg>`;

const CSS = `
:root{--red:#C1272C;--red2:#8E1519;--navy:#152758;--navy2:#2A4A9A;--bamboo:#3E8E41;--bg:#F7F3EC;--ink:#1C1B19;--mut:#6E6A63;--line:#EAE2D5}
*{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{font-family:"Be Vietnam Pro",system-ui,-apple-system,"Segoe UI",sans-serif;background:var(--bg);color:var(--ink);-webkit-font-smoothing:antialiased;line-height:1.7}
a{color:var(--red)}
.w{max-width:1120px;margin:0 auto;padding:0 22px}
nav{position:sticky;top:0;z-index:20;backdrop-filter:saturate(1.6) blur(14px);-webkit-backdrop-filter:saturate(1.6) blur(14px);background:rgba(247,243,236,.82);border-bottom:1px solid rgba(0,0,0,.05)}
nav .w{display:flex;align-items:center;height:64px;gap:18px}
.logo{display:flex;align-items:center;gap:10px;font-weight:900;font-size:20px;letter-spacing:-.5px;color:var(--ink);text-decoration:none}
.logo img{width:34px;height:34px;border-radius:10px;box-shadow:0 4px 12px rgba(193,39,44,.3)}
.lang{margin-left:auto;display:flex;background:#fff;border:1px solid var(--line);border-radius:99px;padding:4px}
.lang a{padding:6px 14px;border-radius:99px;font-weight:700;font-size:13px;color:var(--mut);text-decoration:none}
.lang a.on{background:var(--ink);color:#fff}
.hero{position:relative;overflow:hidden;background:linear-gradient(135deg,#0F1D45,var(--navy) 45%,var(--navy2));color:#fff;padding:58px 0 96px}
.hero:before{content:"";position:absolute;right:-180px;top:-220px;width:620px;height:620px;background:radial-gradient(circle,rgba(193,39,44,.55),transparent 62%)}
.hero:after{content:"";position:absolute;left:-160px;bottom:-300px;width:560px;height:560px;background:radial-gradient(circle,rgba(62,142,65,.35),transparent 60%)}
.hero .w{position:relative;z-index:1}
.kick{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.18);padding:6px 14px;border-radius:99px;font-weight:600;font-size:13px}
.hero h1{font-size:clamp(34px,5.4vw,58px);line-height:1.06;letter-spacing:-1.8px;font-weight:900;margin:18px 0 12px}
.hero p{font-size:17.5px;color:rgba(255,255,255,.8);max-width:680px}
.chips{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:-58px;position:relative;z-index:2}
@media(max-width:860px){.chips{grid-template-columns:repeat(2,1fr)}}
.chip{background:#fff;border-radius:20px;padding:18px;box-shadow:0 14px 40px rgba(21,39,88,.10);border:1px solid var(--line)}
.chip i{display:grid;place-items:center;width:42px;height:42px;border-radius:13px;margin-bottom:10px;font-style:normal}
.chip b{display:block;font-size:15.5px;line-height:1.3}
.chip span{display:block;color:var(--mut);font-size:13px;line-height:1.45;margin-top:4px}
.grid{display:grid;grid-template-columns:250px 1fr;gap:34px;margin:44px auto 70px}
@media(max-width:900px){.grid{grid-template-columns:1fr}.toc{display:none}}
.toc{position:sticky;top:86px;align-self:start}
.toc b{display:block;font-size:12px;letter-spacing:1px;color:var(--mut);margin-bottom:10px}
.toc a{display:flex;gap:10px;padding:7px 10px;border-radius:10px;color:var(--ink);text-decoration:none;font-weight:600;font-size:14px;line-height:1.35}
.toc a:hover{background:#fff}
.toc a em{font-style:normal;color:var(--red);font-weight:800;min-width:18px}
section{background:#fff;border:1px solid var(--line);border-radius:24px;padding:28px 30px;margin-bottom:18px;box-shadow:0 6px 24px rgba(21,39,88,.04);scroll-margin-top:84px}
@media(max-width:600px){section{padding:22px 18px}}
section h2{display:flex;align-items:center;gap:12px;font-size:22px;letter-spacing:-.4px;color:var(--navy);margin-bottom:12px;line-height:1.3}
section h2 em{font-style:normal;display:grid;place-items:center;width:34px;height:34px;border-radius:11px;background:rgba(193,39,44,.1);color:var(--red);font-size:15px;flex:none}
section h3{font-size:16px;margin:18px 0 6px;color:var(--navy)}
section p{margin:8px 0}
section ul{margin:8px 0 8px 20px}
section li{margin:5px 0}
.tbl{display:grid;gap:10px;margin:12px 0}
.row{display:grid;grid-template-columns:200px 1fr;gap:16px;padding:14px 16px;border-radius:16px;background:var(--bg)}
.row.h4{grid-template-columns:170px 150px 1fr}
@media(max-width:700px){.row,.row.h4{grid-template-columns:1fr;gap:4px}}
.row b{color:var(--navy);font-size:15px}
.row small{display:block;color:var(--mut);font-size:13px}
.note{display:flex;gap:12px;align-items:flex-start;background:#FFF6E0;border:1px solid #F3DFA8;border-radius:16px;padding:14px 16px;margin:12px 0;font-size:15px}
.note i{color:#B07A00;font-style:normal;flex:none;margin-top:2px}
.btn{display:inline-flex;align-items:center;gap:10px;background:linear-gradient(135deg,#D4343A,var(--red) 50%,var(--red2));color:#fff;border:0;border-radius:14px;padding:14px 22px;font:inherit;font-weight:800;cursor:pointer;box-shadow:0 12px 28px rgba(193,39,44,.3);text-decoration:none}
input{width:100%;padding:13px 15px;border:1px solid var(--line);border-radius:14px;font:inherit;margin:6px 0 14px;background:var(--bg)}
input:focus{outline:2px solid rgba(193,39,44,.35);background:#fff}
label{font-weight:700;font-size:14px}
#msg{margin-top:14px;font-weight:700}
footer{border-top:1px solid var(--line);padding:26px 0 40px;color:var(--mut);font-size:14px}
footer .w{display:flex;gap:18px;flex-wrap:wrap;align-items:center}
footer a{color:var(--mut);text-decoration:none;font-weight:600}
footer a:hover{color:var(--red)}
`;

function shell(lang, title, alt, inner) {
  const vi = lang === 'vi';
  return `<!DOCTYPE html>
<html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · VieTing</title>
<meta name="theme-color" content="#152758">
<link rel="icon" href="/img/favicon.png">
<link rel="alternate" hreflang="vi" href="${alt.vi}"><link rel="alternate" hreflang="en" href="${alt.en}">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
<style>${CSS}</style></head><body>
<nav><div class="w">
  <a class="logo" href="/tai-app"><img src="/img/icon-256.png" alt="">VieTing</a>
  <div class="lang"><a href="${alt.vi}" class="${vi ? 'on' : ''}">Tiếng Việt</a><a href="${alt.en}" class="${vi ? '' : 'on'}">English</a></div>
</div></nav>
${inner}
<footer><div class="w">
  <span>© 2026 VieTing · Phạm Thành Long</span>
  <a href="${vi ? '/chinh-sach-rieng-tu' : '/privacy'}">${vi ? 'Chính sách quyền riêng tư' : 'Privacy policy'}</a>
  <a href="${vi ? '/dieu-khoan' : '/terms'}">${vi ? 'Điều khoản dịch vụ' : 'Terms of service'}</a>
  <a href="${vi ? '/xoa-tai-khoan' : '/delete-account'}">${vi ? 'Xóa tài khoản' : 'Delete account'}</a>
  <a href="/tai-app">${vi ? 'Tải app' : 'Download'}</a>
</div></footer>
</body></html>`;
}

const rows = (list, four = false) =>
  `<div class="tbl">${list
    .map((r) =>
      four
        ? `<div class="row h4"><b>${r[0]}</b><div><small>${r[1]}</small></div><div>${r[2]}<small>${r[3] || ''}</small></div></div>`
        : `<div class="row"><b>${r[0]}<small>${r[2] || ''}</small></b><div>${r[1]}</div></div>`
    )
    .join('')}</div>`;

// ---------------- Nội dung ----------------
function content(lang, contact) {
  const vi = lang === 'vi';
  const reach = vi
    ? contact
      ? `email <a href="mailto:${contact}">${contact}</a> hoặc mục <b>Cài đặt → Góp ý &amp; báo lỗi</b> trong app`
      : `mục <b>Cài đặt → Góp ý &amp; báo lỗi</b> trong app`
    : contact
      ? `email <a href="mailto:${contact}">${contact}</a> or <b>Settings → Feedback &amp; bug report</b> in the app`
      : `<b>Settings → Feedback &amp; bug report</b> in the app`;

  if (vi)
    return {
      title: 'Chính sách quyền riêng tư',
      kick: 'Áp dụng cho VieTing trên Android, iPhone, Windows và trang web',
      lead: 'VieTing là ứng dụng ghi chép và quản lý chi tiêu cá nhân. Trang này nói rõ app thu thập dữ liệu gì, dùng để làm gì, chia sẻ cho ai và bạn kiểm soát chúng thế nào.',
      updated: 'Cập nhật ' + UPDATED.vi,
      chips: [
        ['ban', '#C1272C', 'Không bán dữ liệu', 'Không quảng cáo, không SDK theo dõi'],
        ['bank', '#152758', 'Không giữ tiền', 'Không đăng nhập vào ngân hàng của bạn'],
        ['lock', '#3E8E41', 'Mã hóa khi truyền', 'HTTPS, mật khẩu chỉ lưu dạng băm'],
        ['trash', '#B07A00', 'Xóa bất cứ lúc nào', 'Trong app hoặc trên web'],
      ],
      sections: [
        ['Ai chịu trách nhiệm', `<p>VieTing do cá nhân <b>Phạm Thành Long</b> phát triển và vận hành ("chúng tôi"). Mọi câu hỏi về quyền riêng tư, liên hệ qua ${reach}.</p>`],
        [
          'Dữ liệu chúng tôi thu thập',
          rows([
            ['Tài khoản', 'Email, mật khẩu (chỉ lưu dạng băm PBKDF2 có muối, chúng tôi không đọc được), tên hiển thị trong quỹ chung, thời điểm tạo tài khoản. Nếu đăng nhập bằng Google: email, tên và mã định danh tài khoản Google (không lấy mật khẩu Google, danh bạ hay dữ liệu khác).', 'Khi đăng ký'],
            ['Vị trí gần đúng', 'Tọa độ làm tròn (sai số khoảng 1 km) để hiện thời tiết và cảnh báo mưa bão. Chỉ lấy khi bạn mở app hoặc mục Thời tiết, không theo dõi ngầm, server không lưu lại. Không dùng nếu bạn chọn tỉnh / thành bằng tay.', 'Chỉ khi bạn đồng ý và cấp quyền vị trí'],
            ['Thông tin cá nhân', 'Họ và tên, năm sinh. Dùng để hiển thị trong hồ sơ của bạn và giúp trợ lý gợi ý phù hợp độ tuổi; không dùng cho quảng cáo, không chia sẻ cho ai. Có thể sửa hoặc xóa bất cứ lúc nào trong Cài đặt.', 'Khi bạn tự nhập'],
            ['Dữ liệu tài chính bạn ghi', 'Giao dịch thu chi (số tiền, danh mục, ghi chú, ngày, ví), ví và số dư, ngân sách, mục tiêu tiết kiệm, hóa đơn định kỳ, danh sách mong muốn, cài đặt.', 'Khi bạn ghi; đồng bộ lên server nếu đăng nhập'],
            ['Thông báo ngân hàng / ví', 'App đọc thông báo trên máy để tự ghi giao dịch. Chỉ thông báo có số tiền được xử lý; nội dung thông báo đó (tên app gửi, tiêu đề, nội dung) được lưu kèm giao dịch. Thông báo khác bị bỏ qua ngay trên máy.', 'Chỉ Android, chỉ khi bạn đồng ý và cấp quyền'],
            ['Ảnh', 'Ảnh hóa đơn, ảnh chuyển khoản bạn chụp hoặc chọn để AI đọc; ảnh chứng từ trong Quỹ chung.', 'Chỉ khi bạn chủ động gửi'],
            ['Nội dung gửi trợ lý AI', 'Tin nhắn, ảnh, đoạn văn bản bạn dán, kèm bản tóm tắt sổ (số dư, các khoản gần đây) để AI trả lời đúng.', 'Khi bạn dùng tính năng AI và đã đồng ý'],
            ['Quỹ chung', 'Các khoản nộp / chi, ảnh chứng từ, xác nhận, duyệt, nhật ký sửa / xóa, thông tin tài khoản nhận quỹ (ngân hàng, số tài khoản, tên chủ tài khoản) do thủ quỹ nhập.', 'Khi bạn tạo hoặc tham gia quỹ'],
            ['Kết nối ngân hàng qua SePay', 'Khóa truy cập SePay (chỉ lưu trên server) và giao dịch của tài khoản quỹ (số tiền, nội dung, thời gian, số dư sau giao dịch).', 'Tùy chọn, chỉ khi thủ quỹ tự nối'],
            ['Hỗ trợ', 'Nội dung góp ý / báo lỗi, thông tin liên hệ bạn tự ghi, báo cáo "AI đọc sai" (số AI đọc và số bạn sửa, không kèm ảnh).', 'Khi bạn gửi'],
            ['Dữ liệu kỹ thuật', 'Mã phiên đăng nhập, số lượt dùng AI mỗi ngày / tháng (để áp hạn mức), thời điểm đồng bộ, phiên bản app.', 'Khi bạn dùng app'],
          ]) +
            `<p>Chúng tôi <b>không</b> thu thập danh bạ, vị trí, mật khẩu hay mã OTP ngân hàng, số thẻ, dữ liệu sinh trắc học, mã quảng cáo. App không có quảng cáo và không dùng SDK theo dõi hay phân tích của bên thứ ba.</p>
            <h3>Quyền trên thiết bị</h3><ul>
            <li><b>Truy cập thông báo</b> (Android): tự ghi giao dịch từ thông báo ngân hàng, ví. App hỏi bạn đồng ý trước, tắt được bất cứ lúc nào trong Cài đặt của điện thoại.</li>
            <li><b>Máy ảnh, thư viện ảnh</b>: chỉ khi bạn chụp / chọn ảnh hóa đơn, chứng từ.</li>
            <li><b>Micro</b>: khi bạn ghi bằng giọng nói. Nhận dạng giọng nói do dịch vụ của hệ điều hành (Google / Apple) thực hiện theo chính sách của họ; VieTing chỉ nhận lại văn bản.</li>
            <li><b>Vân tay / Face ID</b>: để khóa app. Xác thực diễn ra hoàn toàn trên máy, VieTing không nhận dữ liệu sinh trắc học.</li>
            <li><b>Thông báo, báo thức</b>: nhắc ghi chép, nhắc hóa đơn, tin của quỹ chung. App tự hỏi server khoảng 30 phút một lần, không dùng dịch vụ đẩy tin của bên thứ ba.</li></ul>`,
        ],
        [
          'Chúng tôi dùng dữ liệu để làm gì',
          `<ul><li>Cung cấp tính năng: lưu và đồng bộ sổ thu chi, thống kê, nhắc nhở, mục tiêu, quỹ chung, kiểm tra chứng từ.</li>
          <li>Trợ lý AI: trả lời câu hỏi, đọc hóa đơn, tách giao dịch từ văn bản.</li>
          <li>Bảo mật và chống lạm dụng: đăng nhập, hạn mức AI, phát hiện ảnh chứng từ dùng lại.</li>
          <li>Hỗ trợ và cải thiện app: trả lời góp ý, sửa lỗi nhận diện từ báo cáo bạn gửi.</li></ul>
          <p>Chúng tôi không dùng dữ liệu tài chính của bạn để quảng cáo, chấm điểm tín dụng hay bán cho bất kỳ ai.</p>`,
        ],
        [
          'Chia sẻ dữ liệu với ai',
          rows(
            [
              ['Cloudflare, Inc.', 'Hạ tầng: máy chủ, cơ sở dữ liệu, AI dự phòng', 'Toàn bộ dữ liệu lưu trên server VieTing; nội dung gửi AI khi dịch vụ chính quá tải.', 'Lưu trữ, đồng bộ, chạy AI dự phòng (Workers AI)'],
              ['Google LLC (Gemini API)', 'Dịch vụ AI', 'Tin nhắn, ảnh, văn bản bạn gửi cho trợ lý kèm bản tóm tắt sổ và tuổi (nếu bạn nhập năm sinh; không gửi họ tên); ảnh hóa đơn / chứng từ.', 'Tạo câu trả lời, đọc ảnh'],
              ['Google LLC (Đăng nhập bằng Google)', 'Dịch vụ đăng nhập (tùy chọn)', 'Google xác nhận bạn là chủ tài khoản và gửi lại email, tên của bạn cho VieTing.', 'Đăng nhập không cần mật khẩu'],
              ['Dịch vụ gửi email (Gmail / Resend)', 'Gửi thư', 'Địa chỉ email của bạn và mã đặt lại mật khẩu.', 'Gửi mã khi bạn bấm Quên mật khẩu'],
              ['MET Norway (Viện Khí tượng Na Uy)', 'Dịch vụ dự báo thời tiết', 'Tọa độ làm tròn của nơi xem thời tiết (không kèm thông tin nào khác về bạn).', 'Lấy dự báo thời tiết'],
              ['SePay', 'Dịch vụ đọc giao dịch ngân hàng (tùy chọn)', 'VieTing dùng khóa thủ quỹ cấp để đọc giao dịch của tài khoản quỹ.', 'Xác thực tiền vào / ra của Quỹ chung'],
              ['Thành viên cùng Quỹ chung', 'Người dùng khác do bạn mời / chấp nhận', 'Tên hiển thị (hoặc phần trước @ của email), các khoản bạn nộp / chi trong quỹ, ảnh chứng từ, xác nhận, nhật ký.', 'Minh bạch quỹ chung'],
              ['Cơ quan nhà nước có thẩm quyền', 'Theo yêu cầu pháp luật', 'Phần dữ liệu được yêu cầu hợp pháp.', 'Tuân thủ pháp luật Việt Nam'],
            ],
            true
          ) +
            `<div class="note"><i>${svg('shield', 20)}</i><div>VieTing đang dùng gói Gemini API không trả phí. Theo điều khoản của Google, nội dung gửi qua gói này có thể được Google dùng để cải thiện sản phẩm và có thể được người kiểm duyệt của Google xem. Đừng gửi cho trợ lý mật khẩu, mã OTP, số thẻ hay số tài khoản đầy đủ.</div></div>
            <p>Ngoài các bên trên, chúng tôi không chia sẻ, cho thuê hay bán dữ liệu của bạn.</p>`,
        ],
        [
          'Lưu trữ và bảo mật',
          `<ul><li>Dữ liệu lưu trên hạ tầng Cloudflare, có thể đặt ở nhiều quốc gia. Kết nối giữa app và server luôn được mã hóa (HTTPS).</li>
          <li>Mật khẩu chỉ lưu dạng băm; khóa SePay chỉ nằm trên server; ảnh chứng từ chỉ thành viên trong quỹ xem được.</li>
          <li>Không hệ thống nào an toàn tuyệt đối; nếu có sự cố lộ dữ liệu ảnh hưởng tới bạn, chúng tôi sẽ thông báo trong app.</li></ul>`,
        ],
        [
          'Giữ dữ liệu bao lâu',
          `<ul><li>Dữ liệu tài khoản và sổ thu chi được giữ đến khi bạn xóa tài khoản.</li>
          <li>Bộ đếm lượt dùng AI chỉ giữ ngắn hạn để tính hạn mức.</li>
          <li>Khi bạn xóa tài khoản, dữ liệu bị xóa khỏi cơ sở dữ liệu ngay; bản sao lưu tự động của nhà cung cấp hạ tầng tự hết hạn trong tối đa 30 ngày.</li>
          <li>Trong Quỹ chung: các khoản bạn đã ghi ở lại sổ của quỹ để thành viên khác đối chiếu (giữ minh bạch, chống gian lận), nhưng tên bạn được thay bằng "Thành viên cũ"; ảnh chứng từ bạn tải lên bị xóa.</li></ul>`,
        ],
        [
          'Quyền của bạn',
          `<ul><li><b>Xem, sửa</b> dữ liệu ngay trong app.</li>
          <li><b>Xuất dữ liệu</b>: Cài đặt → Xuất CSV.</li>
          <li><b>Rút lại đồng ý</b>: tắt quyền truy cập thông báo, máy ảnh, micro trong Cài đặt điện thoại; tắt "Cho phép gửi dữ liệu tới AI" trong Cài đặt → Quyền riêng tư; ngắt kết nối ngân hàng của quỹ.</li>
          <li><b>Xóa tài khoản và toàn bộ dữ liệu</b>: trong app (Cài đặt → Quyền riêng tư → Xóa tài khoản) hoặc tại <a href="/xoa-tai-khoan">trang xóa tài khoản</a>.</li>
          <li>Khiếu nại hoặc yêu cầu khác theo pháp luật Việt Nam về bảo vệ dữ liệu cá nhân: liên hệ qua ${reach}. Chúng tôi phản hồi trong vòng 15 ngày.</li></ul>`,
        ],
        ['Trẻ em', `<p>VieTing chỉ dành cho người từ 18 tuổi trở lên (khi đăng ký phải nhập năm sinh) và không cố ý thu thập dữ liệu của trẻ em. Nếu bạn biết một trẻ em đã tạo tài khoản, hãy báo để chúng tôi xóa.</p>`],
        ['Thay đổi chính sách', `<p>Khi chính sách thay đổi, chúng tôi cập nhật ngày ở đầu trang và thông báo trong app với các thay đổi quan trọng.</p>`],
      ],
    };

  return {
    title: 'Privacy Policy',
    kick: 'Applies to VieTing on Android, iPhone, Windows and the website',
    lead: 'VieTing is a personal expense-tracking app. This page explains what data the app collects, why, who it is shared with, and how you stay in control.',
    updated: 'Last updated ' + UPDATED.en,
    chips: [
      ['ban', '#C1272C', 'We never sell data', 'No ads, no tracking SDKs'],
      ['bank', '#152758', 'We never hold money', 'We never log in to your bank'],
      ['lock', '#3E8E41', 'Encrypted in transit', 'HTTPS, passwords stored only as hashes'],
      ['trash', '#B07A00', 'Delete anytime', 'In the app or on the web'],
    ],
    sections: [
      ['Who is responsible', `<p>VieTing is developed and operated by <b>Phạm Thành Long</b>, an individual developer ("we"). For any privacy question, contact us via ${reach}.</p>`],
      [
        'Data we collect',
        rows([
          ['Account', 'Email, password (stored only as a salted PBKDF2 hash that we cannot read), display name in shared funds, account creation time. If you sign in with Google: your Google email, name and account identifier (never your Google password, contacts or other data).', 'When you sign up'],
          ['Approximate location', 'Rounded coordinates (accurate to about 1 km) to show the weather and storm warnings. Read only when you open the app or the Weather screen, never in the background, and not stored on the server. Not used if you pick a province / city manually.', 'Only if you agree and grant location permission'],
          ['Personal information', 'Full name and birth year. Used to show in your profile and to help the assistant give age-appropriate tips; never used for ads or shared with anyone. You can edit or clear them anytime in Settings.', 'When you enter them'],
          ['Financial data you record', 'Transactions (amount, category, note, date, wallet), wallets and balances, budgets, savings goals, recurring bills, wish list, settings.', 'When you record them; synced to our server if you sign in'],
          ['Bank / e-wallet notifications', 'The app reads notifications on your device to log transactions automatically. Only notifications containing a money amount are processed; their content (sending app, title, text) is stored with the transaction. All other notifications are ignored on the device.', 'Android only, only after you agree and grant access'],
          ['Photos', 'Receipt or transfer screenshots you take or pick for the AI to read; proof photos in Shared funds.', 'Only when you send them'],
          ['Content sent to the AI assistant', 'Messages, photos and text you paste, plus a summary of your ledger (balances, recent transactions) so the AI can answer accurately.', 'When you use AI features and have agreed'],
          ['Shared funds', 'Contributions / spending, proof photos, confirmations, approvals, edit / delete history, and the fund’s receiving account (bank, account number, holder name) entered by the treasurer.', 'When you create or join a fund'],
          ['Bank connection via SePay', 'A SePay access key (kept only on our server) and transactions of the fund account (amount, description, time, balance after transaction).', 'Optional, only when the treasurer connects it'],
          ['Support', 'Feedback / bug reports, contact details you choose to give, "AI misread" reports (the AI value and your correction, no photo).', 'When you send them'],
          ['Technical data', 'Session token, daily / monthly AI usage counts (for quotas), sync times, app version.', 'When you use the app'],
        ]) +
          `<p>We do <b>not</b> collect contacts, location, bank passwords or OTP codes, card numbers, biometric data or advertising IDs. The app shows no ads and uses no third-party tracking or analytics SDKs.</p>
          <h3>Device permissions</h3><ul>
          <li><b>Notification access</b> (Android): to log transactions from bank and wallet notifications. The app asks for your consent first; you can turn it off anytime in your phone settings.</li>
          <li><b>Camera, photo library</b>: only when you take or pick a receipt / proof photo.</li>
          <li><b>Microphone</b>: when you record by voice. Speech recognition is performed by the operating system’s service (Google / Apple) under their policies; VieTing only receives the resulting text.</li>
          <li><b>Fingerprint / Face ID</b>: to lock the app. Authentication happens entirely on the device; VieTing never receives biometric data.</li>
          <li><b>Notifications, alarms</b>: logging reminders, bill reminders and shared-fund news. The app checks our server about every 30 minutes; no third-party push service is used.</li></ul>`,
      ],
      [
        'How we use data',
        `<ul><li>To provide features: storing and syncing your ledger, statistics, reminders, goals, shared funds, proof checks.</li>
        <li>AI assistant: answering questions, reading receipts, extracting transactions from text.</li>
        <li>Security and abuse prevention: sign-in, AI quotas, detecting reused proof photos.</li>
        <li>Support and improvement: replying to feedback, fixing recognition errors from reports you send.</li></ul>
        <p>We never use your financial data for advertising or credit scoring, and we never sell it.</p>`,
      ],
      [
        'Who we share data with',
        rows(
          [
            ['Cloudflare, Inc.', 'Infrastructure: servers, database, backup AI', 'All data stored on the VieTing server; AI requests when the main AI service is busy.', 'Storage, sync, backup AI (Workers AI)'],
            ['Google LLC (Gemini API)', 'AI service provider', 'Messages, photos and text you send to the assistant with the ledger summary and your age (if you entered a birth year; never your name); receipt / proof photos.', 'Generating answers, reading images'],
            ['Google LLC (Sign in with Google)', 'Sign-in service (optional)', 'Google confirms you own the account and sends your email and name back to VieTing.', 'Password-free sign-in'],
            ['Email delivery (Gmail / Resend)', 'Email sending', 'Your email address and the password reset code.', 'Sending the code when you tap Forgot password'],
            ['MET Norway (Norwegian Meteorological Institute)', 'Weather forecast service', 'Rounded coordinates of the weather location (nothing else about you).', 'Getting the weather forecast'],
            ['SePay', 'Bank transaction reader (optional)', 'VieTing uses the key granted by the treasurer to read the fund account’s transactions.', 'Verifying money in / out of a Shared fund'],
            ['Members of the same Shared fund', 'Other users you invite / accept', 'Display name (or the part of your email before @), your contributions / spending in the fund, proof photos, confirmations, history.', 'Transparency within the fund'],
            ['Competent authorities', 'When required by law', 'Only the data lawfully requested.', 'Compliance with Vietnamese law'],
          ],
          true
        ) +
          `<div class="note"><i>${svg('shield', 20)}</i><div>VieTing currently uses the unpaid tier of the Gemini API. Under Google’s terms, content sent through this tier may be used by Google to improve its products and may be read by human reviewers. Do not send passwords, OTP codes, card numbers or full account numbers to the assistant.</div></div>
          <p>Apart from the parties above, we do not share, rent or sell your data.</p>`,
      ],
      [
        'Storage and security',
        `<ul><li>Data is stored on Cloudflare infrastructure, which may be located in several countries. Traffic between the app and our server is always encrypted (HTTPS).</li>
        <li>Passwords are stored only as hashes; SePay keys stay on the server; proof photos are visible only to members of the fund.</li>
        <li>No system is perfectly secure; if a breach affects you, we will notify you in the app.</li></ul>`,
      ],
      [
        'Retention',
        `<ul><li>Account and ledger data are kept until you delete your account.</li>
        <li>AI usage counters are kept only briefly to enforce quotas.</li>
        <li>When you delete your account, data is removed from our database immediately; automatic infrastructure backups expire within at most 30 days.</li>
        <li>In Shared funds: entries you recorded stay in the fund’s ledger so other members can still reconcile it (transparency and fraud prevention), but your name is replaced with "Former member"; proof photos you uploaded are deleted.</li></ul>`,
      ],
      [
        'Your rights',
        `<ul><li><b>View and edit</b> your data directly in the app.</li>
        <li><b>Export</b>: Settings → Export CSV.</li>
        <li><b>Withdraw consent</b>: turn off notification, camera or microphone access in your phone settings; turn off "Allow sending data to AI" in Settings → Privacy; disconnect the fund’s bank connection.</li>
        <li><b>Delete your account and all data</b>: in the app (Settings → Privacy → Delete account) or on the <a href="/delete-account">account deletion page</a>.</li>
        <li>Complaints or other requests under Vietnamese personal-data-protection law: contact us via ${reach}. We reply within 15 days.</li></ul>`,
      ],
      ['Children', `<p>VieTing is only for people aged 18 and over (a birth year is required at sign-up) and we do not knowingly collect children’s data. If you believe a child has created an account, let us know and we will delete it.</p>`],
      ['Changes to this policy', `<p>When this policy changes, we update the date at the top of this page and announce important changes in the app.</p>`],
    ],
  };
}

// ---------------- Điều khoản dịch vụ ----------------
function terms(lang, contact) {
  const vi = lang === 'vi';
  const reach = vi
    ? contact ? `email <a href="mailto:${contact}">${contact}</a> hoặc mục <b>Cài đặt → Góp ý &amp; báo lỗi</b> trong app` : `mục <b>Cài đặt → Góp ý &amp; báo lỗi</b> trong app`
    : contact ? `email <a href="mailto:${contact}">${contact}</a> or <b>Settings → Feedback &amp; bug report</b> in the app` : `<b>Settings → Feedback &amp; bug report</b> in the app`;
  const P = (t) => `<p>${t}</p>`;
  const L = (a) => `<ul>${a.map((x) => `<li>${x}</li>`).join('')}</ul>`;
  if (vi)
    return {
      title: 'Điều khoản dịch vụ',
      kick: 'Áp dụng cho VieTing trên Android, iPhone, Windows và trang web',
      lead: 'Đây là thỏa thuận giữa bạn và VieTing khi bạn dùng app. Đọc kỹ nhé: dùng VieTing nghĩa là bạn đồng ý với các điều khoản này.',
      updated: 'Cập nhật ' + UPDATED.vi,
      chips: [
        ['bank', '#152758', 'Không giữ tiền', 'VieTing chỉ ghi chép, không chuyển tiền'],
        ['shield', '#C1272C', 'Từ 18 tuổi', 'Dành cho người trưởng thành'],
        ['lock', '#3E8E41', 'Dữ liệu là của bạn', 'Xuất hoặc xóa bất cứ lúc nào'],
        ['ban', '#B07A00', 'Không phải tư vấn', 'Trợ lý AI chỉ để tham khảo'],
      ],
      sections: [
        ['Dịch vụ là gì', P('VieTing là ứng dụng ghi chép thu chi cá nhân do <b>Phạm Thành Long</b> phát triển ("chúng tôi"). App giúp bạn ghi giao dịch (tự nhập hoặc đọc thông báo ngân hàng khi bạn cho phép), đặt ngân sách, mục tiêu tiết kiệm, ghi sổ chung với người quen (Quỹ chung) và hỏi trợ lý AI về chi tiêu.') + P('VieTing <b>không phải ngân hàng hay ví điện tử</b>: không giữ tiền, không chuyển tiền, không cho vay, không đăng nhập vào ngân hàng của bạn. Mọi khoản chuyển tiền đều do bạn tự làm trong app ngân hàng của mình.')],
        ['Ai được dùng', P('Bạn phải từ <b>18 tuổi</b> trở lên. Khi đăng ký bằng email, bạn khai năm sinh thật. Nếu chúng tôi biết tài khoản thuộc người dưới 18 tuổi, tài khoản có thể bị xóa.')],
        ['Tài khoản của bạn', L(['Bạn chịu trách nhiệm giữ mật khẩu và thiết bị của mình. Có thể bật mã PIN / vân tay trong app.', 'Thông tin bạn khai (email, họ tên, năm sinh) phải là của bạn.', 'Mỗi người dùng tài khoản của chính mình; không mua bán hay cho thuê tài khoản.', 'Không cần tài khoản vẫn dùng được phần lớn tính năng; dữ liệu khi đó chỉ nằm trên máy bạn.'])],
        ['Quỹ chung', P('Quỹ chung là <b>sổ ghi chép chung</b> cho nhóm do bạn tự mời bằng mã. Tiền thật nằm trong tài khoản ngân hàng hoặc tiền mặt của thủ quỹ, không nằm ở VieTing.') + L(['Các công cụ như ảnh chứng từ, AI kiểm tra ảnh, đối chiếu số dư, kết nối ngân hàng qua SePay giúp nhóm minh bạch hơn nhưng <b>không bảo đảm</b> không ai gian lận.', 'Tranh chấp tiền giữa các thành viên là việc giữa các thành viên; chúng tôi không phải bên giữ tiền hay bên bảo lãnh.', 'Chỉ ghi những khoản có thật, không dùng ảnh giả hoặc ảnh đã chỉnh sửa.'])],
        ['Trợ lý AI và tính năng đọc ảnh', P('Câu trả lời của trợ lý AI, kết quả đọc hóa đơn và kiểm tra ảnh do máy tạo ra nên <b>có thể sai</b>. Hãy kiểm tra lại trước khi dựa vào. Đây chỉ là gợi ý về chi tiêu, <b>không phải tư vấn tài chính, đầu tư, thuế hay pháp lý</b>.') + P('Đừng gửi cho trợ lý mật khẩu, mã OTP, số thẻ hoặc số tài khoản đầy đủ. Cách dữ liệu gửi AI được xử lý nằm trong <a href="/chinh-sach-rieng-tu">Chính sách quyền riêng tư</a>.')],
        ['VieTing Pro, dùng thử và mã khuyến mãi', L(['Các tính năng cơ bản (ghi chép, đọc thông báo ngân hàng, ví, ngân sách, nhắc nhở, xuất CSV…) luôn miễn phí.', 'Tài khoản mới được dùng thử Pro 7 ngày. Mã khuyến mãi cộng thêm ngày Pro, không đổi được ra tiền và không chuyển nhượng.', 'Khi có bán Pro qua Google Play / App Store, giá, gia hạn, hủy và hoàn tiền theo chính sách của cửa hàng đó và được hiện rõ trước khi bạn trả tiền.', 'Hạn mức dùng AI mỗi ngày có thể thay đổi để giữ dịch vụ ổn định.'])],
        ['Không được làm', L(['Dùng VieTing cho việc trái pháp luật, lừa đảo, rửa tiền hoặc gom tiền trái phép.', 'Tải lên nội dung vi phạm pháp luật, xúc phạm người khác, hoặc ảnh không phải của mình mà không được phép.', 'Tấn công, dò lỗi trái phép, gửi quá nhiều yêu cầu, hoặc cố lách hạn mức AI.', 'Sao chép, bán lại hoặc làm app giả mạo VieTing.'])],
        ['Dữ liệu và quyền riêng tư', P('Dữ liệu bạn ghi là của bạn. Bạn có thể xuất ra file CSV, xóa trên máy, hoặc <a href="/xoa-tai-khoan">xóa tài khoản</a> bất cứ lúc nào. Chi tiết thu thập và chia sẻ dữ liệu nằm trong <a href="/chinh-sach-rieng-tu">Chính sách quyền riêng tư</a>.')],
        ['Tạm ngừng và chấm dứt', P('Bạn có thể ngừng dùng và xóa tài khoản bất cứ lúc nào. Chúng tôi có thể khóa tài khoản vi phạm các điều khoản này, có thông báo lý do khi có thể. Dịch vụ có thể tạm gián đoạn để bảo trì hoặc vì sự cố của nhà cung cấp hạ tầng.')],
        ['Giới hạn trách nhiệm', P('VieTing được cung cấp "như hiện có". Trong phạm vi pháp luật cho phép, chúng tôi không chịu trách nhiệm cho thiệt hại phát sinh từ: số liệu ghi sai hoặc thiếu, ứng dụng ngân hàng đổi mẫu thông báo, câu trả lời sai của AI, mất dữ liệu trên máy chưa đồng bộ, hay tranh chấp giữa các thành viên Quỹ chung. Điều này không làm mất các quyền của người tiêu dùng mà pháp luật không cho phép loại trừ.')],
        ['Thay đổi điều khoản', P('Khi điều khoản thay đổi đáng kể, chúng tôi báo trong app hoặc trên trang này và ghi ngày cập nhật ở đầu trang. Tiếp tục dùng sau khi thay đổi có hiệu lực nghĩa là bạn đồng ý với bản mới.')],
        ['Luật áp dụng và liên hệ', P('Các điều khoản này theo pháp luật Việt Nam. Mọi câu hỏi hoặc khiếu nại, liên hệ qua ' + reach + '.')],
      ],
    };
  return {
    title: 'Terms of Service',
    kick: 'Applies to VieTing on Android, iPhone, Windows and the web',
    lead: 'This is the agreement between you and VieTing when you use the app. Please read it: by using VieTing you agree to these terms.',
    updated: 'Updated ' + UPDATED.en,
    chips: [
      ['bank', '#152758', 'We never hold money', 'VieTing only keeps records'],
      ['shield', '#C1272C', '18+ only', 'Made for adults'],
      ['lock', '#3E8E41', 'Your data is yours', 'Export or delete anytime'],
      ['ban', '#B07A00', 'Not advice', 'The AI assistant is for reference'],
    ],
    sections: [
      ['What the service is', P('VieTing is a personal expense-tracking app developed by <b>Phạm Thành Long</b> ("we"). It helps you record transactions (manually or from bank notifications if you allow it), set budgets and savings goals, keep a shared ledger with people you invite (Shared funds) and ask an AI assistant about your spending.') + P('VieTing is <b>not a bank or e-wallet</b>: it does not hold money, transfer money, lend, or sign in to your bank. Any transfer is made by you in your own banking app.')],
      ['Who may use it', P('You must be at least <b>18 years old</b>. When signing up by email you provide your real birth year. If we learn an account belongs to someone under 18, it may be deleted.')],
      ['Your account', L(['You are responsible for keeping your password and device safe. You can turn on a PIN / fingerprint lock in the app.', 'The details you provide (email, name, birth year) must be your own.', 'Use only your own account; do not sell or rent accounts.', 'Most features work without an account; your data then stays on your device only.'])],
      ['Shared funds', P('A Shared fund is a <b>shared ledger</b> for a group you invite with a code. The actual money sits in the treasurer\'s bank account or cash, not with VieTing.') + L(['Tools such as proof photos, AI photo checks, balance reconciliation and bank connection via SePay make the group more transparent but <b>do not guarantee</b> that nobody cheats.', 'Money disputes between members are between the members; we are not a custodian or guarantor.', 'Only record real transactions and never use fake or edited photos.'])],
      ['AI assistant and photo reading', P('Answers from the AI assistant, receipt reading and photo checks are machine-generated and <b>can be wrong</b>. Check them before relying on them. They are spending tips only, <b>not financial, investment, tax or legal advice</b>.') + P('Do not send the assistant passwords, OTP codes, card numbers or full account numbers. How data sent to AI is handled is described in the <a href="/privacy">Privacy policy</a>.')],
      ['VieTing Pro, trials and promo codes', L(['Core features (recording, reading bank notifications, wallets, budgets, reminders, CSV export…) are always free.', 'New accounts get a 7-day Pro trial. Promo codes add Pro days; they have no cash value and cannot be transferred.', 'When Pro is sold through Google Play / the App Store, pricing, renewal, cancellation and refunds follow that store\'s policies and are shown clearly before you pay.', 'Daily AI limits may change to keep the service stable.'])],
      ['What you must not do', L(['Use VieTing for anything illegal, fraud, money laundering or unlawful fundraising.', 'Upload unlawful or abusive content, or photos that are not yours without permission.', 'Attack the service, probe it without permission, flood it with requests or try to bypass AI limits.', 'Copy, resell or create look-alike versions of VieTing.'])],
      ['Data and privacy', P('The data you record is yours. You can export it to CSV, delete it from your device, or <a href="/delete-account">delete your account</a> at any time. What we collect and share is described in the <a href="/privacy">Privacy policy</a>.')],
      ['Suspension and termination', P('You may stop using VieTing and delete your account at any time. We may lock accounts that break these terms, giving a reason when we can. The service may be interrupted for maintenance or because of an infrastructure provider outage.')],
      ['Limitation of liability', P('VieTing is provided "as is". To the extent permitted by law, we are not liable for losses caused by: wrong or missing records, banking apps changing their notification format, incorrect AI answers, loss of unsynced data on a device, or disputes between Shared fund members. This does not remove consumer rights that the law does not allow to be excluded.')],
      ['Changes to these terms', P('When these terms change significantly we will tell you in the app or on this page and update the date at the top. Continuing to use VieTing after a change takes effect means you accept the new version.')],
      ['Governing law and contact', P('These terms are governed by the laws of Vietnam. For any question or complaint, contact us via ' + reach + '.')],
    ],
  };
}

function privacyPage(lang, contact) {
  return docPage(lang, content(lang, contact), { vi: '/chinh-sach-rieng-tu', en: '/privacy' });
}

function termsPage(lang, contact) {
  return docPage(lang, terms(lang, contact), { vi: '/dieu-khoan', en: '/terms' });
}

function docPage(lang, c, alt) {
  const vi = lang === 'vi';
  const inner = `
<header class="hero"><div class="w">
  <span class="kick">${svg('shield', 16)} ${c.kick}</span>
  <h1>${c.title}</h1>
  <p>${c.lead}</p>
  <p style="margin-top:14px;font-size:14px;color:rgba(255,255,255,.6)">${c.updated}</p>
</div></header>
<div class="w">
  <div class="chips">${c.chips
    .map(([ic, col, b, s]) => `<div class="chip"><i style="background:${col}1A;color:${col}">${svg(ic)}</i><b>${b}</b><span>${s}</span></div>`)
    .join('')}</div>
  <div class="grid">
    <aside class="toc"><b>${vi ? 'MỤC LỤC' : 'CONTENTS'}</b>${c.sections.map((s, i) => `<a href="#s${i + 1}"><em>${i + 1}</em>${s[0]}</a>`).join('')}</aside>
    <main>${c.sections.map((s, i) => `<section id="s${i + 1}"><h2><em>${i + 1}</em>${s[0]}</h2>${s[1]}</section>`).join('')}</main>
  </div>
</div>`;
  return shell(lang, c.title, alt, inner);
}

function deletePage(lang) {
  const vi = lang === 'vi';
  const t = vi
    ? {
        title: 'Xóa tài khoản VieTing',
        lead: 'Xóa vĩnh viễn tài khoản cùng toàn bộ dữ liệu trên server: sổ thu chi, ví, mục tiêu, cài đặt, lịch sử trò chuyện với trợ lý, góp ý và tư cách thành viên trong các quỹ chung.',
        items: [
          'Trong quỹ chung, các khoản bạn đã ghi ở lại cho thành viên khác đối chiếu, tên bạn được thay bằng "Thành viên cũ"; ảnh chứng từ bạn tải lên bị xóa.',
          'Bản sao lưu tự động hết hạn trong tối đa 30 ngày.',
          'Không thể hoàn tác.',
        ],
        inapp: 'Cũng có thể xóa ngay trong app: <b>Cài đặt → Quyền riêng tư → Xóa tài khoản</b>.',
        email: 'Email',
        pw: 'Mật khẩu',
        btn: 'Xóa vĩnh viễn tài khoản',
        confirm: 'Xóa vĩnh viễn tài khoản và toàn bộ dữ liệu? Không thể hoàn tác.',
        busy: 'Đang xóa...',
        ok: 'Đã xóa tài khoản và toàn bộ dữ liệu.',
        fail: 'Không xóa được',
        net: 'Lỗi mạng, thử lại sau.',
      }
    : {
        title: 'Delete your VieTing account',
        lead: 'Permanently delete your account and all of its data on our server: ledger, wallets, goals, settings, assistant chat history, feedback and your membership in shared funds.',
        items: [
          'In shared funds, entries you recorded stay so other members can reconcile, with your name replaced by "Former member"; proof photos you uploaded are deleted.',
          'Automatic backups expire within at most 30 days.',
          'This cannot be undone.',
        ],
        inapp: 'You can also delete it in the app: <b>Settings → Privacy → Delete account</b>.',
        email: 'Email',
        pw: 'Password',
        btn: 'Permanently delete account',
        confirm: 'Permanently delete your account and all data? This cannot be undone.',
        busy: 'Deleting...',
        ok: 'Your account and all data have been deleted.',
        fail: 'Could not delete the account',
        net: 'Network error, please try again.',
      };
  const inner = `
<header class="hero"><div class="w">
  <span class="kick">${svg('trash', 16)} ${vi ? 'Tài khoản & dữ liệu' : 'Account & data'}</span>
  <h1>${t.title}</h1><p>${t.lead}</p>
</div></header>
<div class="w" style="max-width:760px;margin-top:-58px;position:relative;z-index:2;padding-bottom:70px">
  <section>
    <ul>${t.items.map((x) => `<li>${x}</li>`).join('')}</ul>
    <p>${t.inapp}</p>
    <form id="f" style="margin-top:18px">
      <label>${t.email}</label><input id="e" type="email" required autocomplete="username">
      <label>${t.pw}</label><input id="p" type="password" required autocomplete="current-password">
      <button class="btn">${svg('trash', 18)} ${t.btn}</button>
      <div id="msg"></div>
    </form>
  </section>
</div>
<script>
document.getElementById('f').onsubmit = async (ev) => {
  ev.preventDefault();
  const m = document.getElementById('msg');
  if (!confirm(${JSON.stringify(t.confirm)})) return;
  m.style.color = '#6E6A63'; m.textContent = ${JSON.stringify(t.busy)};
  try {
    const r = await fetch('/api/account/delete', { method: 'POST', headers: { 'content-type': 'application/json', 'accept-language': '${lang}' },
      body: JSON.stringify({ email: document.getElementById('e').value, password: document.getElementById('p').value }) });
    const j = await r.json();
    m.style.color = r.ok ? '#2E7D32' : '#C1272C';
    m.textContent = r.ok ? ${JSON.stringify(t.ok)} : (j.error || ${JSON.stringify(t.fail)});
  } catch (e) { m.style.color = '#C1272C'; m.textContent = ${JSON.stringify(t.net)}; }
};
</script>`;
  return shell(lang, t.title, { vi: '/xoa-tai-khoan', en: '/delete-account' }, inner);
}

/** Xóa tài khoản và dữ liệu của userId. */
async function wipe(env, userId) {
  const D = env.DB;
  const run = (sql, ...a) => D.prepare(sql).bind(...a).run().catch(() => null);
  // quỹ chung: rời quỹ; quỹ không còn ai thì xóa cả quỹ
  const spaces = ((await D.prepare('SELECT space_id FROM space_members WHERE user_id = ?').bind(userId).all().catch(() => ({ results: [] }))).results || []).map((r) => r.space_id);
  for (const sid of spaces) {
    await run('DELETE FROM space_members WHERE space_id = ? AND user_id = ?', sid, userId);
    const left = (await D.prepare('SELECT COUNT(*) AS n FROM space_members WHERE space_id = ?').bind(sid).first())?.n || 0;
    if (!left) {
      for (const t of ['space_records', 'space_marks', 'space_log', 'space_proofs', 'space_settings', 'space_proof_keys', 'space_bank', 'space_bank_txns']) {
        await run(`DELETE FROM ${t} WHERE space_id = ?`, sid);
      }
      await run('DELETE FROM spaces WHERE id = ?', sid);
    } else {
      // ảnh chứng từ của người này bị xóa; khoản đã ghi ở lại (tên hiển thị thành "Thành viên cũ")
      await run('DELETE FROM space_proofs WHERE space_id = ? AND rec_id IN (SELECT id FROM space_records WHERE space_id = ? AND by_user = ?)', sid, sid, userId);
      await run('DELETE FROM space_bank WHERE space_id = ? AND linked_by = ?', sid, userId);
      await run(
        "INSERT INTO space_log (space_id, at, by_user, rec_id, action, text) VALUES (?, ?, ?, '', 'leave', 'Một thành viên đã xóa tài khoản và rời quỹ')",
        sid,
        Date.now(),
        userId
      );
    }
  }
  await run('DELETE FROM records WHERE user_id = ?', userId);
  await run('DELETE FROM sessions WHERE user_id = ?', userId);
  await run('DELETE FROM tickets WHERE user_id = ?', userId);
  await run('DELETE FROM ocr_reports WHERE user_id = ?', userId);
  await run('DELETE FROM voucher_uses WHERE user_id = ?', userId);
  await run('DELETE FROM plans WHERE user_id = ?', userId);
  await run('DELETE FROM ai_usage WHERE k LIKE ? OR k LIKE ? OR k = ?', `%:u${userId}`, `%u${userId}:%`, `u${userId}`);
  await run('DELETE FROM pw_reset WHERE email = (SELECT email FROM users WHERE id = ?)', userId);
  await run('DELETE FROM users WHERE id = ?', userId);
}

/** GET /chinh-sach-rieng-tu, /privacy, /xoa-tai-khoan, /delete-account · POST /api/account/delete */
export async function handleLegal(req, env, url, h) {
  const p = url.pathname.replace(/\/+$/, '');
  const html = (s) => new Response(s, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=600' } });
  if (req.method === 'GET') {
    if (p === '/chinh-sach-rieng-tu') return html(privacyPage('vi', env.CONTACT_EMAIL || ''));
    if (p === '/privacy' || p === '/privacy-policy') return html(privacyPage('en', env.CONTACT_EMAIL || ''));
    if (p === '/dieu-khoan' || p === '/dieu-khoan-dich-vu') return html(termsPage('vi', env.CONTACT_EMAIL || ''));
    if (p === '/terms' || p === '/terms-of-service') return html(termsPage('en', env.CONTACT_EMAIL || ''));
    if (p === '/xoa-tai-khoan') return html(deletePage('vi'));
    if (p === '/delete-account') return html(deletePage('en'));
    return null;
  }
  if (req.method === 'POST' && p === '/api/account/delete') {
    const en = /^en/i.test(req.headers.get('accept-language') || '');
    const b = await h.readJson(req);
    // trong app: đã đăng nhập + nhập lại mật khẩu; trên web: email + mật khẩu
    let u = null;
    const me = await h.auth(req, env);
    if (me != null) u = await env.DB.prepare('SELECT id, salt, hash, nopw FROM users WHERE id = ?').bind(me).first().catch(() => null)
      || await env.DB.prepare('SELECT id, salt, hash FROM users WHERE id = ?').bind(me).first();
    else {
      const email = String(b?.email || '').trim().toLowerCase();
      u = await env.DB.prepare('SELECT id, salt, hash FROM users WHERE email = ?').bind(email).first();
    }
    const pw = String(b?.password || '');
    // tài khoản tạo bằng Google chưa đặt mật khẩu: đã đăng nhập trong app là đủ (app hỏi gõ lại email để xác nhận)
    const googleOnly = me != null && u && u.nopw === 1 && String(b?.confirm || '') === 'delete';
    if (!googleOnly && (!u || !pw || !h.safeEqual(await h.hashPassword(pw, u.salt), u.hash))) {
      return h.json({ error: en ? 'Wrong email or password' : 'Sai email hoặc mật khẩu' }, 401);
    }
    await wipe(env, u.id);
    return h.json({ ok: true });
  }
  return null;
}
