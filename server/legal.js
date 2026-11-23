// Chính sách quyền riêng tư (/chinh-sach-rieng-tu, /privacy) và xóa tài khoản (/xoa-tai-khoan, POST /api/account/delete).
// Trang công khai, không cần đăng nhập, theo yêu cầu của Google Play.
// Tác giả: Phạm Thành Long (thlong)

const UPDATED = '23/11/2026';

const page = (title, body) => `<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · VieTing</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;600;800&display=swap" rel="stylesheet">
<style>
  :root{--red:#C1272C;--navy:#152758;--paper:#F7F3EC}
  *{box-sizing:border-box} body{margin:0;background:var(--paper);color:#1d1d1f;font:16px/1.7 'Be Vietnam Pro',system-ui,sans-serif}
  header{background:var(--navy);color:#fff;padding:28px 20px}
  header .in,main{max-width:820px;margin:0 auto}
  header a{color:#fff;text-decoration:none;font-weight:800;font-size:22px} header a span{color:#ff8a83}
  h1{font-size:32px;line-height:1.25;margin:34px 0 6px;color:var(--navy)}
  h2{font-size:21px;margin:34px 0 8px;color:var(--navy)}
  h3{font-size:17px;margin:20px 0 4px}
  main{padding:0 20px 60px} .muted{color:#6b6b70;font-size:14px}
  .box{background:#fff;border-radius:16px;padding:18px 22px;margin:14px 0;box-shadow:0 4px 18px rgba(21,39,88,.06)}
  table{width:100%;border-collapse:collapse;background:#fff;border-radius:14px;overflow:hidden;font-size:15px}
  th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #eee;vertical-align:top} th{background:#eef0f6;color:var(--navy)}
  a{color:var(--red)} li{margin:4px 0}
  input{width:100%;padding:12px 14px;border:1px solid #ccc;border-radius:12px;font:inherit;margin:6px 0 12px}
  button{background:var(--red);color:#fff;border:0;border-radius:12px;padding:13px 22px;font:inherit;font-weight:800;cursor:pointer}
  #msg{margin-top:14px;font-weight:600}
</style></head><body>
<header><div class="in"><a href="/tai-app">Vie<span>Ting</span></a></div></header>
<main>${body}</main></body></html>`;

