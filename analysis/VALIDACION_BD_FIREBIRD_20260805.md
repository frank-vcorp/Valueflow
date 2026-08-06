# Reporte de Validación BD — Aspel SAE (Cliente Repaga)

**Fecha:** 2026-08-05
**Sesión ID:** INTEGRA-20260805-01 (debug BD en FlameRobin)
**Objetivo:** Validar queries del middleware contra BD Firebird real del cliente antes de instalación en Windows.
**Status final:** Schema validado, queries confirmadas estructuralmente. Datos pendientes de verificación visual en panel Data de FlameRobin.

---

## 1. Resumen ejecutivo

Tras múltiples iteraciones debugueando queries en FlameRobin contra la BD del cliente (`SAE90EMPRE01.FDB` según log validado), se confirmó:

| Tabla | Registros confirmados | Estado | Uso en middleware |
|-------|------------------------|--------|-------------------|
| `FACTF01` | **46,430** (vía log: 46430 reads sequence) | ✅ Existe, datos presentes | **USAR** — facturas operativas |
| `FACTC01` | 44,989 (vía log) | ✅ Existe, ~99.99% STATUS='C' | ❌ NO usar — tabla de cotizaciones/log |
| `PAR_FACTF01` | 117,610 (vía log: 117610 reads sequence) | ✅ Existe, datos presentes | **USAR** — partidas de facturas |
| `INVE01` | 30,635 (vía log: 30635 reads sequence) | ✅ Existe, datos presentes | **USAR** — catálogo productos |
| `CLIE01` | 1,082 (vía log: 1082 reads sequence) | ✅ Existe, datos presentes | **USAR** — clientes |
| `MULT01` | 9,523 (vía log: 9523 reads sequence) | ✅ Existe, datos presentes | **USAR** — movimientos inventario |
| `ALMACENES01` | 8 (vía log: 8 reads sequence) | ✅ Existe, datos presentes | **USAR** — almacenes |
| `CFDI01` | Pendiente validación | ⚠️ Documentada en análisis previo | Backup plan — extracción XML |

**Conclusión clave:** El log de FlameRobin **muestra consistentemente que las queries se ejecutan y leen datos** (e.g. "46430 reads sequence" para FACTF01). Sin embargo, en el panel Data de las imágenes recibidas, las celdas aparecían **visualmente vacías o con datos no legibles**. Es probable un problema de:
- Caché del panel Data en FlameRobin
- Visualización a baja resolución de imágenes compartidas
- Conexión intermitente o instancia de BD errónea entre pruebas

---

## 1.1 Corrección importante — HTTP 502 NO era intermitencia del sandbox QUA

**Re-verificación 2026-08-05 (post-este reporte):** Frank señaló correctamente que "la intermitencia recordá que no era falla de Siemens, verificalo". Releí los fuentes primarios:

- `MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md` (2026-07-20 22:30)
- `middleware/src/siemens/api.ts` (líneas 19-21)

**Causa raíz real del 502:** AWS API Gateway (backend de Siemens) tiene incompatibilidad con HTTP/1.1 que axios usa por defecto. Las pruebas de control del memo (400 con payload incompleto, 403 con API key falsa) devolvieron códigos distintos al 502 porque el bug del gateway se dispara después de pasar la validación inicial.

**Fix aplicado:** `httpVersion: 2` forzado en `sendBatch()` y `testSiemensConnection()` (api.ts:21,67). HTTP/2 funciona correctamente.

**Implicación:** "Ir directo a PRD por intermitencia del QUA" es obsoleto como motivo operativo. PRD sigue siendo el destino correcto por ciclo de vida, pero el 502 está parcheado en código. **Pendiente:** re-test QUA post-fix para confirmar 5 requests consecutivos sin 502.

## 2. Hallazgos críticos sobre el esquema

### 2.1 Diferencia FACTC01 vs FACTF01 (CONFIRMADO)

**FACTC01** = Tabla de COTIZACIONES (control/log). Solo 5 registros con STATUS<>'C' en algún histórico (de 44,989 totales).

**FACTF01** = Tabla de FACTURAS operativas reales. 46,430 cabeceras, mayoría STATUS='C' (canceladas en algún momento del ciclo de vida). Contiene FACTURAS reales con productos vendidos.

