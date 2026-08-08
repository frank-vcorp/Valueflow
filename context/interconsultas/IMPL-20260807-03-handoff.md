# HANDOFF INTEGRA → SOFIA — IMPL-20260807-03

**De:** INTEGRA (orquestador)
**Para:** SOFIA (implementador)
**Fecha:** 2026-08-07 11:37 CST
**Proyecto:** `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens`
**Autorización:** lote-ventas-20260805-01 (vigente hasta 2026-08-07T23:59-06:00)
**Restricciones:** NO commit, NO push, NO PR, NO deploy, NO datos reales a PRD Siemens. Trabajo local.

---

## Contexto

INTEGA delega. Frank confirmó en VM Windows 11 que tras IMPL-20260807-02 (que cerraste: v2.0.10 generado), el servicio PM2 quedó bloqueado por **F1**: `ecosystem.config.js:13` tiene `wait_ready: true` pero el middleware NUNCA emite `process.send('ready')` → PM2 marca `online` pero el proceso queda en deadlock esperando la señal; el puerto 4567 nunca bindea. Adicionalmente, el bundle actual NO trae `node_modules` (el instalador hace `npm install` en la VM cliente → dependencia externa que falla con proxy/firewall/poco internet) ni `fbclient.dll`.

## Objetivo

Generar **bundle v2.0.11 self-contained**: node_modules pre-instalado Y portable a Windows (todo JS puro, sin `.node` nativos), resolver la dependencia de `fbclient.dll`, quitar `wait_ready`, verificar E2E localmente.

## Alcance — 6 cambios obligatorios

### 1. `middleware/ecosystem.config.js` — quitar `wait_ready` (F1 fix definitivo)

Archivo actual (17 líneas):
- Línea 13: `wait_ready: true,`
- Línea 14: `listen_timeout: 10000,`
- Líneas 1-3: comentario que dice "wait_ready + listen_timeout son validos en PM2 OSS y esperan a que el proceso notifique 'ready' antes de marcarlo online."

**Cambios:**
- Eliminar la línea `wait_ready: true,` (línea 13).
- Cambiar `listen_timeout: 10000,` → `listen_timeout: 5000,` (línea 14).
- Reescribir el comentario del header (líneas 1-3) explicando que se quitó `wait_ready` porque el middleware no emite `process.send('ready')` y causaba deadlock en PM2 (F1). `listen_timeout` se mantiene como cortesía (PM2 lo ignora sin `wait_ready`, pero es inofensivo y documentativo).

**No tocar:** `name`, `script`, `cwd`, `instances`, `autorestart`, `watch`, `max_memory_restart`, `env`.

### 2. `installer/prepare-dist-pkg.sh` — pre-instalar `node_modules` portable en el bundle

El rsync actual (líneas 139-142) copia `middleware/` al staging EXCLUYENDO `node_modules`. Esto sigue siendo correcto (no copiamos el node_modules del working tree, que puede tener bins Linux no portables). **Después** de ese rsync, agregar un bloque que cree `node_modules` fresco y portable dentro del staging:

```bash
# Pre-instalar node_modules en el staging (bundle self-contained)
echo "==> Pre-instalando node_modules portable en staging del bundle..."
cd "$DIST_PKG/middleware"
npm install --omit=dev --ignore-scripts --no-audit --no-fund || {
    echo "ERROR: npm install fallo en staging del bundle"
    exit 1
}
# Verificar que node_modules se creo
test -d "node_modules" || { echo "ERROR: node_modules no se creo en staging"; exit 1; }
test -d "node_modules/.bin" || mkdir -p "node_modules/.bin"
# Verificar tamano razonable (< 100 MB; si hay .node nativos, abortar)
SIZE=$(du -sm "$DIST_PKG/middleware/node_modules" | cut -f1)
test "$SIZE" -lt 100 || { echo "ERROR: node_modules pesa ${SIZE}MB — posible binario nativo no portable"; exit 1; }
# Verificar que NO hay archivos .node (binarios nativos) en el bundle
if find "$DIST_PKG/middleware/node_modules" -name "*.node" | grep -q .; then
    echo "ERROR: encontrado .node nativo en node_modules del bundle — NO portable a Windows"
    find "$DIST_PKG/middleware/node_modules" -name "*.node"
    exit 1
fi
echo "==> node_modules portable OK (${SIZE}MB, sin .node nativos)"
cd "$SCRIPT_DIR"
```

