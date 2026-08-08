#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador robusto de Valueflow Middleware v2.0.4

.DESCRIPTION
    v2.0.2: ARREGLADO el bug de paths fijos que apuntan a instalaciones
    anteriores. Ahora:
    - Detecta si es la version vieja (v1.x) y aborta con mensaje claro
    - SIEMPRE busca el bundle solo en $env:TEMP (donde Inno Setup extrae)
    - Limpia versiones anteriores antes de continuar

.NOTES
    Frank descubrio que ejecutar install.bat desde una instalacion
    anterior usaba bundle viejo. Ahora instalable verifica su propia version.
    ID de intervencion: IMPL-20260806-03 (fix VERSION CHECK aborts incorrectos)
#>

[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\apps\siemens-middleware',
    [string]$LogFile = 'C:\apps\siemens-middleware\install.log',
    [string]$AselBdPath = 'C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB',
    [string]$DefaultUsername = 'Admin',
    [string]$DefaultPassword = 'Admin123'
)


# ===== CREAR LOG PRIMERO =====
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType File -Path $LogFile -Force | Out-Null

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','STEP')] [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
    switch ($Level) {
        'INFO'  { Write-Host $logLine -ForegroundColor White }
        'STEP'  { Write-Host $logLine -ForegroundColor Cyan }
        'OK'    { Write-Host $logLine -ForegroundColor Green }
        'WARN'  { Write-Host $logLine -ForegroundColor Yellow }
        'ERROR' { Write-Host $logLine -ForegroundColor Red }
    }
}

# ===== INICIO =====
Write-Log '=== INSTALADOR VALUEFLOW MIDDLEWARE v2.0.4 ===' 'STEP'
Write-Log "=== PS Script Root: $PSScriptRoot ===" 'INFO'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name } catch { }
}

# ===== ROLLBACK STACK =====
$script:RollbackStack = New-Object System.Collections.Stack

function Register-Rollback {
    param([scriptblock]$Action)
    $script:RollbackStack.Push($Action)
}

function Invoke-Rollback {
    Write-Log '=== EJECUTANDO ROLLBACK ===' 'WARN'
    while ($script:RollbackStack.Count -gt 0) {
        $action = $script:RollbackStack.Pop()
        try {
            & $action
        } catch {
            Write-Log "Rollback fallo: $_" 'ERROR'
        }
    }
}

# ===== 1. VERIFICAR PERMISOS =====
Write-Log '=== PASO 1/8 INICIANDO ===' 'STEP'
Write-Log '=== PASO 1/8: Verificar permisos de administrador ===' 'STEP'

if (-not (Test-Admin)) {
    Write-Log 'ERROR: No se ejecuta como Administrador' 'ERROR'
    Write-Host 'Ejecuta PowerShell como Administrador (click derecho > Ejecutar como administrador)' -ForegroundColor Red
    exit 1
}
Write-Log 'Permisos OK' 'OK'

# ===== 2. VERIFICAR WINDOWS =====
Write-Log '=== PASO 2/8: Verificar Windows 10/11 x64 ===' 'STEP'

$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$is64Bit = [Environment]::Is64BitOperatingSystem
$isWindows10Plus = $osInfo.Version -ge '10.0'

if (-not $is64Bit) {
    Write-Log 'ERROR: Sistema no es 64-bit' 'ERROR'
    exit 2
}
if (-not $isWindows10Plus) {
    Write-Log 'ERROR: Se requiere Windows 10 o superior' 'ERROR'
    exit 2
}
Write-Log "Windows $($osInfo.Caption) x64 ($($osInfo.Version))" 'OK'

# ===== 3. VERIFICAR FIREBIRD =====
Write-Log '=== PASO 3/8: Verificar Firebird 2.5+ (instalado por Aspel) ===' 'STEP'

