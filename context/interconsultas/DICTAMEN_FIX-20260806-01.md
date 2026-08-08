# DICTAMEN TÉCNICO: Instalador Valueflow — 3 bugs de primera ejecución (bcrypt Trim, PM2 Win32, copia desde bundle viejo)

- **ID:** FIX-20260806-01
- **Fecha:** 2026-08-06
- **Solicitante:** Frank (instalación real en VM) / canal INTEGRA
- **Nivel:** L2 (1 archivo —`installer/install.ps1`—, ~80 líneas en 5 bloques, sin cambio de contrato público, comportamiento Windows-only verificable solo en VM)
- **Estado:** ✅ VALIDADO (diagnóstico confirmado con evidencia empírica en pwsh; parches propuestos con sintaxis verificada — NO aplicados por instrucción explícita del solicitante)
- **Archivo afectado:** `installer/install.ps1` (541 líneas, git `main` @ `1ab9160`)

---

## A. Análisis de Causa Raíz

### Bug 1 — `Trim()` sobre ErrorRecord (líneas 344-346) — CONFIRMADO

**Síntoma:** `[!] No se pudo hashear la contrasena: Error en la invocación del método porque [System.Management.Automation.ErrorRecord] no contiene ningún método llamado 'Trim'.`

**Hallazgo forense (líneas 345-346 del código actual):**

```powershell
$bcryptHash = & $nodeExe -e $nodeScript $passwordFile 2>&1
$bcryptHash = $bcryptHash.Trim()
```

La redirección `2>&1` envuelve cada línea de stderr nativo en objetos `System.Management.Automation.ErrorRecord`. Cuando `node.exe` falla (module no encontrado, node corrupto, etc.), `$bcryptHash` queda como `ErrorRecord` (o arreglo mixto) y `.Trim()` lanza la excepción del log. Verificado empíricamente con pwsh 7:

```
Tipo recibido: System.Management.Automation.ErrorRecord
Es ErrorRecord: True
```

La excepción real de node queda **oculta** detrás del error de `Trim()`, imposibilitando diagnosticar por qué falló node (probable: `Cannot find module 'bcryptjs'` encadenado al Bug 3, o fallo parcial del `npm install` del paso 6, que solo emite `Write-Warn` y continúa).

**⚠ Bug 1b (descubierto en esta auditoría, MISMO bloque):** incluso cuando el hash SÍ se genera correctamente, **nunca se persiste**. Líneas 356-358:

```powershell
$envContent = $envContent -replace '(?ms)^UI_PASSWORD_HASH=.*$', ('UI_PASSWORD_HASH=' + $bcryptHash)
```

El `.env` se regenera desde cero en el paso 7 (línea 264, `Set-Content -Force`) sin línea `UI_PASSWORD_HASH`. El `-replace` con patrón no coincidente devuelve el string **sin cambios** → el hash se descarta en silencio → el `[OK] UI_PASSWORD_HASH generado` del log es un falso positivo. Consecuencia verificada en el código del middleware: `src/config/env.ts:30` declara `uiPasswordHash: required('UI_PASSWORD_HASH', NODE_ENV==='production' ? undefined : ...)` → con PM2 (`ecosystem.config.js` fija `NODE_ENV: 'production'`) el middleware **crashea al arranque** con `Variable de entorno requerida no configurada: UI_PASSWORD_HASH`. Adicionalmente, si la línea existiera, el valor del hash contiene `$2`/`$12` que .NET interpreta como referencias de grupo de regex en el replacement (semántica documentada en .NET Framework / PS 5.1, la VM destino), corrompiendo o lanzando excepción. Verificado empíricamente: `No-op confirmado (hash NO persiste): True`.

### Bug 2 — PM2 "%1 no es una aplicación Win32 válida" (líneas 383-405, 425-434) — CONFIRMADO

**Síntoma:** `Error configurando PM2: Este comando no se puede ejecutar debido al error: %1 no es una aplicación Win32 válida.`

**Doble defecto confirmado en el código actual:**

