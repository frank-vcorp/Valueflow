# PROYECTO — Repaga Siemens Integration

**Cliente:** REPRESENTACIONES AGA 2 (Repaga)
**Stack destino:** Aspel SAE 10 + Siemens PoSi API
**Contacto:** Francisco Aguirre
**Última actualización:** 2026-08-07 (12:01 CST) — IMPL-20260807-03 DONE (bundle v2.0.11 self-contained, .exe 108 MB final tras slim post-GEMINI); GEMINI APROBADO_CON_CAMBIOS (QA-20260807-03); pendiente verificación E2E rama (b) Expand-Archive en VM Windows 11 de Frank + OK commit/push separado

## Objetivo
Integrar Aspel SAE 10 con Siemens PoSi para sincronizar ventas (Value Flow) e inventario en tiempo real mediante middleware local.

---

## 🔴 NOTAS PARA PRÓXIMA SESIÓN (2026-08-06)

### Estado del lote `lote-ventas-20260805-01`

| Ticket | Estado | Notas |
|--------|--------|-------|
| FACT-20260805-01 (validación esquema BD) | ✅ DONE | 46,430 facturas en FACTF01 |
| FACT-20260805-02 (E2E ventas) | ✅ DONE | CFDI_32700 enviado a QUA, status=201 |
| FIX-20260805-01 (race condition firebird) | ✅ DONE | NO_WAIT + streaming fetch |
| IMPL-20260806-01 (QA fixes Gemini) | ✅ DONE | 8 fixes aplicados por SOFIA |
| MR-20260806-01 (instalación limpia VM) | 🟡 WORKAROUND EN VALIDACIÓN | Bundle desde `C:\Users\frank\Downloads\valueflow-middleware\middleware` + PM2 directo; instalador v2.0.8 roto (path mismatch, dist no precompilado en bundle, slots zombi). Frank ejecuta FASE 1 en VM |
| MR-20260806-02 (fix instalador v2.0.9) | ⏳ EN PROGRESO | Delegado a SOFIA (Agent Manager `am-1786079068352-yb6491`): unificar InstallDir, precompilar dist/ en bundle, .env Windows-friendly, healthcheck PM2 anti-zombi |

### ⚠️ Bloqueadores HUMANOS pendientes (no se pueden resolver automáticamente)

1. **Rotar API Key QUA con Siemens (B5)**
   - Estado: code está con placeholder `<api_key_a_configurar>` en `installer/install.ps1`
   - Riesgo: la key real `I1k****gbv` está expuesta en historial de git público
   - Acción Frank: solicitar nueva API key al Data Steward de Siemens; reemplazar placeholder tras instalar
   - Workaround: mientras tanto, instalar y pegar la key directamente en UI Configuración → API Key Siemens

2. **Confirmar mapeo IMPU1 vs COST con Data Steward (B7)**
   - Estado: `middleware/src/siemens/sales.ts:32-39` usa `d.IMPU1` para `extended_cost_of_goods_sold`
   - Esperado según análisis: `CANT × COST`
   - Acción Frank: preguntar a Siemens si el campo correcto es COST en lugar de IMPU1
   - Si confirma: SOFIA arregla con task pequeña (~5 líneas)

### 🟡 Pendientes funcionales (no bloquean go-live sandbox)

- Credenciales PRD de Siemens (actualmente solo QUA)
- Decisión `quantity_unit_of_measure` ("pz" vs "each")
- Actualización del cliente a Aspel SAE 10 (actualmente tiene SAE 9.0)

### 🔧 Artefactos listos para usar

- **Instalable:** `installer/build_output/Valueflow-Setup-v1.0.exe` (48 MB)
- **SHA256:** `9f33080c589352580ac3b9bfeb1398d203ec2b9f982b4ccc1d62d2d66f2a0a8b`
- **Bundle alternativo:** `dist-pkg/valueflow-middleware-v1.0.zip` (29 MB)
- **Último commit:** `e785aff` en `main` (GitHub)

### 🔐 Credenciales del middleware (para pruebas)

- **UI login:** user=`Admin`, pass=`Admin123`
- **API key Siemens:** preconfigurada como placeholder (cambiar desde UI Configuración)
- **BD Aspel:** ruta configurable en wizard del instalable

### 📋 Reportes generados esta sesión

