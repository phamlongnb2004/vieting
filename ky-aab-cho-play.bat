@echo off
chcp 65001 >nul
setlocal EnableExtensions
rem Ky file AAB bang khoa tai len de dua len Google Play. Tac gia: Pham Thanh Long (thlong)
rem 1. Tu tai Java (JDK 17) neu may chua co   2. Tao khoa vieting-upload.jks neu chua co (ban tu dat mat khau)
rem 3. Tai file AAB moi nhat (link trong play-store\aab-url.txt) hoac dung play-store\VieTing.aab co san
rem 4. Ky lai -> play-store\VieTing-play.aab : tai file nay len Play Console
cd /d "%~dp0"
if not exist play-store mkdir play-store

rem ---- 1. Java ----
set "JBIN="
for %%P in ("%ProgramFiles%\Android\Android Studio\jbr\bin" "%JAVA_HOME%\bin") do if exist "%%~P\jarsigner.exe" set "JBIN=%%~P"
if not defined JBIN for /f "delims=" %%D in ('dir /b /s "%LOCALAPPDATA%\VieTing\jdk\jarsigner.exe" 2^>nul') do set "JBIN=%%~dpD"
if not defined JBIN (
  echo Dang tai Java 17 ^(khoang 190 MB, chi lan dau^)...
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'; $d=Join-Path $env:LOCALAPPDATA 'VieTing\jdk'; New-Item -ItemType Directory -Force $d | Out-Null; $z=Join-Path $env:TEMP 'vieting-jdk.zip'; Invoke-WebRequest 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' -OutFile $z; Expand-Archive $z $d -Force; Remove-Item $z" || (echo Khong tai duoc Java. & pause & exit /b 1)
  for /f "delims=" %%D in ('dir /b /s "%LOCALAPPDATA%\VieTing\jdk\jarsigner.exe" 2^>nul') do set "JBIN=%%~dpD"
)
if not defined JBIN (echo Khong tim thay Java. & pause & exit /b 1)

rem ---- 2. Khoa tai len ----
if not exist vieting-upload.jks (
  echo.
  echo === TAO KHOA TAI LEN ^(chi lam 1 lan^) ===
  echo Tu dat mat khau it nhat 6 ky tu, go 2 lan. Ghi lai mat khau va giu ky file vieting-upload.jks.
  "%JBIN%\keytool.exe" -genkeypair -keystore vieting-upload.jks -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Pham Thanh Long, O=VieTing, C=VN" || (pause & exit /b 1)
)

rem ---- 3. File AAB ----
if exist play-store\aab-url.txt (
  echo Dang tai file AAB moi nhat...
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $u=(Get-Content 'play-store\aab-url.txt' -Raw).Trim(); try { Invoke-WebRequest $u -OutFile 'play-store\VieTing.aab' -ErrorAction Stop; Remove-Item 'play-store\aab-url.txt' } catch { Write-Host 'Link tai da het han, dung file VieTing.aab co san (neu co).' }"
)
if not exist play-store\VieTing.aab (
  echo Chua co play-store\VieTing.aab. Tai VieTing.aab tu Codemagic, luu vao thu muc play-store roi chay lai.
  pause & exit /b 1
)

rem ---- 4. Bo chu ky cu, ky bang khoa tai len ----
copy /y play-store\VieTing.aab "%TEMP%\vieting-unsigned.aab" >nul
powershell -NoProfile -Command "Add-Type -A System.IO.Compression.FileSystem; $z=[IO.Compression.ZipFile]::Open((Join-Path $env:TEMP 'vieting-unsigned.aab'),'Update'); @($z.Entries | ? { $_.FullName -match '^META-INF/(.*\.(SF|RSA|DSA|EC)|MANIFEST\.MF)$' }) | ForEach-Object { $_.Delete() }; $z.Dispose()"
echo.
echo === KY FILE AAB: go mat khau khoa tai len ===
"%JBIN%\jarsigner.exe" -keystore vieting-upload.jks -sigalg SHA256withRSA -digestalg SHA-256 -signedjar play-store\VieTing-play.aab "%TEMP%\vieting-unsigned.aab" upload || (pause & exit /b 1)
del "%TEMP%\vieting-unsigned.aab" >nul 2>&1
echo.
echo XONG: play-store\VieTing-play.aab . Tai file nay len Play Console ^(Thu nghiem noi bo - Tai len^).
explorer play-store
pause
