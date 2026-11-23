@echo off
chcp 65001 >nul
setlocal
rem Bat "Dang nhap bang Google" cho VieTing. Tac gia: Pham Thanh Long (thlong)
rem Lay Client ID va Client secret o Google Cloud: Google Auth Platform - Clients - VieTing server
rem Redirect URI: https://vieting.phamthanhlong-contact.workers.dev/auth/google/callback
cd /d "%~dp0server"
echo Dang kiem tra dang nhap Cloudflare...
call npx -y -p node@22 -p wrangler@latest wrangler whoami >nul 2>&1 || npx -y -p node@22 -p wrangler@latest wrangler login

echo.
echo === Dan CLIENT ID (dang ...apps.googleusercontent.com) ===
echo Dan bang chuot phai ^(hoac Ctrl+V^) roi bam Enter.
set "V_GOOGLE_CLIENT_ID="
set /p "V_GOOGLE_CLIENT_ID=> "
if not defined V_GOOGLE_CLIENT_ID (echo Chua dan gi, dung lai. & pause & exit /b 1)
powershell -NoProfile -Command "$env:V_GOOGLE_CLIENT_ID.Trim()" | npx -y -p node@22 -p wrangler@latest wrangler secret put GOOGLE_CLIENT_ID || (echo Loi khi luu GOOGLE_CLIENT_ID. & pause & exit /b 1)
set "V_GOOGLE_CLIENT_ID="
echo.
echo === Dan CLIENT SECRET (dang GOCSPX-...) ===
echo Dan bang chuot phai ^(hoac Ctrl+V^) roi bam Enter.
set "V_GOOGLE_CLIENT_SECRET="
set /p "V_GOOGLE_CLIENT_SECRET=> "
if not defined V_GOOGLE_CLIENT_SECRET (echo Chua dan gi, dung lai. & pause & exit /b 1)
powershell -NoProfile -Command "$env:V_GOOGLE_CLIENT_SECRET.Trim()" | npx -y -p node@22 -p wrangler@latest wrangler secret put GOOGLE_CLIENT_SECRET || (echo Loi khi luu GOOGLE_CLIENT_SECRET. & pause & exit /b 1)
set "V_GOOGLE_CLIENT_SECRET="
echo.
echo Cac khoa dang co tren server:
call npx -y -p node@22 -p wrangler@latest wrangler secret list
echo.
echo Xong. Nut "Tiep tuc voi Google" trong app da dung duoc ^(co the mat vai phut^).
pause
