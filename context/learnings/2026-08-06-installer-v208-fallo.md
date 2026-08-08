# Learning — Instalador Valueflow v2.0.8: fallo sistémico en VM Windows 11

**Fecha:** 2026-08-06
**Lote:** lote-ventas-20260805-01 (reactivado 2026-08-06T22:57-06:00)
**Tickets:** MR-20260806-01 (workaround), MR-20260806-02 (fix v2.0.9)
**Agente:** INTEGRA (actuando como CRONISTA — DOC-20260806-01)
**Decisión de Frank:** Plan A — workaround HOY (VM operativa) + fix v2.0.9 en paralelo como deuda técnica.

## Patrón detectado
El instalador v2.0.x falla en VM Windows 11 por **3 causas combinadas y encadenadas**:

1. **Path mismatch — 3 rutas distintas en el código:**
   - `installer/install.ps1` defaultea `C:\apps\siemens-middleware` (linea ~21).
   - `installer/installer.iss` usa `{autopf}\siemens-middleware` → resuelve a `C:\Program Files\siemens-middleware` (pide UAC, falla en cuentas no admin, y **no coincide** con lo que espera PM2).
   - `middleware/ecosystem.config.js` hardcodea `cwd: 'C:/apps/siemens-middleware/middleware'`.
   Resultado: el bundle se copia a una ruta, pero PM2 levanta la app desde otra → `dist/index.js` no se encuentra en el `cwd` real → proceso muere al instante.

2. **`dist/` no precompilado dentro del bundle:**
   `installer/prepare-dist-pkg.sh` zipea el middleware **sin ejecutar `npm run build`**. En una VM sin toolchain completo (o con el addon nativo `node-firebird-native-api` problemático de compilar), `dist/index.js` nunca se genera tras instalar. Confirmado: en el repo `middleware/dist/index.js` SÍ existe (build local del 16:52), pero ese dist no llega al bundle zipeado → el instalador entrega un middleware sin `dist/`.

3. **Slots zombi de PM2:**
   PM2 persiste la definición `siemens-middleware` con `script: dist/index.js` (inexistente en el `cwd` instalado). `pm2 restart` revive el zombi. `pm2 list` muestra `online` pero CPU 0 % + memoria baja + puerto 4567 cerrado. **Sin healthcheck**, PM2 nunca detecta que el proceso no sirve tráfico real.

## Decisión arquitectónica (v2.0.9 — delegada a SOFIA)
- **Unificar InstallDir canónico en `C:\apps\siemens-middleware\`** (evita UAC de `Program Files` y problemas con espacios). Mismo path en `install.ps1`, `installer.iss`, `ecosystem.config.js` (dinámico vía `__dirname`/`path.dirname`), `uninstall.bat`.
- **Precompilar `dist/` dentro del bundle:** `prepare-dist-pkg.sh` ejecuta `npm run build` antes de zippear; **aborta** la generación del bundle si el build falla.
- **Hacer `dist/` opcional en el instalador:** si el bundle lo trae, skip build (más rápido); si no, ejecutar `npm run build` con manejo de error explícito (exit 7 + rollback).
- **`.env` Windows-friendly:** `LOG_DIR` con ruta Windows (`C:\apps\siemens-middleware\logs`), `FIREBIRD_PASSWORD` con default `MASTERKEY` (nunca vacío) + log de warning explícito.
- **Healthcheck PM2 anti-zombi:** `wait_ready: true` + `health_check` contra `http://localhost:4567/health` → PM2 marca `online` solo cuando el servicio responde tráfico.

## Workaround aplicado HOY (MR-20260806-01)
Mientras se fixea v2.0.9, el servicio queda operativo levantándolo **directamente desde `C:\Users\frank\Downloads\valueflow-middleware\middleware`** con un `ecosystem.config.js` ad-hoc apuntando a esa ruta + `.env` local. Saltea el instalador roto. No es producción-ready (deps viven en Downloads, no en `C:\apps\`), pero deja al cliente probar la UI HOY con `Admin/Admin123`.

## Pendiente
- [ ] SOFIA aplica fix v2.0.9 (IMPL-20260806-01-sofia) — en marcha (sesión `am-1786079068352-yb6491`).
- [ ] Regenerar bundle con `dist/` precompilado y validar que `dist/index.js` existe dentro del zip.
- [ ] Compilar instalable `.exe` con Inno Setup (Docker) y calcular SHA256 del nuevo artefacto.
- [ ] Validar en VM limpia (no en Downloads) que el instalador v2.0.9 deja el servicio up sin pasos manuales.

## Nota canónica (§15 INTEGRA)
`PROYECTO.md` aún usa términos no canónicos heredados (`✅ DONE`, `[x] Completado`, `[ ] Pendiente`, `🟡 WORKAROUND`, `⏳ EN PROGRESO`). No se migraron en esta pasada (fuera del alcance del CRONISTA solicitado). Queda como follow-up de una sesión CRONISTA de auditoría de consistencia completa.

## Referencias
- `PROYECTO.md` → "Estado del lote lote-ventas-20260805-01" (tabla) + "Autorizaciones autónomas vigentes".
- SPEC delegada a SOFIA vía Agent Manager (sesión `am-1786079068352-yb6491`).
- Diagnóstico previo y handoff: sesión ATLAS `ses_025740aecffesutNHhsS1dqkWu`.