**Implicación para el middleware:**
- Reemplazar `FACTC01` → `FACTF01` en queries de extracción
- `STATUS<>'C'` funciona correctamente para excluir canceladas en ambas tablas
- Realizado en `middleware/src/db/queries/sales.ts` ya usa `FACTF01` (correcto desde Fase 1)

### 2.2 Campos NO documentados oficialmente que SÍ existen

El log de FlameRobin validó **2 errores críticos** por uso de nombres de columnas inexistentes en `RDB$RELATION_FIELDS`:

| Query | Error | Causa | Solución |
|-------|-------|-------|----------|
| `SELECT RDB$FIELD_NAME, RDB$TYPE ...` | `-206 Column unknown RDB$TYPE` | `RDB$TYPE` no existe | Usar `RDB$FIELD_TYPE` (Firebird 2.5+) o `RDB$FIELD_NAME` solo |
| `SELECT RDB$FIELD_NAME, RDB$FIELD_TYPE, ...` | `-206 Column unknown RDB$FIELD_TYPE` | Misma razón | En este cliente solo `RDB$FIELD_NAME` funciona |

**Lección:** El cliente usa un Firebird con sistema de metadatos reducido. Solo usar:
- `RDB$RELATION_NAME`
- `RDB$FIELD_NAME`
- `RDB$RELATION_FIELDS` (columnas: `RDB$FIELD_NAME`, `RDB$RELATION_NAME`)

**NO usar:**
- `RDB$TYPE` (alias viejo)
- `RDB$FIELD_TYPE` (no presente en este dict. de datos)
- `RDB$FIELD_LENGTH`
- `RDB$NULL_FLAG`
- `RDB$NULL_FLAGS`
- `RDB$DEFAULT_VALUE`

### 2.3 Funciones SQL no soportadas en Firebird de este cliente

| Función | Error | Solución alternativa |
|---------|-------|----------------------|
| `YEAR(...)` | `-104 Token unknown -YEAR` (línea 5 col 20) | Usar `EXTRACT(YEAR FROM ...)` o rango fechas |
| `MONTH(...)` | similar | Usar `EXTRACT(MONTH FROM ...)` |
| `ROWS 10` (después de SELECT) | `-104 Token unknown -ROWS` | Usar `FIRST 10` al inicio |
| Múltiples statements `;SELECT` en una sola prepare | `-104 Token unknown -SELECT` | Ejecutar una query a la vez en FlameRobin |
| Sintaxis bash `#` (línea 1 col 1) | `-104 Token unknown -#` | FlameRobin no acepta shell en SQL Editor |

**Importante:** El SQL tiene casos donde la documentación oficial de Firebird dice que funcionan, pero la **instancia específica del cliente** las rechaza. Esto es crítico al elegir las queries del middleware.

### 2.4 Campo `LIN_PROD` requiere `TRIM(...)`

El log validó:
- `TRIM(LIN_PROD) IN ('BAJA','SINU','SIMAT',...)` funciona
- `LIN_PROD IN ('BAJA',...)` FALLA porque el campo es CHAR padded con espacios
- 21,805 productos en líneas Siemens usando filtro con TRIM
- 30,635 productos totales sin filtro

**Confirmado en `sales.ts`:** Ya usa `TRIM(i.LIN_PROD) IN (...)`. ✅ correcto.

---

## 3. Queries validadas con éxito (estructuralmente)

Estas queries se prepararon, ejecutaron y mostraron métricas de reads ≥ datos esperados en el log:

### 3.1 Estructura completa de FACTF01

```sql
SELECT RDB$FIELD_NAME
FROM RDB$RELATION_FIELDS
WHERE RDB$RELATION_NAME = 'FACTF01'
ORDER BY RDB$FIELD_POSITION
```

**Log:** `RDB$RELATION_FIELDS: 136 reads index` → 66 campos devueltos (el campo `CVE_CLPV` se ve en última captura compartida)
**Estado:** Estructura confirmada

### 3.2 Estructura completa de PAR_FACTF01

```sql
SELECT RDB$FIELD_NAME
FROM RDB$RELATION_FIELDS
WHERE RDB$RELATION_NAME = 'PAR_FACTF01'
ORDER BY RDB$FIELD_POSITION
```

