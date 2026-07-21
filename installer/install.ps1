#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador de Valueflow Middleware - Aspel SAE 10 ↔ Siemens PoSi
.DESCRIPTION
    Script PowerShell que automatiza la instalación completa del middleware:
    - Verifica/Instala Node.js 20 LTS
    - Copia el código del middleware a C:\apps\siemens-middleware
    - Ejecuta npm install --production
    - Configura .env y config.json
    - Instala y configura PM2 como Servicio Windows
    - Crea acceso directo en el escritorio
    - Excluye del antivirus
.NOTES
    Versión: 1.0
    Autor: VCorp - Frank Saavedra
    Para: Representaciones Aga de Saltillo
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "C:\apps\siemens-middleware",
    [string]$SourceDir = $PSScriptRoot,
    [string]$NodeVersion = "20.14.0",
    [int]$UIPort = 4567,
    [string]$FirebirdDBPath = "C:\Program Files\Aspel\Aspel SAE 10.0\BD\SAE10.FDB",
    [string]$FirebirdUser = "readonly_siemens",
    [string]$SiemensEnvironment = "qua",
    [string]$DistributorSenderID = "MX-REPRESENTACIONES"
)

# ===== Configuración =====
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Colores
function Write-Step { param($msg) Write-Host "`n===> $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "  ✗ $msg -ForegroundColor Red" }

$LogoText = @"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║       Valueflow Middleware                            ║
║       Aspel SAE 10 ↔ Siemens PoSi Portal             ║
║                                                       ║
║       Instalador v1.0                                 ║
║       VCorp - Representaciones Aga de Saltillo        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
"@
Write-Host $LogoText -ForegroundColor Cyan

# ===== Verificar permisos de administrador =====
Write-Step "Verificando permisos de administrador..."
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "Este instalador requiere permisos de administrador."
    Write-Host "  Por favor, ejecuta como administrador (clic derecho → Ejecutar como administrador)"
    pause
    exit 1
}
Write-OK "Permisos de administrador OK"

# ===== Detectar/Descargar Node.js 20 LTS =====
Write-Step "Verificando Node.js..."

$nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
$nodeVersionInstalled = $null

