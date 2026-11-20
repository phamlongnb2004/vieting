@echo off
chcp 65001 >nul
rem Dua trang tai VieTing + server dong bo len Cloudflare (goi mien phi). Tac gia: Pham Thanh Long (thlong)
rem Chep file cai (VieTing.apk, VieTing-Setup.exe, VieTing-Windows-portable.zip, VieTing.ipa) vao thu muc dist\ truoc khi chay.
rem Can Node.js. Lan dau trinh duyet mo trang dang nhap Cloudflare, bam Allow.
cd /d "%~dp0"
findstr /c:"DIEN-ID-D1-VAO-DAY" server\wrangler.jsonc >nul
if not errorlevel 1 (
  echo == Lan dau: tao co so du lieu D1 "vieting"
  pushd server
  call npx -y wrangler@4 d1 create vieting
  popd
  echo.
  echo Chep dong database_id o tren vao file server\wrangler.jsonc ^(thay DIEN-ID-D1-VAO-DAY^), luu lai roi chay lai file nay.
  pause
  exit /b 0
)
echo == Cat file cai thanh phan 20 MB
node tools\pack-cloudflare.js || (pause & exit /b 1)
pushd server
echo == Tao bang du lieu ^(neu chua co^)
call npx -y wrangler@4 d1 execute vieting --remote --file=schema.sql
echo == Deploy
call npx -y wrangler@4 deploy
popd
echo.
echo Xong. Trang tai: https://vieting.^<ten-tai-khoan^>.workers.dev/tai-app
echo Dia chi server dong bo de nhap vao app: https://vieting.^<ten-tai-khoan^>.workers.dev
pause