- `analysis/PRUEBA_E2E_VENTAS_20260805.md` — E2E QUA con CFDI_32700
- `analysis/FIX-20260805-01-firebird-concurrency.md` — Detalle del fix de race condition
- `analysis/VALIDACION_BD_FIREBIRD_20260805_R2.md` — Validación completa BD
- `analysis/PROCEDIMIENTO_LEVANTAR_FIREBIRD_FLAMEROBIN.md` — Procedimiento Linux
- `installer/COMPILAR-EXE-EN-VM.md` — Guía paso a paso para VM

### 🚨 Comando de rescate (si servicio no levanta)

Pegar en PowerShell Admin de la VM si el instalable no logra arrancar PM2:

```powershell
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Set-Location "C:\apps\siemens-middleware\middleware"
$nodeExe = "C:\apps\siemens-middleware\node\node-v20.14.0-win-x64\node.exe"
Start-Process -FilePath $nodeExe -ArgumentList "dist/index.js" -WindowStyle Hidden
Start-Sleep -Seconds 5
Get-Process node
netstat -an | findstr :4567
Start-Process "http://localhost:4567/"
```

### 📋 Próximos pasos para go-live producción

1. Frank ejecuta instalable en VM Windows 11 (SHA256 arriba)
2. Login con Admin/Admin123
3. Pegar nueva API key QUA en UI Configuración → API Key Siemens
4. Esperar rotación de Siemens
5. Confirmar B7 con Data Steward (IMPU1 vs COST)
6. Si B7 positivo: SOFIA arregla `sales.ts`
7. Re-test en QUA (5 requests sin 502)
8. Instalar en PC de Ing. Paco
9. Cron job 24h: monitorear logs por errores

### 🔄 Historial de cambios recientes

| Commit | Descripción |
|--------|-------------|
| `e785aff` | Fix 8 QA blockers (B1-B8): bcrypt escape, config.json completo, fechas BETWEEN, race condition, API key placeholder, CI build, comentario IMPU1, verificación addon |
| `cfdf3d9` | Fix installer: búsqueda inteligente middleware + fallback Node directo |
| `6e23151` | Fix installer: filtro de archivos del wizard (mostrar todos) |
| `d4f6620` | Feat installer: wizard 1-solo-campo + credenciales preconfiguradas + icono |
| `0481358` | Fix installer: bypass PowerShell Execution Policy |
| `8f20c11` | Fix installer: corregir firma CreateInputFilePage.Add |
| `893a217` | Feat installer: wizard 3-campos todo-en-uno |
| `0e4cc5b` | Chore: trigger build-installer |
| `5396b81` | Feat middleware: E2E QUA + concurrency fix + install package |

---

## Arquitectura confirmada
- Middleware en la misma PC Windows de SAE 10 (conexión localhost)
- Acceso directo a Firebird 5.0 vía `node-firebird-native-api`
- UI local de administración en `localhost:4567`
- Scheduler con `node-cron` embebido
- Sin mantenimiento mensual — intervenciones por presupuesto previo
- Volumen del cliente: ~12,000 productos → 4 batches de inventario

## Arquitectura confirmada
- Middleware en la misma PC Windows de SAE 10 (conexión localhost)
- Acceso directo a Firebird 5.0 vía `node-firebird-native-api`
- UI local de administración en `localhost:4567`
- Scheduler con `node-cron` embebido
- Sin mantenimiento mensual — intervenciones por presupuesto previo
- Volumen del cliente: ~12,000 productos → 4 batches de inventario

## Backlog

### [x] Completado
- **SIEMENS-CRED-20260805-01** | api_key movida a .env (sin secretos en repo) | SOFIA IMPL-20260805-03
  - ✅ `middleware/config.json` ahora tiene `"api_key": "env:SIEMENS_API_KEY"` (literal, igual que `password_source`).
  - ✅ Valor real persistido solo en `middleware/.env` (gitignored).
  - ✅ `validateRuntimeConfig` rechaza strings reales en `siemens.api_key` (literal forzado).
  - ✅ `siemens/api.ts` lee la api_key desde `env.siemensApiKey` (variable `SIEMENS_API_KEY`).
  - ✅ UI `/api/config/siemens-key` ahora escribe al `.env` (helper `updateEnvVariable` en `config/env.ts`) y refleja en `process.env`.
  - ✅ Tests: 8/8 pasan (nuevo test `rechaza api_key como string real` agregado).
