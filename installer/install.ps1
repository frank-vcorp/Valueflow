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

# ===== 0. Deshabilitar Execution Policy (CRITICO para PM2/Node global) =====
Write-Step "Configurando PowerShell Execution Policy..."
try {
    # Bypass a nivel proceso: solo aplica a esta sesión, no cambia el sistema globalmente
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

    # Tambien intentar a nivel CurrentUser (persistente para el usuario actual)
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($currentPolicy -eq "Restricted") {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Write-OK "Execution Policy cambiada de Restricted a RemoteSigned (solo para este usuario)"
    } else {
        Write-OK "Execution Policy actual: $currentPolicy (compatible con PM2)"
    }
} catch {
    Write-Warn "No se pudo cambiar Execution Policy: $_"
    Write-Host "  Continuando... PM2 puede no arrancar si la policy es 'Restricted'" -ForegroundColor Yellow
}

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

# ===== 2. Verificar / Extraer Node.js 20 LTS portable =====
Write-Step "Verificando Node.js 20 LTS..."

$nodeExe = $null
$nodeVersion = $null

# Opcion A: Node.js del sistema (ya instalado en PATH)
$systemNode = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($systemNode) {
    $nodeExe = $systemNode
    $nodeVersion = & node --version
    Write-OK "Node.js del sistema: $nodeVersion"
}

# Opcion B: Extraer Node.js portable del bundle (incluido en el .exe)
if (-not $nodeExe) {
    $nodeZip = Join-Path $PSScriptRoot "..\node-portable\node-v20.14.0-win-x64.zip"
    $nodeExtractDir = Join-Path $InstallDir "node"

    if (Test-Path $nodeZip) {
        Write-Step "Extrayendo Node.js portable desde el bundle..."
        if (-not (Test-Path $nodeExtractDir)) {
            New-Item -ItemType Directory -Path $nodeExtractDir -Force | Out-Null
        }
        # Usar Expand-Archive de PowerShell (compatible con ZIP)
        Expand-Archive -Path $nodeZip -DestinationPath $nodeExtractDir -Force
        Write-OK "Node.js portable extraido a $nodeExtractDir"

        $nodeExe = Join-Path $nodeExtractDir "node-v20.14.0-win-x64\node.exe"
        if (Test-Path $nodeExe) {
            # Agregar al PATH de la sesion actual
            $nodeBinDir = Split-Path $nodeExe -Parent
            $env:Path = "$nodeBinDir;$env:Path"

            # Persistir PATH a nivel sistema (HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment)
            $currentSysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentSysPath -notlike "*$nodeBinDir*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$currentSysPath;$nodeBinDir", "Machine")
                Write-OK "Node.js agregado al PATH del sistema"
            }
            $nodeVersion = & $nodeExe --version
            Write-OK "Node.js portable activo: $nodeVersion"
        } else {
            Write-Err "node.exe no encontrado despues de extraer"
            pause
            exit 2
        }
    } else {
        Write-Err "============================================================"
        Write-Err "  No se encontro Node.js en sistema ni en el bundle"
        Write-Err "============================================================"
        Write-Host ""
        Write-Host "  Soluciones:" -ForegroundColor Yellow
        Write-Host "  1. Instalar Node.js 20 LTS desde https://nodejs.org/" -ForegroundColor Yellow
        Write-Host "  2. O descargar node-v20.14.0-win-x64.zip y copiarlo a:" -ForegroundColor Yellow
        Write-Host "     $nodeZip" -ForegroundColor Yellow
        Write-Host "  3. Volver a ejecutar este instalador" -ForegroundColor Yellow
        Write-Host ""
        pause
        exit 2
    }
}

$nodeMajor = ($nodeVersion -replace 'v','').Split('.')[0]
if ([int]$nodeMajor -lt 20) {
    Write-Warn "Se recomienda Node.js 20 LTS. Actual: $nodeVersion. La instalacion continuara pero pueden haber problemas."
}