1. **Líneas 384-388:** la lista de detección previa busca `pm.cmd`, `pm.cmd`, `pm.cmd` — nombre de archivo **erróneo** (npm instala `pm2.cmd`/`pm2.ps1`, no `pm.cmd`; además `$env:APPDATA\Roaming\npm` duplica `Roaming`). Nunca encuentra PM2 → siempre reinstala.
2. **Línea 405:** `$pm2Exe = Get-Command pm2 ... | Select-Object -ExpandProperty Source`. La resolución de comandos de PowerShell antepone scripts externos `.ps1` a ejecutables nativos (`.cmd`), por lo que devuelve `pm2.ps1`.
3. **Línea 425:** `Start-Process -FilePath $pm2Exe` con un `.ps1` → `ShellExecute` no puede ejecutar `.ps1` como binario → error `%1 no es una aplicación Win32 válida` (`ERROR_BAD_EXE_FORMAT`), capturado en línea 438 — coincidencia literal con el log de la VM.

**Riesgo equivalente no reportado (líneas 428-430):** `Get-Command pm2-startup` resuelve también a `pm2-startup.ps1` (paquete `pm2-windows-startup` instala ambos shims) → el mismo fallo `%1` se repetirá en `pm2-startup install` aunque se corrija `pm2`.

### Bug 3 — Copia del middleware desde instalable viejo (líneas 175-194, 215-221) — CONFIRMADO

**Síntoma:** `Origen: C:\Program Files\siemens-middleware\installer\..\middleware` (instalable viejo) en lugar del bundle nuevo en `C:\apps\siemens-middleware\`.

**Mecanismo confirmado:**

- `installer.iss` instala en `{autopf}\siemens-middleware` e instala un icono de escritorio/Start apuntando a `{app}\installer\install.bat` (líneas 62-64 del `.iss`). El script viejo queda residente en `C:\Program Files\siemens-middleware\installer\`.
- `$SearchPaths` (líneas 175-182) evalúa en orden: primero `Join-Path $PSScriptRoot '..\middleware'` — si la ejecución se lanza desde el directorio viejo (icono viejo, shortcut, o reinstall sobre instalación previa), el middleware **viejo** gana la búsqueda. El bundle nuevo en `Join-Path $InstallDir 'middleware'` está **último** (posición 6).
- La validación actual solo exige `package.json` + `dist` genéricos (línea 189) — cualquier middleware viejo válido gana; no hay verificación de identidad.
- La búsqueda con `break` en primer match no distingue viejo/nuevo: ambos `package.json` se llaman igual.

**⚠ Regresión contenida en el fix propuesto por Frank (CRÍTICO):** su regex de identidad es `'"name"\s*:\s*"valueflow-middleware"'`, pero el `package.json` real declara `"name": "repaga-siemens-middleware"` (verificado en repo, dist-pkg y bundle v1.3.1). Aplicado literalmente, **rechaza TODOS los candidatos incluida la instalación legítima → exit 4 en el 100% de los casos**. Verificado empíricamente:

```
Regex Frank 'valueflow-middleware' matchea: False
Regex corregido 'repaga-siemens-middleware' matchea: True
```

**⚠ Segunda regresión (auto-borrado):** con el nuevo orden, si el bundle está en `$InstallDir\middleware` (caso ZIP extraído en `C:\apps\siemens-middleware` = `$InstallDir` default), las líneas 216-218 eliminan `$InstallDir\middleware` **antes** de copiarlo: el borra su propio origen → `Copy-Item` falla → `exit 4`. Requiere guarda explícita (incluida abajo).

---

## B. Justificación de la Solución y Código Exacto

Todos los bloques: parseados con `PSParser` → **0 errores de sintaxis**; lógica simulada en pwsh con escenarios viejo/nuevo/random → comportamiento correcto. Se respeta la convención del script (ASCII puro, comillas simples, concatenación con `+`).

**Orden recomendado de aplicación: Bug 3 → Bug 1 (+1b) → Bug 2.** Razón: el Bug 3 determina QUÉ código se instala (payload); los bugs 1 y 2 pueden ser enmascarados o amplificados por instalar código viejo (deps distintas, `node_modules` corrupto). El Bug 1 va segundo porque el hash es prerrequisito de arranque del servicio bajo PM2 (`required()` en producción), y su fix de tipo revela errores reales de node si persisten. El Bug 2 es el paso final: `pm2 list` + healthcheck prueban end-to-end los tres fixes.

### Fix 3 — Búsqueda del middleware (reemplaza líneas 174-194)

```powershell
# Buscar la carpeta middleware: bundle NUEVO primero, con validacion de identidad
$SearchPaths = @(
    (Join-Path $InstallDir 'middleware'),
    (Join-Path $PSScriptRoot '..\middleware'),
    (Join-Path $PSScriptRoot '..\..\middleware'),
    'C:\Users\frank\Desktop\REPAGA\valueflow-middleware\middleware',
    'C:\Temp\valueflow-middleware\middleware',
    'C:\apps\valueflow-middleware\middleware'
)

