@echo off
chcp 65001 >nul
rem Dat khoa Gemini (mien phi) cho tro ly AI cua VieTing. Tac gia: Pham Thanh Long (thlong)
rem Lay khoa tai https://aistudio.google.com/apikey  (dang nhap Google, bam Create API key).
rem Khong co khoa thi tro ly van chay bang Cloudflare Workers AI (mien phi), chi kem hon mot chut ve tieng Viet.
cd /d "%~dp0server"
echo Dan khoa Gemini roi bam Enter:
call npx -y wrangler@latest secret put GEMINI_API_KEY
echo.
echo Xong. Tro ly AI da dung Gemini.
pause
