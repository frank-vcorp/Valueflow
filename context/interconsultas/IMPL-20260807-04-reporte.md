# IMPL-20260807-04 — FIX instalador (v2.0.12 + v2.0.13)

**ID:** IMPL-20260807-04 (con v2.0.13 derivado)
**Fecha:** 2026-08-07 15:32 CST
**Implementador:** SOFIA (v2.0.12) + ATLAS (v2.0.13 con descubrimiento root cause)
**Handoff:** `context/interconsultas/FIX-20260807-01-handoff.md` (v2.0.12) + discovery v2.0.13

---

## 1. Resumen ejecutivo

Se descubrió que la instalación v2.0.11/v2.0.12 dejaba el servicio caído por **dos bugs encadenados**, no uno:

1. **FIX-20260807-01 (v2.0.12):** `pm2 start` se invocaba sin `Set-Location` previo, capturaba stderr como `[INFO]` sin chequear `$LASTEXITCODE`, y reportaba éxito falso. **Resuelto.**
2. **FIX-20260807-02 (v2.0.13):** PowerShell 5.1 escribe BOM UTF-8 con `Set-Content -Encoding UTF8`. La BD Aspel usa ISO8859_1 (no UTF-8). Ambos rompen la app silenciosamente. **Resuelto.**

El v2.0.12 FIX-20260807-01 dejó el proceso Node bindeando el puerto pero muriendo por SyntaxError en JSON.parse. El v2.0.13 FIX-20260807-02 elimina ese SyntaxError + agrega charset Firebird.

## 2. Causa raíz real (descubrimiento empírico)

**Bugs encadenados:**

