#!/usr/bin/env bash
# Tạo các thư mục nền tảng (android / ios / windows) của Flutter rồi gắn cấu hình riêng của VieTing.
# File đã có trong kho (AndroidManifest.xml, MainActivity.kt, BankNotificationService.kt...) KHÔNG bị ghi đè.
# Dùng trên GitHub Actions, Codemagic, hoặc máy bạn:  bash tools/setup-platforms.sh
set -e
cd "$(dirname "$0")/.."

flutter create --org vn.thlong --project-name vieting --platforms=android,ios,windows .

if python3 -c "" >/dev/null 2>&1; then PY=python3; else PY=python; fi
$PY tools/patch_platforms.py

flutter pub get
dart run flutter_launcher_icons
echo "Xong: android/, ios/, windows/ đã sẵn sàng."