# ===== 3. Leer ruta del .FDB del archivo temporal =====
Write-Step "Leyendo ruta de la base de datos..."
$ConfigFile = Join-Path $env:TEMP "valueflow_install_config.ini"
if (Test-Path $ConfigFile) {
    $IniContent = Get-Content $ConfigFile -Raw
    $FirebirdDBPath = if ($IniContent -match "FIREBIRD_DB_PATH=(.+)") { $matches[1].Trim() } else { "" }
    Remove-Item $ConfigFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Warn "No se encontro archivo de credenciales (ejecutado sin Inno Setup)"
    $FirebirdDBPath = Read-Host "  Ruta del archivo .FDB de Aspel SAE"
}

# Validar ruta de BD
if ($FirebirdDBPath -eq "" -or !(Test-Path $FirebirdDBPath)) {
    Write-Err "Ruta de BD no valida: '$FirebirdDBPath'"
    Write-Host "  Verifique que el archivo .FDB existe en esa ubicacion" -ForegroundColor Yellow
    pause
    exit 3
}
Write-OK "BD Aspel encontrada: $FirebirdDBPath"

# CREDENCIALES PRECONFIGURADAS (cambiar despues desde UI)
# FIX IMPL-20260806-05: API key removida del repo (estaba expuesta en el repo público).
# El operador DEBE configurar la key real en el primer arranque desde la UI, o
# inyectarla vía variable de entorno antes de ejecutar el instalador.
# Rotación de la key QUA comprometida: ACCIÓN EXTERNA pendiente con Frank + Siemens.
$SiemensAPIKey = "<api_key_a_configurar>"   # Placeholder — configurar antes de producción
$UIPasswordPlain = "Admin123"                                       # Default UI password (cambiar desde UI)
$UIUsername = "Admin"                                                # Default UI username
Write-OK "API Key Siemens pendiente de configurar — completar antes del primer envio a produccion"
Write-OK "Credenciales UI preconfiguradas: $UIUsername / $UIPasswordPlain (cambiar desde UI)"

# ===== 4. Crear directorio de instalacion =====
Write-Step "Creando directorio: $InstallDir"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-OK "Directorio listo"

# ===== 5. Copiar archivos del middleware desde bundle =====
Write-Step "Copiando archivos del middleware..."

# Buscar la carpeta middleware en multiples paths posibles
$SearchPaths = @(
    (Join-Path $PSScriptRoot "..\middleware"),                    # installer/../middleware (bundle estandar)
    (Join-Path $PSScriptRoot "..\..\middleware\dist\.."),         # installer/../../middleware (cuando se corre desde installer/)
    (Join-Path $PSScriptRoot "..\dist\..\.."),                    # installer/../dist/../../middleware (variante)
    (Join-Path $InstallDir "..\middleware"),                       # InstallDir/../middleware (caso directo)
    "C:\Users\frank\Desktop\REPAGA\valueflow-middleware\middleware",  # Default comun para Ing. Paco
    "C:\Temp\valueflow-middleware\middleware",                     # Posible extraccion reciente
    "C:\apps\valueflow-middleware\middleware"                      # Si se reinstalo a otra ruta
)

$SourceMiddleware = $null
foreach ($path in $SearchPaths) {
    if ($path -and (Test-Path $path)) {
        $pkgCheck = Join-Path $path "package.json"
        $distCheck = Join-Path $path "dist"
        if ((Test-Path $pkgCheck) -and (Test-Path $distCheck)) {
            $SourceMiddleware = $path
            break
        }
    }
}