function privacyHtml(contact) {
  const reach = contact
    ? `email <a href="mailto:${contact}">${contact}</a> hoặc mục <b>Cài đặt → Góp ý &amp; hỗ trợ</b> trong app`
    : `mục <b>Cài đặt → Góp ý &amp; hỗ trợ</b> trong app`;
  return page(
    'Chính sách quyền riêng tư',
    `
<h1>Chính sách quyền riêng tư</h1>
<p class="muted">Áp dụng cho ứng dụng VieTing (Android, iPhone, Windows) và trang vieting.phamthanhlong-contact.workers.dev · Cập nhật: ${UPDATED}</p>

<div class="box">
<b>Tóm tắt:</b> VieTing là ứng dụng ghi chép và quản lý chi tiêu cá nhân. Chúng tôi chỉ thu thập dữ liệu cần để app hoạt động
(tài khoản, sổ thu chi bạn ghi, nội dung bạn gửi cho trợ lý AI). Chúng tôi <b>không bán dữ liệu</b>, <b>không hiển thị quảng cáo</b>,
<b>không giữ tiền</b> và <b>không đăng nhập vào tài khoản ngân hàng</b> của bạn. Bạn có thể xóa tài khoản và toàn bộ dữ liệu bất cứ lúc nào.
</div>

<h2>1. Ai chịu trách nhiệm về dữ liệu</h2>
<p>VieTing do cá nhân Phạm Thành Long phát triển và vận hành ("chúng tôi"). Mọi câu hỏi về quyền riêng tư, liên hệ qua ${reach}.</p>

<h2>2. Dữ liệu chúng tôi thu thập</h2>
<table>
<tr><th>Loại dữ liệu</th><th>Cụ thể</th><th>Khi nào</th></tr>
<tr><td>Tài khoản</td><td>Email, mật khẩu (chỉ lưu dạng băm PBKDF2 có muối, chúng tôi không đọc được mật khẩu), tên hiển thị trong quỹ chung, thời điểm tạo tài khoản</td><td>Khi bạn đăng ký</td></tr>
<tr><td>Dữ liệu tài chính bạn ghi</td><td>Giao dịch thu chi (số tiền, danh mục, ghi chú, ngày, ví), ví và số dư, ngân sách, mục tiêu tiết kiệm, hóa đơn định kỳ, danh sách mong muốn, cài đặt của bạn</td><td>Khi bạn ghi; được đồng bộ lên server để dùng trên nhiều máy</td></tr>
<tr><td>Thông báo ngân hàng / ví (chỉ Android, chỉ khi bạn bật)</td><td>App đọc thông báo trên máy để tự ghi giao dịch. Chỉ thông báo có số tiền được xử lý; phần nội dung thông báo đó (tên app gửi, tiêu đề, nội dung như "−45.000 VND · SD ...") được lưu kèm giao dịch. Thông báo khác bị bỏ qua ngay trên máy và không gửi đi đâu.</td><td>Khi bạn cấp quyền "Truy cập thông báo"</td></tr>
<tr><td>Ảnh</td><td>Ảnh hóa đơn, ảnh chuyển khoản bạn chụp hoặc chọn để AI đọc; ảnh chứng từ trong Quỹ chung</td><td>Chỉ khi bạn chủ động gửi</td></tr>
<tr><td>Nội dung gửi trợ lý AI</td><td>Tin nhắn, ảnh, đoạn văn bản bạn dán (VD tin nhắn chuyển khoản), kèm bản tóm tắt sổ của bạn (số dư, chi tiêu gần đây) để AI trả lời đúng</td><td>Khi bạn dùng trợ lý, đọc hóa đơn, dán giao dịch</td></tr>
<tr><td>Quỹ chung</td><td>Các khoản nộp / chi, ảnh chứng từ, xác nhận, duyệt, nhật ký sửa / xóa, thông tin tài khoản nhận quỹ (ngân hàng, số tài khoản, tên chủ tài khoản) do thủ quỹ nhập</td><td>Khi bạn tạo hoặc tham gia quỹ</td></tr>
<tr><td>Kết nối ngân hàng qua SePay (tùy chọn, chỉ thủ quỹ)</td><td>Khóa truy cập SePay (lưu trên server, không gửi về app của ai) và giao dịch của <b>tài khoản quỹ</b> (số tiền, nội dung, thời gian, số dư sau giao dịch)</td><td>Chỉ khi thủ quỹ tự nối</td></tr>
<tr><td>Hỗ trợ</td><td>Nội dung góp ý / báo lỗi, thông tin liên hệ bạn tự ghi, báo cáo "AI đọc sai" (số AI đọc và số bạn sửa, không kèm ảnh)</td><td>Khi bạn gửi</td></tr>
<tr><td>Dữ liệu kỹ thuật</td><td>Mã phiên đăng nhập, số lượt dùng AI mỗi ngày / tháng (để áp hạn mức), thời điểm đồng bộ, phiên bản app</td><td>Khi bạn dùng app</td></tr>
</table>
<p>Chúng tôi <b>không</b> thu thập: danh bạ, vị trí, mật khẩu hay mã OTP ngân hàng, số thẻ, dữ liệu sinh trắc học, mã quảng cáo. App không có quảng cáo và không dùng SDK theo dõi / phân tích của bên thứ ba.</p>

<h3>Quyền trên thiết bị</h3>
<ul>
<li><b>Truy cập thông báo</b> (Android): để tự ghi giao dịch từ thông báo ngân hàng, ví. Tắt được bất cứ lúc nào trong Cài đặt của điện thoại.</li>
<li><b>Máy ảnh, thư viện ảnh</b>: chỉ khi bạn chụp / chọn ảnh hóa đơn, chứng từ.</li>
<li><b>Micro</b>: khi bạn ghi giao dịch bằng giọng nói. Việc nhận dạng giọng nói do dịch vụ của hệ điều hành (Google trên Android, Apple trên iPhone) thực hiện theo chính sách của họ; VieTing chỉ nhận lại văn bản.</li>
<li><b>Vân tay / Face ID</b>: để khóa app. Việc xác thực diễn ra hoàn toàn trên máy, VieTing không nhận dữ liệu sinh trắc học.</li>
<li><b>Thông báo, báo thức</b>: để nhắc ghi chép, nhắc hóa đơn và hiện tin của quỹ chung. App tự hỏi server khoảng 30 phút một lần, không dùng dịch vụ đẩy tin của bên thứ ba.</li>
</ul>

<h2>3. Chúng tôi dùng dữ liệu để làm gì</h2>
<ul>
<li>Cung cấp tính năng: lưu và đồng bộ sổ thu chi, thống kê, nhắc nhở, mục tiêu, quỹ chung, kiểm tra chứng từ.</li>
<li>Trợ lý AI: trả lời câu hỏi, đọc hóa đơn, tách giao dịch từ văn bản.</li>
<li>Bảo mật và chống lạm dụng: đăng nhập, hạn mức AI, phát hiện ảnh chứng từ dùng lại.</li>
<li>Hỗ trợ và cải thiện app: trả lời góp ý, sửa lỗi nhận diện (từ báo cáo "AI đọc sai" bạn gửi).</li>
</ul>
<p>Chúng tôi không dùng dữ liệu tài chính của bạn để quảng cáo, chấm điểm tín dụng hay bán cho bất kỳ ai.</p>

<h2>4. Chia sẻ dữ liệu với ai</h2>
<table>
<tr><th>Bên nhận</th><th>Loại bên</th><th>Dữ liệu</th><th>Mục đích</th></tr>
<tr><td>Cloudflare, Inc.</td><td>Nhà cung cấp hạ tầng (máy chủ, cơ sở dữ liệu, AI dự phòng)</td><td>Toàn bộ dữ liệu được lưu trên server của VieTing; nội dung gửi AI khi dịch vụ chính quá tải</td><td>Lưu trữ, đồng bộ, chạy AI dự phòng (Workers AI)</td></tr>
<tr><td>Google LLC (Gemini API)</td><td>Nhà cung cấp dịch vụ AI</td><td>Tin nhắn, ảnh, văn bản bạn gửi cho trợ lý và bản tóm tắt sổ kèm theo; ảnh hóa đơn / chứng từ</td><td>Tạo câu trả lời, đọc ảnh. Lưu ý: VieTing đang dùng gói Gemini API không trả phí; theo điều khoản của Google, nội dung gửi qua gói này có thể được Google dùng để cải thiện sản phẩm và có thể được người kiểm duyệt của Google xem. Đừng gửi cho trợ lý thông tin bạn không muốn chia sẻ (số tài khoản đầy đủ, mã OTP, mật khẩu).</td></tr>
<tr><td>SePay</td><td>Dịch vụ đọc giao dịch ngân hàng (tùy chọn)</td><td>VieTing dùng khóa thủ quỹ cấp để đọc giao dịch của tài khoản quỹ</td><td>Xác thực tiền vào / ra của Quỹ chung</td></tr>
<tr><td>Các thành viên cùng Quỹ chung</td><td>Người dùng khác do bạn mời / chấp nhận</td><td>Tên hiển thị (hoặc phần trước @ của email), các khoản bạn nộp / chi trong quỹ, ảnh chứng từ, xác nhận, nhật ký</td><td>Minh bạch quỹ chung</td></tr>
<tr><td>Cơ quan nhà nước có thẩm quyền</td><td>Theo yêu cầu pháp luật</td><td>Phần dữ liệu được yêu cầu hợp pháp</td><td>Tuân thủ pháp luật Việt Nam</td></tr>
</table>
<p>Ngoài các trường hợp trên, chúng tôi không chia sẻ, cho thuê hay bán dữ liệu của bạn.</p>

<h2>5. Lưu trữ và bảo mật</h2>
<ul>
<li>Dữ liệu được lưu trên hạ tầng Cloudflare, có thể đặt ở nhiều quốc gia. Kết nối giữa app và server luôn được mã hóa (HTTPS).</li>
<li>Mật khẩu chỉ lưu dạng băm; khóa SePay chỉ nằm trên server; ảnh chứng từ chỉ thành viên trong quỹ xem được.</li>
<li>Không có hệ thống nào an toàn tuyệt đối; nếu có sự cố lộ dữ liệu ảnh hưởng tới bạn, chúng tôi sẽ thông báo trong app.</li>
</ul>

<h2>6. Giữ dữ liệu bao lâu</h2>
<ul>
<li>Dữ liệu tài khoản và sổ thu chi được giữ đến khi bạn xóa tài khoản.</li>
<li>Bộ đếm lượt dùng AI được giữ ngắn hạn để tính hạn mức.</li>
<li>Khi bạn xóa tài khoản, dữ liệu bị xóa khỏi cơ sở dữ liệu ngay; bản sao lưu tự động của nhà cung cấp hạ tầng tự hết hạn trong tối đa 30 ngày.</li>
<li>Trong Quỹ chung: các khoản bạn đã ghi vẫn ở lại sổ của quỹ để các thành viên khác đối chiếu, nhưng tên bạn được thay bằng "Thành viên cũ"; ảnh chứng từ bạn tải lên bị xóa.</li>
</ul>

<h2>7. Quyền của bạn</h2>
<ul>
<li><b>Xem, sửa</b> dữ liệu ngay trong app.</li>
<li><b>Xuất dữ liệu</b>: Cài đặt → Xuất CSV.</li>
<li><b>Rút lại đồng ý</b>: tắt quyền truy cập thông báo, máy ảnh, micro trong Cài đặt điện thoại; ngắt kết nối ngân hàng của quỹ; ngừng dùng trợ lý AI.</li>
<li><b>Xóa tài khoản và toàn bộ dữ liệu</b>: trong app (Cài đặt → Xóa tài khoản) hoặc tại <a href="/xoa-tai-khoan">trang xóa tài khoản</a>.</li>
<li>Khiếu nại hoặc yêu cầu khác theo quy định pháp luật Việt Nam về bảo vệ dữ liệu cá nhân: liên hệ qua ${reach}. Chúng tôi phản hồi trong vòng 15 ngày.</li>
</ul>

<h2>8. Trẻ em</h2>
<p>VieTing không dành cho người dưới 16 tuổi và không cố ý thu thập dữ liệu của trẻ em. Nếu bạn biết một trẻ em đã tạo tài khoản, hãy báo để chúng tôi xóa.</p>

<h2>9. Thay đổi chính sách</h2>
<p>Khi chính sách thay đổi, chúng tôi cập nhật ngày ở đầu trang và thông báo trong app với các thay đổi quan trọng.</p>
`
  );
}