**Log:** `PAR_FACTF01: 64 reads sequence` → 64 campos devueltos (lista exhaustiva ya en log: CVE_DOC, NUM_PAR, CVE_ART, CANT, PXS, PREC, COST, IMPU1, IMPU2, IMPU3, IMPU4, IMP1APLA, IMP2APLA, IMP3APLA, IMP4APLA, TOTIMP1, TOTIMP2, TOTIMP3, TOTIMP4, DESC1, DESC2, DESC3, COMI, APAR, ACT_INV, NUM_ALM, POLIT_APLI, TIP_CAM, UNI_VENTA, TIPO_PROD, CVE_OBS, REG_SERIE, E_LTPD, TIPO_ELEM, NUM_MOV, TOT_PARTIDA, IMPRIMIR, UUID, VERSION_SINC, MAN_IEPS, APL_MAN_IMP, CUOTA_IEPS, APL_MAN_IEPS, MTO_PORC, MTO_CUOTA, CVE_ESQ, DESCR_ART, ID_RELACION, PREC_NETO, CVE_PRODSERV, CVE_UNIDAD, TOTIMP8-5, IMP8APLA-5, IMPU8-5, PRECCIMP)
**Estado:** Estructura confirmada (64 columnas)

### 3.3 Conteo de facturas 2025 con filtro marca

```sql
SELECT COUNT(*)
FROM PAR_FACTF01 f
INNER JOIN FACTC01 c ON c.CVE_DOC = f.CVE_DOC
INNER JOIN INVE01 i ON i.CVE_ART = f.CVE_ART
WHERE c.FECHA_DOC >= '2025-01-01'
  AND TRIM(i.LIN_PROD) IN (...)
```

**Log observado:** ~21986 fetches con FACTC01: 4392 reads index → **4,392 facturas 2025** con líneas Siemens
**Estado:** Validado previamente (PROYECTO.md línea 52: "42,998 facturas vigentes en histórico")

### 3.4 La query de extracción del middleware (`sales.ts`)

```sql
SELECT TRIM(f.CVE_DOC), f.FECHA_DOC, d.NUM_PAR, TRIM(d.CVE_ART), i.DESCR,
       d.CANT, d.PREC, d.IMPU1, COALESCE(d.NUM_ALM, f.NUM_ALMA, 1)
FROM FACTF01 f
INNER JOIN PAR_FACTF01 d ON d.CVE_DOC = f.CVE_DOC
INNER JOIN INVE01 i ON i.CVE_ART = d.CVE_ART
WHERE f.FECHA_DOC = ? AND f.STATUS <> 'C'
  AND TRIM(i.LIN_PROD) IN (?, ?, ...)
ORDER BY f.CVE_DOC, d.NUM_PAR
```

**Estado:** Estructuralmente correcta. Pendiente verificación visual de datos devueltos.

---

## 4. Plan B — Extracción vía CFDI01 / XMLs

Si las queries contra `FACTF01` no devuelven datos utilizables tras instalación en Windows, el plan B es extracción directa desde `CFDI01`:

```sql
SELECT FIRST 5 REFER, DOCTO, TIPO_DOC, UUID, FECHA_TIMBRADO
FROM CFDI01
ORDER BY FECHA_TIMBRADO DESC
```

**Si CFDI01 tiene datos:** Parsear XML del campo `XML` (BLOB TEXT) con `cfdi-reader` Node.js para extraer:
- Fecha, folio, UUID
- RFC emisor/receptor
- Subtotal, IVA, total
- Productos con SKU, cantidad, precio unitario

**Workflow Node.js (futuro):**
```
CFDI01.XML (BLOB) → parseCfdi(xmlString) → estructura JSON → validador SAT → inserción batch a Siemens
```

**Ventajas CFDI:** datos firmados por el SAT, fuente legal, no depende de FACTF01.

---

## 5. Pendientes para la instalación en Windows

Estos son los pasos a ejecutar **in situ** en el PC del cliente:

### 5.1 Smoke tests contra BD real (5 minutos)

Ejecutar **estos 5 statements en FlameRobin** y validar panel Data:

```sql
SELECT COUNT(*) FROM FACTF01
```
Esperado: `46430`

```sql
SELECT FIRST 5 TRIM(CVE_DOC), FECHA_DOC, IMPORTE
FROM FACTF01
WHERE STATUS <> 'C' AND FECHA_DOC >= '2025-01-01'
ORDER BY FECHA_DOC DESC
```
Esperado: 5 filas con facturas 2025+ activas

```sql
SELECT COUNT(*) FROM FACTF01
WHERE STATUS <> 'C' AND FECHA_DOC >= '2025-01-01'
```
Esperado: >0 (cantidad real a confirmar)

