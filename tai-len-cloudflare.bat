@echo off
chcp 65001 >nul
rem Dua trang tai VieTing + server dong bo len Cloudflare (goi mien phi). Tac gia: Pham Thanh Long (thlong)
rem Chep file cai (VieTing.apk, VieTing-Setup.exe, VieTing-Windows-portable.zip, VieTing.ipa) vao thu muc dist\ truoc khi chay.
rem Can Node.js. Lan dau trinh duyet mo trang dang nhap Cloudflare, bam Allow.
call npx -y wrangler@latest whoami >nul 2>&1 || call npx -y wrangler@latest login
cd /d "%~dp0"
findstr /c:"DIEN-ID-D1-VAO-DAY" server\wrangler.jsonc >nul
if not errorlevel 1 (
  echo == Lan dau: tao co so du lieu D1 "vieting"
  pushd server
  call npx -y wrangler@latest d1 create vieting > "%TEMP%\vieting-d1.txt" 2>&1
  type "%TEMP%\vieting-d1.txt"
  powershell -NoProfile -Command "$t = Get-Content -Raw $env:TEMP\vieting-d1.txt; $m = [regex]::Match($t, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'); if (-not $m.Success) { exit 1 }; $f = Join-Path (Get-Location) 'wrangler.jsonc'; [IO.File]::WriteAllText($f, [IO.File]::ReadAllText($f).Replace('DIEN-ID-D1-VAO-DAY', $m.Value))"
  if errorlevel 1 (
    echo Khong lay duoc database_id. Chep tay ID o tren vao server\wrangler.jsonc roi chay lai.
    popd
    pause
    exit /b 1
  )
  popd
  echo Da ghi database_id vao server\wrangler.jsonc
)
echo == Cat file cai thanh phan 20 MB
node tools\pack-cloudflare.js || (pause & exit /b 1)
pushd server
echo == Tao bang du lieu ^(neu chua co^)
call npx -y wrangler@latest d1 execute vieting --remote --yes --file=schema.sql
echo == Deploy
call npx -y wrangler@latest deploy > "%~dp0deploy-log.txt" 2>&1
type "%~dp0deploy-log.txt"
set "URL="
findstr /r /c:"https://[a-z0-9.-]*workers\.dev" "%~dp0deploy-log.txt" >nul || (
  echo == Lan dau Cloudflare can them it giay, deploy lai...
  timeout /t 8 /nobreak >nul
  call npx -y wrangler@latest deploy > "%~dp0deploy-log.txt" 2>&1
  type "%~dp0deploy-log.txt"
)
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "$m = Select-String -Path ..\deploy-log.txt -Pattern 'https://[a-z0-9.-]+\.workers\.dev' ^| Select-Object -First 1; if ($m) { $m.Matches[0].Value }"`) do set "URL=%%u"
popd
if defined URL (
  echo %URL%> server-url.txt
  echo %URL%| clip
  echo.
  echo ==================================================
  echo  Dia chi server: %URL%
  echo  Da copy san. Gui dia chi nay cho Claude de gan vao app.
  echo ==================================================
)
echo.
if defined URL (echo Xong. Trang tai: %URL%/tai-app) else (echo Xong.)
pause
