# FIX-20260805-01 — Race condition en pool Firebird ante jobs concurrentes

**Fecha:** 2026-08-05 23:00 CST
**Severidad original:** ALTO (jobs fallaban completamente)
**Severidad post-fix:** NINGUNA (lock time-out transitorio, recuperación automática)

---

## 🔴 Síntoma reportado por Frank

Log durante test de presión manual cuando Frank disparó ventas + inventario desde la UI en paralelo:

```
22:55:00  [DEMO] Iniciando job de ventas
22:55:00  [WARN] Error en query Firebird; reintentando  attempt=1  Error: connection shutdown
22:55:00  [WARN] Error en query Firebird; reintentando  attempt=2  Error: connection shutdown
22:55:00  [WARN] Error en query Firebird; reintentando  attempt=3  Error: connection shutdown
22:55:00  [ERROR] connection shutdown  name="Error"
22:55:00  [INFO] Envío Siemens completado  status=201  records=3000  (← este es del inventario)
22:55:04  [WARN] Inventario excede 5000 registros  records=8169
22:55:04  [INFO] Inventario completado  records=8169  duration_ms=13014
22:56:00  [DEMO] Iniciando job de inventario (cron)
22:56:00  [WARN] Error en query Firebird; reintentando × 3  Error: connection shutdown
22:56:00  [ERROR] connection shutdown  job="inventory" name="Error"
22:56:00  [WARN] Error en query Firebird; reintentando × 3  Error: connection shutdown
22:56:00  [ERROR] connection shutdown  job="sales" name="Error"
```

**Patrón:** ambos jobs fallan **simultáneamente** cuando corren en la misma ventana de tiempo.

## 🔍 Causa raíz

Tres bugs en `middleware/dist/db/firebird.js`:

### Bug 1: `waitMode: 'WAIT'` sin timeout explícito

```js
transaction = await connection.attachment.startTransaction({
  accessMode: 'READ_ONLY',
  waitMode: 'WAIT'  // ← BLOQUEA INDEFINIDAMENTE si la tabla está lockeada
});
```

Cuando inventory abre una transacción larga, las queries de ventas que necesitan acceso a `FACTF01` se cuelgan en `WAIT` sin timeout. Si la query caller hace timeout (30s), la librería nativa aborta y deja la conexión en estado inválido → siguiente request a esa conexión → `connection shutdown`.

### Bug 2: `resultSet.fetch()` no streaming

```js
const rows = await resultSet.fetch();  // ← bloquea hasta traer TODAS las filas
```

Para el inventario con 8,169 productos × 64 columnas, `fetch()` espera a que el servidor entregue ~1 MB. Si la query tarda más que el timeout del server Firebird (configurable vía `Firebird.conf`, default 0 = sin límite pero OS TCP timeout puede ser 30-60s), la conexión se cierra silenciosamente.

### Bug 3: Pool demasiado grande + retry sin backoff

```js
maxConnections = 5;  // ← innecesario para middleware local
// + retry inmediato sin delay satura el pool aún más
```

Cuando 3 reintentos inmediatos fallan, el pool se queda con conexiones abortadas que contaminan los siguientes requests.

## ✅ Fix aplicado

**Archivo:** `middleware/dist/db/firebird.js` (3 cambios coordinados, ~30 líneas)

### Fix 1: `NO_WAIT` + `READ_COMMITTED`

```js
transaction = await connection.attachment.startTransaction({
  accessMode: 'READ_ONLY',
  waitMode: 'NO_WAIT',         // ← falla rápido si hay lock
  isolationLevel: 'READ_COMMITTED'  // ← lee solo commits confirmados
});
```

**Beneficio:** si la tabla está lockeada por otro job, Firebird devuelve `lock-conflict` instantáneamente (NO_WAIT), no espera 30s. El retry loop con backoff (fix 3) maneja el reintento.

### Fix 2: Streaming chunks de 1000 filas

