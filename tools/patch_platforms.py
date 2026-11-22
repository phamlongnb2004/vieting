"""Gắn cấu hình VieTing vào thư mục nền tảng do `flutter create` tạo ra.

- Android: ký bản release bằng khóa riêng (biến môi trường VIETING_KEYSTORE...), nếu không có thì dùng khóa debug.
- iOS: tên hiển thị "VieTing", link vieting://, tắt deep link mặc định của Flutter.
- Windows: tiêu đề cửa sổ + thông tin file exe.
Tác giả: Phạm Thành Long (thlong)
"""
import os
import plistlib
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def p(*parts):
    return os.path.join(ROOT, *parts)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, s):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(s)


# ---------------- Android ----------------
KTS_SIGNING = """    signingConfigs {
        create("vieting") {
            val ks = System.getenv("VIETING_KEYSTORE")
            if (ks != null && ks.isNotEmpty()) {
                storeFile = file(ks)
                storePassword = System.getenv("VIETING_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("VIETING_KEY_ALIAS")
                keyPassword = System.getenv("VIETING_KEY_PASSWORD")
            }
        }
    }

"""
GROOVY_SIGNING = """    signingConfigs {
        vieting {
            def ks = System.getenv("VIETING_KEYSTORE")
            if (ks != null && !ks.isEmpty()) {
                storeFile file(ks)
                storePassword System.getenv("VIETING_KEYSTORE_PASSWORD")
                keyAlias System.getenv("VIETING_KEY_ALIAS")
                keyPassword System.getenv("VIETING_KEY_PASSWORD")
            }
        }
    }

"""


def patch_android():
    kts = p("android", "app", "build.gradle.kts")
    groovy = p("android", "app", "build.gradle")
    if os.path.exists(kts):
        s = read(kts)
        if "VIETING_KEYSTORE" not in s:
            s = s.replace("    buildTypes {", KTS_SIGNING + "    buildTypes {", 1)
            s = s.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                'signingConfig = if (System.getenv("VIETING_KEYSTORE").isNullOrEmpty()) '
                'signingConfigs.getByName("debug") else signingConfigs.getByName("vieting")',
            )
            write(kts, s)
    elif os.path.exists(groovy):
        s = read(groovy)
        if "VIETING_KEYSTORE" not in s:
            s = s.replace("    buildTypes {", GROOVY_SIGNING + "    buildTypes {", 1)
            s = s.replace(
                "signingConfig signingConfigs.debug",
                'signingConfig (System.getenv("VIETING_KEYSTORE") ? signingConfigs.vieting : signingConfigs.debug)',
            )
            write(groovy, s)


    # Lint "vital" của một số plugin (image_picker) bị crash với JDK mới -> tắt, không ảnh hưởng app.
    for root in (p("android", "build.gradle.kts"), p("android", "build.gradle")):
        if os.path.exists(root):
            s = read(root)
            if "lintVital" not in s:
                s += '\nsubprojects {\n    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }\n}\n'
                write(root, s)
            break


# ---------------- iOS ----------------
def patch_ios():
    path = p("ios", "Runner", "Info.plist")
    if not os.path.exists(path):
        return
    with open(path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleDisplayName"] = "VieTing"
    pl["CFBundleURLTypes"] = [{"CFBundleURLName": "vn.thlong.vieting", "CFBundleURLSchemes": ["vieting"]}]
    pl["FlutterDeepLinkingEnabled"] = False
    pl["ITSAppUsesNonExemptEncryption"] = False
    pl["NSMicrophoneUsageDescription"] = "VieTing dùng micro để bạn nói nhanh khoản chi, VD: ăn phở 45 nghìn."
    pl["NSSpeechRecognitionUsageDescription"] = "VieTing chuyển lời nói thành giao dịch."
    pl["NSCameraUsageDescription"] = "VieTing dùng camera để chụp hóa đơn và đọc số tiền."
    pl["NSPhotoLibraryUsageDescription"] = "VieTing đọc ảnh hóa đơn / ảnh chuyển khoản bạn chọn."
    pl["NSFaceIDUsageDescription"] = "Mở khóa VieTing bằng Face ID."
    with open(path, "wb") as f:
        plistlib.dump(pl, f)

    # Ghi nhanh từ Phím tắt / Siri / Action Button / Back Tap (App Intents, iOS 16+)
    app = p("ios", "Runner", "AppDelegate.swift")
    extra = p("tools", "ios", "QuickIntents.swift")
    if os.path.exists(app) and os.path.exists(extra):
        s = read(app)
        if "VieTingQuickQueue" not in s:
            if "import AppIntents" not in s:
                s = s.replace("import UIKit", "import UIKit\nimport AppIntents", 1)
            s += "\n" + read(extra)
            write(app, s)


# ---------------- Windows ----------------
def patch_windows():
    main = p("windows", "runner", "main.cpp")
    if os.path.exists(main):
        write(main, read(main).replace('L"vieting"', 'L"VieTing"'))
    rc = p("windows", "runner", "Runner.rc")
    if os.path.exists(rc):
        s = read(rc)
        s = re.sub(r'(VALUE "CompanyName", )"[^"]*"', r'\1"thlong"', s)
        s = re.sub(r'(VALUE "FileDescription", )"[^"]*"', r'\1"VieTing - quan ly chi tieu"', s)
        s = re.sub(r'(VALUE "ProductName", )"[^"]*"', r'\1"VieTing"', s)
        s = re.sub(r'(VALUE "InternalName", )"[^"]*"', r'\1"VieTing"', s)
        s = re.sub(r'(VALUE "LegalCopyright", )"[^"]*"', r'\1"Copyright (C) Pham Thanh Long (thlong)"', s)
        write(rc, s)


patch_android()
patch_ios()
patch_windows()
print("patch_platforms: xong")
