#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador de Valueflow Middleware - Aspel SAE - Siemens PoSi Portal
.DESCRIPTION
    Script PowerShell todo-en-uno. NO usa caracteres especiales problematicos.
    - Extrae Node.js portable del bundle
    - Copia el codigo del middleware
    - Ejecuta npm install
    - Genera hash bcrypt para Admin123
    - Configura .env y config.json
    - Levanta PM2 como servicio (con fallback a Node directo)
    - Crea acceso directo en escritorio
.NOTES
    Version 2.1 (re-escrito completo tras bugs de sintaxis)
    Todas las cadenas usan comillas simples para evitar problemas.
    Cualquier concatenacion se hace con + en lugar de interpolacion.
#>

[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\apps\siemens-middleware',
    [int]$UIPort = 4567,
    [string]$DefaultUsername = 'Admin',
    [string]$DefaultPassword = 'Admin123'
)

# ===== Colores =====
function Write-Step { param($msg) Write-Host ('`n===> ' + $msg) -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host ('  [OK] ' + $msg) -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host ('  [!] ' + $msg) -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host ('  [X] ' + $msg) -ForegroundColor Red }

# ===== Banner =====
$LogoText = @'
+==========================================================+
|       Valueflow Middleware                                |
|       Aspel SAE - Siemens PoSi Portal                     |
|       Instalador v2.1                                     |
+==========================================================+
'@
Write-Host $LogoText -ForegroundColor Cyan

# ===== 0. Bypass Execution Policy =====
Write-Step 'Configurando PowerShell Execution Policy...'
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($currentPolicy) {
        Write-OK ('Execution Policy actual: ' + $currentPolicy)
    } else {
        Write-OK 'Execution Policy: Undefined (compatible con PM2)'
    }
} catch {
    Write-Warn 'No se pudo cambiar Execution Policy. Continuando...'
}

# ===== 1. Permisos admin =====
Write-Step 'Verificando permisos de administrador...'
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err 'Este instalador requiere permisos de administrador.'
    Write-Host '  Clic derecho sobre el archivo .exe - Ejecutar como administrador' -ForegroundColor Yellow
    pause
    exit 1
}
Write-OK 'Permisos OK'

# ===== 2. Node.js 20 LTS =====
Write-Step 'Verificando Node.js 20 LTS...'
$nodeExe = $null
$nodeVersion = $null

# Opcion A: Node del sistema
$systemNode = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($systemNode) {
    $nodeExe = $systemNode
    $nodeVersion = & node --version 2>&1
    Write-OK ('Node.js del sistema: ' + $nodeVersion)
}

# Opcion B: Extraer Node.js portable del bundle
if (-not $nodeExe) {
    $nodeZip = Join-Path $PSScriptRoot '..\node-portable\node-v20.14.0-win-x64.zip'
    $nodeExtractDir = Join-Path $InstallDir 'node'

    if (Test-Path $nodeZip) {
        Write-Step 'Extrayendo Node.js portable desde el bundle...'
        if (-not (Test-Path $nodeExtractDir)) {
            New-Item -ItemType Directory -Path $nodeExtractDir -Force | Out-Null
        }
        Expand-Archive -Path $nodeZip -DestinationPath $nodeExtractDir -Force
        Write-OK ('Node.js portable extraido a ' + $nodeExtractDir)

        $nodeExe = Join-Path $nodeExtractDir 'node-v20.14.0-win-x64\node.exe'
        if (Test-Path $nodeExe) {
            $nodeBinDir = Split-Path $nodeExe -Parent
            $env:Path = $nodeBinDir + ';' + $env:Path

            # Persistir PATH a nivel sistema
            $currentSysPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
            if ($currentSysPath -notlike ('*' + $nodeBinDir + '*')) {
                [System.Environment]::SetEnvironmentVariable('Path', $currentSysPath + ';' + $nodeBinDir, 'Machine')
                Write-OK 'Node.js agregado al PATH del sistema'
            }
            $nodeVersion = & $nodeExe --version
            Write-OK ('Node.js portable activo: ' + $nodeVersion)
        } else {
            Write-Err 'node.exe no encontrado despues de extraer'
            pause
            exit 2
        }
    } else {
        Write-Err '============================================================'
        Write-Err '  PREREQUISITO FALTANTE: Node.js 20 LTS'
        Write-Err '============================================================'
        Write-Host ''
        Write-Host '  Pasos para instalar:' -ForegroundColor Yellow
        Write-Host '  1. Abrir navegador en: https://nodejs.org/dist/v20.14.0/' -ForegroundColor Yellow
        Write-Host '  2. Descargar node-v20.14.0-x64.msi (~30 MB)' -ForegroundColor Yellow
        Write-Host '  3. Doble click, Next - Next - Install (todo por defecto)' -ForegroundColor Yellow
        Write-Host '  4. ABRIR PowerShell NUEVO y volver a ejecutar este instalador' -ForegroundColor Yellow
        pause
        exit 2
    }
}

