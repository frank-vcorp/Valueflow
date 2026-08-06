; ============================================
; Valueflow Middleware - Inno Setup Script
; Versión TODO-EN-UNO con wizard de 3 campos
; Compilable con ISCC.exe v6.x o v7.x
; Output: build_output\Valueflow-Setup-v1.0.exe
; ============================================

#define MyAppName "Valueflow Middleware"
#define MyAppVersion "1.0"
#define MyAppPublisher "VCorp - Representaciones Aga de Saltillo"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
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
OutputBaseFilename=Valueflow-Setup-v{#MyAppVersion}
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

; Assets (logos)
Source: "..\middleware\public\logo_aga_letras_2.png"; DestDir: "{app}\middleware\public"; Flags: ignoreversion
Source: "..\middleware\public\partner.png"; DestDir: "{app}\middleware\public"; Flags: ignoreversion

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
  FirebirdDBPathValue: String;
  SiemensAPIKeyValue: String;
  UIPasswordValue: String;

procedure InitializeWizard;
begin
  { Pagina personalizada con 3 campos para el wizard }
  FirebirdDBPathPage := CreateInputFilePage(
    wpSelectDir,
    'Configuracion del Middleware',
    'Parametros de conexion',
    'Ingrese los parametros para conectar el middleware a Aspel SAE y Siemens PoSi:' + #13#10 +
    '- Ruta del archivo .FDB de Aspel SAE' + #13#10 +
    '- API Key de Siemens PoSi (sandbox QUA por defecto)' + #13#10 +
    '- Contrasena para la interfaz web de administracion'
  );

  { Campo 1: Ruta del archivo .FDB de Aspel SAE }
  FirebirdDBPathPage.Add(
    'Ruta del archivo .FDB de Aspel SAE:',
    'Archivo .FDB|Asel SAE 9.0/10.0 (*.FDB)|*.FDB|Todos los archivos (*.*)|*.*',
    '.FDB',
    'C:\Program Files\Aspel\Aspel SAE 9.0\BD\SAE90EMPRE01.FDB',
    False
  );

  { Campo 2: API Key de Siemens (vacio por defecto; usuario pega la real) }
  FirebirdDBPathPage.Add(
    'API Key de Siemens PoSi (pegar su key; sandbox o productiva):',
    'API Key (32+ caracteres)',
    '',
    '',
    False
  );

  { Campo 3: Password para la UI admin (minimo 8 caracteres) }
  FirebirdDBPathPage.Add(
    'Contrasena para la UI web (minimo 8 caracteres):',
    'Contrasena (texto plano)',
    '',
    '',
    False
  );
end;

{ Capturar valores de los campos del wizard }
function GetFirebirdDBPath(Param: String): String;
begin
  Result := FirebirdDBPathPage.Values[0];
end;

function GetSiemensAPIKey(Param: String): String;
begin
  Result := FirebirdDBPathPage.Values[1];
end;

function GetUIPasswordPlain(Param: String): String;
begin
  Result := FirebirdDBPathPage.Values[2];
end;

{ Guardar valores en archivo temporal que install.bat leera }
procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigFile: String;
  ConfigContent: String;
begin
  if CurStep = ssPostInstall then
  begin
    ConfigFile := ExpandConstant('{tmp}\valueflow_install_config.ini');
    ConfigContent :=
      'FIREBIRD_DB_PATH=' + FirebirdDBPathPage.Values[0] + #13#10 +
      'SIEMENS_API_KEY=' + FirebirdDBPathPage.Values[1] + #13#10 +
      'UI_PASSWORD=' + FirebirdDBPathPage.Values[2] + #13#10;
    SaveStringToFile(ConfigFile, ConfigContent, False);
  end;
end;
