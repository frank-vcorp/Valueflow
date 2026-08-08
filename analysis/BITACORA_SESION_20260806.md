# Bitacora de Sesion — Instalacion de Valueflow Middleware en VM Windows 11

**Sesion:** 2026-08-05 18:19 - 2026-08-06 14:36 CST (~20 horas)
**Operador:** Frank (INTEGRA / SOFIA / GEMINI / DEBY)
**Cliente objetivo:** REPRESENTACIONES AGA 2 (Repaga)
**VM:** Windows 11 + Firebird 2.5 + Aspel SAE 9.0 con BD `SAE90EMPRE01.FDB` (767 KB)

---

## 📋 Resumen ejecutivo

| Hito | Estado | Commit |
|------|--------|--------|
| Validación esquema BD cliente | ✅ DONE | - |
| E2E ventas a QUA (CFDI_32700) | ✅ DONE | `5396b81` |
| Race condition firebird.js | ✅ DONE | `5396b81` |
| API key a .env (sin secretos) | ✅ DONE | `5396b81` |
| Push a GitHub | ✅ DONE | `5396b81` |
| Instalable .exe v1.0 | ✅ Compilado | - |
| Instalable .exe v1.1.1 | ✅ Compilado | `a20c6d3` |
| Instalable .exe v1.2.0 | ✅ Compilado | `ed7e79e` |
| Instalacion limpia en VM | ⏳ PENDIENTE | - |

---

## 🎯 Objetivo de la sesion

Lograr instalar Valueflow Middleware en la VM Windows 11 del cliente (provisionada con Aspel SAE 9.0 + Firebird 2.5 + BD real `SAE90EMPRE01.FDB`), con instalable .exe TODO-EN-UNO que:
- Solo pida la ruta del .FDB de Aspel (1 campo)
- Tenga credenciales UI preconfiguradas (user=Admin, pass=Admin123)
- Tenga API Key Siemens QUA preconfigurada
- Levante el servicio automaticamente (PM2 con fallback Node)
- Cree acceso directo en escritorio con icono personalizado
- Tenga desinstalador standalone (sin Panel de Control)

---

## 🐛 Bugs encontrados y corregidos en `install.ps1`

### v1.0 - Primer instalable (compilado OK pero con bugs)
- **B1**: `sLineBreak` no existe en Inno Pascal → cambié a `#13#10` concatenado (comillas dobles)
- **B2**: `const CRLF` no permitido a nivel global en `[Code]` → moví a variable local dentro de función
- **B3**: `DownloadTemporaryFile` cambió firma en v7 → eliminé la lógica (todo-en-uno, no descarga internet)
- **B4**: `Exec()` firma distinta entre `[Code]` y preprocessor → eliminé la llamada
- **B5**: `//` comentario → cambié a `{ }` (estilo Delphi/Pascal)
- **B6**: Wizard con 6 parámetros → `CreateInputFilePage.Add()` solo acepta 5
- **B7**: `Flags: checked` no soportado en Inno 7 → eliminado

### v1.1.1 - Wizard simplificado (un campo solo)
- `Flags: checked` en `[Tasks]` → removido (compatible Inno 6 y 7)
- `#13#10` concatenado con string → fallaba porque PowerShell interpreta `#` como directiva preprocessor
- `sLineBreak` → no existe en Inno Pascal Script
- `const CRLF` a nivel global → no permitido en `[Code]`
- Todo reemplazado por `NewLine` declarada como variable local y `+` para concatenar

### v1.2.0 - install.bat con auto-elevación
- `install.bat` agregaba auto-elevación de privilegios vía PowerShell con `Start-Process -Verb RunAs -Wait`
- Agregado `uninstall.bat` standalone para desinstalar sin Panel de Control
- Acceso directo "Desinstalar" en menú inicio

### v1.2.0 (compilado 14:35) - 5 bugs de sintaxis PowerShell