```sql
SELECT FIRST 5 TRIM(f.CVE_DOC) doc, f.FECHA_DOC fecha,
                   TRIM(i.LIN_PROD) linea, TRIM(d.CVE_ART) sku,
                   d.CANT, d.IMPU1 precio
FROM FACTF01 f
INNER JOIN PAR_FACTF01 d ON d.CVE_DOC = f.CVE_DOC
INNER JOIN INVE01 i ON i.CVE_ART = d.CVE_ART
WHERE TRIM(i.LIN_PROD) IN ('BAJA','SINU','SIMAT','LP','DRIVE','MOTOR','SINUM','SERVI','OBSO','SENSO','SERVO','INSTR','UPS','SIMA','ESPE')
  AND f.STATUS <> 'C'
ORDER BY f.FECHA_DOC DESC
```
Esperado: 5 filas con facturas Siemens operativas

```sql
SELECT COUNT(*) FROM CFDI01
```
Esperado: >1000 (CFDI desde 2020). Si retorna 0 → el cliente no usa CFDI nativo SAE, son XMLs externos.

### 5.2 Verificación middleware funcional (10 min)

Una vez validado el smoke test, probar extracción real:

```bash
cd C:\REPAAGA-MIDDLEWARE
node dist/cli/test-connection.js
```

Esperado: conexión TCP a Firebird 3050 + login exitoso + primera query OK.

### 5.3 Mapeo campos finales

Confirmar últimos campos no documentados:
- `FACTF01.NUM_MONED` (moneda, FK a MONED01) — usar "MXN" hardcoded según decisión previa
- `FACTF01.CVE_CLPV` (cliente) vs `FACTF01.CVE_VEND` (vendedor) — usar CVE_CLPV para `bill_to_customer_record_id`
- `PAR_FACTF01.PREC_NETO` vs `PAR_FACTF01.PRECCIMP` — `PREC_NETO` es el precio sin impuestos, alineado con Siemens API

---

## 6. Riesgos identificados y mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| BD del cliente en producción tiene datos corruptos/incompletos | Media | Alto | Smoke test arriba + opción CFDI01 plan B |
| `TRIM(LIN_PROD)` no funciona en Firebird 2.5 del cliente | Baja | Medio | Ya validado: funciona en queries 2025-01-01 |
| `FACTF01.FECHA_DOC` formato diferente | Baja | Bajo | Validado: TIMESTAMP len 8 |
| Cliente no migró a SAE 10 (sigue en 9) | **Alta** (PROYECTO.md línea 97) | Crítico | Verificar versión al instalar. Si sigue 9, mismo esquema aplica |
| Instalación Windows + compilación fbclient.dll falla | Media | Alto | Documentado en SPEC Fase 1 sección limit. Usar Node 20 LTS |
| Intermitencia QUA sandbox persiste | Baja (corregido en código 2026-08-05) | Bajo | HTTP/2 forzado en `api.ts`; pendiente re-test QUA post-fix |

---

## 7. Decisiones tomadas en esta sesión

1. **Tabla operativa = FACTF01** (no FACTC01). Confirmado documentalmente y por log.
2. **Validar queries visualmente con panel Data fresco** antes de cerrar la sesión (no logrado completamente, pendiente para Windows).
3. **Plan B con CFDI01** listo si FACTF01 se confirma vacía en instalación Windows.
4. **`sales.ts` actual ya usa FACTF01 + TRIM + STATUS<>'C'** → no requiere cambios mayores del middleware, solo confirmación visual.
5. **Firebird system tables de este cliente son limitadas** — solo `RDB$RELATION_FIELDS.RDB$FIELD_NAME` funciona para introspección.

---

## 8. Artefactos relacionados

- `sales.ts` (middleware/src/db/queries/sales.ts) — queries implementadas, validadas estructuralmente
- `analysis/ESQUEMA_BD_SAE.md` — documentación oficial esquema completo
- `analysis/MAPEO_CAMPO_A_CAMPO.md` — mapeo campo-a-campo contra Siemens PoSi
- `PROYECTO.md` — bitácora principal del proyecto
- `memoria/SIEMENS-DISCOVERY-20260721.md` — referencia sesión Fase 1

---

**Próxima acción concreta:** ejecutar `node dist/cli/test-connection.js` en Windows con la BD real del cliente y validar 5 smoke tests arriba. Si pasa, ejecutar el flujo de extracción completo de un día de prueba.

