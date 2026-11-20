#!/usr/bin/env node
// Cắt các file cài trong dist/ thành phần 20 MB vào server/site/files/ + ghi manifest.json để đưa lên Cloudflare.
// Dùng: node tools/pack-cloudflare.js [thư-mục-chứa-file-cài] [phiên-bản]
// Tác giả: Phạm Thành Long (thlong)
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const SRC = path.resolve(process.argv[2] || path.join(ROOT, 'dist'));
const pub = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const VER = process.argv[3] || ((/^version:\s*([^+\s]+)/m.exec(pub) || [])[1] || '');
const SITE = path.join(ROOT, 'server', 'site'), FILES = path.join(SITE, 'files');
const PART = 20 * 1024 * 1024;
const MAP = {
  android: ['VieTing.apk', 'application/vnd.android.package-archive'],
  windows: ['VieTing-Setup.exe', 'application/vnd.microsoft.portable-executable'],
  'windows-portable': ['VieTing-Windows-portable.zip', 'application/zip'],
  ios: ['VieTing.ipa', 'application/octet-stream'],
};
fs.rmSync(FILES, { recursive: true, force: true });
fs.mkdirSync(FILES, { recursive: true });
const man = { version: VER, built: Date.now(), files: {} };
for (const [key, [name, type]] of Object.entries(MAP)) {
  const src = path.join(SRC, name);
  if (!fs.existsSync(src)) { console.log('  (bỏ qua, chưa có)', name); continue; }
  const size = fs.statSync(src).size, dir = path.join(FILES, key);
  fs.mkdirSync(dir, { recursive: true });
  const fd = fs.openSync(src, 'r'), buf = Buffer.alloc(PART);
  let i = 0;
  for (let off = 0; off < size; off += PART, i++) {
    const n = fs.readSync(fd, buf, 0, PART, off);
    fs.writeFileSync(path.join(dir, String(i).padStart(3, '0') + '.bin'), buf.subarray(0, n));
  }
  fs.closeSync(fd);
  man.files[key] = { name, type, size, partSize: PART, parts: i };
  console.log(`  ${name}: ${(size / 1048576).toFixed(1)} MB, ${i} phần`);
}
fs.writeFileSync(path.join(SITE, 'manifest.json'), JSON.stringify(man, null, 2));
console.log('Đã chuẩn bị trang tải, phiên bản ' + VER);