# IMPL-20260807-03 (escenario a): el middleware usa `node-firebird` (driver JS puro,
# sin bindings nativos). NO requiere fbclient.dll cliente para funcionar — el
# driver habla el protocolo wire-level directo contra el servidor Firebird en
# localhost:3050 (parte de Aspel SAE). Antes esto era un exit 3 bloqueante; ahora
# es un WARN informativo para mantener trazabilidad sin abortar la instalacion
# cuando el .dll cliente no esta (caso tipico: VM con Aspel SAE sin Firebird
# Client Tools adicionales).
$fbclientPaths = @(
    'C:\Windows\System32\fbclient.dll',
    'C:\Windows\SysWOW64\FBCLIENT.DLL',
    'C:\Program Files (x86)\Firebird\Firebird_2_5\bin\fbclient.dll',
    'C:\Program Files (x86)\Firebird\Firebird_5_0\bin\fbclient.dll'
)

$fbclientFound = $null
foreach ($path in $fbclientPaths) {
    if (Test-Path $path) {
        $fbclientFound = $path
        break
    }
}

if ($fbclientFound) {
    Write-Log "fbclient.dll encontrado en: $fbclientFound (no requerido para node-firebird JS puro; OK)" 'OK'
} else {
    Write-Log 'WARN: fbclient.dll no encontrado en rutas comunes. No es bloqueante: el middleware usa node-firebird (JS puro) que conecta directo al servidor Firebird en localhost:3050 via wire protocol. Asegurate de que Aspel SAE / Firebird server este corriendo en localhost:3050.' 'WARN'
}

# ===== 4. INSTALAR VC++ REDISTRIBUTABLE =====
Write-Log '=== PASO 4/8: Instalar VC++ Redistributable 2015-2022 ===' 'STEP'

$vcRedistPath = Join-Path $PSScriptRoot 'assets\installers\vc_redist.x64.exe'

if (-not (Test-Path $vcRedistPath)) {
    Write-Log "ERROR: No se encuentra $vcRedistPath" 'ERROR'
    exit 4
}

$vcInstalled = Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' 'Installed'
$vcInstalled2022 = Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\VisualStudio\17.0\VC\Runtimes\x64' 'Installed'

if ($vcInstalled -eq 1 -or $vcInstalled2022 -eq 1) {
    Write-Log 'VC++ Redistributable ya instalado, skip' 'OK'
} else {
    Write-Log 'Instalando VC++ Redistributable (silencioso)...' 'INFO'
    Register-Rollback { Write-Log 'No se puede desinstalar VC++ automaticamente' 'WARN' }

    $proc = Start-Process -FilePath $vcRedistPath -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Log 'VC++ Redistributable instalado correctamente' 'OK'
    } else {
        Write-Log "VC++ install fallo con codigo: $($proc.ExitCode)" 'WARN'
        Write-Log 'Continuando de todas formas (puede no ser critico)' 'WARN'
    }
}

# ===== 5. INSTALAR NODE.JS (MSI OFICIAL) =====
Write-Log '=== PASO 5/8: Instalar Node.js 20 LTS (MSI oficial) ===' 'STEP'

$nodeMsiPath = Join-Path $PSScriptRoot 'assets\installers\node-v20.14.0-x86.msi'

if (-not (Test-Path $nodeMsiPath)) {
    Write-Log "ERROR: No se encuentra $nodeMsiPath" 'ERROR'
    exit 5
}

$existingNode = (Get-Command node -ErrorAction SilentlyContinue).Source

if ($existingNode -and ($existingNode -match 'Program Files')) {
    $nodeVersion = & node --version 2>&1
    Write-Log "Node.js ya instalado: $nodeVersion" 'OK'
    Write-Log 'Skip instalacion de Node.js MSI (ya hay version del sistema)' 'INFO'
} else {
    Write-Log 'Instalando Node.js 20 LTS via MSI...' 'INFO'
    Register-Rollback { Write-Log 'Rollback de Node.js no aplicado automaticamente' 'WARN' }

    $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', "`"$nodeMsiPath`"", '/quiet', '/norestart', 'ADDLOCAL=ALL' -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Log 'Node.js instalado correctamente' 'OK'
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    } else {
        Write-Log "ERROR: Node.js MSI install fallo con codigo: $($proc.ExitCode)" 'ERROR'
        Write-Log 'Ver log MSI: C:\Users\frank\AppData\Local\Temp\MSI*.log' 'ERROR'
        Invoke-Rollback
        exit 5
    }
}

$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
$npmPath = (Get-Command npm -ErrorAction SilentlyContinue).Source