**Notas:**
- El `--ignore-scripts` evita post-install que requieran node-gyp/Python.
- La verificación de `.node` nativos es la garantía de portabilidad Linux→Windows.
- Actualizar el README del bundle (líneas 171-199) para mencionar que `node_modules` va pre-instalado.

### 3. `installer/prepare-dist-pkg.sh` — incluir/verificar `fbclient.dll` (DEFENDER con baseline primero)

**AMBIGÜEDAD CRÍTICA — resolver con Fact-Forcing ANTES de tocar fbclient:**

IMPL-20260807-02 (que cerraste) limpió 4 deps nativas huérfanas incluyendo `node-firebird-native-api` (confirmado no importadas en `src/`). PERO `install.ps1:116-136` sigue buscando `fbclient.dll` en rutas de Windows y hace `exit 3` si no lo encuentra. Esto es contradictorio: si no hay dep nativa, ¿para qué se requiere `fbclient.dll`?

**TAREA DE BASELINE (obligatoria antes del punto 3):** Lee y reporta:
1. `middleware/package.json` — ¿qué dependencias firebird hay? ¿`node-firebird` (JS puro, protocolo wire-level) o `node-firebird-native-api` (nativo, requiere fbclient.dll)?
2. `middleware/src/` (busca imports de firebird) — ¿qué lib se importa realmente en el código?
3. `FirebirdCS-2.5.0.26074-0.amd64/` (en raíz del repo) — ¿contiene `fbclient.dll` Windows o solo `libfbclient.so` Linux?

**3 escenarios posibles:**

- **(a) Solo `node-firebird` (JS puro), sin native-api en package.json ni en src:** El middleware NO requiere `fbclient.dll` para funcionar (usa protocolo wire-level directo a Firebird server en localhost:3050). El requisito de `fbclient.dll` en `install.ps1:116-136` es **obsoleto**. Acciones:
  - Relajar `install.ps1:131-135`: cambiar `exit 3` por un `WARN` (Firebird client .dll es opcional cuando se usa driver JS puro; solo se requiere Firebird server corriendo en localhost:3050).
  - En el README del bundle explicar que Firebird server (parte de Aspel SAE) debe estar corriendo en `localhost:3050`, no se requiere `fbclient.dll` client.
  - NO incluir `fbclient.dll` en el bundle (no hay .dll Windows y no se necesita).
  - Reportar este hallazgo como edge case resuelto.

- **(b) `node-firebird-native-api` SIGUE importado en src/:** El middleware SÍ requiere `fbclient.dll` y un addon `.node` compilado en Windows. Bundle self-contained 100% portable NO es posible. **BLOCKED** — escalar a INTEGA (no continues con el resto, reporta el blocker).

- **(c) Ambiguo:** Reporta lo que encontraste y pide a INTEGA decisión. No adivines.

**Si (a) confirmado:** procede. El bundle queda 100% self-contained sin `fbclient.dll`.
**Si (b) o (c):** detente en el punto 3, reporta BLOCKED con evidencia, no continues con puntos 4-6.

### 4. `installer/install.ps1` — saltar `npm install` si el bundle trae `node_modules`

En el PASO 7 (líneas 311-345), antes del bloque `cmd /c "cd /d ... && npm install ..."` (línea 323), agregar lógica de detección:

```powershell
# Verificar si el bundle trae node_modules pre-instalado (self-contained)
$nodeFirebirdPkg = Join-Path $destMiddleware 'node_modules\node-firebird\package.json'
if (Test-Path $nodeFirebirdPkg) {
    Write-Log 'node_modules pre-instalado en bundle (self-contained), saltando npm install' 'OK'
    $skipNpmInstall = $true
} else {
    Write-Log 'node_modules no encontrado en bundle, ejecutando npm install' 'INFO'
    $skipNpmInstall = $false
}

if (-not $skipNpmInstall) {
    # ... comando npm install actual (linea 323) ...
    cmd /c "cd /d `"$destMiddleware`" && `"$npmCmd`" install --ignore-scripts --omit=dev --no-audit --no-fund"
    $npmExit = $LASTEXITCODE
    if ($npmExit -ne 0) {
        Write-Log "ERROR: npm install fallo con codigo: $npmExit" 'ERROR'
        Invoke-Rollback
        exit 7
    }
    Write-Log 'npm install completado correctamente' 'OK'
} else {
    Write-Log 'Skip npm install: bundle self-contained' 'OK'
}
```

**Mantener** las verificaciones de `bcryptjs` (líneas 333-338) y `node-firebird` (líneas 340-345) después del bloque — deben pasar en ambos caminos (self-contained o npm install).

### 5. `installer/installer.iss` — bump v2.0.11 + Opción B (con fallback autorizado a A)

**Cambios de versión (líneas 9, 16, 32):**
- `#define MyAppVersion "2.0.10"` → `"2.0.11"` (línea 9).
- `AppVerName={#MyAppName} v2.0.10 (build 2026-08-07)` → `v2.0.11 (build 2026-08-07)` (línea 16).
- `OutputBaseFilename=Valueflow-Setup-v2.0.10` → `Valueflow-Setup-v2.0.11` (línea 32).
- Actualizar comentarios header (líneas 1-6) a v2.0.11.