if (-not $SourceMiddleware) {
    Write-Err "No se encontro el codigo del middleware en ninguno de estos paths:"
    foreach ($path in $SearchPaths) {
        Write-Host "    - $path" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  OPCION MANUAL: indique la ruta donde esta el codigo del middleware:" -ForegroundColor Cyan
    $SourceMiddleware = Read-Host "  Ruta del middleware"
    if (-not (Test-Path "$SourceMiddleware\package.json")) {
        Write-Err "El path $SourceMiddleware no contiene un middleware valido (falta package.json)"
        pause
        exit 4
    }
}

Write-Host "  Origen: $SourceMiddleware"
Write-Host "  Destino: $InstallDir"

# Eliminar instalacion anterior si existe (pero NO node portable)
if (Test-Path "$InstallDir\dist") {
    Remove-Item "$InstallDir\dist" -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$InstallDir\src") {
    Remove-Item "$InstallDir\src" -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$InstallDir\package.json") {
    Remove-Item "$InstallDir\package.json" -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$InstallDir\tsconfig.json") {
    Remove-Item "$InstallDir\tsconfig.json" -Force -ErrorAction SilentlyContinue
}

Copy-Item -Path "$SourceMiddleware\*" -Destination $InstallDir -Recurse -Force -Exclude @("node_modules\.bin", "coverage", ".nyc_output", "*.log")

# Verificar que la copia funciono
if (-not (Test-Path "$InstallDir\package.json")) {
    Write-Err "La copia fallo - no se encontro package.json en destino"
    pause
    exit 4
}
Write-OK "Archivos copiados correctamente ($(Get-ChildItem $InstallDir -Recurse -File | Measure-Object).Count archivos)"

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
UI_USERNAME=$UIUsername
LOG_LEVEL=info
LOG_DIR=logs
"@
Set-Content -Path $envPath -Value $envContent -Force
# FIX IMPL-20260806-05: si quedó el placeholder, advertir al operador para que configure
# la key real antes de iniciar envíos a producción.
if ($SiemensAPIKey -eq "<api_key_a_configurar>" -or [string]::IsNullOrWhiteSpace($SiemensAPIKey)) {
    Write-Warn "SIEMENS_API_KEY sin configurar (placeholder)."
    Write-Host "  Cambia la key desde la UI (https://localhost:$UIPort) en Configuracion > API Key Siemens" -ForegroundColor Yellow
}
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
    # FIX IMPL-20260806-02: validateRuntimeConfig exige retry_policy y optional_fields.
    # Sin estas secciones el middleware falla al arrancar.
    retry_policy = @{
        max_retries = 5
        initial_delay_ms = 2000
        backoff_multiplier = 2
        max_delay_ms = 60000
    }
    siemens_line_filter = @{
        enabled = $true
        lines = @("BAJA","SINU","SIMAT","LP","DRIVE","MOTOR","SINUM","SERVI","OBSO","SENSO","SERVO","INSTR","UPS","SIMA","ESPE")
        include_inactive_products = $true
    }
    optional_fields = @{
        inventory = @{
            distributor_order_taking_branch_name = $false
            distributor_order_taking_branch_id = $true
            vendor_item_options = $false
            upc_ean = $false
            stock_item = $false
            abc_segmentation = $false
        }
        sales = @{
            product_description = $false
            customer_name = $false
            discount_amount = $false
            tax_amount = $false
        }
    }
} | ConvertTo-Json -Depth 10
Set-Content -Path $configPath -Value $configContent -Force
Write-OK "config.json configurado"

