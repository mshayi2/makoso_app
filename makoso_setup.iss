; ============================================================
;  Makoso App – Inno Setup Script
;  Prérequis : flutter build windows --release
;  Généré pour : Makoso App 1.0.0
; ============================================================

#define AppName      "Makoso"
#define AppVersion   "1.0.0"
#define AppPublisher "Menji Group"
#define AppURL       "https://makoso.menji-group.com"
#define AppExeName   "makoso_app.exe"
#define BuildDir     "build\windows\x64\runner\Release"

[Setup]
AppId={{6E2A7F3D-4C1B-4E9F-8A2D-1B3C5E7F9A0D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}

; Répertoire d'installation par défaut
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

; Fichier de sortie
OutputDir=installer
OutputBaseFilename=Makoso_Setup_{#AppVersion}

; Compression
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; Icône du setup
SetupIconFile={#BuildDir}\{#AppExeName},0

; Interface
WizardStyle=modern
WizardSizePercent=110
ShowLanguageDialog=no

; Droits
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Version Windows minimale : Windows 10
MinVersion=10.0

; Métadonnées pour l'ajout/suppression de programmes
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName} {#AppVersion}

; Fichier de licence (décommenter si disponible)
; LicenseFile=LICENSE.txt

[Languages]
Name: "french";  MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Exécutable principal
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLs Flutter et Visual C++ runtime
Source: "{#BuildDir}\*.dll";         DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Données Flutter (flutter_assets, etc.)
Source: "{#BuildDir}\data\*";        DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";              Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";        Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Supprimer les données applicatives laissées par l'app (base SQLite, etc.)
; Décommenter si vous souhaitez une désinstallation complète des données utilisateur :
; Type: filesandordirs; Name: "{localappdata}\{#AppName}"

[Code]
// Vérification optionnelle : avertir si une version est déjà installée
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