**Opción B (recomendación Frank: .exe compacto + bundle con node_modules):**

Implementación **Opción B-1 (definida por INTEGRA)** — la más fiel a Frank:
- MANTENER exclusión `node_modules\*` en línea 45 (el .exe NO empaqueta node_modules del working tree `..\middleware\`).
- Agregar el bundle.zip como asset del .exe:
  ```iss
  ; Bundle self-contained con node_modules pre-instalado (Opcion B: .exe compacto)
  Source: "..\dist-pkg\valueflow-middleware-v2.0.11.zip"; DestDir: "{app}\installer\assets"; Flags: ignoreversion
  ```
- En `install.ps1` (punto 4扩展): si no encuentra `node_modules` en `{app}\middleware`, buscar `valueflow-middleware-*.zip` en `{app}\installer\assets\`, descomprimir con `Expand-Archive` a un temp, localizar `middleware/` (carpeta raíz del zip: `valueflow-middleware-v2.0.11/middleware/`), copiar a `{app}\middleware` CON node_modules.
- Actualizar comentario de línea 43-45.

**FALLBACK AUTORIZADO a Opción A** (si B-1 choca):
- Si `Expand-Archive` en PS 5.1 tiene quirks (paths con espacios, codificación), o el manejo de la carpeta raíz del zip es frágil, SOFIA puede elegir **Opción A**: quitar `node_modules\*` de `Excludes` en línea 45. El .exe empaqueta `..\middleware\*` CON node_modules (~110 MB, self-contained puro). install.ps1 detecta node_modules en `{app}\middleware`, skip npm install, copia in-place.
- **Reportar cuál opción elegiste y por qué** (B-1 implementada, o A por fallback con justificación del quirk detectado).

### 6. `installer/VERSION` — bump a 2.0.11

- `MAJOR=2`, `MINOR=0`, `PATCH=11`.
- `prepare-dist-pkg.sh` lo lee y genera el bundle v2.0.11.

## Verificación E2E OBLIGATORIA (SOFIA ejecuta, NO delega a Frank)

1. **Generar bundle:** desde raíz del proyecto, `bash installer/prepare-dist-pkg.sh`. Verificar que crea `dist-pkg/valueflow-middleware-v2.0.11/` con `middleware/node_modules/` y `middleware/dist/index.js`.

2. **Sintaxis ecosystem.config.js** (debe parsear y NO contener `wait_ready`):
   ```bash
   node -e "const cfg=require('./dist-pkg/valueflow-middleware-v2.0.11/middleware/ecosystem.config.js'); const a=cfg.apps[0]; if(a.wait_ready!==undefined){console.error('FAIL: wait_ready presente');process.exit(1)} console.log('OK:',JSON.stringify({name:a.name,listen_timeout:a.listen_timeout,script:a.script},null,2))"
   ```

3. **package.json válido JSON:**
   ```bash
   node -e "console.log('OK name:', JSON.parse(require('fs').readFileSync('dist-pkg/valueflow-middleware-v2.0.11/middleware/package.json','utf8')).name)"
   ```

4. **dist/index.js sin requires de `.node` nativos:**
   ```bash
   if grep -r "\.node'" dist-pkg/valueflow-middleware-v2.0.11/middleware/dist/ 2>/dev/null; then echo "FAIL: .node nativos en dist"; else echo "OK: dist sin .node nativos"; fi
   ```
   (Si encuentra `.node`, reportar — bundle no portable.)

5. **node_modules pre-instalado, `npm ls` sin missing:**
   ```bash
   cd dist-pkg/valueflow-middleware-v2.0.11/middleware && npm ls --omit=dev 2>&1 | grep -iE "missing|ERR" && echo "FAIL: missing deps" || echo "OK: sin missing"
   ```

6. **Compilar .exe v2.0.11:**
   ```bash
   docker run --rm -v "$(pwd):/work" -w /work amake/innosetup:latest /opt/innosetup/ISCC.exe installer/installer.iss
   ```
   Si `docker` no está disponible o falla, reportar y dejar `.exe` pendiente (no es bloqueante para el bundle, pero reporta el comando intentado y el error).

7. **SHA256** del bundle y del .exe:
   ```bash
   sha256sum dist-pkg/valueflow-middleware-v2.0.11.zip
   sha256sum installer/build_output/Valueflow-Setup-v2.0.11.exe 2>/dev/null || echo ".exe no generado"
   ```

## Restricciones

- **NO commit, NO push, NO PR** (Frank no dio OK todavía).
- NO deploy, NO datos reales a PRD Siemens, NO secretos en logs.
- Trabajo local en `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens`.
- Si el F1 fix (quitar `wait_ready`) resulta insuficiente — p.ej. PM2 sigue marcando online prematuramente y necesitas `process.send('ready')` en `src/server.ts` tras `app.listen()` para robustez — **reporta y plantea la alternativa**, no la apliques sin consultar a INTEGA (toca código del middleware, requiere SPEC).

## Validaciones obligatorias antes de cerrar (self-review manual — Qodo está sunset)

1. ¿El código refleja la SPEC? (los 6 cambios aplicados)
2. ¿Hay code smells evidentes?
3. ¿Los edge cases (ambigüedad node-firebird JS puro vs native-api; Opción A vs B) están resueltos o reportados?
4. ¿Riesgo de regresión en el flujo de instalación (8 fixes previos IMPL-20260807-01) preservado?
5. `pnpm typecheck`/`tsc --noEmit` y `npm test` en `middleware/` (no se rompió nada del middleware al tocar ecosystem.config.js).

## Entregable — Reporte en este path

Escribe el reporte final en:
```
/mnt/Datos/Proyectos 2.0/PC/repaga-siemens/context/interconsultas/IMPL-20260807-03-reporte.md
```

Formato:
```
# IMPL-20260807-03 — REPORTE SOFIA

## Archivos modificados
- [lista con rutas relativas]

## Cambios aplicados
1. [✓/✗] ecosystem.config.js — quitar wait_ready
2. [✓/✗] prepare-dist-pkg.sh — pre-instalar node_modules
3. [✓/✗] prepare-dist-pkg.sh — fbclient.dll / baseline node-firebird (escenario a/b/c)
4. [✓/✗] install.ps1 — skip npm install si bundle trae node_modules
5. [✓/✗] installer.iss — bump v2.0.11 + Opción [B-1/A]
6. [✓/✗] VERSION — bump 2.0.11

## Baseline node-firebird (punto 3)
- package.json deps firebird: [qué encontraste]
- src/ imports firebird: [qué encontraste]
- FirebirdCS-2.5.0.26074-0.amd64/ contenido: [.dll Windows o .so Linux]
- Escenario: [a/b/c]
- Acción tomada: [qué hiciste]

## Opción installer.iss elegida
- [B-1 implementada | A por fallback (justifica el quirk de PS 5.1)]

## Validaciones
1. [✓/✗] Sintaxis ecosystem.config.js OK (sin wait_ready)
2. [✓/✗] package.json válido JSON
3. [✓/✗] dist/index.js sin requires de .node nativos
4. [✓/✗] node_modules pre-instalado en bundle (npm ls sin missing)
5. [✓/✗] .exe compila OK con nuevo tamaño [X MB]
6. [✓/✗] SHA256 bundle: [hash]
   [✓/✗] SHA256 .exe: [hash o "no generado, motivo"]

## Edge cases detectados
- [lista]

## Riesgos de regresión
- [lista]

## Estado
- [DONE-PENDING-REVIEW | BLOCKED]
- Si BLOCKED: motivo y qué falta
```

INTEGA leerá el reporte al cerrar tu sesión y auditará con GEMINI (subagent_type='gemini') como segunda mano de validación.
