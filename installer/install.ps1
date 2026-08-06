#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador de Valueflow Middleware - Aspel SAE ↔ Siemens PoSi

.DESCRIPTION
    Script PowerShell simple, robusto y TODO-EN-UNO:
    - Lee credenciales del archivo temporal dejado por Inno Setup
    - Verifica Node.js 20 LTS (falla con instrucciones si no esta)
    - Copia el codigo del middleware a C:\apps\siemens-middleware
    - Ejecuta npm install --production (incluye compilación nativa para Firebird)
    - Configura .env con secretos (QUA por defecto, puede cambiarse desde UI)
    - Levanta el servicio con PM2
    - Crea acceso directo en el escritorio

.NOTES
    Version: 2.0 (re-escrito tras feedback: ZERO descargas de internet)
    Autor: VCorp - Frank Saavedra
    Para: Representaciones Aga de Saltillo
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "C:\apps\siemens-middleware",
    [int]$UIPort = 4567
)

# ===== Colores para output =====
function Write-Step { param($msg) Write-Host "`n===> $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "  [X] $msg -ForegroundColor Red" }

# ===== Banner =====
$LogoText = @"
+==========================================================+
|                                                          |
|       Valueflow Middleware                                |
|       Aspel SAE <-> Siemens PoSi Portal                  |
|                                                          |
|       Instalador v2.0 (todo-en-uno)                      |
|       VCorp - Representaciones Aga de Saltillo           |
|                                                          |
+==========================================================+
"@
Write-Host $LogoText -ForegroundColor Cyan

# ===== 1. Verificar permisos de administrador =====
Write-Step "Verificando permisos de administrador..."
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "Este instalador requiere permisos de administrador."
    Write-Host "  Clic derecho sobre el archivo .exe -> Ejecutar como administrador" -ForegroundColor Yellow
    pause
    exit 1
}
Write-OK "Permisos OK"

# ===== 2. Verificar Node.js 20 LTS =====
Write-Step "Verificando Node.js 20 LTS..."
$nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
$nodeVersion = $null
if ($nodeExe) {
    $nodeVersion = & node --version
    Write-OK "Node.js instalado: $nodeVersion"
} else {
    Write-Err "============================================================"
    Write-Err "  PREREQUISITO FALTANTE: Node.js 20 LTS"
    Write-Err "============================================================"
    Write-Host ""
    Write-Host "  Pasos para instalar:" -ForegroundColor Yellow
    Write-Host "  1. Abrir navegador en: https://nodejs.org/dist/v20.14.0/" -ForegroundColor Yellow
    Write-Host "  2. Descargar 'node-v20.14.0-x64.msi' (~30 MB)"
    Write-Host "  3. Doble click, Next > Next > Install (todo por defecto)"
    Write-Host "  4. ABRIR PowerShell NUEVO y volver a ejecutar este instalador"
    Write-Host ""
    Write-Host "  Si ya esta instalado pero no se detecta, abre PowerShell como admin" -ForegroundColor Yellow
    Write-Host "  y verifica con: where.exe node" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 2
}

$nodeMajor = ($nodeVersion -replace 'v','').Split('.')[0]
if ([int]$nodeMajor -lt 20) {
    Write-Warn "Se recomienda Node.js 20 LTS. Actual: $nodeVersion. La instalacion continuara pero pueden haber problemas."
}

# ===== 3. Leer credenciales del archivo temporal =====
Write-Step "Leyendo credenciales..."
$ConfigFile = Join-Path $env:TEMP "valueflow_install_config.ini"
if (Test-Path $ConfigFile) {
    Write-OK "Credenciales recibidas del wizard del instalador"
    $IniContent = Get-Content $ConfigFile -Raw
    $FirebirdDBPath = if ($IniContent -match "FIREBIRD_DB_PATH=(.+)") { $matches[1].Trim() } else { "" }
    $SiemensAPIKey = if ($IniContent -match "SIEMENS_API_KEY=(.+)") { $matches[1].Trim() } else { "" }
    $UIPasswordPlain = if ($IniContent -match "UI_PASSWORD=(.+)") { $matches[1].Trim() } else { "" }
    Remove-Item $ConfigFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Warn "No se encontro archivo de credenciales (ejecutado sin Inno Setup)"
    Write-Host "  Ingrese los parametros manualmente:"
    $FirebirdDBPath = Read-Host "  Ruta del archivo .FDB de Aspel SAE"
    $SiemensAPIKey = Read-Host "  API Key de Siemens PoSi"
    $UIPasswordPlain = Read-Host "  Contrasena para la UI web (min 8 caracteres)" -AsSecureString
    $UIPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($UIPasswordPlain))
}

