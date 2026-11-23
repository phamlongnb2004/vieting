@echo off
chcp 65001 >nul
rem Tao khoa tai len (upload key) de ky app dua len Google Play. Tac gia: Pham Thanh Long (thlong)
rem Chi lam MOT lan. Giu file vieting-upload.jks va mat khau that ky: mat la khong cap nhat app duoc
rem (Google Play van cho xin doi khoa tai len, nhung mat vai ngay).
cd /d "%~dp0"
set "KT=keytool"
where keytool >nul 2>nul
if errorlevel 1 (
  if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" set "KT=%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe"
)
if "%KT%"=="keytool" (
  where keytool >nul 2>nul
  if errorlevel 1 (
    echo Chua co Java keytool. Cai Android Studio hoac Java 17 ^(https://adoptium.net^) roi chay lai.
    pause
    exit /b 1
  )
)
if exist vieting-upload.jks (
  echo Da co vieting-upload.jks, khong tao lai de tranh mat khoa cu.
  pause
  exit /b 0
)
echo Tu dat mat khau ^(it nhat 6 ky tu^), keytool se hoi 2 lan. Ghi lai mat khau nay.
"%KT%" -genkeypair -v -keystore vieting-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Pham Thanh Long, O=VieTing, C=VN"
echo.
echo Xong: vieting-upload.jks. Tai file nay len Codemagic ^(Teams - Code signing identities - Android keystores^),
echo Reference name: vieting_upload, Key alias: upload, mat khau vua dat. Roi chay workflow "android-play".
pause