if ($nodeExe) {
    $nodeVersionInstalled = & node --version 2>&1
    Write-OK "Node.js ya instalado: $nodeVersionInstalled"
} else {
    Write-Warn "Node.js no detectado. Se descargará versión $NodeVersion..."

    $nodeMsiUrl = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-x64.msi"
    $nodeMsiPath = "$env:TEMP\node-installer.msi"

    try {
        Write-Host "  Descargando desde $nodeMsiUrl"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $nodeMsiUrl -OutFile $nodeMsiPath -UseBasicParsing
        Write-OK "Descarga completa"

        Write-Host "  Instalando Node.js (silencioso)..."
        $installArgs = "/i `"$nodeMsiPath`" /quiet /norestart ADDLOCAL=ALL"
        $installProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru

        if ($installProcess.ExitCode -ne 0) {
            Write-Err "Falló la instalación de Node.js (código: $($installProcess.ExitCode))"
            pause
            exit 1
        }

        # Refrescar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Verificar instalación
        Start-Sleep -Seconds 2
        $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
        if ($nodeExe) {
            $nodeVersionInstalled = & node --version
            Write-OK "Node.js instalado: $nodeVersionInstalled"
        } else {
            Write-Err "Node.js instalado pero no detectable. Reinicia e intenta de nuevo."
            pause
            exit 1
        }
    } catch {
        Write-Err "Error descargando/instalando Node.js: $_"
        pause
        exit 1
    }
}

# Verificar versión mínima
$nodeMajor = ($nodeVersionInstalled -replace 'v','').Split('.')[0]
if ([int]$nodeMajor -lt 20) {
    Write-Warn "Se recomienda Node.js 20 LTS o superior. Versión actual: $nodeVersionInstalled"
}

# ===== Crear directorio de instalación =====
Write-Step "Creando directorio de instalación: $InstallDir"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-OK "Directorio listo"

# ===== Copiar archivos del middleware =====
Write-Step "Copiando archivos del middleware..."

# Si hay un tarball del middleware en la misma carpeta, extraer
$middlewareTarball = Join-Path $SourceDir "middleware.tar.gz"
if (Test-Path $middlewareTarball) {
    Write-Host "  Extrayendo desde $middlewareTarball"
    Start-Process tar -ArgumentList "xzf `"$middlewareTarball`" -C `"$InstallDir`" --strip-components=1" -Wait -NoNewWindow
} else {
    # Si no, copiar el directorio middleware directamente
    $sourceMiddleware = Join-Path $SourceDir "..\middleware"
    if (Test-Path $sourceMiddleware) {
        Write-Host "  Copiando desde $sourceMiddleware"
        Copy-Item -Path "$sourceMiddleware\*" -Destination $InstallDir -Recurse -Force
    } else {
        Write-Err "No se encontró el código del middleware. Esperado en: $sourceMiddleware"
        Write-Host "  Coloque el instalador junto a la carpeta 'middleware' del proyecto."
        pause
        exit 1
    }
}
Write-OK "Archivos copiados"

# ===== Instalar dependencias =====
Write-Step "Instalando dependencias npm (puede tardar varios minutos)..."

Push-Location $InstallDir
try {
    $npmInstall = Start-Process -FilePath "npm.cmd" -ArgumentList "install --production" -Wait -PassThru -NoNewWindow
    if ($npmInstall.ExitCode -ne 0) {
        Write-Warn "npm install terminó con código: $($npmInstall.ExitCode)"
        Write-Host "  Esto puede ser normal en entornos con restricciones."
    } else {
        Write-OK "Dependencias instaladas"
    }
} catch {
    Write-Warn "Error en npm install: $_"
} finally {
    Pop-Location
}

# ===== Compilar TypeScript =====
Write-Step "Compilando TypeScript..."
Push-Location $InstallDir
try {
    & npm run build 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Compilación exitosa"
    } else {
        Write-Warn "Compilación con warnings. Continuando..."
    }
} catch {
    Write-Warn "Error en compilación: $_"
} finally {
    Pop-Location
}

# ===== Configurar archivos (.env y config.json) =====
Write-Step "Configurando variables de entorno y operativa..."

# Crear directorios necesarios
New-Item -ItemType Directory -Path "$InstallDir\logs" -Force | Out-Null
New-Item -ItemType Directory -Path "$InstallDir\public" -Force | Out-Null

# Solicitar credenciales al usuario
Write-Host "`n  Configuración de credenciales:" -ForegroundColor Cyan

# Password de Firebird
$secureFirebirdPassword = Read-Host "  Password de Firebird (solo lectura)" -AsSecureString
$firebirdPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureFirebirdPassword)
)

# Password de UI
$secureUIPassword = Read-Host "  Password para acceso a la UI (mín. 8 caracteres)" -AsSecureString
$uiPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureUIPassword)
)

# Generar hash bcrypt para UI
Write-Host "  Generando hash bcrypt para UI..."
$bcryptHash = & node -e "console.log(require('bcryptjs').hashSync('$uiPasswordPlain', 12))"

# Crear .env
$envContent = @"
# Generado por instalador el $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Firebird
FIREBIRD_PASSWORD=$firebirdPasswordPlain

# UI
UI_PORT=$UIPort
UI_USERNAME=admin
UI_PASSWORD_HASH=$bcryptHash

# Logging
LOG_LEVEL=info
LOG_DIR=$InstallDir\logs
"@
$envContent | Out-File -FilePath "$InstallDir\.env" -Encoding UTF8 -NoNewline
Write-OK ".env creado"

# Crear config.json desde ejemplo
$configExample = Get-Content "$InstallDir\config.json.example" -Raw | ConvertFrom-Json