| Linea | Bug | Fix |
|-------|-----|-----|
| **288** | `if ($SiemensAPIKey -eq "<api_key_a_configurar>" -or [string]::IsNullOrEmpty(...))` → operador `<` reservada | Removida comparación redundante, solo `IsNullOrWhiteSpace` |
| **371** | `}` extra de edición anterior (doble cierre de bloque) | Llave removida |
| **372** | `& $nodeBin -e "...hashSync(process.argv[1], 12));" $UIPasswordPlain` → escape roto en string | Cambiado a archivo temporal `%TEMP%\valueflow_bcrypt_input.txt` y Node lee con `fs.readFileSync(process.argv[1])` |
| **504** | `$shortcut.Description = "Valueflow Middleware - Aspel SAE <-> Siemens PoSi"` → `<>` interpretados como redirectores | Concatenación con `+` |
| **545-548** | `Write-Host "    3. cd $InstallDir && npm rebuild..."` → `&&` no soportado en PowerShell | Concatenación con `+` y comillas externas diferentes |
| **551** | Mismo problema en `Write-OK "Addon nativo..."` | Concatenación con `+` |

---

## 🛠️ Sistema de versionado automatico

### Archivos creados:
- `installer/VERSION` — Contiene `MAJOR.MINOR.PATCH`, `BUILD_DATE`, `BUILD_HASH`
- `installer/bump-version.sh` — Incrementa version (patch/minor/major)
- `installer/prepare-dist-pkg.sh` — Lee `VERSION` y actualiza `installer.iss` + genera bundle con nombre versionado

### Flujo de regeneracion:
```bash
cd /mnt/Datos/Proyectos\ 2.0/PC/repaga-siemens

# 1. Incrementar version
bash installer/bump-version.sh patch   # o minor, major

# 2. Regenerar bundle
bash installer/prepare-dist-pkg.sh

# 3. Compilar instalable .exe
docker run --rm \
  -v "$(pwd):/work" \
  -v "$(pwd)/installer/build_output:/work/installer/build_output" \
  -w /work/installer \
  amake/innosetup:latest \
  /opt/innosetup/ISCC.exe /work/installer/installer.iss

# 4. Mover .exe al directorio
mv installer/pt/innosetup/ISCC.exe/Valueflow-Setup-v*.exe installer/build_output/
rm -rf installer/pt

# 5. Limpiar archivos .fuse_hidden* (basura de Docker mounts)
find installer/build_output -name ".fuse_hidden*" -delete 2>/dev/null
```

### Versionado generado:
| Version | Nombre del bundle | Nombre del instalable | SHA256 |
|---------|-------------------|------------------------|--------|
| v1.0 | valueflow-middleware-v1.0.zip | Valueflow-Setup-v1.0.exe | 4f692ae045bf65... |
| v1.1.1 | valueflow-middleware-v1.1.1.zip | Valueflow-Setup-v1.1.1.exe | (rebuild) |
| v1.2.0 | valueflow-middleware-v1.2.0.zip | Valueflow-Setup-v1.2.0.exe | daed6302ec352e5210458b4101353e68bea32a27e0e96940fbe6826b18a2ab6f |

---

## 🔍 Auditoria QA de Gemini (8 bloqueadores)

| ID | Bloqueador | Estado |
|----|------------|--------|
| **B1** | `UI_PASSWORD_HASH` no se escribe correctamente | ✅ Fix por SOFIA (escape backtick) |
| **B2** | `config.json` incompleto (falta `retry_policy`, `optional_fields`) | ✅ Fix por SOFIA |
| **B3** | Fix de fechas solo en `dist/`, no en `src/` | ✅ Fix por SOFIA (aplicado en src/) |
| **B4** | Race condition solo en `dist/`, no en `src/` | ✅ Fix por SOFIA (NO_WAIT + streaming + backoff) |
| **B5** | API Key QUA real en repo público | ⚠️ Pendiente: rotar con Siemens |
| **B6** | CI sin `npm run build` antes de compilar | ✅ Fix por SOFIA (step nuevo en GitHub Actions) |
| **B7** | `IMPU1` enviado como COGS | ⚠️ Pendiente: confirmar con Data Steward |
| **B8** | Addon nativo Firebird sin verificar | ✅ Fix por SOFIA (verificación post-install) |

---

## 📋 Procedimiento de instalacion para Frank

### Pre-requisitos
- **VM Windows 11** provisionada con:
  - Aspel SAE 9.0 instalado (incluye `fbclient.dll`)
  - BD `SAE90EMPRE01.FDB` en `C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB`
- **Permisos de administrador** (UAC)
- **Conexion a internet** solo la primera vez (para `npm install`)