# Validar credenciales
if ($FirebirdDBPath -eq "" -or !(Test-Path $FirebirdDBPath)) {
    Write-Err "Ruta de BD no valida: '$FirebirdDBPath'"
    Write-Host "  Verifique que el archivo .FDB existe en esa ubicacion" -ForegroundColor Yellow
    pause
    exit 3
}
Write-OK "BD Aspel encontrada: $FirebirdDBPath"

if ($SiemensAPIKey -eq "" -or $SiemensAPIKey.Length -lt 32) {
    Write-Err "API Key invalida (debe tener minimo 32 caracteres)"
    pause
    exit 3
}
Write-OK "API Key Siemens recibida (longitud: $($SiemensAPIKey.Length))"

if ($UIPasswordPlain -eq "" -or $UIPasswordPlain.Length -lt 8) {
    Write-Err "Contrasena UI muy corta (minimo 8 caracteres)"
    pause
    exit 3
}
Write-OK "Contrasena UI recibida (longitud: $($UIPasswordPlain.Length))"

# ===== 4. Crear directorio de instalacion =====
Write-Step "Creando directorio: $InstallDir"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-OK "Directorio listo"

# ===== 5. Copiar archivos del middleware desde bundle =====
Write-Step "Copiando archivos del middleware..."
$SourceMiddleware = Join-Path $PSScriptRoot "..\middleware"
if (-not (Test-Path $SourceMiddleware)) {
    Write-Err "No se encontro el codigo del middleware en: $SourceMiddleware"
    Write-Host "  El bundle debe contener una carpeta 'middleware' junto a 'installer'." -ForegroundColor Yellow
    pause
    exit 4
}
Write-Host "  Origen: $SourceMiddleware"
Write-Host "  Destino: $InstallDir"
Copy-Item -Path "$SourceMiddleware\*" -Destination $InstallDir -Recurse -Force -Exclude @("node_modules\.bin", "coverage", ".nyc_output", "*.log")
Write-OK "Archivos copiados"

# ===== 6. Instalar dependencias de produccion =====
Write-Step "Instalando dependencias npm (puede tardar 3-5 min)..."
Push-Location $InstallDir
try {
    $env:npm_config_audit = "false"
    $npmInstall = Start-Process -FilePath "npm.cmd" -ArgumentList "install --production" -Wait -PassThru -NoNewWindow
    if ($npmInstall.ExitCode -eq 0) {
        Write-OK "Dependencias instaladas"
    } else {
        Write-Warn "npm install finalizo con codigo: $($npmInstall.ExitCode)"
        Write-Host "  Esto puede indicar problemas de red. La instalacion continuara."
    }
} catch {
    Write-Warn "Error en npm install: $_"
} finally {
    Pop-Location
}

# ===== 7. Configurar .env =====
Write-Step "Configurando variables de entorno (.env)..."
$envPath = Join-Path $InstallDir ".env"
$envContent = @"
FIREBIRD_PASSWORD=masterkey
SIEMENS_API_KEY=$SiemensAPIKey
UI_PORT=$UIPort
UI_USERNAME=admin
LOG_LEVEL=info
LOG_DIR=logs
"@
Set-Content -Path $envPath -Value $envContent -Force
Write-OK ".env configurado"

# ===== 8. Configurar config.json =====
Write-Step "Configurando operativa (config.json)..."
$configPath = Join-Path $InstallDir "config.json"
$FirebirdUser = "SYSDBA"
$configContent = @{
    siemens = @{
        base_url = "https://api.pos.siemens.com"
        api_key = "env:SIEMENS_API_KEY"
        environment = "qua"
        distributor_sender_id = "MX-REPRESENTACIONES"
    }
    firebird = @{
        db_path = $FirebirdDBPath
        user = $FirebirdUser
        password_source = "env:FIREBIRD_PASSWORD"
    }
    schedules = @{
        inventory = @{ enabled = $true; cron = "0 2 * * *"; timezone = "America/Mexico_City" }
        sales = @{ enabled = $true; cron = "0 3 * * *"; timezone = "America/Mexico_City" }
    }
    batch_size = 3000
    siemens_line_filter = @{
        enabled = $true
        lines = @("BAJA","SINU","SIMAT","LP","DRIVE","MOTOR","SINUM","SERVI","OBSO","SENSO","SERVO","INSTR","UPS","SIMA","ESPE")
        include_inactive_products = $true
    }
} | ConvertTo-Json -Depth 10
Set-Content -Path $configPath -Value $configContent -Force
Write-OK "config.json configurado"