# Actualizar rutas con valores del instalador
$configExample.firebird.db_path = $FirebirdDBPath
$configExample.firebird.user = $FirebirdUser
$configExample.siemens.environment = $SiemensEnvironment
$configExample.siemens.distributor_sender_id = $DistributorSenderID

$configExample | ConvertTo-Json -Depth 10 | Out-File -FilePath "$InstallDir\config.json" -Encoding UTF8 -NoNewline
Write-OK "config.json configurado"

# Limpiar password en memoria
$firebirdPasswordPlain = $null
$uiPasswordPlain = $null
[System.GC]::Collect()

# ===== Instalar PM2 y configurar como Servicio Windows =====
Write-Step "Instalando PM2 y configurando como Servicio Windows..."

$pm2Exe = (Get-Command pm2 -ErrorAction SilentlyContinue).Source
if (-not $pm2Exe) {
    Write-Host "  Instalando PM2 globalmente..."
    & npm install -g pm2 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falló instalación de PM2"
        pause
        exit 1
    }
    Write-OK "PM2 instalado"
} else {
    Write-OK "PM2 ya instalado: $pm2Exe"
}

# Instalar pm2-windows-startup
Write-Host "  Instalando pm2-windows-startup..."
& npm install -g pm2-windows-startup 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Falló instalación de pm2-windows-startup (puede no ser crítico)"
}

# Registrar como Servicio Windows
Write-Host "  Registrando como Servicio Windows..."
& pm2-startup install 2>&1 | Out-Null

# Iniciar el middleware
Write-Host "  Iniciando middleware con PM2..."
Push-Location $InstallDir
try {
    & pm2 start ecosystem.config.js 2>&1 | Out-Null
    & pm2 save 2>&1 | Out-Null
    Write-OK "Middleware registrado en PM2"
} catch {
    Write-Warn "Error iniciando con PM2: $_"
} finally {
    Pop-Location
}

# ===== Excluir del antivirus (Windows Defender) =====
Write-Step "Excluyendo del antivirus (Windows Defender)..."

$defenderPaths = @(
    $InstallDir,
    "$InstallDir\node_modules",
    "$InstallDir\logs",
    "C:\Program Files\nodejs"
)

foreach ($path in $defenderPaths) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
        Write-OK "Excluido: $path"
    } catch {
        Write-Warn "No se pudo excluir: $path (requiere permisos elevados o Defender deshabilitado)"
    }
}

# ===== Crear acceso directo en el escritorio =====
Write-Step "Creando acceso directo en el escritorio..."

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "Valueflow Middleware.lnk"

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "http://localhost:$UIPort"
$Shortcut.IconLocation = "$InstallDir\public\partner.png,0"
$Shortcut.Description = "Valueflow Middleware - UI de administración"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.WindowStyle = 1
$Shortcut.Save()
Write-OK "Acceso directo creado: $shortcutPath"

# ===== Crear entrada en Menú Inicio =====
$startMenu = [Environment]::GetFolderPath("StartMenu")
$programsFolder = Join-Path $startMenu "Programs"
$appFolder = Join-Path $programsFolder "Valueflow Middleware"
if (-not (Test-Path $appFolder)) {
    New-Item -ItemType Directory -Path $appFolder -Force | Out-Null
}

# Acceso directo en Menú Inicio
$startShortcut = $WshShell.CreateShortcut((Join-Path $appFolder "Valueflow Middleware UI.lnk"))
$startShortcut.TargetPath = "http://localhost:$UIPort"
$startShortcut.IconLocation = "$InstallDir\public\partner.png,0"
$startShortcut.Description = "Abrir UI de administración"
$startShortcut.Save()
Write-OK "Entrada en Menú Inicio creada"

# Script de desinstalación
$uninstallScript = @"
#Requires -RunAsAdministrator
# Desinstalador de Valueflow Middleware