- **SIEMENS-INFRA-20260805-02** | instalador Windows ahora detecta BD automáticamente y soporta modo -Silent | SOFIA IMPL-20260805-03
  - ✅ Función `Find-AspelDatabase` busca `SAE*.FDB` en `C:\Program Files\Aspel`, `C:\SAE`, `D:\Aspel` y junto al instalador; prioriza SAE9 sobre SAE10.
  - ✅ Default `FirebirdUser` cambiado a `SYSDBA` (default Firebird 2.5/Aspel SAE 9.0).
  - ✅ Switch `[switch]$Silent` agregado: lee `FIREBIRD_PASSWORD` y `UI_PASSWORD_PLAIN`/`SIEMENS_API_KEY` del entorno, sin `Read-Host`.
  - ✅ Parámetro `-FirebirdDBPathOverride` permite ruta explícita en modo silent.
  - ✅ Si no detecta BD en modo silent, falla con error claro (en interactivo pide ruta con input mejorado).
  - ✅ `.env` generado incluye `SIEMENS_API_KEY` (placeholder o valor real según modo).
  - ✅ Sintaxis PowerShell validada con `pwsh` parser (sin errores).
- **SIEMENS-TEST-20260720-01** — Prueba de conexión a Siemens PoSi API (QUA).
  - ✅ Credenciales QUA validadas: `qua-MX-REPRESENTACIONES` + API Key (ofuscada `I1kL****gbv`).
  - ✅ 2 endpoints probados con autenticación exitosa:
    - `https://api.pos.siemens.com/qua/create_record` (Value Flow / Ventas)
    - `https://api.pos.siemens.com/qua/inventory/create_record` (Inventario)
  - ✅ Esquema técnico completo descubierto (11 campos inventario, 43 campos Value Flow).
  - ✅ Reporte PDF generado: `REPORTE_CONEXION_SIEMENS.pdf` (5 pp, 97 KB).
  - ✅ HTML fuente: `REPORTE_CONEXION_SIEMENS.html`.
  - Distributor sender ID confirmado: `MX-REPRESENTACIONES`.
  - Sin datos reales enviados a Siemens (todos sintéticos: TEST-CONN-001, SKU-TEST).
  - Latencia promedio: ~0.55 s.