### Paso 0: Limpieza total (PowerShell Admin)
```powershell
# Cerrar todo
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process pm2 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Eliminar carpetas de instalaciones anteriores
Remove-Item -Recurse -Force "C:\Program Files\siemens-middleware" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\apps\siemens-middleware" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\Temp\valueflow-middleware" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\apps\valueflow-middleware" -ErrorAction SilentlyContinue

# Eliminar accesos directos del escritorio
Remove-Item "$env:USERPROFILE\Desktop\Valueflow Middleware.lnk" -ErrorAction SilentlyContinue

# Eliminar entrada del registro (Panel de Control)
$appName = 'Valueflow Middleware'
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$appName"
)
foreach ($reg in $regPaths) {
    if (Test-Path $reg) { Remove-Item -Path $reg -Force -ErrorAction SilentlyContinue }
}

# Verificar limpieza
Test-Path "C:\Program Files\siemens-middleware"  # False
Test-Path "C:\apps\siemens-middleware"            # False
Get-Process node -ErrorAction SilentlyContinue   # vacio
netstat -an | findstr :4567                       # vacio
```

### Paso 1: Copiar instalable a la VM
```bash
# Desde Linux (en mi terminal)
cp "/mnt/Datos/Proyectos 2.0/PC/repaga-siemens/installer/build_output/Valueflow-Setup-v1.2.0.exe" /media/$USER/USB/
# O via scp, carpeta compartida, etc.
```

### Paso 2: Verificar SHA256
```powershell
Get-FileHash "C:\path\Valueflow-Setup-v1.2.0.exe" -Algorithm SHA256
# Esperado: DAED6302EC352E5210458B4101353E68BEA32A27E0E96940FBE6826B18A2AB6F
```

### Paso 3: Ejecutar instalable
1. **Doble click** en `Valueflow-Setup-v1.2.0.exe`
2. Aceptar **UAC** (permisos admin)
3. Wizard:
   - Welcome → **Next**
   - Select Destination Location → **Next** (default `C:\Program Files\siemens-middleware`)
   - Seleccionar ruta `.FDB` → **Browse** → `C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB` → **Next**
   - Ready to install → **Install**
4. Esperar **3-5 minutos** mientras:
   - Extrae Node.js portable
   - Copia archivos del middleware
   - `npm install --production`
   - Genera hash bcrypt para `Admin123`
   - Configura `.env` y `config.json`
   - Configura PM2 como servicio
   - Crea acceso directo con icono personalizado

### Paso 4: Verificar instalacion
```powershell
# Verificar servicio
Get-Process node
netstat -an | findstr :4567
# Esperado: 1 proceso Node, puerto LISTENING

# Si algo falla, ver logs:
Get-Content "C:\Program Files\siemens-middleware\logs\stderr.log" -Tail 50
```

### Paso 5: Login en la UI
Abrir navegador en `http://localhost:4567/` (HTTP, NO HTTPS)
- **User:** `Admin`
- **Password:** `Admin123`

---

## 🆘 Comando de RESCATE (si el servicio no levanta)

Si después de la instalacion ves `ERR_CONNECTION_REFUSED`:

```powershell
# 1. Verificar estructura
Test-Path "C:\Program Files\siemens-middleware\middleware\package.json"
Test-Path "C:\Program Files\siemens-middleware\middleware\dist\index.js"
Test-Path "C:\Program Files\siemens-middleware\node\node-v20.14.0-win-x64\node.exe"

# 2. Si los 3 son False, la copia fallo. Re-instalar limpio.

# 3. Si existen, arrancar manualmente:
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$env:Path = "C:\Program Files\siemens-middleware\node\node-v20.14.0-win-x64;$env:Path"

Set-Location "C:\Program Files\siemens-middleware\middleware"
$nodeExe = "C:\Program Files\siemens-middleware\node\node-v20.14.0-win-x64\node.exe"
Start-Process -FilePath $nodeExe -ArgumentList "dist/index.js" -WindowStyle Hidden
Start-Sleep -Seconds 5

Get-Process node
netstat -an | findstr :4567

# Si LISTENING, abrir navegador
Start-Process "http://localhost:4567/"
```

---