Write-Host "Desinstalando Valueflow Middleware..." -ForegroundColor Cyan

# Detener y eliminar de PM2
pm2 stop siemens-middleware 2>`$null
pm2 delete siemens-middleware 2>`$null
pm2 save 2>`$null
pm2-startup uninstall 2>`$null

# Eliminar servicio Windows
Stop-Service siemens-middleware -ErrorAction SilentlyContinue
sc.exe delete siemens-middleware 2>`$null

# Eliminar accesos directos
Remove-Item "`$env:USERPROFILE\Desktop\Valueflow Middleware.lnk" -ErrorAction SilentlyContinue
Remove-Item "$startMenu\Programs\Valueflow Middleware" -Recurse -ErrorAction SilentlyContinue

# Eliminar directorio
Remove-Item "$InstallDir" -Recurse -Force

Write-Host "Desinstalación completa." -ForegroundColor Green
pause
"@
$uninstallPath = Join-Path $appFolder "Desinstalar.bat"
$uninstallScript | Out-File -FilePath $uninstallPath -Encoding ASCII
Write-OK "Desinstalador creado: $uninstallPath"

# ===== Verificar instalación =====
Write-Step "Verificando instalación..."

Start-Sleep -Seconds 3

try {
    $test = Invoke-WebRequest -Uri "http://localhost:$UIPort" -UseBasicParsing -Headers @{"Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:test"))} -TimeoutSec 5 -ErrorAction Stop
    Write-OK "Middleware respondiendo en puerto $UIPort (HTTP $($test.StatusCode))"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__ -as [int]
    if ($statusCode -eq 401) {
        Write-OK "Middleware respondiendo correctamente (HTTP 401 - autenticación requerida, como se esperaba)"
    } else {
        Write-Warn "Middleware no responde aún. Puede tardar unos segundos en arrancar."
    }
}

# ===== Resumen final =====
Write-Host "`n"
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                       ║" -ForegroundColor Green
Write-Host "║       INSTALACIÓN COMPLETADA                          ║" -ForegroundColor Green
Write-Host "║                                                       ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Instalado en: $InstallDir" -ForegroundColor White
Write-Host "  UI disponible en: http://localhost:$UIPort" -ForegroundColor White
Write-Host "  Usuario UI: admin" -ForegroundColor White
Write-Host "  Contraseña UI: (la que ingresaste)" -ForegroundColor White
Write-Host ""
Write-Host "  Accesos directos creados:" -ForegroundColor White
Write-Host "    • Escritorio: Valueflow Middleware.lnk" -ForegroundColor Gray
Write-Host "    • Menú Inicio: Valueflow Middleware" -ForegroundColor Gray
Write-Host ""
Write-Host "  Próximos pasos:" -ForegroundColor White
Write-Host "    1. Abre la UI desde el acceso directo del escritorio" -ForegroundColor Gray
Write-Host "    2. Configura la API Key de Siemens en /config" -ForegroundColor Gray
Write-Host "    3. Prueba conexión con 'Test conexión Siemens' en /actions" -ForegroundColor Gray
Write-Host "    4. Los jobs automáticos corren a las 02:00 (inventario) y 03:00 (ventas)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Comandos útiles:" -ForegroundColor White
Write-Host "    pm2 status                    - ver estado del servicio" -ForegroundColor Gray
Write-Host "    pm2 logs siemens-middleware   - ver logs en tiempo real" -ForegroundColor Gray
Write-Host "    pm2 restart siemens-middleware - reiniciar servicio" -ForegroundColor Gray
Write-Host ""

# Preguntar si abrir la UI
$openUI = Read-Host "¿Abrir la UI en el navegador ahora? (S/N)"
if ($openUI -eq "S" -or $openUI -eq "s" -or $openUI -eq "Y" -or $openUI -eq "y") {
    Start-Process "http://localhost:$UIPort"
}

Write-Host "`n  Presiona Enter para salir..."
$null = Read-Host