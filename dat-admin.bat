@echo off
chcp 65001 >nul
rem Cap quyen quan tri (trang /admin) cho mot tai khoan VieTing. Tac gia: Pham Thanh Long (thlong)
rem Tai khoan phai dang ky trong app truoc. Sau lan dau, admin co the cap quyen cho nguoi khac ngay tren trang /admin.
cd /d "%~dp0server"
set "EMAIL="
set /p EMAIL=Nhap email tai khoan VieTing can lam admin: 
if "%EMAIL%"=="" (echo Chua nhap email. & pause & exit /b 1)
echo %EMAIL%| findstr /r /c:"^[^ '\"]*@[^ '\"]*\.[^ '\"]*$" >nul || (echo Email khong hop le. & pause & exit /b 1)
call npx -y -p node@22 -p wrangler@latest wrangler d1 execute vieting --remote --yes --file=schema.sql >nul
call npx -y -p node@22 -p wrangler@latest wrangler d1 execute vieting --remote --yes --command "INSERT OR IGNORE INTO admins (user_id, created) SELECT id, 0 FROM users WHERE email = lower('%EMAIL%')"
call npx -y -p node@22 -p wrangler@latest wrangler d1 execute vieting --remote --yes --command "SELECT u.email AS admin FROM admins a JOIN users u ON u.id = a.user_id"
echo.
echo Neu email cua ban nam trong danh sach "admin" o tren thi da xong.
echo Vao trang quan tri: https://vieting.phamthanhlong-contact.workers.dev/admin
pause
