; Bộ cài Windows cho VieTing (Inno Setup 6). Tác giả: Pham Thanh Long (thlong)
; GitHub Actions tự chạy file này sau khi dựng bản Windows.
#define MyAppVersion GetEnv("VIETING_VERSION")
#if MyAppVersion == ""
  #define MyAppVersion "0.1.0"
#endif

[Setup]
AppId={{55C37CF3-6B5E-45F9-AAA9-144AF68D797A}
AppName=VieTing
AppVersion={#MyAppVersion}
AppPublisher=Pham Thanh Long (thlong)
DefaultDirName={localappdata}\Programs\VieTing
DefaultGroupName=VieTing
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=VieTing-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\vieting.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VieTing"; Filename: "{app}\vieting.exe"
Name: "{autodesktop}\VieTing"; Filename: "{app}\vieting.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\vieting.exe"; Description: "{cm:LaunchProgram,VieTing}"; Flags: nowait postinstall skipifsilent
