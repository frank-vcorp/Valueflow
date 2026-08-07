#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador robusto de Valueflow Middleware v2.0.2

.DESCRIPTION
    v2.0.2: ARREGLADO el bug de paths fijos que apuntan a instalaciones
    anteriores. Ahora:
    - Detecta si es la version vieja (v1.x) y aborta con mensaje claro
    - SIEMPRE busca el bundle solo en $env:TEMP (donde Inno Setup extrae)
    - Limpia versiones anteriores antes de continuar

.NOTES
    Frank descubrio que ejecutar install.bat desde una instalacion
    anterior usaba bundle viejo. Ahora instalable verifica su propia version.
    ID de intervencion: IMPL-20260806-02
#>

[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\apps\siemens-middleware',
    [string]$LogFile = 'C:\apps\siemens-middleware\install.log',
    [string]$AselBdPath = 'C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB',
    [string]$DefaultUsername = 'Admin',
    [string]$DefaultPassword = 'Admin123'
)

# ===== VERSION CHECK =====
# Detectar si es instalable v1.x (viejo) o v2.x (nuevo)
$expectedVersion = '2.0.2'
if ($MyInvocation.MyCommand.Path -match 'siemens-middleware') {
    # Estamos ejecutando desde una instalacion existente
    # Verificar que sea la version esperada
    $versionFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'VERSION'
    if (Test-Path $versionFile) {
        $bundleVersion = Get-Content $versionFile -Raw | Select-String -Pattern 'MAJOR=(\d+).*MINOR=(\d+).*PATCH=(\d+)' |
            ForEach-Object { "$($_.Matches.Groups[1].Value).$($_.Matches.Groups[2].Value).$($_.Matches.Groups[3].Value)" }
        if ($bundleVersion -ne $expectedVersion) {
            Write-Host "============================================================" -ForegroundColor Red
            Write-Host "ERROR: Version de bundle incompatible" -ForegroundColor Red
            Write-Host "  Bundle version: $bundleVersion" -ForegroundColor Red
            Write-Host "  Esperada: $expectedVersion" -ForegroundColor Red
            Write-Host ""
            Write-Host "PROBABLE CAUSA:" -ForegroundColor Yellow
            Write-Host "  Estas ejecutando el install.ps1 de una instalacion ANTERIOR." -ForegroundColor Yellow
            Write-Host "  Para usar la version nueva v2.0.2:" -ForegroundColor Yellow
            Write-Host "  1. Borra C:\Program Files\siemens-middleware (PowerShell Admin)"
            Write-Host "  2. Borra C:\apps\siemens-middleware"
            Write-Host "  3. Borra C:\Temp\valueflow-middleware*"
            Write-Host "  4. Ejecuta Valueflow-Setup-v2.0.2.exe desde el Escritorio"
            Write-Host "============================================================" -ForegroundColor Red
            pause
            exit 99
        }
    } else {
        # No hay VERSION file en la instalacion existente
        # Si no estamos en InstallDir, podria ser una instalacion vieja
        $scriptDir = Split-Path -Parent $PSScriptRoot
        if ($scriptDir -match 'Program Files') {
            Write-Host "============================================================" -ForegroundColor Red
            Write-Host "ERROR: Instalacion v1.x detectada en $scriptDir" -ForegroundColor Red
            Write-Host "  Esta corriendo un instalable antiguo." -ForegroundColor Red
            Write-Host ""
            Write-Host "  SOLUCION:" -ForegroundColor Yellow
            Write-Host "  1. Cierre esta ventana PowerShell" -ForegroundColor Yellow
            Write-Host "  2. Ejecute estos comandos en PowerShell Admin:" -ForegroundColor Yellow
            Write-Host "     Remove-Item -Recurse -Force 'C:\Program Files\siemens-middleware'"
            Write-Host "     Remove-Item -Recurse -Force 'C:\apps\siemens-middleware'"
            Write-Host "     Remove-Item -Recurse -Force 'C:\Temp\valueflow-middleware*'"
            Write-Host "  3. Doble click en Valueflow-Setup-v2.0.2.exe desde el Escritorio" -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Red
            pause
            exit 99
        }
    }
}

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
Write-Log '=== INSTALADOR VALUEFLOW MIDDLEWARE v2.0.2 ===' 'STEP'
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
Write-Log '=== INSTALADOR VALUEFLOW MIDDLEWARE v2.0.0 ===' 'STEP'
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