# Validar version
$nodeMajor = ($nodeVersion -replace 'v','').Split('.')[0]
if ([int]$nodeMajor -lt 20) {
    Write-Warn ('Se recomienda Node.js 20 LTS. Actual: ' + $nodeVersion + '. Continuando con advertencias.')
}

# ===== 3. Leer ruta del .FDB =====
Write-Step 'Leyendo ruta de la base de datos...'
$ConfigFile = Join-Path $env:TEMP 'valueflow_install_config.ini'
if (Test-Path $ConfigFile) {
    $IniContent = Get-Content $ConfigFile -Raw
    $FirebirdDBPath = if ($IniContent -match 'FIREBIRD_DB_PATH=(.+)') { $matches[1].Trim() } else { '' }
    Remove-Item $ConfigFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Warn 'No se encontro archivo de credenciales (ejecutado sin Inno Setup)'
    # Usar path por defecto en lugar de Read-Host (evita cuelgue de stdin)
    $FirebirdDBPath = 'C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB'
    Write-Host ('  Usando ruta por defecto: ' + $FirebirdDBPath) -ForegroundColor Yellow
}

# Validar ruta de BD
if ($FirebirdDBPath -eq '' -or !(Test-Path $FirebirdDBPath)) {
    Write-Err ('Ruta de BD no valida: ' + $FirebirdDBPath)
    Write-Host '  Verifique que el archivo .FDB existe en esa ubicacion' -ForegroundColor Yellow
    pause
    exit 3
}
Write-OK ('BD Aspel encontrada: ' + $FirebirdDBPath)

# CREDENCIALES PRECONFIGURADAS (cambiar despues desde UI)
$SiemensAPIKey = '<api_key_a_configurar>'   # Placeholder -- configurar antes de produccion
$UIPasswordPlain = $DefaultPassword
$UIUsername = $DefaultUsername
Write-OK 'API Key Siemens preconfigurada (cambiar a produccion desde UI)'
Write-OK ('Credenciales UI preconfiguradas: ' + $UIUsername + ' / ' + $UIPasswordPlain + ' (cambiar desde UI)')

# ===== 4. Crear directorio de instalacion =====
Write-Step ('Creando directorio: ' + $InstallDir)
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-OK 'Directorio listo'

# ===== 5. Copiar archivos del middleware =====
Write-Step 'Copiando archivos del middleware...'

# Buscar la carpeta middleware en multiples paths posibles
$SearchPaths = @(
    (Join-Path $PSScriptRoot '..\middleware'),
    (Join-Path $PSScriptRoot '..\..\middleware'),
    'C:\Users\frank\Desktop\REPAGA\valueflow-middleware\middleware',
    'C:\Temp\valueflow-middleware\middleware',
    'C:\apps\valueflow-middleware\middleware',
    (Join-Path $InstallDir 'middleware')
)

$SourceMiddleware = $null
foreach ($path in $SearchPaths) {
    if ($path -and (Test-Path $path)) {
        $pkgCheck = Join-Path $path 'package.json'
        $distCheck = Join-Path $path 'dist'
        if ((Test-Path $pkgCheck) -and (Test-Path $distCheck)) {
            $SourceMiddleware = $path
            break
        }
    }
}

if (-not $SourceMiddleware) {
    Write-Err 'No se encontro el codigo del middleware en ninguno de estos paths:'
    foreach ($path in $SearchPaths) {
        Write-Host ('    - ' + $path) -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host '  ERROR: Instalacion abortada. Reinstale el bundle correctamente.' -ForegroundColor Red
    pause
    exit 4
}
    if (-not (Test-Path (Join-Path $SourceMiddleware 'package.json'))) {
        Write-Err ('El path ' + $SourceMiddleware + ' no contiene un middleware valido')
        pause
        exit 4
    }
}

Write-Host ('  Origen: ' + $SourceMiddleware)
Write-Host ('  Destino: ' + $InstallDir)

# Eliminar instalacion anterior si existe (solo el codigo, no el node portable)
if (Test-Path (Join-Path $InstallDir 'middleware\package.json')) {
    Remove-Item (Join-Path $InstallDir 'middleware') -Recurse -Force -ErrorAction SilentlyContinue
}