## 🔓 Desinstalar con `uninstall.bat` (sin Panel de Control)

Doble click en:
```
C:\Program Files\siemens-middleware\installer\uninstall.bat
```

O desde Menú Inicio → `Valueflow Middleware` → `Desinstalar Valueflow Middleware`.

El script:
1. Pide confirmacion
2. Detiene servicio PM2 (`pm2 stop siemens-middleware`)
3. Elimina servicio Windows (`pm2-startup uninstall`)
4. Mata procesos Node del middleware
5. Elimina la carpeta `C:\Program Files\siemens-middleware`
6. Elimina acceso directo del escritorio

---

## 📂 Estado del repo en GitHub

### Commits pusheados:
| Commit | Descripcion |
|--------|-------------|
| `ed7e79e` | fix(installer): 5 bugs de sintaxis PowerShell en install.ps1 v1.2.0 |
| `a20c6d3` | fix(installer): 4 bugs criticos detectados durante prueba en VM |
| `4050df4` | docs(PROYECTO.md): agregar notas para proxima sesion |
| `e785aff` | fix(installer+middleware): aplicar 8 fixes QA antes de go-live |
| `cfdf3d9` | fix(installer): busqueda inteligente del middleware + fallback Node directo |
| `6e23151` | fix(installer): filtro de archivos del wizard |
| `d4f6620` | feat(installer): wizard 1-solo-campo + credenciales preconfiguradas + icono |
| `0481358` | fix(installer): bypass PowerShell Execution Policy |
| `8f20c11` | fix(installer): corregir firma CreateInputFilePage.Add |
| `893a217` | feat(installer): wizard 3-campos todo-en-uno |
| `5396b81` | feat(middleware): E2E QUA + concurrency fix + install package |

### Pendientes (commitear local):
- `installer/uninstall.bat` (nuevo en v1.2.0)
- `installer/bump-version.sh` (nuevo sistema versionado)
- `installer/VERSION` (nuevo)
- `installer/installer.iss` (cambios v1.2.0)
- `installer/prepare-dist-pkg.sh` (cambios v1.2.0)

---

## 🎯 Estado del lote `lote-ventas-20260805-01`

| Ticket | Estado | Notas |
|--------|--------|-------|
| FACT-20260805-01 (validacion esquema BD) | ✅ DONE | - |
| FACT-20260805-02 (E2E ventas) | ✅ DONE | - |
| FIX-20260805-01 (race condition) | ✅ DONE | - |
| IMPL-20260806-01 (QA fixes Gemini) | ✅ DONE | 8 fixes SOFIA |
| **MR-20260806-01 (instalacion limpia VM)** | ⏳ EN PROGRESO | v1.2.0 listo para probar |

---

## 📝 Pendientes HUMANOS (no se pueden resolver automaticamente)

### B5: Rotar API Key QUA con Siemens
- Estado: codigo tiene placeholder `<api_key_a_configurar>`
- Riesgo: la key real `I1k****gbv` esta expuesta en historial de git publico
- **ACCION FRANK**: solicitar nueva API key al Data Steward de Siemens
- **POST-INSTALACION**: pegar la nueva key en UI Configuracion → API Key Siemens
- **WORKAROUND temporal**: el instalable funciona con el placeholder, solo los envios fallaran hasta configurar la key real

### B7: Confirmar mapeo IMPU1 vs COST con Data Steward
- Estado: `middleware/src/siemens/sales.ts:32-39` usa `d.IMPU1` para `extended_cost_of_goods_sold`
- Codigo actual:
  ```typescript
  extended_cost_of_goods_sold: data.IMPU1  // deberia ser CANT × COST
  ```
- **ACCION FRANK**: preguntar a Siemens si el campo correcto es `COST` en lugar de `IMPU1`
- **Si confirma**: SOFIA arregla con task pequena (~5 lineas)

### Funcionales (no bloquean sandbox):
- Credenciales PRD de Siemens (actualmente solo QUA)
- Decision `quantity_unit_of_measure` ("pz" vs "each")
- Actualizacion del cliente a Aspel SAE 10 (actualmente tiene SAE 9.0)

---

## 🔧 Artefactos listos para usar

