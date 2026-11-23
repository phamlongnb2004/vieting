@echo off
chcp 65001 >nul
rem Bat gui email ma "Quen mat khau" qua Gmail. Tac gia: Pham Thanh Long (thlong)
rem 1. Dung mot tai khoan Gmail (nen tao rieng, VD vieting.app@gmail.com), bat Xac minh 2 buoc
rem 2. Vao https://myaccount.google.com/apppasswords tao "Mat khau ung dung" (16 ky tu)
rem 3. Dan dia chi Gmail va mat khau ung dung vao duoi day
cd /d "%~dp0server"
echo Dan dia chi Gmail gui thu roi bam Enter:
call npx -y -p node@22 -p wrangler@latest wrangler secret put SMTP_USER
echo.
echo Dan mat khau ung dung (16 ky tu, bo dau cach) roi bam Enter:
call npx -y -p node@22 -p wrangler@latest wrangler secret put SMTP_PASS
echo.
echo Xong. Muc "Quen mat khau" trong app da gui duoc ma qua email.
pause