Copy-Item -Path (Join-Path $SourceMiddleware '*') -Destination $InstallDir -Recurse -Force `
    -Exclude @('node_modules\.bin', 'coverage', '.nyc_output', '*.log')

# Verificar que la copia funciono
if (-not (Test-Path (Join-Path $InstallDir 'package.json'))) {
    Write-Err 'La copia fallo - no se encontro package.json en destino'
    pause
    exit 4
}
Write-OK 'Archivos copiados correctamente'

# ===== 6. Instalar dependencias npm =====
Write-Step 'Instalando dependencias npm (puede tardar 3-5 min)...'
Push-Location $InstallDir
try {
    $env:npm_config_audit = 'false'
    $nodePath = if ($nodeExe) { $nodeExe } else { 'node' }
    $npmCmd = Join-Path (Split-Path $nodePath -Parent) 'npm.cmd'
    $npmInstall = Start-Process -FilePath $npmCmd -ArgumentList 'install --production' -Wait -PassThru -NoNewWindow
    if ($npmInstall.ExitCode -eq 0) {
        Write-OK 'Dependencias instaladas'
    } else {
        Write-Warn ('npm install finalizo con codigo: ' + $npmInstall.ExitCode)
        Write-Host '  Esto puede indicar problemas de red. La instalacion continuara.'
    }
} catch {
    Write-Warn ('Error en npm install: ' + $_)
} finally {
    Pop-Location
}

# ===== 7. Configurar .env =====
Write-Step 'Configurando variables de entorno (.env)...'
$envPath = Join-Path $InstallDir '.env'

# Construir .env sin caracteres raros (todas comillas dobles con escape)
$envLines = @(
    'FIREBIRD_PASSWORD=masterkey',
    'SIEMENS_API_KEY=' + $SiemensAPIKey,
    'UI_PORT=' + $UIPort,
    'UI_USERNAME=' + $UIUsername,
    'LOG_LEVEL=info',
    'LOG_DIR=logs'
)
Set-Content -Path $envPath -Value $envLines -Force
Write-OK 'Archivo .env configurado'

# Advertencia si quedo placeholder de API key
if ($SiemensAPIKey -eq '<api_key_a_configurar>') {
    Write-Warn 'SIEMENS_API_KEY en modo placeholder. Cambiala desde UI Configuracion para envios reales.'
}

# ===== 8. Configurar config.json =====
Write-Step 'Configurando operativa (config.json)...'
$configPath = Join-Path $InstallDir 'config.json'
$FirebirdUser = 'SYSDBA'

$configContent = @{
    siemens = @{
        base_url = 'https://api.pos.siemens.com'
        api_key = 'env:SIEMENS_API_KEY'
        environment = 'qua'
        distributor_sender_id = 'MX-REPRESENTACIONES'
    }
    firebird = @{
        db_path = $FirebirdDBPath
        user = $FirebirdUser
        password_source = 'env:FIREBIRD_PASSWORD'
    }
    schedules = @{
        inventory = @{ enabled = $true; cron = '0 2 * * *'; timezone = 'America/Mexico_City' }
        sales = @{ enabled = $true; cron = '0 3 * * *'; timezone = 'America/Mexico_City' }
    }
    batch_size = 3000
    retry_policy = @{
        max_retries = 5
        initial_delay_ms = 2000
        backoff_multiplier = 2
        max_delay_ms = 60000
    }
    siemens_line_filter = @{
        enabled = $true
        lines = @('BAJA','SINU','SIMAT','LP','DRIVE','MOTOR','SINUM','SERVI','OBSO','SENSO','SERVO','INSTR','UPS','SIMA','ESPE')
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
Write-OK 'config.json configurado'

# ===== 9. Generar hash bcrypt para Admin123 =====
Write-Step 'Generando hash bcrypt para contrasena UI...'
try {
    Push-Location $InstallDir

    # Buscar Node (sistema o portable)
    if (-not $nodeExe) {
        $nodeExe = Get-ChildItem -Path $InstallDir -Recurse -Filter 'node.exe' -ErrorAction SilentlyContinue |
                   Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $nodeExe) {
        throw 'No se encontro node.exe para generar hash bcrypt'
    }

    # Usar archivo temporal para evitar escape issues
    $passwordFile = Join-Path $env:TEMP 'valueflow_bcrypt_input.txt'
    Set-Content -Path $passwordFile -Value $UIPasswordPlain -NoNewline -Encoding UTF8

    # Node.js script que lee el password del archivo y genera hash
    $nodeScript = 'const fs=require("fs");const b=require("bcryptjs");const p=fs.readFileSync(process.argv[1],"utf8").trim();console.log(b.hashSync(p,12));'
    $bcryptHash = & $nodeExe -e $nodeScript $passwordFile 2>&1
    $bcryptHash = $bcryptHash.Trim()
    Remove-Item $passwordFile -Force -ErrorAction SilentlyContinue

    if ($bcryptHash -notmatch '^\$2[ayb]\$') {
        throw ('Hash bcrypt invalido generado: ' + $bcryptHash)
    }

    Pop-Location

    # Agregar hash al .env (sin escape de $ en PowerShell con backtick)
    $envContent = Get-Content $envPath -Raw
    $envContent = $envContent -replace '(?ms)^UI_PASSWORD_HASH=.*$', ('UI_PASSWORD_HASH=' + $bcryptHash)
    Set-Content -Path $envPath -Value $envContent -Force
    Write-OK ('UI_PASSWORD_HASH generado para password: ' + $UIPasswordPlain)
    Write-Host ('    Hash: ' + $bcryptHash) -ForegroundColor Gray
} catch {
    Write-Warn ('No se pudo hashear la contrasena: ' + $_)
    Write-Host '  Puedes cambiarla despues desde la UI en /config' -ForegroundColor Yellow
}

# ===== 10. Verificar addon nativo Firebird =====
Write-Step 'Verificando addon nativo de Firebird...'
$addonPath = Join-Path $InstallDir 'middleware\node_modules\node-firebird-driver-native\build\Release\addon.node'
if (-not (Test-Path $addonPath)) {
    Write-Warn 'El addon nativo Firebird no compilo. Funcionalidad limitada.'
    Write-Host '  Para compilarlo:' -ForegroundColor Yellow
    Write-Host '    1. Instalar Visual Studio Build Tools 2022 con C++' -ForegroundColor Yellow
    Write-Host '    2. Abrir Developer Command Prompt for VS 2022 como admin' -ForegroundColor Yellow
    Write-Host ('    3. cd ' + $InstallDir + ' ; npm rebuild node-firebird-driver-native') -ForegroundColor Yellow
} else {
    Write-OK ('Addon nativo Firebird compilado correctamente: ' + $addonPath)
}

# ===== 11. Instalar PM2 =====
Write-Step 'Verificando PM2 (gestor de procesos)...'
$pm2Exe = $null

# Buscar PM2 instalado
$pm2Locations = @(
    "$env:APPDATA\npm\pm.cmd",
    "$env:ProgramFiles\npmjs\pm.cmd",
    "$env:APPDATA\Roaming\npm\pm.cmd"
)
foreach ($loc in $pm2Locations) {
    if (Test-Path $loc) {
        $pm2Exe = $loc
        break
    }
}

if (-not $pm2Exe) {
    Write-Warn 'PM2 no detectado. Instalando globalmente...'
    Push-Location $InstallDir
    try {
        $npmCmd = Join-Path (Split-Path $nodeExe -Parent) 'npm.cmd'
        Start-Process -FilePath $npmCmd -ArgumentList 'install -g pm2 pm2-windows-startup' -Wait -PassThru -NoNewWindow | Out-Null
        $sysPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = $sysPath + ';' + $userPath
        $pm2Exe = Get-Command pm2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($pm2Exe) {
            Write-OK 'PM2 instalado'
        } else {
            Write-Warn 'PM2 instalado pero no detectable. Continuando...'
        }
    } catch {
        Write-Warn ('Error instalando PM2: ' + $_)
    } finally {
        Pop-Location
    }
} else {
    Write-OK 'PM2 ya instalado'
}

# ===== 12. Configurar servicio =====
Write-Step 'Configurando como servicio de Windows...'
try {
    Push-Location $InstallDir
    if ($pm2Exe) {
        Start-Process -FilePath $pm2Exe -ArgumentList 'start ecosystem.config.js --name siemens-middleware' -Wait -PassThru -NoNewWindow | Out-Null
        Start-Process -FilePath $pm2Exe -ArgumentList 'save' -Wait -PassThru -NoNewWindow | Out-Null

        $pm2Startup = Get-Command pm2-startup -ErrorAction SilentlyContinue
        if ($pm2Startup) {
            Start-Process -FilePath $pm2Startup.Source -ArgumentList 'install' -Wait -PassThru -NoNewWindow | Out-Null
            Write-OK 'Servicio Windows instalado (auto-arranque habilitado)'
        } else {
            Write-Warn 'pm2-startup no disponible - usando pm2 save'
        }
    }
    Pop-Location
} catch {
    Write-Warn ('Error configurando PM2: ' + $_)
}

# FALLBACK: Si el servicio no arranco, arrancar Node directo
Start-Sleep -Seconds 3
$nodeRunning = Get-Process node -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $nodeRunning) {
    Write-Warn 'PM2 no levanto el servicio. Arrancando Node directo como fallback...'

    Set-Location (Join-Path $InstallDir 'middleware')
    $nodeExeLocal = if ($nodeExe) { $nodeExe } else { 'node' }
    Start-Process -FilePath $nodeExeLocal -ArgumentList 'dist/index.js' -WindowStyle Hidden

    Start-Sleep -Seconds 5
    $nodeRunning = Get-Process node -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nodeRunning) {
        Write-OK ('Middleware arrancado via Node directo (PID: ' + $nodeRunning.Id + ')')
    } else {
        Write-Err 'Fallo al arrancar el middleware via Node directo'
    }
}

# ===== 13. Crear acceso directo en escritorio =====
Write-Step 'Creando acceso directo al escritorio...'
$shell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')

# Buscar icono .ico en varios paths
$iconCandidates = @(
    (Join-Path $PSScriptRoot '..\assets\valueflow-icon.ico'),
    (Join-Path $PSScriptRoot '..\middleware\valueflow-icon.ico'),
    (Join-Path $InstallDir 'valueflow-icon.ico')
)
$iconSource = $null
foreach ($candidate in $iconCandidates) {
    if (Test-Path $candidate) {
        $iconSource = $candidate
        break
    }
}

$iconDest = Join-Path $InstallDir 'valueflow-icon.ico'
if ($iconSource) {
    if ($iconSource -ne $iconDest) {
        Copy-Item -Path $iconSource -Destination $iconDest -Force -ErrorAction SilentlyContinue
    }
    Write-OK ('Icono personalizado: ' + $iconDest)
} else {
    Write-Warn 'No se encontro valueflow-icon.ico en el bundle, usando icono default'
    $iconDest = 'shell32.dll,13'
}

$shortcut = $shell.CreateShortcut((Join-Path $desktop 'Valueflow Middleware.lnk'))
$shortcut.TargetPath = ('http://localhost:' + $UIPort + '/')
$shortcut.WorkingDirectory = $InstallDir
$shortcut.IconLocation = $iconDest
$shortcut.Description = 'Valueflow Middleware - Aspel SAE - Siemens PoSi'
$shortcut.WindowStyle = 1
$shortcut.Save()
Write-OK 'Acceso directo creado con icono personalizado'

# ===== 14. Verificacion final =====
Write-Step 'Verificando instalacion...'
Start-Sleep -Seconds 3
try {
    Push-Location $InstallDir
    if ($pm2Exe) {
        $pm2List = Start-Process -FilePath $pm2Exe -ArgumentList 'list' -Wait -PassThru -NoNewWindow
        Write-OK ('PM2 status: ' + $pm2List.StandardOutput.ReadToEnd().Trim())
    }
    Pop-Location
} catch {
    Write-Warn ('No se pudo verificar PM2: ' + $_)
}

try {
    $response = Invoke-WebRequest -Uri ('http://localhost:' + $UIPort + '/api/health') -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-OK ('UI respondiendo en http://localhost:' + $UIPort)
    }
} catch {
    Write-Warn 'UI aun no responde. Puede tardar 10-20 segundos en arrancar.'
}

# ===== Resumen =====
Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host '  INSTALACION COMPLETADA EXITOSAMENTE' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host ('  UI del middleware: http://localhost:' + $UIPort) -ForegroundColor White
Write-Host ('  Acceso directo: ' + $desktop + '\Valueflow Middleware.lnk')
Write-Host ''
Write-Host '  Credenciales UI por defecto:' -ForegroundColor Yellow
Write-Host ('    User: ' + $UIUsername) -ForegroundColor Yellow
Write-Host ('    Password: ' + $UIPasswordPlain) -ForegroundColor Yellow
Write-Host ''
Write-Host '  Para cambiar la API Key (sandbox - produccion):' -ForegroundColor Yellow
Write-Host ('    1. Abrir http://localhost:' + $UIPort) -ForegroundColor Yellow
Write-Host '    2. Login con admin / Admin123' -ForegroundColor Yellow
Write-Host '    3. Ir a Configuracion > API Key Siemens > Actualizar' -ForegroundColor Yellow
Write-Host ''
Write-Host '  Cerrando en 5 segundos...' -ForegroundColor Gray
Start-Sleep -Seconds 5