| Artefacto | Path | Tamano | SHA256 |
|-----------|------|--------|--------|
| **Instalable** | `installer/build_output/Valueflow-Setup-v1.2.0.exe` | 48 MB | `daed6302ec352e5210458b4101353e68bea32a27e0e96940fbe6826b18a2ab6f` |
| **Bundle alternativo** | `dist-pkg/valueflow-middleware-v1.2.0.zip` | 29 MB | `b738ce738383d800854c36744913ed6f06fd7881a51ec5046e90ca65862ec9d4` |

### Credenciales del middleware (para pruebas):
- **UI login:** user=`Admin`, pass=`Admin123`
- **API key Siemens:** placeholder (cambiar desde UI Configuracion)
- **BD Aspel:** ruta configurable en wizard del instalable

---

## 📊 Reportes generados esta sesion

- `analysis/PRUEBA_E2E_VENTAS_20260805.md` — E2E QUA con CFDI_32700 (status 201)
- `analysis/FIX-20260805-01-firebird-concurrency.md` — Fix race condition firebird.js
- `analysis/VALIDACION_BD_FIREBIRD_20260805_R2.md` — Validacion completa BD
- `analysis/PROCEDIMIENTO_LEVANTAR_FIREBIRD_FLAMEROBIN.md` — Procedimiento Linux
- `installer/COMPILAR-EXE-EN-VM.md` — Guia VM Windows

---

## 🎯 Proximos pasos para go-live produccion

1. Frank ejecuta `Valueflow-Setup-v1.2.0.exe` en VM Windows 11 con limpieza total previa
2. Login con `Admin / Admin123`
3. Pegar nueva API key QUA en UI Configuracion → API Key Siemens (B5)
4. Esperar rotacion de Siemens
5. Confirmar B7 con Data Steward (IMPU1 vs COST)
6. Si B7 positivo: SOFIA arregla `sales.ts`
7. Re-test en QUA (5 requests sin 502)
8. Instalar en PC de Ing. Paco
9. Cron job 24h: monitorear logs por errores

---

## 📞 Comandos utiles post-instalacion

```powershell
# Ver estado del servicio
pm2 status

# Ver logs en tiempo real
pm2 logs siemens-middleware

# Reiniciar servicio
pm2 restart siemens-middleware

# Ver todos los procesos
Get-Process node

# Ver puerto
netstat -an | findstr :4567

# Ver configuracion actual
Get-Content "C:\Program Files\siemens-middleware\middleware\.env"
Get-Content "C:\Program Files\siemens-middleware\middleware\config.json"
```

---

**Ultima actualizacion (sesion previa):** 2026-08-06 14:36 CST
**Estado (sesion previa):** Instalable v1.2.0 listo para Frank. Pendiente: ejecutar limpieza total + instalacion limpia.

---

# 🚨 SESIÓN POSTERIOR — Hilo ATLAS-M3 escalado a INTEGRA (2026-08-06 22:47 CST)

**Sesión:** 2026-08-06 22:47 CST (continuación)
**Operador:** INTEGRA (Spark 1.1) — recibió handoff de ATLAS-M3 (rol explorador, ilimitado)
**Contexto:** Lote `lote-ventas-20260805-01` EXPIRADO. Cliente SIN servicio tras instalador v2.0.8 falla sistémica.

## Resumen ejecutivo

ATLAS-M3 preparó handoff a INTEGRA tras detectar falla sistémica del instalador v2.0.8 en VM Windows 11 del cliente. El instalador "completó exitosamente" según su log, pero el bundle quedó en `Downloads` (no en ruta final), `dist/` no se compiló, PM2 levantó slot zombi (pid 3400 muerto, puerto 4567 nunca bindeado). Cliente sin acceso a `http://localhost:4567/`.

## Diagnóstico confirmado por INTEGRA (verificación propia, no asume handoff)