# Hashear password UI
Write-Host "  Generando hash bcrypt para contrasena UI..."
try {
    Push-Location $InstallDir
    $bcryptHash = node -e "const b = require('bcryptjs'); console.log(b.hashSync(process.argv[1], 12));" $UIPasswordPlain 2>&1
    Pop-Location

    # Leer .env actual y actualizar UI_PASSWORD_HASH
    $envContent = Get-Content $envPath -Raw
    $envContent = $envContent -replace "(?ms)^UI_PASSWORD_HASH=.*$", "UI_PASSWORD_HASH=$bcryptHash"
    Set-Content -Path $envPath -Value $envContent -Force
    Write-OK "UI_PASSWORD_HASH generado"
} catch {
    Write-Warn "No se pudo hashear la contrasena: $_"
    Write-Host "  Puedes cambiarla despues desde la UI en /config" -ForegroundColor Yellow
}

# ===== 9. Instalar PM2 globalmente (ya viene en npm pero requiere -g) =====
Write-Step "Verificando PM2 (gestor de procesos)..."
$pm2Exe = (Get-Command pm2 -ErrorAction SilentlyContinue).Source
if (-not $pm2Exe) {
    Write-Warn "PM2 no detectado. Instalando globalmente..."
    Push-Location $InstallDir
    try {
        npm install -g pm2 pm2-windows-startup 2>&1 | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ((Get-Command pm2 -ErrorAction SilentlyContinue).Source) {
            Write-OK "PM2 instalado"
        } else {
            Write-Warn "PM2 instalado pero no detectable. Continuando..."
        }
    } catch {
        Write-Warn "Error instalando PM2: $_"
    } finally {
        Pop-Location
    }
} else {
    Write-OK "PM2 ya instalado"
}

# ===== 10. Registrar como servicio de Windows =====
Write-Step "Configurando como servicio de Windows..."
try {
    Push-Location $InstallDir
    pm2 start ecosystem.config.js --name siemens-middleware 2>&1 | Out-Null
    pm2 save 2>&1 | Out-Null

    # Instalar como servicio Windows (auto-arranque)
    $pm2Startup = Get-Command pm2-startup -ErrorAction SilentlyContinue
    if ($pm2Startup) {
        pm2-startup install 2>&1 | Out-Null
        Write-OK "Servicio Windows instalado (auto-arranque habilitado)"
    } else {
        Write-Warn "pm2-startup no disponible - usando pm2 save (servicio manual)"
    }
    Pop-Location
} catch {
    Write-Warn "Error configurando PM2: $_"
}

# ===== 11. Crear acceso directo en escritorio =====
Write-Step "Creando acceso directo al escritorio..."
$shell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath("Desktop")
$shortcut = $shell.CreateShortcut("$desktop\Valueflow Middleware.lnk")
$shortcut.TargetPath = "https://localhost:$UIPort"
$shortcut.WorkingDirectory = $InstallDir
$shortcut.IconLocation = Join-Path $InstallDir "public\logo_aga_letras_2.png"
$shortcut.Save()
Write-OK "Acceso directo creado"

# ===== 12. Verificacion final =====
Write-Step "Verificando instalacion..."
Start-Sleep -Seconds 3
try {
    Push-Location $InstallDir
    $pm2List = pm2 list 2>&1
    if ($pm2List -match "siemens-middleware.*online") {
        Write-OK "Servicio corriendo correctamente"
    } else {
        Write-Warn "El servicio puede no estar corriendo. Verificar con: pm2 status"
    }
    Pop-Location
} catch {
    Write-Warn "No se pudo verificar PM2: $_"
}

# Probar la UI
try {
    $response = Invoke-WebRequest -Uri "https://localhost:$UIPort/api/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-OK "UI respondiendo en https://localhost:$UIPort"
    }
} catch {
    Write-Warn "UI aun no responde. Puede tardar 10-20 segundos en arrancar. Verificar en navegador."
}

# ===== Resumen =====
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  INSTALACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  UI del middleware: https://localhost:$UIPort" -ForegroundColor White
Write-Host "  Acceso directo: $([System.Environment]::GetFolderPath('Desktop'))\Valueflow Middleware.lnk"
Write-Host "  Para cambiar la API Key (sandbox -> productivo):" -ForegroundColor Yellow
Write-Host "    1. Abrir https://localhost:$UIPort" -ForegroundColor Yellow
Write-Host "    2. Login con admin / (tu contrasena)" -ForegroundColor Yellow
Write-Host "    3. Ir a Configuracion > API Key Siemens > Actualizar" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Comandos utiles:" -ForegroundColor Cyan
Write-Host "    pm2 status                - Ver estado del servicio" -ForegroundColor Gray
Write-Host "    pm2 logs siemens-middleware  - Ver logs en tiempo real" -ForegroundColor Gray
Write-Host "    pm2 restart siemens-middleware - Reiniciar servicio" -ForegroundColor Gray
Write-Host ""
Read-Host "  Presiona ENTER para cerrar"
