@echo off
chcp 65001 >nul
rem Tao 3 tai khoan thu cho nguoi duyet Google Play / App Store, kem du lieu mau va Quy chung (ma moi REVIEW).
rem Tac gia: Pham Thanh Long (thlong). Chay sau tai-len-cloudflare.bat. Chay lai duoc de doi mat khau / lam moi du lieu.
rem Tai khoan: reviewer@example.com, reviewer2@example.com, reviewer3@example.com (cung mot mat khau ban tu dat).
cd /d "%~dp0server"
call npx -y -p node@22 node ..\tools\seed_reviewers.mjs "%TEMP%\vieting-seed.sql" || (pause & exit /b 1)
call npx -y -p node@22 -p wrangler@latest wrangler d1 execute vieting --remote --yes --file="%TEMP%\vieting-seed.sql"
del "%TEMP%\vieting-seed.sql" >nul 2>&1
echo.
echo Xong. Dien vao Play Console: reviewer@example.com + mat khau vua dat.
pause