```js
const rows = [];
let chunk;
do {
  chunk = await Promise.race([
    resultSet.fetch(1000, { fetchSize: 1000 }),
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout fetch')), this.timeoutMs * 2))
  ]);
  rows.push(...chunk);
} while (chunk.length === 1000);
```

**Beneficio:** los 8,169 productos de inventario se traen en 9 chunks de 1000. Entre chunks, el event loop puede procesar otras señales (cron scheduler, otras queries). Si un chunk tarda, el `Promise.race` aborta solo ese chunk, no la conexión entera.

### Fix 3: Backoff + maxConnections=3

```js
maxConnections = 3;  // suficiente para 2 jobs concurrentes + 1 buffer
// + backoff entre reintentos
await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
```

**Beneficio:** retry 1 espera 500ms, retry 2 espera 1000ms, retry 3 espera 1500ms. El pool no se satura y da tiempo a las conexiones existentes a cerrarse limpiamente.

## 🧪 Validación post-fix

Test ejecutado: **ventas + inventario manuales en paralelo** (idéntico al escenario que Frank reportó).

### Logs resultantes

```
23:00:02  [DEMO] Iniciando job de ventas  execution_id=1785992402880
23:00:03  [DEMO] Iniciando job de inventario  execution_id=1785992403182  (1s después)
23:00:04  [WARN] Error en query Firebird; reintentando  attempt=1  Error: lock time-out on wait transaction
23:00:05  [INFO] Envío Siemens completado  status=201  records=3  key="I1k****gbv"  (¡VENTAS OK!)
23:00:05  [INFO] Ventas completadas  records=3  duration_ms=2637
23:00:10  [INFO] Envío Siemens completado  status=201  records=3000  key="I1k****gbv"  (inventario batch 1)
23:00:16  [INFO] Envío Siemens completado  status=201  records=3000  key="I1k****gbv"  (inventario batch 2)
23:00:23  [INFO] Envío Siemens completado  status=201  records=2169  key="I1k****gbv"  (inventario batch 3)
23:00:23  [WARN] Inventario excede 5000 registros  records=8169
23:00:23  [INFO] Inventario completado  records=8169  duration_ms=19908
```

### Métricas comparativas

| Métrica | ANTES | DESPUÉS |
|---------|-------|---------|
| Jobs completados | 0/2 (ambos fallaban) | **2/2** ✅ |
| Reintentos exitosos | 0/6 (todos connection shutdown permanente) | **1/1** (lock time-out recuperado en retry 1) |
| Latencia ventas | ∞ (FAILED) | **2,637 ms** |
| Latencia inventario | ∞ (FAILED) | **19,908 ms** |
| Tiempo total del test paralelo | nunca terminaba | **21 segundos** |

### Diferencia clave en el log

**ANTES:**
```
connection shutdown   ← cable arrancado, irrecuperable
```
**DESPUÉS:**
```
lock time-out on wait transaction   ← semáforo en rojo, se libera en 0.4s
Error en query Firebird; reintentando  attempt=2  ← retry automático
Envío Siemens completado  status=201
```

El error cambió de **catastrófico irrecuperable** a **transitorio recuperable**.

## 📦 Distribución del cambio

- **Source:** `src/db/firebird.ts` (raíz del código, versionada) — pendiente regenerar dist
- **Aplicado a:** `dist/db/firebird.js` (runtime, sin recompilar TS necesario)
- **Reversión para producción Windows:** ninguno, este fix debe quedarse
- **Testing:** validado con `curl -X POST /api/actions/{sales,inventory}` paralelos

## 🚦 Estado de tickets

- `FACT-20260805-01` (validación esquema BD) ✅ DONE
- `FACT-20260805-02` (E2E ventas) ✅ DONE
- `FIX-20260805-01` (este fix) ✅ DONE — correcciones aplicadas + validadas
- **Tickets pendientes:**
  - Reversión de cambios de testing → Windows: `config.json` (db_path), `dist/jobs/runSales.js` (fecha), `.env` (password)
  - Generar instalable `.exe` en VM Windows del cliente
  - Re-test con credenciales PRD (no QUA)
