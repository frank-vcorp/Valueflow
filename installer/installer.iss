; ============================================
; Valueflow Middleware - Inno Setup Script
; Versión TODO-EN-UNO con wizard de 3 campos
; Compilable con ISCC.exe v6.x o v7.x
; Output: build_output\Valueflow-Setup-v1.0.exe
; ============================================

#define MyAppName "Valueflow Middleware"
#define MyAppVersion "1.4.0"
#define MyAppPublisher "VCorp - Representaciones Aga de Saltillo"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v1.3.1 (build 2026-08-06)
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\siemens-middleware
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
OutputBaseFilename=Valueflow-Setup-v1.4.0
OutputDir=build_output

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
; Middleware completo (sin node_modules compilado, sin dist para Linux)
Source: "..\middleware\*"; DestDir: "{app}\middleware"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\.bin,coverage,.nyc_output,*.log,dist\**\*.map"

; Scripts del instalador
Source: "install.ps1"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "install.bat"; DestDir: "{app}\installer"; Flags: ignoreversion

; Node.js 20 LTS portable (NO requiere instalacion MSI; viene incluido)
Source: "assets\node-v20.14.0-win-x64.zip"; DestDir: "{app}\node-portable"; Flags: ignoreversion

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

; Pasar credenciales como parámetros de línea de comandos a install.bat
; (instalador las recogió vía [Code] InitializeSetup)

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\middleware\node_modules"
Type: filesandordirs; Name: "{app}\middleware\.env"
Type: filesandordirs; Name: "{app}\middleware\config.json"

[UninstallRun]
Filename: "pm2"; Parameters: "delete siemens-middleware"; Flags: runhidden

[Code]
{ Esta seccion del [Code] se conserva minima y compatible con Inno Setup 6 y 7. }
{ Recoge 3 campos de credenciales via wizard personalizada, los pasa a install.bat }
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

  { UNICO campo: Ruta del archivo .FDB de Aspel SAE }
  { Filtro: mostramos TODOS los archivos primero para que el usuario encuentre }
  { el .FDB en cualquier carpeta. Para que Inno Setup muestre archivos, el }
  { filtro debe terminar con *.* (no *.FDB primero) y los filtros se separan con | }
  FirebirdDBPathPage.Add(
    'Ruta del archivo .FDB de Aspel SAE (use Examinar para navegar):',
    'Todos los archivos (*.*)|*.*|Archivos Firebird (*.FDB)|*.FDB',
    'C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB'
  );
end;

{ Guardar solo la ruta del FDB en archivo temporal que install.bat leera }
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