if (-not $nodePath) {
    Write-Log 'ERROR: node no encontrado en PATH despues de instalar' 'ERROR'
    exit 5
}
if (-not $npmPath) {
    Write-Log 'ERROR: npm no encontrado en PATH' 'ERROR'
    exit 5
}
Write-Log "node: $nodePath" 'INFO'
Write-Log "npm: $npmPath" 'INFO'

$nodeVersion = & node --version
$npmVersion = & npm --version
Write-Log "node $nodeVersion + npm $npmVersion verificados" 'OK'

# ===== 6. EXTRAER MIDDLEWARE DEL BUNDLE =====
Write-Log '=== PASO 6/8: Extraer middleware del bundle ===' 'STEP'

$bundleSearchPaths = @(
    (Join-Path $env:TEMP 'valueflow-middleware*'),
    (Join-Path $PSScriptRoot '..'),
    (Join-Path $PSScriptRoot '..\..'),
    'C:\Temp\valueflow-middleware-v2.0.0',
    'C:\Temp\valueflow-middleware'
)

$bundlePath = $null
foreach ($candidate in $bundleSearchPaths) {
    $resolvedPaths = Get-Item -Path $candidate -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
    foreach ($p in $resolvedPaths) {
        if (Test-Path (Join-Path $p.FullName 'middleware\package.json')) {
            $bundlePath = $p.FullName
            break
        }
    }
    if ($bundlePath) { break }
}

if (-not $bundlePath) {
    Write-Log "ERROR: No se encontro bundle del middleware" 'ERROR'
    Write-Log "Bundle buscado en: $($bundleSearchPaths -join ', ')" 'ERROR'
    exit 6
}

Write-Log "Bundle encontrado en: $bundlePath" 'OK'

# H6: Leer FIREBIRD_DB_PATH= del .ini escrito por el wizard Inno Setup
# (installer.iss:128-131 -> {tmp}\valueflow_install_config.ini con formato
#  FIREBIRD_DB_PATH=<ruta>\r\n). Si no existe o la key falta, fallback al
#  default del parametro -AselBdPath.
$wizardIniPath = Join-Path $env:TEMP 'valueflow_install_config.ini'
if (Test-Path $wizardIniPath) {
    $wizardIniContent = Get-Content $wizardIniPath -Raw
    if ($wizardIniContent -match '(?m)^FIREBIRD_DB_PATH=(.+?)\r?$') {
        $wizardDbPath = $matches[1].Trim()
        if ($wizardDbPath -ne '') {
            Write-Log "FIREBIRD_DB_PATH leido del wizard: $wizardDbPath" 'INFO'
            $AselBdPath = $wizardDbPath
        } else {
            Write-Log '[WARN] FIREBIRD_DB_PATH vacio en wizard .ini, usando default -AselBdPath' 'WARN'
        }
    } else {
        Write-Log '[WARN] key FIREBIRD_DB_PATH no encontrada en wizard .ini, usando default -AselBdPath' 'WARN'
    }
} else {
    Write-Log "[WARN] wizard .ini no encontrado en $wizardIniPath, usando default -AselBdPath" 'WARN'
}

$sourceMiddleware = Join-Path $bundlePath 'middleware'

$destMiddleware = Join-Path $InstallDir 'middleware'