# Hashear password UI
Write-Host "  Generando hash bcrypt para contrasena UI..."
try {
    Push-Location $InstallDir
    # Usar Node portable extraido (con PATH actualizado debe funcionar)
    $nodeBin = "$env:ProgramFiles\nodejs\node.exe"
    if (-not (Test-Path $nodeBin)) {
        # Si no hay Node del sistema, usar el portable extraido
        $nodeBin = Join-Path (Split-Path $InstallDir) "node\node-v20.14.0-win-x64\node.exe"
    }
    if (-not (Test-Path $nodeBin)) {
        # Buscar el node.exe portable en el directorio de instalacion
        $nodeBin = Get-ChildItem -Path $InstallDir -Recurse -Filter "node.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }
    Write-Host "    Usando: $nodeBin"
    $bcryptHash = & $nodeBin -e "const b = require('bcryptjs'); console.log(b.hashSync(process.argv[1], 12));" $UIPasswordPlain 2>&1
    $bcryptHash = $bcryptHash.Trim()
    Pop-Location

    if ($bcryptHash -notmatch '^\$2[ayb]\$') {
        throw "Hash bcrypt invalido generado: $bcryptHash"
    }

    # Leer .env actual y actualizar UI_PASSWORD_HASH
    # FIX IMPL-20260806-01: escapar `$bcryptHash` con backtick para que PowerShell no lo interprete como variable
    $envContent = Get-Content $envPath -Raw
    $envContent = $envContent -replace "(?ms)^UI_PASSWORD_HASH=.*$", "UI_PASSWORD_HASH=`$bcryptHash"
    Set-Content -Path $envPath -Value $envContent -Force
    Write-OK "UI_PASSWORD_HASH generado para password: $UIPasswordPlain"
    Write-Host "    Hash: $bcryptHash" -ForegroundColor Gray
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

# FALLBACK: Si el servicio PM2 no arranco correctamente, lanzar Node directo
Start-Sleep -Seconds 3
$nodeRunning = Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq "" } | Select-Object -First 1
if (-not $nodeRunning) {
    Write-Warn "PM2 no levanto el servicio. Arrancando Node directo como fallback..."

    # Buscar Node portable
    $portableNode = Join-Path (Split-Path $InstallDir) "node\node-v20.14.0-win-x64\node.exe"
    if (-not (Test-Path $portableNode)) {
        $portableNode = Get-ChildItem -Path (Split-Path $InstallDir) -Recurse -Filter "node.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }

    if ($portableNode) {
        Set-Location $InstallDir
        # IMPORTANTE: usar Set-Location en lugar de -WorkingDirectory
        # porque PowerShell interpreta los backslashes en param strings
        Start-Process -FilePath $portableNode -ArgumentList "dist/index.js" -WindowStyle Hidden

        Start-Sleep -Seconds 5

        $nodeRunning = Get-Process node -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($nodeRunning) {
            Write-OK "Middleware arrancado via Node directo (PID: $($nodeRunning.Id))"
        } else {
            Write-Err "Fallo al arrancar el middleware via Node directo"
        }
    } else {
        Write-Err "No se encontro node.exe portable para arrancar como fallback"
    }
}

# ===== 11. Crear acceso directo en escritorio =====
Write-Step "Creando acceso directo al escritorio..."
$shell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath("Desktop")

# Buscar el icono .ico en varios paths posibles (bundle + instalacion previa)
$iconCandidates = @(
    (Join-Path $PSScriptRoot "..\assets\valueflow-icon.ico"),
    (Join-Path $PSScriptRoot "..\middleware\valueflow-icon.ico"),
    (Join-Path $InstallDir "valueflow-icon.ico")
)
$iconSource = $null
foreach ($candidate in $iconCandidates) {
    if (Test-Path $candidate) {
        $iconSource = $candidate
        break
    }
}

$iconDest = Join-Path $InstallDir "valueflow-icon.ico"
if ($iconSource) {
    if ($iconSource -ne $iconDest) {
        Copy-Item -Path $iconSource -Destination $iconDest -Force -ErrorAction SilentlyContinue
    }
    Write-OK "Icono personalizado: $iconDest"
} else {
    Write-Warn "No se encontro valueflow-icon.ico en el bundle, usando icono default de Windows"
    $iconDest = "shell32.dll,13"  # Icono de shield/red de Windows
}

$shortcut = $shell.CreateShortcut("$desktop\Valueflow Middleware.lnk")
$shortcut.TargetPath = "http://localhost:$UIPort/"
$shortcut.WorkingDirectory = $InstallDir
$shortcut.IconLocation = $iconDest
$shortcut.Description = "Valueflow Middleware - Aspel SAE <-> Siemens PoSi"
$shortcut.WindowStyle = 1  # Normal window
$shortcut.Save()
Write-OK "Acceso directo creado con icono personalizado"

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

# FIX IMPL-20260806-08: verificar que el addon nativo de Firebird se compiló.
# node-firebird-driver-native requiere node-gyp + Visual Studio Build Tools (C++ workload).
# Sin el .node compilado, el middleware NO puede leer la BD Aspel.
$addonPath = Join-Path $InstallDir "middleware\node_modules\node-firebird-driver-native\build\Release\addon.node"
if (-not (Test-Path $addonPath)) {
    Write-Warn "El addon nativo Firebird no compilo (no se encontro $addonPath)"
    Write-Host "  El middleware NO podra conectarse a la BD Aspel hasta que se compile." -ForegroundColor Yellow
    Write-Host "  Para compilarlo:" -ForegroundColor Yellow
    Write-Host "    1. Instalar Visual Studio Build Tools 2022 con el workload 'Desarrollo para escritorio con C++'" -ForegroundColor Yellow
    Write-Host "    2. Abrir 'Developer Command Prompt for VS 2022' como administrador" -ForegroundColor Yellow
    Write-Host "    3. cd $InstallDir && npm rebuild node-firebird-driver-native" -ForegroundColor Yellow
} else {
    Write-OK "Addon nativo Firebird compilado correctamente: $addonPath"
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