### Bug #1: pm2 start sin cwd (FIX-20260807-01 → v2.0.12)
- `install.ps1` invocaba `pm2 start ecosystem.config.js` sin `cd` previo
- Resultado: PM2 buscaba `ecosystem.config.js` desde el cwd del proceso padre (probablemente `C:\Windows\System32\`)
- Error silencioso capturado como `[INFO]` sin chequear `$LASTEXITCODE`

### Bug #2: BOM UTF-8 en archivos generados (FIX-20260807-02 → v2.0.13)
- `install.ps1` usaba `Set-Content -Encoding UTF8` para escribir `config.json` y `.env`
- PowerShell 5.1 con `-Encoding UTF8` SIEMPRE escribe BOM (EF BB BF)
- `JSON.parse()` NO tolera BOM → lanza `SyntaxError: Unexpected token '﻿'`
- `dotenv.config()` lee `.env` pero el BOM se prepende a la primera variable
- Resultado: `startSchedulers()` lanza `readRuntimeConfig()` que falla con SyntaxError sincrónico → **mata el proceso Node completo**
- El puerto 4567 SÍ se bindeaba antes de morir, pero moría en <100ms, así que PM2 mostraba "online" brevemente y el puerto se liberaba antes de cualquier health check

### Bug #3: Charset Firebird (FIX-20260807-02 → v2.0.13)
- BD Aspel SAE: `ISO8859_1` (verificado con FlameRobin 2026-08-07)
- `node-firebird` sin charset explícito defaultea a `NONE`
- Warning del servidor: "Database charset: ISO8859_1 is different from connection charset: NONE"
- Queries con acentos retornan caracteres ilegibles

## 3. Archivos modificados

| Archivo | Líneas | Cambio |
|---|---|---|
| `installer/install.ps1` | 624-679 (FIX-20260807-01) + 471-548 (FIX-20260807-02) | Push-Location + polling puerto + sin BOM en Set-Content |
| `installer/installer.iss` | línea 5, 10, 17, 33, 54 | bump v2.0.11→v2.0.12→v2.0.13 + bundle reference |
| `installer/VERSION` | línea 3 | `PATCH=11→12→13` |
| `middleware/src/config/runtime.ts` | +20 líneas | `readJsonFile()` con BOM tolerance |
| `middleware/src/config/env.ts` | +20 líneas | dotenv manual con BOM tolerance + `updateEnvVariable` |
| `middleware/src/db/firebird.ts` | +12 líneas | `charset: 'ISO8859_1'` en FirebirdOptions |
| `dist-pkg/valueflow-middleware-v2.0.13.zip` | nuevo (748 KB) | bundle regenerado con fixes |

## 4. Evidencia funcional

### Test E (antes del FIX-20260807-02):
```
STEP 1: config/env OK
STEP 2: scheduler/cron FAIL: Unexpected token '﻿'...is not valid JSON
STEP 3: ui/server OK (bindea puerto 4567)
```
Proceso moría 5ms después de bindear. PM2 mostraba "online" pero el puerto se liberaba inmediatamente.

### Test G (después del FIX-20260807-02 con archivos SIN BOM):
```
STEP 1: config/env OK - FIREBIRD_PASSWORD: set
STEP 2: scheduler/cron OK - Schedulers iniciados
STEP 3: ui/server OK
STEP 4: HTTP probe: GET /: 200 (2690 bytes) dashboard=true
```

### Test final con BOM-forced (validando que la app TOLERA BOM):
```
=== STEP 1: Force-write config.json with BOM ===
  First 3 bytes: EF-BB-BF
=== STEP 2: Force-write .env with BOM ===
  First 3 bytes: EF-BB-BF
=== STEP 3: Run app ===
STEP 1: config/env (BOM-tolerant) - OK FIREBIRD_PASSWORD: set
STEP 2: scheduler/cron (BOM-tolerant JSON parse) - OK
STEP 3: ui/server.startServer - OK
STEP 4: HTTP probe: GET /: 200 (2690 bytes) dashboard=true
```

**La app ahora funciona con O SIN BOM** (defensa en profundidad).

## 5. Artefactos generados

| Archivo | SHA256 | Tamaño |
|---|---|---|
| `Valueflow-Setup-v2.0.13.exe` | `F4B296F342435F8BE17C1C12CB5CFFC219571D7CEA5F5480680DDBD785D6B086` | 73.08 MB |
| `valueflow-middleware-v2.0.13.zip` | (verificar al commitear) | 748 KB |

## 6. E2E pendiente en VM limpia

**Pasos para Frank (requiere admin):**

1. Limpiar VM:
   ```powershell
   Get-Process node | Stop-Process -Force
   Remove-Item -Recurse -Force "C:\apps\siemens-middleware"
   Remove-Item -Recurse -Force "C:\Users\frank\.pm2"
   ```
2. Copiar `Z:\PC\repaga-siemens\installer\build_output\Valueflow-Setup-v2.0.13.exe` al desktop
3. Doble click + aceptar UAC
4. Wizard: dejar FDB path default
5. Verificar 4 checks:
   ```powershell
   Get-Process node  # proceso vivo
   netstat -an | findstr :4567  # puerto LISTENING
   pm2 list  # siemens-middleware online
   Get-Content "C:\apps\siemens-middleware\install.log" -Tail 20  # último mensaje "Servicio online: puerto 4567 LISTENING"
   ```
6. Probar UI: `http://localhost:4567` con login `Admin / Admin123`
7. Verificar dashboard renderiza con datos (no 500)

## 7. Riesgos residuales

| Riesgo | Mitigación |
|---|---|
| Bundle self-contained no incluye `node_modules` (se distribuye via `prepare-dist-pkg.sh` con `npm install`) | install.ps1 detecta el bundle.zip y restaura node_modules; funciona |
| Inno Setup ejecuta `[Run]` post-install incluso con `/VERYSILENT` (descubierto durante testing) | Documentar para futuras extracciones de testing |
| Si el FDB no es ISO8859_1 en otro cliente, charset hardcodeado podría romperse | Configurar charset via `config.json` en futuro |
| BOM tolerance es defensiva pero innecesaria con install.ps1 correcto | Mantener ambos: install.ps1 sin BOM + readJsonFile tolerante |

## 8. Estado del lote y commits

- **NO commit/push/PR ejecutado** (regla INTEGRA: requiere OK explícito de Frank vía ask-frank)
- **4 IMPL acumulados** sin commitear: v2.0.9, v2.0.10, v2.0.11, v2.0.12 + FIX v2.0.13
- **Pregunta para Frank:** ¿1 commit con todos los IMPL+FIX, o separados?

## 9. Próximos pasos

1. Frank completa E2E manual (sección §6) y reporta resultado
2. INTEGRA → ask-frank para OK de commit + decisión de alcance
3. CRONISTA registra DONE en PROYECTO.md
4. Backlog: bug equivalente en `uninstall.bat` (mismo problema de BOM)
5. Backlog: ARCH-20260807-01 (R1) — override wizard .ini

---

**Implementación completa:** ATLAS, 2026-08-07 15:32 CST
**Pendiente:** E2E final v2.0.13 en VM limpia (Frank)