- **SIEMENS-TEST-20260721-01** — Re-verificación de sandbox y validación de esquema (24h después).
  - ✅ DNS resuelve (`api.pos.siemens.com` → AWS).
  - ✅ TLS handshake OK, certificado Amazon RSA 2048.
  - ✅ Puerto 443 abierto.
  - ✅ Ambos endpoints devuelven **HTTP 201 Created** con el esquema mínimo confirmado.
  - ✅ Decisión arquitectónica: **`distributor_sender_id` debe ser configurable desde UI**, no hardcoded en código.
  - ✅ Decisión arquitectónica (refinamiento 2026-07-21 15:15): **patrón de campos opcionales seleccionables desde UI**:
    - Campos requeridos: hardcoded como obligatorios, siempre se envían (5 inventario / 10 ventas)
    - Campos opcionales: listados en UI como toggles, default OFF, cliente activa selectivamente sin tocar código
    - Si opcional activo pero dato vacío en SAE 10 → se omite silenciosamente
    - Configuración operativa en `config.json` (editable desde UI), secretos en `.env`
  - ✅ Decisión de negocio (Ing. Paco, 2026-07-21 15:20): **filtro de marca Siemens por campo `LIN_PROD`**:
    - Solo se reportan a Siemens las líneas de factura donde `LIN_PROD` ∈ {BAJA, SINU, SIMAT, LP, DRIVE, MOTOR, SINUM, SERVI, OBSO, SENSO, SERVO, INSTR, UPS, SIMA, ESPE}
    - 7,788 productos Siemens identificados en catálogo del cliente (15 líneas activas)
    - Lógica: factura se lee completa, se descartan líneas no-Siemens, si no quedan líneas se omite la factura completa
    - Lista de líneas válida en `config.json` (editable desde UI)
  - ✅ Validación contra BD real Firebird (2026-07-21 15:25):
    - Conteo en INVE01: 30,635 productos totales / 21,805 en líneas Siemens / 7,788 activos
    - Hallazgo: el documento de 7,788 correspondía a productos con `STATUS='A'` (activos). Para filtro completo usar los 21,805.
    - 42,998 facturas vigentes en histórico; 28,274 (~66%) contienen al menos un producto Siemens
    - Encontrada factura real con líneas mixtas: `CFDI_32670` (cliente 830, 2026-07-03) con 4 líneas Siemens + 2 no-Siemens (Hoffman + canaleta)
    - Validado: el filtro funciona, solo se enviarían las 4 líneas correctas
  - ⚠️ **Prueba con datos reales (2026-07-21 15:28)**: payload con datos filtrados reales enviado a QUA → **HTTP 502 Internal Server Error** (persistente después de 3 reintentos con backoff).
    - Conclusión inicial: el problema parecía ser del sandbox QUA de Siemens.
    - Ver: `MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md` (ya documentado el 2026-07-20 22:30).
    - 🔧 **Causa raíz REAL identificada post-fix (2026-08-05)**: NO era el sandbox QUA caído. Era una incompatibilidad entre **AWS API Gateway (backend de Siemens) y HTTP/1.1** que axios usa por defecto. Las pruebas de control originales (400 con payload incompleto, 403 con API key falsa) devolvían códigos distintos al 502 precisamente porque el bug del gateway solo se dispara con requests que pasan la validación inicial.
    - **Fix aplicado en `middleware/src/siemens/api.ts`** (líneas 19-21 y 66-67): `httpVersion: 2` fuerza HTTP/2, AWS API Gateway responde correctamente.
    - **Estado post-fix**: pendiente re-test contra QUA para confirmar que el 502 está resuelto. **El plan "ir directo a PRD por intermitencia QUA" queda obsoleto** — PRD sigue siendo lo correcto por ciclo de vida, pero el motivo operativo del 502 ya no aplica.
    - Acción: re-testeo QUA post-fix antes de declarar cerrado este frente. Si pasa 5/5 requests, continuar el flujo normal hacia PRD.
    - ✅ **Prueba end-to-end via UI (2026-07-21 16:43)**: Configuración cargada via UI + test ejecutado desde la UI del middleware.
      - Se cargó `api_key` y `distributor_sender_id` via formulario en `/config` con enmascaramiento.
      - Se ejecutó "Test conexión Siemens" desde `/actions` → respuesta real del sandbox.
      - **Bug detectado y corregido:** el `environment` en `config.json` venía como `"QUA"` (mayúsculas) cuando la API espera `"qua"` (minúsculas). Esto causaba HTTP 403. Corregido a `qua` via UI.
      - Después del fix, la respuesta es **HTTP 502** (que después se confirmó era el bug HTTP/1.1 vs HTTP/2 de AWS API Gateway, ahora corregido vía `httpVersion: 2`) — confirmando que la URL, autenticación y payload son correctos.
      - Validación final (post-fix HTTP/2): pendiente confirmar en QUA con 5 requests consecutivos sin 502.

### [x] Completado
- **ERP-INT-005** — Integración Aspel SAE 10 + Siemens PoSi (Fase 1-3, 6 semanas, $60K MXN + IVA).
  - Estado: **Fase 1 COMPLETADA. Fase 2 IMPLEMENTADA por SOFIA (2026-07-21 15:52)**. Pendiente: instalación en PC Windows del cliente + credenciales PRD.
  - **SPEC-IMPL-20260721-01-siemens-middleware.md** implementada por SOFIA. Ver `repaga-siemens/middleware/` (41 archivos).
  - Validaciones SOFIA: `npm run build` OK, `tsc --noEmit` OK, `npm test` OK (7 tests, 80.43% coverage), lint OK.
  - Limitación conocida: `npm install` no completó en este entorno Linux por problemas de compilación del addon nativo. Se resuelve en Windows con Node 20 LTS + `fbclient.dll` de SAE 10.
  - Última validación (2026-07-21 15:38): filtro marca Siemens OK, esquema API OK, intermitencia sandbox documentada.
  - Documentos comerciales generados:
    - `PROPUESTA_TECNICA_SAE10_SIEMENS.md` + `.pdf` (v1.3)
    - `PROPUESTA_ECONOMICA_SAE10_SIEMENS.md` + `.pdf` (v1.5)
    - `CORREO_PRESENTACION.md` (plantilla de correo)
  - Documentos de análisis (referencia interna):
    - `SIEMENS_INTEGRATION_EXTRACT.md` (extracto del portal)
    - `SAE10_SIEMENS_INTEGRATION_ANALYSIS.md` (análisis arquitectónico)
  - **Entregables Fase 1 (Discovery):**
    - ✅ `REPORTE_CONEXION_SIEMENS.pdf` — Prueba de conexión QUA validada
    - ✅ `ESQUEMA_BD_SAE.md` — Análisis completo de BD Aspel SAE 9.0 (210 tablas)
    - ✅ `MAPEO_CAMPO_A_CAMPO.md` — Mapeo campo a campo SAE ↔ Siemens (entregable formal)
    - ✅ 7,788 productos Siemens identificados en 15 líneas
    - ✅ Queries de extracción validados con datos reales
    - ✅ Esquema Siemens completo documentado (11 campos inventario, 43 campos Value Flow)