function deleteHtml() {
  return page(
    'Xóa tài khoản',
    `
<h1>Xóa tài khoản VieTing</h1>
<p>Nhập email và mật khẩu tài khoản VieTing để xóa vĩnh viễn tài khoản cùng toàn bộ dữ liệu: sổ thu chi, ví, mục tiêu, cài đặt,
lịch sử trò chuyện với trợ lý, góp ý và thành viên trong các quỹ chung. Trong quỹ chung, các khoản bạn đã ghi vẫn ở lại cho thành viên khác
đối chiếu nhưng tên bạn được thay bằng "Thành viên cũ"; ảnh chứng từ bạn tải lên bị xóa. Bản sao lưu tự hết hạn trong tối đa 30 ngày.
Không thể hoàn tác.</p>
<p>Cũng có thể xóa ngay trong app: <b>Cài đặt → Xóa tài khoản</b>.</p>
<div class="box">
<form id="f">
<label>Email</label><input id="e" type="email" required autocomplete="username">
<label>Mật khẩu</label><input id="p" type="password" required autocomplete="current-password">
<button>Xóa vĩnh viễn tài khoản</button>
<div id="msg"></div>
</form>
</div>
<p class="muted">Xem <a href="/chinh-sach-rieng-tu">chính sách quyền riêng tư</a>.</p>
<script>
document.getElementById('f').onsubmit = async (ev) => {
  ev.preventDefault();
  const m = document.getElementById('msg');
  if (!confirm('Xóa vĩnh viễn tài khoản và toàn bộ dữ liệu? Không thể hoàn tác.')) return;
  m.textContent = 'Đang xóa...';
  try {
    const r = await fetch('/api/account/delete', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: document.getElementById('e').value, password: document.getElementById('p').value }) });
    const j = await r.json();
    m.style.color = r.ok ? '#2e7d32' : '#C1272C';
    m.textContent = r.ok ? 'Đã xóa tài khoản và toàn bộ dữ liệu.' : (j.error || 'Không xóa được');
  } catch (e) { m.style.color = '#C1272C'; m.textContent = 'Lỗi mạng, thử lại sau.'; }
};
</script>`
  );
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
  await run("DELETE FROM ai_usage WHERE k LIKE ? OR k LIKE ? OR k = ?", `%:u${userId}`, `%u${userId}:%`, `u${userId}`);
  await run('DELETE FROM users WHERE id = ?', userId);
}

