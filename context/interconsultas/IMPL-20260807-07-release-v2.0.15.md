# IMPL-20260807-07 — Release v2.0.15

**ID:** IMPL-20260807-07
**Fecha:** 2026-08-07 18:10 CST
**Implementador:** SOFIA + ATLAS (sesion conjunta)
**Handoff origen:** `context/interconsultas/FIX-20260807-01-handoff.md` + IMPL-20260807-04

---

## 1. Resumen

Release v2.0.15 incluye **5 fixes acumulados** desde v2.0.10, ademas de nuevas funcionalidades de UI:

| Categoria | Cambios |
|---|---|
| **Bug fixes** | pm2 start cwd + polling puerto + $LASTEXITCODE + BOM UTF-8 + charset Firebird + FIREBIRD_PASSWORD lowercase |
| **Funcionalidad nueva** | Terminal en vivo SSE embebida en /actions, paleta corporativa Repaga, timestamps CDMX -06:00, test SAE muestra empresa BD |
| **Mejoras operativas** | Progreso por chunk en jobs, bus singleton para SSE compartido entre server y jobs |

## 2. FIXes incluidos (FIX-20260807-01 a FIX-20260807-18)

| ID | Titulo | Componente |
|---|---|---|
| FIX-20260807-01 | pm2 start cwd + polling puerto 4567 + $LASTEXITCODE | install.ps1 |
| FIX-20260807-02 | BOM UTF-8 tolerance + charset Firebird ISO8859_1 | env.ts, runtime.ts, db/firebird.ts |
| FIX-20260807-03 | FIREBIRD_PASSWORD default masterkey (lowercase) | install.ps1 |
| FIX-20260807-04 | node-firebird pool db.execute binding fix | db/firebird.js |
| FIX-20260807-05 | SSE stream + terminal embebida | logger/stream-bus.js, ui/server.js, ui/views/actions.html |
| FIX-20260807-06 | Paleta corporativa Repaga (#1f3a5f, #c8a04a, #3da0a8) | ui/views/layout.html, ui/views/actions.html |
| FIX-20260807-07 | Botones con colores corporativos | ui/server.js |
| FIX-20260807-08 | Test SAE muestra empresa BD + path + charset | db/firebird.js, ui/server.js |
| FIX-20260807-09 | testConnection retorna metadata util | db/firebird.js |
| FIX-20260807-10 | testConnection con charset explicito | db/firebird.js |
| FIX-20260807-11 | testConnection con query a PARAM01 (empresa) | db/firebird.js |
| FIX-20260807-12 | cstNow() helper timezone CDMX | logger/stream-bus.js |
| FIX-20260807-12b | cstNow() con offset ISO 8601 -06:00 | logger/stream-bus.js |
| FIX-20260807-13 | Emit progreso por chunk en jobs inventario/ventas | jobs/runInventory.js, jobs/runSales.js |
| FIX-20260807-14 | Stream-bus singleton global | logger/stream-bus.js |
| FIX-20260807-15 | Test SAE con HTML estilizado (panel verde/rojo) | ui/server.js |
| FIX-20260807-16 | runSalesJob busca ultima fecha con ventas | jobs/runSales.js |
| FIX-20260807-17 | E2E test: 5 ventas reales -> 201 Created | test_e2e_5v3.js |
| FIX-20260807-18 | Mojibake cleanup (acentos removidos) | ui/server.js |

## 3. Archivos modificados

### Codigo fuente (`src/`)
- `installer/install.ps1` (FIX-01, FIX-03)
- `middleware/src/config/env.ts` (FIX-02 BOM tolerance)
- `middleware/src/config/runtime.ts` (FIX-02 readJsonFile)
- `middleware/src/db/firebird.ts` (FIX-02, FIX-04, FIX-08 charset + empresa)

### Codigo compilado (`dist/`)
- `dist/logger/stream-bus.js` (FIX-12, FIX-12b, FIX-14)
- `dist/db/firebird.js` (FIX-04 pool binding, FIX-08, FIX-09, FIX-10, FIX-11)
- `dist/jobs/runInventory.js` (FIX-13 chunk emit)
- `dist/jobs/runSales.js` (FIX-13 chunk emit, FIX-16 latest date)
- `dist/ui/server.js` (FIX-05, FIX-07, FIX-15, FIX-18)
- `dist/ui/views/layout.html` (FIX-06 palette + Terminal link)
- `dist/ui/views/actions.html` (FIX-05 terminal embebida, FIX-06 palette)
- `dist/ui/views/terminal.html` (FIX-05 standalone terminal)

### Build / installer
- `installer/installer.iss` (bump v2.0.15 + bundle reference)
- `installer/VERSION` (PATCH=15)

### Bundle
- `dist-pkg/valueflow-middleware-v2.0.15.zip` (782 KB, regenerado desde dist/ actual)
- `installer/build_output/Valueflow-Setup-v2.0.15.exe` (73 MB)

## 4. Evidencia funcional

### E2E test (test_e2e_5v3.js)
```
=== E2E TEST: ultimas 5 ventas con linea Siemens ===
Lines obtained (ya filtradas): 5
[1] factura=CFDI_32700 linea=1 art=6SE64402UD230BA1 cant=1 prec=80218
[2] factura=CFDI_32700 linea=2 art=6SE64402UD230BA1 cant=1 prec=80218
[3] factura=CFDI_32699 linea=1 art=3SU11502BF603MA0 cant=1 prec=620.64
[4] factura=CFDI_32696 linea=1 art=3RT20261AK60 cant=3 prec=1411
[5] factura=CFDI_32695 linea=1 art=3SU11030AB401FA0 cant=6 prec=714
Payload entries: 5
=== Step 4: enviar a Siemens QUA ===
Response status=201
x-amzn-requestid=97ce37df-fa98-456d-98cb-777064c44e83
=== E2E EXITOSO: 5 entries OK ===
```

### Visual (screenshot de Frank)
- Header azul corporativo #1f3a5f
- Boton dorado Ejecutar Inventario/Ventas (#c8a04a)
- Boton aguamarina Test conexion Siemens (#3da0a8)
- Boton azul Test conexion SAE (#1f3a5f)
- Terminal embebida con timestamps CDMX (-06:00)
- Progreso por chunk visible: 3 batches, 8169 registros

### Inventario en vivo
```
[17:36:08] Inventory INFO Leyendo snapshot de productos desde Firebird...
[17:36:08] Inventory INFO Snapshot leido: 8169 productos raw
[17:36:09] Inventory INFO Productos transformados para Siemens: 8169
[17:36:09] Inventory INFO Enviando batch 1/3 (3000 registros)...
[17:36:16] Inventory OK Batch 1/3 OK (status=201, 3000 registros)
[17:36:16] Inventory INFO Enviando batch 2/3 (3000 registros)...
[17:36:21] Inventory OK Batch 2/3 OK (status=201, 3000 registros)
[17:36:21] Inventory INFO Enviando batch 3/3 (2169 registros)...
[17:36:29] Inventory OK Batch 3/3 OK (status=201, 2169 registros)
[17:36:29] Inventory OK Job de inventario completado: 8169 registros enviados en 21s
```

## 5. Validacion DoD

- [x] Sintaxis JS verificada (server.js, firebird.js OK)
- [x] Tests E2E ejecutados (5 ventas -> HTTP 201)
- [x] Visual validado por Frank (terminal + colores)
- [x] Mojibake eliminado (8 strings limpios en server.js)
- [x] Compilacion ISCC exitosa (12.1 seg, 0 errores)
- [x] Bundle regenerado desde dist/ actualizado

## 6. Pendientes (no bloquean go-live)

| ID | Descripcion | Severidad |
|---|---|---|
| B7 | unit_cost deberia usar COST real, no IMPU1 (IVA) | Media (datos incorrectos a Siemens) |
| Uninst-BOM | uninstall.bat tiene el mismo bug de BOM que install.ps1 | Baja |
| Rotacion-API | API key actual fue expuesta en chat/logs | Alta (rotar ASAP) |
| PRD-cred | Faltan credenciales PRD para go-live produccion | Bloqueante para prod |

## 7. Artefactos finales

| Archivo | SHA256 | Tamanio |
|---|---|---|
| `Valueflow-Setup-v2.0.15.exe` | `952A2196E8EAD5DAAAF74AC9FED6874F3DFB634154D26466EA4B1D46B230F7BE` | 73 MB (76664212 bytes) |
| `valueflow-middleware-v2.0.15.zip` | (regenerar SHA al commitear) | 782 KB (782762 bytes) |
| Path VM | `Z:\PC\repaga-siemens\installer\build_output\Valueflow-Setup-v2.0.15.exe` | |
| Path desktop | `C:\Users\frank\Desktop\Valueflow-Setup-v2.0.15.exe` | |

## 8. Como probar en Windows nativo de Frank

1. Copiar `Valueflow-Setup-v2.0.15.exe` a la PC Windows nativa
2. Doble click + aceptar UAC
3. Wizard: dejar path default `C:\apps\siemens-middleware`
4. FDB path: dejar default `C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB` (ajustar si difiere)
5. Esperar ~5 min instalacion
6. Validar:
   - Browser: http://localhost:4567 (login Admin / Admin123)
   - Colores corporativos en header
   - Botones con colores diferenciados
   - Click "Test conexion SAE" -> ver "Conexion SAE disponible" + empresa
   - Click "Ejecutar Inventario" -> ver progreso por batch en terminal
   - Timestamps CDMX con -06:00

## 9. Estado de commits

**NO commit/push/PR ejecutado** (regla INTEGRA: requiere OK explicito de Frank via ask-frank)

4 IMPL acumulados + 18 FIX sin commitear (v2.0.9, v2.0.10, v2.0.11, v2.0.12, v2.0.13, v2.0.14, v2.0.15)

**Pregunta para Frank:** ¿1 commit con todo o separados?

---

**Release v2.0.15 lista para pruebas en Windows nativo.** 🟢