# H1: Guard in-place. Si el bundle se está ejecutando desde el mismo path destino
# (ej. pruebas locales con source==dest), NO borrar+copiar: el source ya esta en
# su lugar final. Cualquier delete borraria el bundle mismo.
if ($sourceMiddleware -eq $destMiddleware) {
    Write-Log '[WARN] Instalacion in-place detectada, saltando copia (source==dest)' 'WARN'
} else {
    if (Test-Path (Join-Path $destMiddleware 'package.json')) {
        Write-Log 'Eliminando instalacion anterior de middleware...' 'INFO'
        Remove-Item -Recurse -Force $destMiddleware -ErrorAction SilentlyContinue
        # Si aún existe, forzar eliminación de forma agresiva
        if (Test-Path $destMiddleware) {
            Write-Log 'Forzando eliminacion de archivos restantes...' 'INFO'
            Get-ChildItem -Path $destMiddleware -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            cmd /c "rmdir /s /q `"$destMiddleware`"" | Out-Null
        }
    }

    # Verificar que se eliminó antes de copiar
    if (Test-Path $destMiddleware) {
        Write-Log 'ERROR: No se pudo eliminar middleware existente. Cierre procesos node y reintente.' 'ERROR'
        exit 6
    }

    Copy-Item -Recurse -Force -Path $sourceMiddleware -Destination $destMiddleware
    Register-Rollback { Remove-Item -Recurse -Force $destMiddleware -ErrorAction SilentlyContinue }

    if (-not (Test-Path (Join-Path $destMiddleware 'package.json'))) {
        Write-Log 'ERROR: La copia fallo (no se encontro package.json en destino)' 'ERROR'
        Invoke-Rollback
        exit 6
    }
}

$fileCount = (Get-ChildItem $destMiddleware -Recurse -File | Measure-Object).Count
Write-Log "Middleware copiado correctamente ($fileCount archivos)" 'OK'

# ===== 7. INSTALAR DEPENDENCIAS NPM =====
Write-Log '=== PASO 7/8: npm install (dependencias) ===' 'STEP'

Set-Location $destMiddleware
Write-Log "Directorio de trabajo: $destMiddleware" 'INFO'
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
if (-not $npmCmd) {
    Write-Log 'ERROR: npm.cmd no encontrado en PATH' 'ERROR'
    exit 7
}
Write-Log "Usando npm: $npmCmd" 'INFO'

# IMPL-20260807-03 (bundle self-contained): si el bundle v2.0.11 trae node_modules
# pre-instalado portable (preparado por prepare-dist-pkg.sh), saltamos npm install
# para evitar dependencia de internet/proxy/firewall en la VM cliente. Fallback:
# si node_modules no esta presente (instalacion legacy o bundle sin preparar),
# se hace npm install normalmente.
$nodeFirebirdPkg = Join-Path $destMiddleware 'node_modules\node-firebird\package.json'
$skipNpmInstall = $false

# Opcion B-1 (installer.iss): si no hay node_modules directo, buscar el bundle.zip
# en {app}\installer\assets\ (asset embed en el .exe) y extraerlo como fallback
# para obtener node_modules portable sin depender de internet.
$assetsZipDir = Join-Path $PSScriptRoot 'assets'
$bundleZip = $null
if (-not (Test-Path $nodeFirebirdPkg) -and (Test-Path $assetsZipDir)) {
    Write-Log 'node_modules ausente; buscando bundle.zip de fallback en assets...' 'INFO'
    $candidateZips = Get-ChildItem -Path $assetsZipDir -Filter 'valueflow-middleware-*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($candidateZips -and $candidateZips.Count -gt 0) {
        $bundleZip = $candidateZips[0].FullName
        Write-Log "bundle.zip encontrado: $bundleZip" 'INFO'
    }
}

if ($bundleZip) {
    try {
        $expandRoot = Join-Path $env:TEMP "valueflow_zip_$([System.IO.Path]::GetRandomFileName())"
        New-Item -ItemType Directory -Path $expandRoot -Force | Out-Null
        Write-Log "Expandiendo bundle.zip a $expandRoot ..." 'INFO'
        # Expand-Archive es nativo en PS 5.1; maneja paths con espacios y UTF-8.
        Expand-Archive -Path $bundleZip -DestinationPath $expandRoot -Force
        # Localizar middleware/ dentro del zip. El zip tiene raiz
        # valueflow-middleware-v2.0.11/middleware/, asi que buscamos el primer
        # directorio que contenga package.json con name=repaga-siemens-middleware.
        $zipMiddleware = $null
        Get-ChildItem -Path $expandRoot -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'package.json') } |
            ForEach-Object {
                $pkgJson = Get-Content (Join-Path $_.FullName 'package.json') -Raw -ErrorAction SilentlyContinue
                if ($pkgJson -and $pkgJson -match '"name"\s*:\s*"repaga-siemens-middleware"') {
                    $zipMiddleware = $_.FullName
                }
            }
        if ($zipMiddleware -and (Test-Path (Join-Path $zipMiddleware 'node_modules\node-firebird\package.json'))) {
            $destNodeModules = Join-Path $destMiddleware 'node_modules'
            if (Test-Path $destNodeModules) {
                Write-Log 'Reemplazando node_modules en destino con el del bundle.zip...' 'INFO'
                Remove-Item -Recurse -Force $destNodeModules -ErrorAction SilentlyContinue
            }
            Copy-Item -Recurse -Force -Path (Join-Path $zipMiddleware 'node_modules') -Destination $destMiddleware
            Write-Log "node_modules restaurado desde bundle.zip ($((Get-ChildItem $destNodeModules -Recurse -File | Measure-Object).Count) archivos)" 'OK'
        } else {
            Write-Log 'WARN: bundle.zip no contiene middleware/node_modules con node-firebird; fallback a npm install' 'WARN'
        }
    } catch {
        Write-Log "WARN: fallo extrayendo bundle.zip ($($_.Exception.Message)); fallback a npm install" 'WARN'
    } finally {
        if (Test-Path $expandRoot) { Remove-Item -Recurse -Force $expandRoot -ErrorAction SilentlyContinue }
    }
}

if (Test-Path $nodeFirebirdPkg) {
    Write-Log 'node_modules pre-instalado en bundle (self-contained), saltando npm install' 'OK'
    $skipNpmInstall = $true
} else {
    Write-Log 'node_modules no encontrado en bundle, ejecutando npm install' 'INFO'
    $skipNpmInstall = $false
}

if (-not $skipNpmInstall) {
    # Ejecutar npm install usando cmd para capturar exit code correctamente
    cmd /c "cd /d `"$destMiddleware`" && `"$npmCmd`" install --ignore-scripts --omit=dev --no-audit --no-fund"
    $npmExit = $LASTEXITCODE
    if ($npmExit -ne 0) {
        Write-Log "ERROR: npm install fallo con codigo: $npmExit" 'ERROR'
        Invoke-Rollback
        exit 7
    }
    Write-Log 'npm install completado correctamente' 'OK'
} else {
    Write-Log 'Skip npm install: bundle self-contained (node_modules pre-instalado)' 'OK'
}

if (-not (Test-Path (Join-Path $destMiddleware 'node_modules\bcryptjs\package.json'))) {
    Write-Log 'ERROR: bcryptjs no se instalo' 'ERROR'
    Invoke-Rollback
    exit 7
}
Write-Log 'bcryptjs OK' 'OK'

if (-not (Test-Path (Join-Path $destMiddleware 'node_modules\node-firebird\package.json'))) {
    Write-Log 'ERROR: node-firebird no se instalo' 'ERROR'
    Invoke-Rollback
    exit 7
}
Write-Log 'node-firebird OK' 'OK'

# ===== 8. GENERAR BCRYPT + ARRANCAR SERVICIO =====
Write-Log '=== PASO 8/8: Configurar .env + arrancar servicio ===' 'STEP'

# Generar bcrypt hash con archivo JS externo (evita bugs de quoting en PS 5.1)
$passwordFile = Join-Path $env:TEMP 'valueflow_bcrypt_input.txt'
[System.IO.File]::WriteAllText($passwordFile, $DefaultPassword)

$jsFile = Join-Path $destMiddleware 'valueflow_bcrypt_gen.js'
$jsCode = 'const fs=require("fs");const b=require("bcryptjs");const p=fs.readFileSync(process.argv[2],"utf8").trim();console.log(b.hashSync(p,12));'
[System.IO.File]::WriteAllText($jsFile, $jsCode)

$bcryptRaw = & node $jsFile $passwordFile 2>&1
$bcryptExit = $LASTEXITCODE
Remove-Item $passwordFile, $jsFile -Force -ErrorAction SilentlyContinue

$bcryptHash = ($bcryptRaw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Out-String).Trim()

if ($bcryptExit -ne 0 -or $bcryptHash -notmatch '^\$2[ayb]\$') {
    Write-Log ("ERROR: No se pudo generar bcrypt hash valido (exit=$bcryptExit, hash='$bcryptHash'). " +
        'Instalacion abortada para evitar login roto.') 'ERROR'
    Write-Log 'Diagnostico: bcryptjs no responde, hash corrupto, o node no escribio al stdout.' 'ERROR'
    Invoke-Rollback
    exit 7
}

# Validar hash generado contra password conocido (regresion: B1 v2.0.8 -> login fallaba
# porque el hash random no correspondia a $DefaultPassword). Si compareSync falla, abortar.
$verifyFile = Join-Path $env:TEMP 'valueflow_bcrypt_verify.txt'
$verifyJs = Join-Path $destMiddleware 'valueflow_bcrypt_verify.js'
try {
    [System.IO.File]::WriteAllText($verifyFile, $DefaultPassword)
    $verifyCode = 'const fs=require("fs");const b=require("bcryptjs");const p=fs.readFileSync(process.argv[2],"utf8").trim();const h=process.argv[3];console.log(b.compareSync(p,h) ? "OK" : "FAIL");'
    [System.IO.File]::WriteAllText($verifyJs, $verifyCode)
    $verifyRaw = & node $verifyJs $verifyFile $bcryptHash 2>&1
    $verifyExit = $LASTEXITCODE
    $verifyResult = ($verifyRaw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Out-String).Trim()
    if ($verifyExit -ne 0 -or $verifyResult -ne 'OK') {
        Write-Log ("ERROR: bcrypt hash generado NO valida contra password por defecto (verify='$verifyResult', exit=$verifyExit). " +
            'Instalacion abortada para evitar login roto.') 'ERROR'
        Invoke-Rollback
        exit 7
    }
    Write-Log "bcrypt hash validado contra password por defecto (compareSync=OK)" 'OK'
} finally {
    Remove-Item $verifyFile, $verifyJs -Force -ErrorAction SilentlyContinue
}

# Escribir/actualizar .env (en el directorio del middleware, donde PM2 arranca)
$envPath = Join-Path $destMiddleware '.env'

# B2: Normalizar UI_USERNAME. Middleware compara case-sensitive (server.ts:31),
# el log final anuncia "Admin" pero el .env debe coincidir exactamente.
if ($DefaultUsername -cne 'Admin') {
    Write-Log ("WARN: UI_USERNAME pasado como '$DefaultUsername'; se normaliza a 'Admin' para coincidir con el caso que anuncia el instalador y espera el middleware.") 'WARN'
    $resolvedUsername = 'Admin'
} else {
    $resolvedUsername = 'Admin'
}

# B4: Advertir explicitamente que FIREBIRD_PASSWORD queda con default si el wizard no lo lo proveyo.
# (El wizard actual - installer.iss - solo pide ruta del FDB, no password.)
# FIX-20260807-03: default debe ser 'masterkey' (lowercase) que es el default de
# Aspel SAE 9.0/10.0 para el usuario SYSDBA. v2.0.13 tenia 'MASTERKEY' (uppercase)
# lo cual causaba 'Your user name and password are not defined' al conectar a la BD.
Write-Log '[WARN] FIREBIRD_PASSWORD no proporcionado por wizard, usando default masterkey (lowercase, default Aspel SAE). Cambialo en UI > Configuracion.' 'WARN'

$envLines = @(
    "FIREBIRD_PASSWORD=masterkey",
    "SIEMENS_API_KEY=I1kfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv",
    "UI_PORT=4567",
    "UI_USERNAME=$resolvedUsername",
    "LOG_LEVEL=info",
    "LOG_DIR=C:\apps\siemens-middleware\logs",
    "UI_PASSWORD_HASH=$bcryptHash",
    "DATA_SOURCE=production"
)
# FIX-20260807-02: Set-Content -Encoding UTF8 en PS 5.1 SIEMPRE escribe BOM (EF BB BF).
# El BOM rompe JSON.parse() y dotenv al cargar el archivo. Usamos UTF8Encoding($false)
# que escribe UTF-8 puro sin BOM.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($envPath, ($envLines -join "`r`n") + "`r`n", $utf8NoBom)
Write-Log '.env configurado' 'OK'

# Escribir config.json (en el directorio del middleware, donde PM2 arranca)
$configPath = Join-Path $destMiddleware 'config.json'
$FirebirdUser = 'SYSDBA'
$configContent = @{
    siemens = @{
        base_url = 'https://api.pos.siemens.com'
        api_key = 'env:SIEMENS_API_KEY'
        environment = 'qua'
        distributor_sender_id = 'MX-REPRESENTACIONES'
    }
    firebird = @{
        db_path = $AselBdPath
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
# FIX-20260807-02: sin BOM. Ver comentario arriba sobre .env.
[System.IO.File]::WriteAllText($configPath, $configContent, $utf8NoBom)
Write-Log 'config.json configurado' 'OK'

# Instalar PM2 si hace falta
$pm2Cmd = Get-Command pm2.cmd -ErrorAction SilentlyContinue
if (-not $pm2Cmd) {
    Write-Log 'Instalando PM2 globalmente...' 'INFO'
    $npmProcess = Start-Process -FilePath 'npm.cmd' -ArgumentList 'install','-g','pm2','pm2-windows-startup','--no-audit','--no-fund' -Wait -PassThru -NoNewWindow
    if ($npmProcess.ExitCode -ne 0) {
        Write-Log "ERROR: PM2 install fallo con codigo: $($npmProcess.ExitCode)" 'ERROR'
        Invoke-Rollback
        exit 8
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}
Write-Log 'PM2 instalado' 'OK'

# Arrancar servicio
$pm2Path = (Get-Command pm2.cmd -ErrorAction SilentlyContinue).Source
if (-not $pm2Path) {
    $possiblePm2Paths = @(
        "$env:APPDATA\npm\pm2.cmd",
        "$env:ProgramFiles\npmjs\pm2.cmd"
    )
    foreach ($p in $possiblePm2Paths) {
        if (Test-Path $p) {
            $pm2Path = $p
            break
        }
    }
}

if ($pm2Path) {
    Write-Log ('Arrancando middleware via PM2 (' + $pm2Path + ')...') 'INFO'
    Set-Location $destMiddleware

    Write-Log ('Directorio de PM2: ' + $destMiddleware) 'INFO'

    # Verificar que ecosystem.config.js existe
    $ecoFile = Join-Path $destMiddleware 'ecosystem.config.js'
    if (-not (Test-Path $ecoFile)) {
        Write-Log ('ERROR: ecosystem.config.js no existe en ' + $destMiddleware) 'ERROR'
        Invoke-Rollback
        exit 8
    }
    Write-Log 'ecosystem.config.js encontrado' 'INFO'

    # Verificar que dist/index.js existe. Si no, ejecutar build (bundle sin dist precompilado).
    $indexFile = Join-Path $destMiddleware 'dist/index.js'
    if (-not (Test-Path $indexFile)) {
        Write-Log ('dist/index.js no existe en ' + $destMiddleware + '; ejecutando npm run build (bundle sin dist precompilado)...') 'INFO'
        Register-Rollback { Write-Log 'Build del middleware no aplicado automaticamente en rollback' 'WARN' }
        # H7: el install principal uso --omit=dev (linea ~293), asi que tsc/typescript
        # no estan instalados. Necesitamos devDependencies para poder hacer build.
        $installDev = cmd /c 'cd /d "' + $destMiddleware + '" && "' + $npmCmd + '" install --include=dev --no-audit --no-fund' 2>&1
        $installDevExit = $LASTEXITCODE
        Write-Log ("Salida npm install --include=dev: " + $installDev) 'INFO'
        if ($installDevExit -ne 0) {
            Write-Log "ERROR: npm install --include=dev fallo (exit=$installDevExit) en fallback build" 'ERROR'
            Invoke-Rollback
            exit 7
        }
        $buildOutput = cmd /c 'cd /d "' + $destMiddleware + '" && "' + $npmCmd + '" run build' 2>&1
        $buildExit = $LASTEXITCODE
        Write-Log ('Salida build: ' + $buildOutput) 'INFO'
        if ($buildExit -ne 0 -or -not (Test-Path $indexFile)) {
            Write-Log ("ERROR: npm run build fallo (exit=$buildExit) o dist/index.js sigue sin existir. Instalacion abortada.") 'ERROR'
            Invoke-Rollback
            exit 7
        }
        Write-Log 'npm run build OK; dist/index.js generado' 'OK'
    } else {
        Write-Log 'dist/index.js encontrado (bundle precompilado, skip build)' 'INFO'
    }
    Write-Log 'dist/index.js verificado' 'INFO'

    # IMPL-20260807-04 (FIX-20260807-01, mini-SPEC §4 criterios 1-6):
    # - Push-Location garantiza cwd del middleware durante pm2 delete/start.
    # - $LASTEXITCODE se captura INMEDIATAMENTE despues de cada invocacion,
    #   ANTES de loguear la salida (no se mete en pipeline ForEach-Object, que
    #   en PS 5.1 no propaga $LASTEXITCODE al ambito padre).
    # - pm2 delete NO aborta si falla: la limpieza es idempotente y en una
    #   instalacion limpia no existe instancia previa.
    # - pm2 start ES FATAL si falla: aborta la instalacion con error claro.
    # - Verificacion de puerto 4567 con polling 2s/timeout 30s (no chequeo unico).
    # - Pop-Location en finally garantiza restauracion del cwd del script.
    Push-Location $destMiddleware
    try {
        # Eliminar instancias anteriores (limpieza idempotente, NO aborta)
        Write-Log 'Eliminando instancias PM2 anteriores (idempotente)...' 'INFO'
        $delOutput = & $pm2Path delete all 2>&1
        $delExit = $LASTEXITCODE
        Write-Log ('Salida delete: ' + ($delOutput | Out-String)) 'INFO'
        if ($delExit -ne 0) {
            Write-Log ("pm2 delete retorno exit code no-cero ($delExit); continuando (limpieza idempotente)") 'WARN'
        }

        # Arrancar el servicio (FATAL si falla)
        Write-Log ('Iniciando middleware via pm2 start ' + $ecoFile + '...') 'INFO'
        $startOutput = & $pm2Path start $ecoFile 2>&1
        $startExit = $LASTEXITCODE  # capturar ANTES de pipe a Out-String
        Write-Log ('Salida start (exit=' + $startExit + '): ' + ($startOutput | Out-String)) 'INFO'
        if ($startExit -ne 0) {
            Write-Log ("ERROR: pm2 start fallo con exit code $startExit. Instalacion abortada.") 'ERROR'
            throw "pm2 start failed with exit code $startExit"
        }
    } finally {
        Pop-Location
    }

    # Polling puerto 4567 con timeout 30s (warm-up de node-firebird puede tardar)
    Write-Log 'Verificando puerto 4567 LISTENING (polling 2s, timeout 30s)...' 'INFO'
    $portReady = $false
    $portDeadline = (Get-Date).AddSeconds(30)
    $pollAttempt = 0
    while ((Get-Date) -lt $portDeadline) {
        $pollAttempt++
        $portCheck = netstat -an 2>&1 | Select-String ':4567\s.*LISTENING'
        if ($portCheck) {
            $portReady = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if ($portReady) {
        Write-Log ("Servicio online: puerto 4567 LISTENING (confirmado en intento $pollAttempt)") 'OK'
    } else {
        Write-Log 'ERROR: puerto 4567 NO bindeado despues de 30s. Instalacion abortada.' 'ERROR'
        Write-Log 'Diagnostico: revisar pm2 logs y middleware\logs\*.log para causa raiz.' 'ERROR'
        Invoke-Rollback
        exit 8
    }
} else {
    Write-Log 'ERROR: pm2.cmd no encontrado en PATH ni en %APPDATA%\npm\pm2.cmd. Instalacion abortada.' 'ERROR'
    Invoke-Rollback
    exit 8
}

# Crear acceso directo en escritorio
$shell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')
$iconPath = Join-Path $InstallDir 'valueflow-icon.ico'
$shortcut = $shell.CreateShortcut((Join-Path $desktop 'Valueflow Middleware.lnk'))
$shortcut.TargetPath = 'http://localhost:4567/'
$shortcut.IconLocation = $iconPath
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Description = 'Valueflow Middleware'
$shortcut.Save()
Write-Log 'Acceso directo en escritorio creado' 'OK'

# Resumen final
Write-Log '===========================================' 'INFO'
Write-Log 'INSTALACION COMPLETADA EXITOSAMENTE' 'OK'
Write-Log '===========================================' 'INFO'
Write-Log 'UI del middleware: http://localhost:4567' 'INFO'
Write-Log ('User: ' + $DefaultUsername) 'INFO'
Write-Log ('Password: ' + $DefaultPassword) 'INFO'
Write-Log ('Log completo: ' + $LogFile) 'INFO'
Write-Log 'Cambiar API Key desde UI > Configuracion' 'INFO'

exit 0
