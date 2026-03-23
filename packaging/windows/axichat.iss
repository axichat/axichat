#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define RepoRoot AddBackslash(SourcePath) + "..\..\"

#ifndef AppSourceDir
  #define AppSourceDir AddBackslash(RepoRoot) + "build\windows\x64\runner\Release"
#endif

#ifndef AppOutputDir
  #define AppOutputDir AddBackslash(RepoRoot) + "dist"
#endif

#define AppId "{{B7F0D98A-6D0C-4EAA-A63C-9A5E4A9C0F7D}"
#define AppName "Axichat"
#define AppPublisher "Axichat"
#define AppExeName "Axichat.exe"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://axi.chat
AppSupportURL=https://axi.chat
AppUpdatesURL=https://github.com/axichat/axichat/releases
DefaultDirName={localappdata}\Programs\Axichat
DefaultGroupName=Axichat
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern
OutputDir={#AppOutputDir}
OutputBaseFilename=axichat-windows-setup
SetupIconFile={#AddBackslash(RepoRoot) + "windows\runner\resources\app_icon.ico"}
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Axichat"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Axichat"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,Axichat}"; Flags: nowait postinstall skipifsilent
