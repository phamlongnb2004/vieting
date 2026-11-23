@echo off
chcp 65001 >nul
rem Bat "Dang nhap bang Google" cho VieTing. Tac gia: Pham Thanh Long (thlong)
rem 1. Vao https://console.cloud.google.com/apis/credentials (tao project neu chua co)
rem 2. OAuth consent screen: User type External, dien ten app VieTing, email ho tro, bam Publish app
rem 3. Credentials - Create credentials - OAuth client ID - Application type: Web application
rem    Authorized redirect URIs: https://vieting.phamthanhlong-contact.workers.dev/auth/google/callback
rem 4. Copy Client ID va Client secret roi dan vao duoi day
cd /d "%~dp0server"
echo Dan Client ID roi bam Enter:
call npx -y -p node@22 -p wrangler@latest wrangler secret put GOOGLE_CLIENT_ID
echo.
echo Dan Client secret roi bam Enter:
call npx -y -p node@22 -p wrangler@latest wrangler secret put GOOGLE_CLIENT_SECRET
echo.
echo Xong. Nut "Tiep tuc voi Google" trong app da dung duoc.
pause