| Hallazgo | Confirmación en código |
|----------|------------------------|
| Mismatch de paths (3 rutas distintas para "el mismo" dir) | `installer/install.ps1:21` → `InstallDir='C:\apps\siemens-middleware'`; `installer/installer.iss:18` → `DefaultDirName={autopf}\siemens-middleware` = `C:\Program Files\siemens-middleware` (x64); `middleware/ecosystem.config.js:5` → `cwd:'C:/apps/siemens-middleware/middleware'` |
| Bundle v2.0.8 sin `dist/` precompilado | Listado de `dist-pkg/valueflow-middleware-v2.0.8/middleware/` no contiene `dist/` |
| Instalador no ejecuta `npm run build` visible | No hay step explícito con manejo de error en `install.ps1` |
| Slot PM2 zombi | `ecosystem.config.js` `script:'dist/index.js'` inexistente → node crashea al arranque → PM2 marca online con pid muerto |
| Bundle quedó en `Downloads` no en ruta final | `Get-ChildItem -Filter ecosystem.config.js -Recurse C:\` → único resultado en `C:\Users\frank\Downloads\valueflow-middleware\middleware\` |
| `.env` con bugs colaterales | `FIREBIRD_PASSWORD` vacío; `LOG_DIR=/tmp/siemens-middleware-logs` (path Linux en Windows); `UI_PASSWORD_HASH` presente (OK); `SIEMENS_API_KEY` real en historial git (B5) |
| Dictamen DEBY `FIX-20260806-01` Bug 3 no resuelto | Confirmado en `context/interconsultas/DICTAMEN_FIX-20260806-01.md:54-72`: copia desde instalable viejo persiste en v2.0.8 |

## Recomendación INTEGRA (G1) — HÍBRIDO A→B

Decisión bloqueante escalada a Frank vía `ask-frank.sh` (ID `ARCH-20260806-01` + followup `ARCH-20260806-02`). El gateway Hermes clasificó ambas consultas como VERDE (autonomous) sin esperar respuesta explícita de Frank, a pesar de lenguaje explícitamente bloqueante. INTEGRA NO procede solo contra protocolo (§2 confianza ~75% <80%, §4 lote expirado + fix v2.0.9 fuera de alcance del lote original, §10 escalar siempre lo irreversible).

**Estado actual:** `BLOCKED (espera-decisión-humana)` para G1.

## Workaround A para Frank (servicio HOY, ~20 min)

Frank ejecuta en PowerShell Admin de la VM. Pasos (descripción natural + comandos clave):

1. **Limpiar slot zombi PM2:** `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force`; `pm2 kill`; `pm2 delete all`.
2. **Copiar bundle a path canónico** (coincide con `ecosystem.config.js` cwd): `New-Item -ItemType Directory -Path "C:\apps\siemens-middleware" -Force`; copiar contenido de `C:\Users\frank\Downloads\valueflow-middleware\*` a `C:\apps\siemens-middleware\` con `Copy-Item -Recurse -Force`.
3. **Instalar deps y compilar `dist/`** (CRÍTICO — el bundle v2.0.8 NO trae `dist/` precompilado, y es la causa raíz del slot zombi): `Set-Location "C:\apps\siemens-middleware\middleware"`; `npm install --no-audit --no-fund`; `npm run build`; verificar `Test-Path "dist\index.js"` devuelve `True`.
4. **Corregir `.env` (3 bugs colaterales):**
   - `FIREBIRD_PASSWORD`: llenar con valor real (Frank debe saberlo — SYSDBA default Aspel SAE 9.0).
   - `LOG_DIR`: cambiar de `/tmp/siemens-middleware-logs` a `C:\apps\siemens-middleware\logs`. Comando: `(Get-Content .env) -replace '^LOG_DIR=.*','LOG_DIR=C:\apps\siemens-middleware\logs' | Set-Content .env`.
   - `SIEMENS_API_KEY`: **NO pegar key real aquí** (B5 — expuesta en git público). Dejar placeholder, cargar desde UI Configuración → API Key Siemens después del arranque.
   - `UI_PASSWORD_HASH`: ya presente (OK según ATLAS).
5. **Arrancar PM2:** `pm2 start ecosystem.config.js`; `Start-Sleep -Seconds 5`; `netstat -an | findstr :4567` (debe mostrar `LISTENING`); `Start-Process "http://localhost:4567/"`.
6. **Persistencia (opcional, recomendado):** `pm2 save`; `pm2-startup install` para que el servicio sobreviva reinicio de VM.

**Riesgos del workaround A:**
- No sobrevive a reinicio de VM sin `pm2 save` + `pm2-startup install`.
- `FIREBIRD_PASSWORD` real en `.env` local (dato sensible — no commitear).
- API key QUA: NO pegar en `.env` (B5). Cargar desde UI después del arranque.
- Si `FIREBIRD_PASSWORD` es required en producción (como `UI_PASSWORD_HASH`), el middleware crasheará al arranque si queda vacío.

## Plan fix v2.0.9 (alcance G2 — se delega a SOFIA tras OK de Frank)

SPEC mínima para SOFIA (pendiente OK para delegar):

1. **Path canónico único:** `C:\apps\siemens-middleware\` (evita UAC de Program Files + espacios). Unificar `install.ps1`, `installer.iss` y `ecosystem.config.js` a este path.
2. **`install.ps1` detecta `InstallDir` real:** desde `$PSScriptRoot\..` (no asume hardcoded `C:\apps\`). Pasar como parámetro a `install.bat`.
3. **Step explícito `npm run build` con manejo de error:** bloque `try/catch`, log claro, abort si falla.
4. **Pre-compilar `dist/` en bundle:** más determinista que compilar en VM. Agregar `dist/` al `dist-pkg/valueflow-middleware-v2.0.9/`.
5. **`ecosystem.config.js` path relativo dinámico:** `cwd: process.cwd()` o `__dirname`-based, no hardcoded `C:/apps/...`.
6. **`.env` Windows-friendly:** `LOG_DIR=C:\apps\siemens-middleware\logs`; `FIREBIRD_PASSWORD=<colocar_password_firebird>` placeholder detectable que `validateRuntimeConfig` rechace en producción.
7. **Healthcheck PM2 anti-zombi:** `pm2 start ecosystem.config.js --wait-ready` o script post-start que verifique puerto 4567 + ping `/health`.

Validaciones SOFIA: `npm run typecheck`, `npm test`, `npm run lint` (si existe), self-review manual (Qodo está sunset — usar GEMINI como segunda mano). Regenerar bundle con `installer/bump-version.sh patch` + `prepare-dist-pkg.sh`.

## Bloqueadores humanos (independientes de G1)

- **B5 (API key QUA expuesta en git público):** Frank debe rotar con Siemens. Mientras tanto, NO pegar key real en `.env` local — cargar desde UI.
- **B7 (IMPU1 vs COST en `middleware/src/siemens/sales.ts:32-39`):** Frank debe confirmar con Data Steward. Si `IMPU1` está mal, SOFIA arregla con task pequeña (~5 líneas).

## Estado del lote `lote-ventas-20260805-01`

| Ticket | Estado | Notas |
|--------|--------|-------|
| FACT-20260805-01 | ✅ DONE | 46,430 facturas en FACTF01 |
| FACT-20260805-02 | ✅ DONE | CFDI_32700 enviado a QUA, status=201 |
| FIX-20260805-01 | ✅ DONE | NO_WAIT + streaming fetch |
| IMPL-20260806-01 | ✅ DONE | 8 fixes aplicados por SOFIA |
| MR-20260806-01 (instalación VM) | ❌ **BLOCKED (espera-decisión-humana)** | v2.0.8 falla sistémica; espera G1 de Frank |

**Lote EXPIRADO** (expiración 2026-08-05T23:41-06:00). Requiere renovación en PROYECTO.md si Frank decide continuar.

## Nota operativa: wrapper `ask-frank.sh` clasificación VERDE

El gateway Hermes clasificó la duda G1 como VERDE (autonomous) en ambas invocaciones (`ARCH-20260806-01` y followup `ARCH-20260806-02`), a pesar de lenguaje explícitamente bloqueante ("ACCIÓN DESTRUCTIVA PENDIENTE", "URGENTE", "no procedo sin OK"). El wrapper devolvió `decision: autonomous` sin esperar respuesta de Frank. INTEGRA no procede solo contra protocolo. Frank debe responder en el chat Kilo Code cuando aparezca para destrabar G1. Posible mejora futura: agregar flag `--blocking` al wrapper o ajustar heurística del gateway para detectar palabras clave de bloqueo (tarea para META).

---

**Ultima actualizacion:** 2026-08-06 22:47 CST
**Estado:** BLOCKED esperando decisión de Frank para G1 (instalador v2.0.8 falla sistémica). Workaround A documentado arriba. SPEC mínima para fix v2.0.9 preparada, pendiente OK para delegar SOFIA.
