; ============================================
; Valueflow Middleware - Inno Setup Script
; Genera un instalador .exe profesional para Windows
; ============================================
; Compilar con: iscc.exe installer.iss
; Output: Valueflow-Setup-v1.0.exe

#define MyAppName "Valueflow Middleware"
#define MyAppVersion "1.0"
#define MyAppPublisher "VCorp - Representaciones Aga de Saltillo"
#define MyAppURL "https://github.com/frank-vcorp/Valueflow"
#define MyAppExeName "ValueflowMiddleware.exe"

[Setup]
; Identificador único de la aplicación
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Directorio de instalación por defecto
DefaultDirName={autopf}\Valueflow
DefaultGroupName={#MyAppName}

; Compresión y opciones
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; Habilitar installable para 64-bit
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Información de versión
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Valueflow Middleware Installer
VersionInfoCopyright=Copyright (C) 2026 VCorp

; Salida
OutputBaseFilename=Valueflow-Setup-v{#MyAppVersion}
OutputDir=output
; Icono (opcional, descomentar si tienes un .ico)
//SetupIconFile=assets\installer.ico

; Mensaje de bienvenida
[Messages]
WelcomeLabel2=Este instalador configurará [name/ver] en su equipo.%n%nValueflow Middleware automatiza el envío de información de inventario y ventas desde Aspel SAE 10 hacia el portal Siemens PoSi.%n%nLa instalación incluye:%n  • Node.js 20 LTS (si no está instalado)%n  • El middleware completo%n  • Configuración como Servicio Windows%n  • Acceso directo en el escritorio

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: checked

[Files]
; Middleware completo
Source: "..\middleware\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules,dist,logs,coverage,*.log"

; Scripts del instalador
Source: "install.ps1"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "install.bat"; DestDir: "{app}\installer"; Flags: ignoreversion

; Logo
Source: "..\assets\logo_aga_letras_2.png"; DestDir: "{app}\public"; Flags: ignoreversion
Source: "..\assets\partner.png"; DestDir: "{app}\public"; Flags: ignoreversion

[Icons]
; Acceso directo en el escritorio
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\installer\install.bat"; Tasks: desktopicon
; Acceso directo en Menú Inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\installer\install.bat"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
; Ejecutar el instalador PowerShell al final de la instalación
Filename: "{app}\installer\install.bat"; Description: "Configurar e iniciar el servicio de Valueflow"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Limpiar archivos al desinstalar
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\node_modules"
Type: filesandordirs; Name: "{app}\dist"
Type: filesandordirs; Name: "{app}\.env"
Type: filesandordirs; Name: "{app}\config.json"

[UninstallRun]
; Limpiar PM2 al desinstalar
Filename: "pm2"; Parameters: "delete siemens-middleware"; Flags: runhidden

[Code]
// Función para verificar requisitos antes de instalar
function InitializeSetup: Boolean;
var
  ResultCode: Integer;
begin
  Result := True;

  // Verificar Node.js
  if not Exec('node.exe', '--version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if MsgBox('No se detectó Node.js instalado.' + #13#10 + #13#10 +
              'El instalador descargará Node.js 20 LTS durante la instalación.' + #13#10 +
              '¿Desea continuar?',
              mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
end;

// Mensaje de finalización
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // El script install.bat se ejecuta automáticamente (definido en [Run])
  end;
end;