@echo off
chcp 65001 >nul
rem Dua server dong bo VieTing len Cloudflare Workers + D1 (mien phi). Tac gia: Pham Thanh Long (thlong)
rem Can Node.js. Lan dau trinh duyet mo trang dang nhap Cloudflare, bam Allow.
cd /d "%~dp0"
findstr /c:"DIEN-ID-D1-VAO-DAY" wrangler.jsonc >nul
if not errorlevel 1 (
  echo == Tao co so du lieu D1 "vieting"
  call npx -y wrangler@4 d1 create vieting
  echo.
  echo Chep dong database_id o tren vao file server\wrangler.jsonc ^(thay DIEN-ID-D1-VAO-DAY^), luu lai roi chay lai file nay.
  pause
  exit /b 0
)
echo == Tao bang du lieu
call npx -y wrangler@4 d1 execute vieting --remote --file=schema.sql
echo == Deploy server
call npx -y wrangler@4 deploy
echo.
echo Xong. Dia chi server: https://vieting.^<ten-tai-khoan^>.workers.dev  ^(nhap vao app khi dang nhap^)
pause