$SourceMiddleware = $null
foreach ($path in $SearchPaths) {
    if ($path -and (Test-Path $path)) {
        $pkgCheck = Join-Path $path 'package.json'
        $distCheck = Join-Path $path 'dist'
        if ((Test-Path $pkgCheck) -and (Test-Path $distCheck)) {
            # Validar identidad: SOLO el middleware correcto, no cualquier package.json
            $pkgContent = Get-Content $pkgCheck -Raw
            if ($pkgContent -match '"name"\s*:\s*"repaga-siemens-middleware"') {
                $SourceMiddleware = $path
                break
            }
        }
    }
}
```

Notas de diseño respecto a la propuesta original de Frank:
- Se **conserva el requisito de `dist`**: el bundle ZIP v1.3.1 NO incluye `dist` (verificado: `unzip -l` → 0 entradas `middleware/dist/`). Eliminar el chequeo (como hacía el snippet propuesto) produciría instalaciones que "succeeden" pero cuyo servicio jamás arranca. Si el flujo ZIP debe funcionar, ver hallazgo adicional D-4.
- Regex corregido a `repaga-siemens-middleware` (el nombre real).

### Fix 3b — Guarda anti self-delete (reemplaza líneas 215-218)

```powershell
# Eliminar instalacion anterior SOLO si no es el origen que vamos a copiar
$legacyMiddlewareDir = Join-Path $InstallDir 'middleware'
if ((Test-Path (Join-Path $legacyMiddlewareDir 'package.json')) -and ((Resolve-Path $legacyMiddlewareDir).Path -ne (Resolve-Path $SourceMiddleware).Path)) {
    Remove-Item $legacyMiddlewareDir -Recurse -Force -ErrorAction SilentlyContinue
}
```

Verificado: con `$SourceMiddleware == $InstallDir\middleware` la guarda bloquea el borrado (`True`); el `-ne` de PowerShell es case-insensitive y `Resolve-Path` normaliza separators.

### Fix 1 — Captura segura del output de node (reemplaza líneas 345-346)

```powershell
# FIX-20260806-01: 2>&1 envuelve stderr en ErrorRecord; validar tipo antes de Trim()
$bcryptRaw = & $nodeExe -e $nodeScript $passwordFile 2>&1
$errLines = @($bcryptRaw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
$bcryptHash = (($bcryptRaw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) | Out-String).Trim()
if ($bcryptHash -eq '' -and $errLines.Count -gt 0) {
    throw ('Node.js error: ' + $errLines[0].Exception.Message)
}
```

Es una variante estrictamente más robusta del fix propuesto por Frank: la versión original (`if ($bcryptHash -is [ErrorRecord]) throw`) solo cubre salida 100% stderr y además `-is` sobre un arreglo mixto devuelve `$false`; esta versión recupera stdout aunque haya warnings en stderr y solo lanza cuando no hay hash utilizable — exponiendo el mensaje real de node. El resto del paso 9 (validación `'^\$2[ayb]\$'` y catch) se conserva igual.

### Fix 1b — Persistencia real del hash (reemplaza líneas 356-358)

```powershell
# FIX-20260806-01: append plano sin -replace (el hash contiene $ que .NET interpreta como grupos)
$envContent = Get-Content $envPath -Raw
if ($envContent -match '(?m)^UI_PASSWORD_HASH=') {
    $envContent = $envContent -replace '(?ms)^UI_PASSWORD_HASH=.*\r?\n', ''
}
$envContent = $envContent.TrimEnd() + "`r`n" + 'UI_PASSWORD_HASH=' + $bcryptHash + "`r`n"
Set-Content -Path $envPath -Value $envContent -Force
```

El `-replace` residual solo BORRA la línea previa (replacement vacío → inmune a `$`); el valor se inserta por concatenación pura.

### Fix 2 — Detección e invocación de PM2 siempre vía `.cmd`

Reemplazar líneas 380-418 (paso 11 completo):

```powershell
# ===== 11. Instalar PM2 =====
Write-Step 'Verificando PM2 (gestor de procesos)...'

# FIX-20260806-01: detectar SIEMPRE pm2.cmd (Start-Process no puede ejecutar .ps1: error %1 Win32)
function Find-Pm2Cmd {
    param([string]$NodeDir)
    $candidates = @(
        "$env:APPDATA\npm\pm2.cmd",
        "$env:ProgramFiles\nodejs\pm2.cmd",
        "$env:ProgramFiles\npmjs\pm2.cmd",
        (Join-Path $NodeDir 'pm2.cmd')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    foreach ($dir in ($env:Path -split ';')) {
        if ($dir -and (Test-Path (Join-Path $dir 'pm2.cmd'))) {
            return (Join-Path $dir 'pm2.cmd')
        }
    }
    return $null
}

$pm2Exe = Find-Pm2Cmd -NodeDir (Split-Path $nodeExe -Parent)

if (-not $pm2Exe) {
    Write-Warn 'PM2 no detectado. Instalando globalmente...'
    Push-Location $InstallDir
    try {
        $npmCmd = Join-Path (Split-Path $nodeExe -Parent) 'npm.cmd'
        Start-Process -FilePath $npmCmd -ArgumentList 'install -g pm2 pm2-windows-startup' -Wait -PassThru -NoNewWindow | Out-Null
        $sysPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = $sysPath + ';' + $userPath
        # NUNCA Get-Command pm2: resuelve a pm2.ps1, que no es ejecutable
        $pm2Exe = Find-Pm2Cmd -NodeDir (Split-Path $nodeExe -Parent)
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
```

El candidato `(Join-Path $NodeDir 'pm2.cmd')` cubre Node portable: con node no-MSI el prefijo global de npm es el directorio de `node.exe` (`C:\apps\siemens-middleware\node\node-v20.14.0-win-x64\pm2.cmd`). El barrido de `$env:Path` cubre prefijos no estándar. Las líneas 425-426 (`Start-Process` de `pm2 start`/`save`) se conservan: con `.cmd`, `ShellExecute` funciona correctamente.

### Fix 2b — pm2-startup sin Get-Command (reemplaza líneas 428-434)

```powershell
$pm2StartupCmd = Join-Path (Split-Path $pm2Exe -Parent) 'pm2-startup.cmd'
if (Test-Path $pm2StartupCmd) {
    Start-Process -FilePath $pm2StartupCmd -ArgumentList 'install' -Wait -PassThru -NoNewWindow | Out-Null
    Write-OK 'Servicio Windows instalado (auto-arranque habilitado)'
} else {
    Write-Warn 'pm2-startup no disponible - usando pm2 save'
}
```

---

## Hallazgos adicionales (adyacentes, recomendados en el mismo pase)

- **D-1. `ecosystem.config.js` con `cwd` hardcodeado** (`middleware/ecosystem.config.js:5` → `cwd: 'C:/apps/siemens-middleware'`). Si `$InstallDir` difiere, PM2 arranca el servicio contra un directorio inexistente aunque el Fix 2 sea correcto. Fix propuesto (validado, CWD-REWRITE-OK) en el paso 12, tras el `Push-Location`:

```powershell
$ecoPath = Join-Path $InstallDir 'ecosystem.config.js'
if (Test-Path $ecoPath) {
    $ecoContent = Get-Content $ecoPath -Raw
    $installDirFw = $InstallDir -replace '\\', '/'
    $ecoContent = $ecoContent -replace 'cwd:\s*''[^'']*''', ('cwd: ''' + $installDirFw + '''')
    Set-Content -Path $ecoPath -Value $ecoContent -Force
}
```

- **D-2. Layout viejo residual en 2 chequeos:** línea 368 busca el addon nativo en `$InstallDir\middleware\node_modules\...` y la línea 447 (fallback) hace `Set-Location (Join-Path $InstallDir 'middleware')`, pero la copia actual (línea 220) deposita el middleware en la **raíz** de `$InstallDir` (consistente con `script: 'dist/index.js'` de ecosystem). Corrección: `$addonPath = Join-Path $InstallDir 'node_modules\node-firebird-driver-native\build\Release\addon.node'` y `Set-Location $InstallDir`. Sin esto: warning falso de addon + fallback roto cuando PM2 no arranca.
- **D-3. `[UninstallRun] Filename: "pm2"`** en `installer.iss` hereda el mismo riesgo de resolución; monitorizar (no bloqueante).
- **D-4. El bundle ZIP no es instalable:** `installer/prepare-dist-pkg.sh:104` excluye `dist` del bundle (`--exclude='dist'`), y la búsqueda exige `dist`. Verificado: el ZIP v1.3.1 tiene 0 archivos bajo `middleware/dist/`. El flujo `.exe` (Inno Setup empaqueta `..\middleware\*` del repo, que sí tiene `dist`) funciona; el flujo ZIP descrito en el `README` del bundle aborta con `exit 4`. Fix sugerido: quitar `--exclude='dist'` del rsync y regenerar el ZIP.

---

## C. Instrucciones de Handoff para SOFIA (aplicación L2) / GEMINI (verificación)

1. **Aplicar en este orden** los bloques B sobre `installer/install.ps1` (Fix 3 + 3b → Fix 1 + 1b → Fix 2 + 2b; D-1/D-2 recomendados en el mismo pase). No tocar el resto del script.
2. Verificación local de sintaxis: `pwsh -NoProfile -Command "[System.Management.Automation.PSParser]::Tokenize((Get-Content installer/install.ps1 -Raw), [ref]$errors); $errors"` → esperar 0 errores. Todos los bloques de este dictamen ya pasaron esa validación.
3. Bump de versión: `bash installer/bump-version.sh patch` → v1.3.2; `prepare-dist-pkg.sh` si se regenera bundle.
4. Solicitar revisión final a **GEMINI** (`task` con `subagent_type='gemini'`) como segunda mano antes de commit. NO usar qodo (sunset).
5. Commit sugerido: `fix(installer): FIX-20260806-01 - bcrypt ErrorRecord, pm2.cmd y orden de busqueda del bundle`.

### Prueba de humo en VM (criterios de aceptación)

1. Desinstalar estado previo y dejar **solo** el instalable viejo en `C:\Program Files\siemens-middleware` (reproducir condición). Ejecutar el instalador nuevo.
2. **Bug 3:** el log debe mostrar `Origen: C:\apps\siemens-middleware\middleware` (o el bundle nuevo), NO `C:\Program Files\...`.
3. **Bug 1:** log `[OK] UI_PASSWORD_HASH generado...` Y `Select-String UI_PASSWORD_HASH C:\apps\siemens-middleware\.env` debe mostrar la línea completa `UI_PASSWORD_HASH=$2b$12$...` (verificación de persistencia — esto fallaba antes aunque el log dijera OK).
4. **Bug 2:** sin `%1 no es una aplicación Win32 válida`; `pm2 list` muestra `siemens-middleware` en `online`; `pm2-startup install` ejecuta sin error.
5. **End-to-end:** `Invoke-WebRequest http://localhost:4567/api/health` → 200; login UI con `Admin / Admin123` acepta (prueba que hash persistido coincide con bcrypt.compareSync en `src/ui/server.ts:31`).
6. Regresión: reinstalar sobre instalación existente (verifica Fix 3b y el borrado de línea vieja de `.env`), y una instalación limpia sin bundle en `$InstallDir` (debe resolver desde `$PSScriptRoot\..\middleware`).

---

**DEBY terminó dictamen** — Confirmados los 3 bugs reportados y hallado un 4º silente (hash bcrypt nunca se persiste en `.env`, crashea el arranque de PM2 en producción); además el regex de validación propuesto por Frank para el Bug 3 usa el nombre equivocado (`valueflow-middleware` vs real `repaga-siemens-middleware`) y bloquearía el 100% de las instalaciones. Dictamen en: `context/interconsultas/DICTAMEN_FIX-20260806-01.md`. Estado: `VALIDADO`. Acción sugerida: aplicar fixes vía SOFIA en orden Bug 3 → 1 → 2, revisión GEMINI, y prueba de humo en VM con los 6 criterios.