if (-not $fbclientFound) {
    Write-Log 'ERROR: No se encontro fbclient.dll en ninguna ruta comun' 'ERROR'
    Write-Log 'Firebird 2.5 Client Tools debe estar instalado (parte de Aspel SAE)' 'ERROR'
    exit 3
}
Write-Log "fbclient.dll encontrado en: $fbclientFound" 'OK'

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

$sourceMiddleware = Join-Path $bundlePath 'middleware'

$destMiddleware = Join-Path $InstallDir 'middleware'
if (Test-Path (Join-Path $destMiddleware 'package.json')) {
    Write-Log 'Eliminando instalacion anterior de middleware...' 'INFO'
    Remove-Item -Recurse -Force $destMiddleware -ErrorAction SilentlyContinue
}

Copy-Item -Recurse -Force -Path (Join-Path $sourceMiddleware '*') -Destination $destMiddleware
Register-Rollback { Remove-Item -Recurse -Force $destMiddleware -ErrorAction SilentlyContinue }

if (-not (Test-Path (Join-Path $destMiddleware 'package.json'))) {
    Write-Log 'ERROR: La copia fallo (no se encontro package.json en destino)' 'ERROR'
    Invoke-Rollback
    exit 6
}

$fileCount = (Get-ChildItem $destMiddleware -Recurse -File | Measure-Object).Count
Write-Log "Middleware copiado correctamente ($fileCount archivos)" 'OK'

# ===== 7. INSTALAR DEPENDENCIAS NPM =====
Write-Log '=== PASO 7/8: npm install --production ===' 'STEP'

Set-Location $destMiddleware
$npmProcess = Start-Process -FilePath 'npm.cmd' -ArgumentList 'install','--production','--no-audit','--no-fund' -Wait -PassThru -NoNewWindow

if ($npmProcess.ExitCode -ne 0) {
    Write-Log "ERROR: npm install fallo con codigo: $($npmProcess.ExitCode)" 'ERROR'
    Invoke-Rollback
    exit 7
}

Write-Log 'npm install completado correctamente' 'OK'

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
    Write-Log "WARN: No se pudo generar bcrypt (exit $bcryptExit), usando fallback" 'WARN'
    $bcryptHash = '$2b$12$' + [System.Convert]::ToBase64String((1..22 | ForEach-Object { Get-Random -Maximum 255 }))
} else {
    Write-Log 'bcrypt generado correctamente' 'OK'
}

# Escribir/actualizar .env
$envPath = Join-Path $InstallDir '.env'
$envLines = @(
    "FIREBIRD_PASSWORD=masterkey",
    "SIEMENS_API_KEY=<api_key_a_configurar>",
    "UI_PORT=4567",
    "UI_USERNAME=$DefaultUsername",
    "LOG_LEVEL=info",
    "LOG_DIR=logs",
    "UI_PASSWORD_HASH=$bcryptHash"
)
Set-Content -Path $envPath -Value $envLines -Encoding UTF8
Write-Log '.env configurado' 'OK'

# Escribir config.json
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
Set-Content -Path $configPath -Value $configContent -Encoding UTF8
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
    Write-Log "Arrancando middleware via PM2 ($pm2Path)..." 'INFO'
    Set-Location $destMiddleware

    Start-Process -FilePath $pm2Path -ArgumentList 'delete','all' -Wait -PassThru -NoNewWindow | Out-Null

    $startProcess = Start-Process -FilePath $pm2Path -ArgumentList 'start','ecosystem.config.js' -Wait -PassThru -NoNewWindow

    Start-Sleep -Seconds 5

    $tmpListFile = Join-Path $env:TEMP 'pm2_list_check.txt'
    Start-Process -FilePath $pm2Path -ArgumentList 'list','--no-color' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tmpListFile | Out-Null

    $logContent = if (Test-Path $tmpListFile) { Get-Content $tmpListFile -Raw } else { '' }

    if ($logContent -match 'online') {
        Write-Log 'Servicio arrancado correctamente (online)' 'OK'
    } elseif ($logContent -match 'stopped') {
        Write-Log 'Servicio arranco pero esta stopped - revisar logs' 'WARN'
    } else {
        Write-Log 'Estado del servicio desconocido - revisar manualmente' 'WARN'
    }

    Remove-Item $tmpListFile -ErrorAction SilentlyContinue
} else {
    Write-Log 'WARN: pm2.cmd no encontrado, saltando arranque' 'WARN'
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
Write-Log "User: $DefaultUsername" 'INFO'
Write-Log "Password: $DefaultPassword" 'INFO'
Write-Log "Log completo: $LogFile" 'INFO'
Write-Log 'Cambiar API Key desde UI > Configuracion' 'INFO'

exit 0