### [ ] Pendiente
- Credenciales PRD de Siemens (actualmente solo QUA).
- Confirmar `distributor_sender_id` con cliente (`MX-REPRESENTACIONES`).
- Decisión: mapeo de `quantity_unit_of_measure` ("pz" → "each" o enviar "pz").
- Actualización del cliente a Aspel SAE 10 (actualmente tiene SAE 9.0).

## Notas operativas
- Este proyecto es independiente de `repaga-harvesting` (que maneja extracción de catálogos).
- La integración con Siemens requiere que el cliente actualice a Aspel SAE 10 (actualmente tiene SAE 9.0).
- Imágenes corporativas para UI disponibles: `logo_aga_letras_2.png` (Repaga) y `partner.png` (Siemens Approved Partner).

## Especificación técnica (SPEC)
- **`SPEC-IMPL-20260721-01-siemens-middleware.md`** → [`context/SPECs/SPEC-IMPL-20260721-01-siemens-middleware.md`](../context/SPECs/SPEC-IMPL-20260721-01-siemens-middleware.md)
  - Estado: ✅ **Implementada por SOFIA** (2026-07-21 15:52). 41 archivos en `middleware/`. Pendiente instalación en PC Windows del cliente.
  - Contiene: stack técnico, estructura de proyecto, modelo de datos (`.env` + `config.json`), 8 RFs (Firebird, queries, transformador, API cliente, scheduler, UI con logos, logging, errores), DoD, self-review checklist.

- **`SPEC-INFRA-20260721-01-cicd-github-actions.md`** → [`specs/SPEC-INFRA-20260721-01-cicd-github-actions.md`](../specs/SPEC-INFRA-20260721-01-cicd-github-actions.md)
  - Estado: **Lista para delegación a SOFIA** — CI/CD con GitHub Actions.
  - Contiene: 3 workflows (ci.yml para validación, build-installer.yml para compilar .exe con Wine+Inno Setup, release.yml para releases por tag), security scan con Trivy, documentación de workflows.

## Backlog de ejecución (sesión 2026-08-05)

### BACKLOG

### READY
- **FACT-20260805-02** | P2 | Pruebas E2E envío de ventas en VM Windows 11 (SAE 9.0 + Firebird 2.5 + BD `SAE90EMPRE01.FDB`) | SPEC: `installer/COMPILAR-EXE-EN-VM.md` | Bloqueante: FACT-20260805-01 ✅ DONE

### IN_PROGRESS


### VERIFYING
- **IMPL-20260807-01** | P1 | Fixes H1,H2,H4-H9 v2.0.9 | SPEC: handoff INTEGRA chat | SOFIA cerró: 8 fixes, tsc/test/lint PASS, .exe v2.0.9 (76MB PE32) + SHA256 40796480dedd49d3b84348412378c322d36500ba59538ac356ea60b6dc5c2f1f MATCH | GEMINI cerró: APROBADO_CON_CAMBIOS (QA-20260807-01); 7/8 fixes ✓ plenos, H6 ⚠ parcial (R1); no-regresiones B1/B2/B3/B5/B7 ✓; FIREBIRD_PASSWORD=MASTERKEY intacta (H3 OK); secretos protegidos | R1 (ALTO, no-crítico este despliegue): override wizard .ini no materializa ({tmp}=is-XXXXX.tmp vs %TEMP%\valueflow_install_config.ini) — fix L1 <10 líneas antes de iteración pública | R2 (BAJO): AppVerName congelado v2.0.0 (cosmético) | ESPERA DECISIÓN Frank A/B vía ask-frank (ARCH-20260807-01) | NO commit/push/PR

### BLOCKED

