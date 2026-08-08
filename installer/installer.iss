; ============================================
; Valueflow Middleware - Inno Setup Script
; v2.0.19 - FIX-20260807-23 API key hardcodeada en .env desde instalacion
; Compilable con ISCC.exe v6.x o v7.x
; Output: build_output\Valueflow-Setup-v2.0.19.exe
; ID de intervencion: IMPL-20260807-11 (FIX-20260807-23)
; ============================================

#define MyAppName "Valueflow Middleware"
#define MyAppVersion "2.0.19"
#define MyAppPublisher "VCorp - Representaciones Aga de Saltillo"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v2.0.19 (build 2026-08-07)
AppPublisher={#MyAppPublisher}
; B6: Path unificado a C:\apps\siemens-middleware (evita UAC + espacios de Program Files).
; install.ps1, uninstall.bat y ecosystem.config.js ya apuntan a este path.
DefaultDirName=C:\apps\siemens-middleware
DefaultGroupName={#MyAppName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Valueflow Middleware Installer
OutputBaseFilename=Valueflow-Setup-v2.0.19
OutputDir=build_output

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
; IMPL-20260807-03 Opcion B-1: .exe compacto + bundle.zip como asset.
; El .exe NO empaqueta node_modules del working tree (..\middleware\); el
; staging node_modules (preparado por prepare-dist-pkg.sh) se distribuye
; via el bundle.zip que install.ps1 detecta y expande como fallback.
; H2: Excluir .env del .exe para no filtrar SIEMENS_API_KEY real del working tree.
Source: "..\middleware\*"; DestDir: "{app}\middleware"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\*,.env,.env.*,coverage,.nyc_output,*.log,dist\**\*.map"

; Bundle self-contained con node_modules pre-instalado portable (Opcion B-1).
; install.ps1 (PASO 7) busca este zip en {app}\installer\assets y lo expande
; si no encuentra node_modules\node-firebird\package.json directo en destino.
Source: "..\dist-pkg\valueflow-middleware-v2.0.19.zip"; DestDir: "{app}\installer\assets"; Flags: ignoreversion

; Scripts del instalador
Source: "install.ps1"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "install.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "uninstall.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "VERSION"; DestDir: "{app}"; Flags: ignoreversion

; Instaladores oficiales del sistema (NO portables) - v2.0.0
; Deploy a {app}\installer\assets\installers para que install.ps1 los
; encuentre via $PSScriptRoot\assets\installers\... (auto-cleanup en uninstall)
Source: "assets\installers\node-v20.14.0-x86.msi"; DestDir: "{app}\installer\assets\installers"; Flags: ignoreversion
Source: "assets\installers\vc_redist.x64.exe"; DestDir: "{app}\installer\assets\installers"; Flags: ignoreversion
Source: "assets\installers\node-v20.14.0-win-x86.zip"; DestDir: "{app}\installer\assets\installers"; Flags: ignoreversion

; Assets (logos)
Source: "..\middleware\public\logo_aga_letras_2.png"; DestDir: "{app}\middleware\public"; Flags: ignoreversion
Source: "..\middleware\public\partner.png"; DestDir: "{app}\middleware\public"; Flags: ignoreversion

; Icono para acceso directo en escritorio
Source: "assets\valueflow-icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; Documentos (manual de usuario)
Source: "..\middleware\MANUAL_OPERACION.md"; DestDir: "{app}\docs"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\installer\install.bat"; Comment: "Configurar / Reinstalar Valueflow Middleware"
Name: "{group}\Manual de operacion"; Filename: "{app}\docs\MANUAL_OPERACION.md"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\installer\install.bat"; Tasks: desktopicon

[Run]
; Ejecutar install.bat al final del setup (solo en modo NO-silent)
Filename: "{app}\installer\install.bat"; Description: "Configurar e iniciar Valueflow Middleware"; Flags: runmaximized nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\middleware\node_modules"
Type: filesandordirs; Name: "{app}\middleware\.env"
Type: filesandordirs; Name: "{app}\middleware\config.json"
Type: filesandordirs; Name: "{app}\installer\assets"

[UninstallRun]
Filename: "pm2"; Parameters: "delete siemens-middleware"; Flags: runhidden

[Code]
{ Esta seccion del [Code] se conserva minima y compatible con Inno Setup 6 y 7. }
{ Recoge 1 campo (ruta del FDB) via wizard, lo pasa a install.bat }
{ mediante archivo temporal. NO usa funciones Pascal complejas. }

var
  FirebirdDBPathPage: TInputFileWizardPage;

procedure InitializeWizard;
begin
  { Wizard simplificado: SOLO pide la ruta del archivo .FDB de Aspel }
  { Las credenciales (user, password, API key) tienen defaults preconfigurados }
  { que el usuario puede cambiar despues desde la UI o editando el .env }
  FirebirdDBPathPage := CreateInputFilePage(
    wpSelectDir,
    'Ubicacion de la base de datos de Aspel SAE',
    'Seleccionar archivo .FDB',
    'Seleccione el archivo .FDB de la base de datos de Aspel SAE 9.0 o 10.0:' + #13#10 +
    '(Use el boton Examinar... para navegar)' + #13#10 + #13#10 +
    'Credenciales preconfiguradas (cambie despues desde la UI):' + #13#10 +
    '  Usuario: Admin' + #13#10 +
    '  Contrasena: Admin123' + #13#10 +
    '  API Key Siemens: sandbox QUA (cambiar a produccion desde UI)'
  );

  FirebirdDBPathPage.Add(
    'Ruta del archivo .FDB de Aspel SAE (use Examinar para navegar):',
    'Todos los archivos (*.*)|*.*|Archivos Firebird (*.FDB)|*.FDB',
    'C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB'
  );
end;

{ Guardar la ruta del FDB en archivo temporal que install.ps1 leera }
procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigFile: String;
  ConfigContent: String;
begin
  if CurStep = ssPostInstall then
  begin
    ConfigFile := ExpandConstant('{tmp}\valueflow_install_config.ini');
    ConfigContent :=
      'FIREBIRD_DB_PATH=' + FirebirdDBPathPage.Values[0] + #13#10;
    SaveStringToFile(ConfigFile, ConfigContent, False);
  end;
end;
