@echo off
chcp 65001 >nul
setlocal
rem Bat gui email ma "Quen mat khau" qua Gmail. Tac gia: Pham Thanh Long (thlong)
rem Gmail phai bat Xac minh 2 buoc; tao Mat khau ung dung o https://myaccount.google.com/apppasswords
cd /d "%~dp0server"
echo Dang kiem tra dang nhap Cloudflare...
call npx -y -p node@22 -p wrangler@latest wrangler whoami >nul 2>&1 || npx -y -p node@22 -p wrangler@latest wrangler login

echo.
echo === Dan DIA CHI GMAIL gui thu ===
echo Dan bang chuot phai ^(hoac Ctrl+V^) roi bam Enter.
set "V_SMTP_USER="
set /p "V_SMTP_USER=> "
if not defined V_SMTP_USER (echo Chua dan gi, dung lai. & pause & exit /b 1)
powershell -NoProfile -Command "$env:V_SMTP_USER.Trim()" | npx -y -p node@22 -p wrangler@latest wrangler secret put SMTP_USER || (echo Loi khi luu SMTP_USER. & pause & exit /b 1)
set "V_SMTP_USER="
echo.
echo === Dan MAT KHAU UNG DUNG 16 ky tu (bo dau cach) ===
echo Dan bang chuot phai ^(hoac Ctrl+V^) roi bam Enter.
set "V_SMTP_PASS="
set /p "V_SMTP_PASS=> "
if not defined V_SMTP_PASS (echo Chua dan gi, dung lai. & pause & exit /b 1)
powershell -NoProfile -Command "$env:V_SMTP_PASS.Trim()" | npx -y -p node@22 -p wrangler@latest wrangler secret put SMTP_PASS || (echo Loi khi luu SMTP_PASS. & pause & exit /b 1)
set "V_SMTP_PASS="
echo.
echo Cac khoa dang co tren server:
call npx -y -p node@22 -p wrangler@latest wrangler secret list
echo.
echo Xong. Muc "Quen mat khau" da gui duoc ma qua email.
pause