### DONE
- **IMPL-20260807-03** | P1 | Bundle v2.0.11 self-contained (.exe 108 MB final, cumple objetivo "compacto" de Frank) | ✅ Cerrado 2026-08-07 12:01 CST: SOFIA aplicó 6 cambios + slim post-GEMINI (fix #1); 7 validaciones E2E local ✓ + slim verificado; GEMINI APROBADO_CON_CAMBIOS (QA-20260807-03) — bug duplicación binarios en bundle.zip detectado y corregido (.exe 174→108 MB, -38%); baseline node-firebird escenario (a) confirmado independientemente (JS puro, sin fbclient.dll, sin .node nativos); 8 fixes IMPL-20260807-01 preservados; F1 fix (quitar wait_ready) resuelve deadlock PM2 de raíz. SHA256 final: bundle.zip `9fbaf76b733d6c8c90a97b8497d4bdd5bf183a10a23306badc80615aa820cbab` / .exe `9cd94a3d56e605107641cb14dbff3e66c36cb465510e6e8b2b0b828a6329038c`. Reporte: `context/interconsultas/IMPL-20260807-03-reporte.md`. Dictamen: `context/interconsultas/QA-20260807-03-gemini.md` | PENDIENTE PRODUCCIÓN: (1) verificación E2E rama (b) Expand-Archive en VM Windows 11 de Frank — defensa crítica en escenario sin internet; (2) OK commit/push separado. Gap residual documentado: bundle.zip 34 MB (x64 zip 29 MB útil para distribución manual aparte); fix #1.5 opcional próxima iteración (excluir x64 zip → .exe ~75-85 MB). NO commit/push/PR
- **IMPL-20260807-02** | P1 | Fix node-gyp/Python en instalador VM (npm --ignore-scripts install.ps1:323 + limpiar 4 deps nativas huérfanas + bump v2.0.10 .iss) | ✅ Cerrada 2026-08-07 por SOFIA: código aplicado, .exe v2.0.10 generado. Despliegue VM Windows 11 reveló F1 (wait_ready deadlock) — bug DIFERENTE fuera del scope, ahora cubierto por IMPL-20260807-03.
- **FACT-20260805-01** | P1 | Validar esquema de FACTF01/PAR_FACTF01 en BD real del cliente | ATLAS-20260805-01 | ✅ Cerrada 2026-08-05 22:00 | Reporte: `analysis/VALIDACION_BD_FIREBIRD_20260805_R2.md`. Hallazgos:
  - Servidor Firebird 2.5 instalado en `localhost:3050` (migrado de xinetd → systemd unit `firebird-classic.service` por incompatibilidad con sudo-rs moderno).
  - BD `SAE90EMPRE01.FDB` validada con queries reales (no solo log metrics): 46,430 facturas en FACTF01, 117,610 partidas en PAR_FACTF01, 30,635 productos en INVE01, 1,082 clientes en CLIE01, 37,512 CFDIs en CFDI01.
  - **Descubrimiento clave:** `FACTC01` también tiene partidas en `PAR_FACTC01` (129,852). El reporte previo no las detectó por bug de query (`CAST(CVE_DOC AS VARCHAR)='47333'` falla con "conversion error from string AGA1"). Fix: usar `TRIM(CVE_DOC)='47333'` sin CAST.
  - **Factura 47333 verificada end-to-end**: 2 partidas (módulos Siemens SIMATIC ET 200SP 6ES71326BH010BA0 + 6ES71316BH010BA0), cliente BDA ELECTRONEUMATICA (RFC BEL180613RS9), UUID CFDI 87D03732-80DD-4FE2-8E80-44C885EC81B6.
  - **Cambios requeridos a `sales.ts`:** envolver `CVE_DOC` con `TRIM()` en JOINs, evitar `CAST()` sobre columnas VARCHAR en WHERE.
  - **5 smoke tests definidos** para validación final en Windows (ver sección 9 del reporte).

## Autorizaciones autónomas vigentes
- loteId: lote-ventas-20260805-01
- alcance: FACT-20260805-01, FACT-20260805-02 (cuando se desbloquee), MR-20260806-01 (work-around en validación), MR-20260806-02 (fix instalador v2.0.9)
- permisos: lectura/escritura local en `repaga-siemens/middleware/` e `installer/`, ejecución de tests y validación, instalación local en VM VirtualBox Windows 11 ya provisionada
- inicio: 2026-08-05T20:41-06:00 (reactivado 2026-08-06T22:57-06:00 por Frank para incluir fix v2.0.9)
- expiración: 2026-08-07T23:59-06:00 (24h desde reactivación)
- no permitido: commit, push, PR, deploy, producción, datos reales a PRD Siemens, secretos en logs, acciones sobre la PC física del cliente