/** GET /chinh-sach-rieng-tu, /privacy, /xoa-tai-khoan · POST /api/account/delete */
export async function handleLegal(req, env, url, h) {
  const p = url.pathname.replace(/\/+$/, '');
  const html = (s) => new Response(s, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=600' } });
  if (req.method === 'GET' && (p === '/chinh-sach-rieng-tu' || p === '/privacy')) return html(privacyHtml(env.CONTACT_EMAIL || ''));
  if (req.method === 'GET' && (p === '/xoa-tai-khoan' || p === '/delete-account')) return html(deleteHtml());
  if (req.method === 'POST' && p === '/api/account/delete') {
    const b = await h.readJson(req);
    // trong app: đã đăng nhập + nhập lại mật khẩu; trên web: email + mật khẩu
    let u = null;
    const me = await h.auth(req, env);
    if (me != null) u = await env.DB.prepare('SELECT id, salt, hash FROM users WHERE id = ?').bind(me).first();
    else {
      const email = String(b?.email || '').trim().toLowerCase();
      u = await env.DB.prepare('SELECT id, salt, hash FROM users WHERE email = ?').bind(email).first();
    }
    const pw = String(b?.password || '');
    if (!u || !pw || !h.safeEqual(await h.hashPassword(pw, u.salt), u.hash)) return h.json({ error: 'Sai email hoặc mật khẩu' }, 401);
    await wipe(env, u.id);
    return h.json({ ok: true });
  }
  return null;
}
