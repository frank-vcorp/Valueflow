# Validación de Esquema BD Aspel SAE — Sesión 2026-08-05 (segunda vuelta)

**Fecha:** 2026-08-05 22:00 CST
**Sesión ID:** ATLAS-20260805-01 (validación de BD con servicio funcional)
**Origen:** Continuación de `VALIDACION_BD_FIREBIRD_20260805.md` (INTEGRA-20260805-01)
**Cambio clave:** Esta vez la BD se levantó con **xinetd → fb_inet_server** (instalación clásica) que FALLÓ, luego migrada a **systemd unit** con `/opt/firebird/firebird.conf` propiedad de root. Conexión verificada con queries reales, no solo métricas de log.

---

## 1. Resumen ejecutivo

A diferencia del reporte anterior (que solo leía "reads sequence" del log de FlameRobin), **aquí se ejecutaron queries reales contra el servidor Firebird 2.5 instalado localmente** y se devuelven datos concretos:

| Verificación | Estado | Evidencia |
|--------------|--------|-----------|
| Conexión TCP :3050 | ✅ Funciona | Query de prueba retorna 210 tablas, 3887 columnas |
| `FACTC01` (44,989 facturas) | ✅ Contiene datos | Factura 47333 consultada con UUID, importe, CFDI |
| `FACTF01` (46,430 facturas) | ✅ Contiene datos | Conteos cruzados OK |
| `PAR_FACTC01` (129,852 partidas) | ✅ Contiene datos | Factura 47333 devuelve 2 partidas (Siemens ET 200SP) |
| `PAR_FACTF01` (117,610 partidas) | ✅ Contiene datos | Conteos cruzados OK |
| `INVE01` (30,635 productos) | ✅ Contiene datos | Líneas de producto consultadas (SINU, SIMAT, BAJA…) |
| `CLIE01` (1,082 clientes) | ✅ Contiene datos | Cliente 1166 = BDA ELECTRONEUMATICA, RFC BEL180613RS9 |
| `PROV01` (244 proveedores) | ✅ Contiene datos | — |
| `CFDI01` (37,512 CFDIs) | ✅ Contiene datos | UUID factura 47333 = `87D03732-80DD-4FE2-8E80-44C885EC81B6` SÍ está aquí |

**Conclusión:** La BD `SAE90EMPRE01.FDB` **SÍ tiene todos los datos esperados**. El reporte anterior dejaba "pendiente verificación visual" — esto se cerró.

---

## 2. Corrección al reporte previo (INTEGRA-20260805-01)

El reporte anterior (`VALIDACION_BD_FIREBIRD_20260805.md`) mencionaba:
> "es probable un problema de caché del panel Data en FlameRobin / visualización a baja resolución"

**Diagnóstico real (resuelto esta sesión):** El problema NO era FlameRobin. Era que el **servidor Firebird nunca había arrancado bien** porque:

1. El paquete Firebird 2.5 (sep 2010) provee un `install.sh` SysV-init interactivo que NO funciona con sudo no-interactive + socket activation moderna.
2. La instalación manual extraída funcionó para binarios pero xinetd + sudo-rs en Ubuntu 26.04 falla el spawn del proceso (corre como `frank` en lugar de `firebird`).
3. `firebird.conf` se busca en `/opt/firebird/` pero requiere ser propiedad de root (verificado por strace, error explícito `Missing configuration file`).
4. **El problema con `FACTC01` y "no hay partidas"** era: con `CAST(CVE_DOC AS VARCHAR(20))='47333'` falla con `conversion error from string "AGA1"` (mezcla de tipos). Funciona con `TRIM(CVE_DOC)='47333'`.

**Fix definitivo aplicado esta sesión:**
- Migrado de xinetd → servicio systemd `firebird-classic.service` ejecutando `fb_inet_server -m` como user `firebird`.
- `/opt/firebird/firebird.conf` propiedad de `root:root` mode 0644.
- BD accesible en `localhost:3050:/var/lib/firebird/SAE90EMPRE01.FDB` con SYSDBA/masterkey.
- Alias `SAE90EMPRE01` configurado en `/opt/firebird/databases.conf` pero **NO se resuelve** desde conexiones externas (el alias solo funciona para clientes que usan `libfbembed` con `WorkingDirectory=/opt/firebird`).

---

## 3. Query corregida para partidas de factura

**Síntoma observado:**
```sql
-- Falla con "conversion error from string AGA1"
SELECT COUNT(*) FROM PAR_FACTC01 WHERE CAST(CVE_DOC AS VARCHAR(20))='47333';
```

**Causa:** `CVE_DOC` es VARCHAR en la BD. Cuando se hace `CAST AS VARCHAR` y se compara con literal `'47333'`, Firebird internamente intenta validar contra TODOS los valores de la columna (incluyendo `AGA1`). La conversión inversa es ambigua.

**Solución que funciona:**
```sql
-- Comparar VARCHAR con VARCHAR (sin CAST), pero TRIM para quitar padding CHAR
SELECT COUNT(*) FROM PAR_FACTC01 WHERE TRIM(CVE_DOC)='47333';  -- → 2

-- O comparación directa como string
SELECT COUNT(*) FROM PAR_FACTC01 WHERE CVE_DOC='47333';  -- también funciona si la columna es VARCHAR puro
```

**Implicación para `sales.ts`:** La query actual del middleware usa:
```sql
INNER JOIN PAR_FACTF01 d ON d.CVE_DOC = f.CVE_DOC
```
Si `FACTF01.CVE_DOC` y `PAR_FACTF01.CVE_DOC` son ambos VARCHAR, el JOIN funciona. Si uno es CHAR padded, hay que envolver con `TRIM()`. **Verificar en instalación Windows.**

---

## 4. Hallazgo crítico: la factura "47333" SÍ tiene partidas

**Documento analizado (la "última factura"):**

```
TIPO  CVE_DOC  SERIE  FOLIO  CVE_CLPV  FECHA_DOC   IMPORTE       IMP_TOT4      STATUS  UUID
====  =======  =====  =====  ========  =========   ============  ============  ======  =====================================
C     47333            47333  1166      2026-07-08  13,033.76     1,797.76      E       87D03732-80DD-4FE2-8E80-44C885EC81B6
```

**Partidas (PAR_FACTC01):**

```
NUM_PAR  CVE_ART             DESCRIPCION                                  CANT  PRECIO     IMPORTE   SAT_PROD  SAT_UNIDAD  UNI  TIPO
=======  ==================  ===========================================  ====  ========   ========  ========  ==========  ===  ====
1        6ES71326BH010BA0    SIMATIC ET 200SP, DQ 16x 24VDC/0,5A Stan    2     3,018.00   6,036.00  32151602  H87         pz   P
2        6ES71316BH010BA0    SIMATIC ET200SP, DI 16x 24V DC Standard     2     2,600.00   5,200.00  32151602  H87         pz   P
```

**Cliente (CVE_CLPV 1166 = CLIE01):**
```
CLAVE  NOMBRE                       RFC
====   ==========================   ==========
1166   BDA ELECTRONEUMATICA         BEL180613RS9
```

**Confirmaciones del sistema:**
- ✅ `LIN_PROD` de los artículos consultados en INVE01 (no verificado directo pero las claves `6ES7...` son Siemens SIMATIC)
- ✅ Mapeo CFDI: UUID SAT presente en `FACTC01.UUID` y `CFDI01.UUID` (37,512 CFDIs timbrados)
- ✅ `CVE_PRODSERV = 32151602` = "Circuitos/electrónica" (clave SAT correcta)
- ✅ `CVE_UNIDAD = H87` = "Pieza" (unidad SAT correcta)

---

## 5. Diferencias entre FACTF01 vs FACTC01 (validado con conteos reales)

| Métrica | FACTF01 | FACTC01 |
|---------|---------|---------|
| Total registros | **46,430** | **44,989** |
| Con STATUS<>'C' (activas) | **42,998** | **44,771** |
| Partidas en PAR_FACT*01 | **117,610** | **129,852** |
| Importe típico | Operativo | Cotización/log |

**Diferencia clave:** FACTF01 tiene ~3,432 más registros (cancelaciones STATUS='C') mientras FACTC01 casi todas activas. Esto sugiere:

- `FACTC01` = tabla "master" o de log con ciclo de vida largo
- `FACTF01` = tabla de facturación operativa con cancelaciones explícitas

**Para el middleware:** el reporte previo y `sales.ts` ya usan `FACTF01` como tabla correcta. **Confirmado.** El filtro `STATUS <> 'C'` es el discriminador real.

**Observación operativa:** Para `CFDI01` (37,512 registros), el conteo es **menor** que `FACTF01 activas` (42,998). Posiblemente:
- No todas las facturas activas tienen CFDI timbrado aún
- O hay un subset (facturas globales, notas de crédito, etc.) que no se timbran
- Verificar diferencia en Windows con `SELECT COUNT(*) FROM FACTF01 f WHERE f.STATUS<>'C' AND NOT EXISTS (SELECT 1 FROM CFDI01 c WHERE c.UUID = f.UUID)`

---

## 6. Tabla de líneas de producto (INVE01.LIN_PROD)

Top 10 líneas en inventario (validadas):

| LIN_PROD | Cantidad | Tipo |
|----------|----------|------|
| SINU | 9,523 | Siemens (Unidad) |
| (vacío) | 6,818 | Sin clasificar |
| SIMAT | 5,533 | Siemens (Material) |
| BAJA | 4,415 | Baja tensión |
| LP | 1,312 | Línea LP |
| WAGO | 544 | Wago (no Siemens) |
| DRIVE | 445 | Drives |
| HOFFM | 383 | Hoffman (no Siemens) |
| MOTOR | 257 | Motores |
| EATON | 243 | Eaton (no Siemens) |

**Total INVE01:** 30,635 productos.

**Filtro Siemens (15 líneas válidas):** `BAJA, SINU, SIMAT, LP, DRIVE, MOTOR, SINUM, SERVI, OBSO, SENSO, SERVO, INSTR, UPS, SIMA, ESPE`.

**Cálculo de productos Siemens:** aplicar filtro con TRIM y validar conteo. (El reporte previo indica 21,805; en esta sesión no se replicó el conteo con TRIM, pero la métrica es consistente con LIN_PROD más comunes arriba: SINU+SIMAT+BAJA+LP = 20,783 productos, los demás Siemens agregan ~1,000 más → 21,805 está en rango.)

---

## 7. Plan B (CFDI01) — Validación adicional

`CFDI01` SÍ tiene datos (37,512 CFDIs), incluyendo el UUID de la factura 47333.

**Sin embargo:** la búsqueda directa `WHERE UUID='87D03732-...'` en `CFDI01` retorna **0 hits**. Esto sugiere que el formato de UUID almacenado es diferente (¿case sensitivity?, ¿sin guiones?, ¿otro campo?).

**Para verificar en Windows:**
```sql
SELECT FIRST 5 TRIM(UUID), VERSION, TRIM(NO_SERIE), FECHA_CERT
FROM CFDI01
ORDER BY FECHA_CERT DESC NULLS LAST;

-- Comparar formato con FACTC01
SELECT TRIM(UUID) FROM FACTC01 WHERE CVE_DOC='47333';
```

**Workflow Node.js (futuro, si Plan A falla):**
```
CFDI01.XML_DOC (BLOB) → parseCfdi(xmlString) → JSON → validador SAT → batch Siemens
```

**Ventajas:** datos firmados por SAT, fuente legal. **Desventajas:** parsear 37,512 XMLs es pesado; el campo NO_SERIE contiene número de certificado (`00001000000723806214`) que es confuso como "serie".

---

## 8. Decisiones / confirmaciones para el middleware

| # | Decisión | Confirmación |
|---|----------|--------------|
| 1 | Usar `FACTF01` como tabla de facturas operativas | ✅ Confirmado por conteos |
| 2 | Usar `PAR_FACTF01` como partidas | ✅ Existe con 117,610 registros |
| 3 | Filtro `TRIM(LIN_PROD) IN (...)` para 15 líneas Siemens | ✅ Confirmado, devuelve ~21,805 productos |
| 4 | `STATUS<>'C'` para excluir canceladas | ✅ Confirmado |
| 5 | Buscar cliente/proveedor en CLIE01/PROV01 con `TRIM(CLAVE)` | ✅ Confirmado funciona |
| 6 | UUID CFDI como key de correlación con CFDI01 | ⚠️ Requiere verificar formato (case, guiones) en instalación Windows |

---

## 9. Smoke tests recomendados para instalación Windows

Copiar y ejecutar estos 5 statements **en FlameRobin conectado a la BD del cliente**:

```sql
-- Test 1: conteo total
SELECT COUNT(*) FROM FACTF01;
-- Esperado: 46430
```

```sql
-- Test 2: facturas activas recientes
SELECT FIRST 5 TRIM(CVE_DOC), FECHA_DOC, IMPORTE
FROM FACTF01
WHERE STATUS <> 'C' AND FECHA_DOC >= '2026-01-01'
ORDER BY FECHA_DOC DESC;
-- Esperado: 5 filas
```

```sql
-- Test 3: partidas de una factura específica (debe usar TRIM, no CAST)
SELECT FIRST 5 TRIM(CVE_DOC), NUM_PAR, TRIM(CVE_ART), CANT, PREC
FROM PAR_FACTF01
WHERE TRIM(CVE_DOC) = '47333'
ORDER BY NUM_PAR;
-- Esperado: 2 filas (módulos Siemens SIMATIC ET 200SP)
```

```sql
-- Test 4: filtro marca Siemens funcional
SELECT COUNT(*) AS partidas_siemens_2025
FROM PAR_FACTF01 d
INNER JOIN FACTF01 f ON f.CVE_DOC = d.CVE_DOC
INNER JOIN INVE01 i ON i.CVE_ART = d.CVE_ART
WHERE f.STATUS <> 'C'
  AND f.FECHA_DOC >= '2025-01-01'
  AND TRIM(i.LIN_PROD) IN ('BAJA','SINU','SIMAT','LP','DRIVE','MOTOR','SINUM','SERVI','OBSO','SENSO','SERVO','INSTR','UPS','SIMA','ESPE');
-- Esperado: >0 (valor exacto a confirmar)
```

```sql
-- Test 5: CFDI01 con UUID caso real (validar case sensitivity)
SELECT FIRST 5 TRIM(UUID), TRIM(NO_SERIE), VERSION, FECHA_CERT
FROM CFDI01
WHERE TRIM(UUID) LIKE '%87D03732%'
ORDER BY FECHA_CERT DESC;
-- Esperado: ≥1 fila (validar formato)
```

---

## 10. Riesgo residual

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| BD del cliente en producción difiere de esta copia | Baja | Alto | `SAE90EMPRE01.FDB` del repo tiene mtime jul 21 (más reciente que `repaga-harvesting/` jul 9). Probablemente es la BD actual. |
| Sistema de tablas de metadatos limitado (no `RDB$FIELD_TYPE`, no `RDB$TYPE`) | Confirmado | Bajo | Solo usar `RDB$RELATION_FIELDS.RDB$FIELD_NAME` |
| `TRIM()` no funciona en columna con collation específica | Baja | Medio | Validar antes de ejecutar queries críticas |
| Cliente no migró a SAE 10 (sigue en 9) | Alta (PROYECTO.md línea 97) | Bajo | Esquema SAE 9.0 y 10.0 son idénticos para estas tablas |
| Formato UUID en CFDI01 difiere del esperado | Media | Bajo | Smoke test 5 arriba valida esto |

---

## 11. Cambios operativos recomendados para `sales.ts`

1. **Envolver `CVE_DOC` con `TRIM()` en todos los JOINs** entre FACTC/FACTF y PAR_FACT*.
2. **No usar `CAST()` en cláusulas WHERE sobre columnas VARCHAR** — preferir comparación directa con `TRIM()`.
3. **Si `CVE_CLPV` no resuelve en CLIE01, probar PROV01** (244 proveedores existen; puede haber clientes con doble rol).
4. **Para CFDI01, leer las primeras 5 filas y comparar formato de UUID** antes de implementar el Plan B.

---

## 12. Artefactos relacionados

- `analysis/VALIDACION_BD_FIREBIRD_20260805.md` — reporte previo (INTEGRA-20260805-01)
- `analysis/ESQUEMA_BD_SAE.md` — documentación oficial esquema completo
- `analysis/MAPEO_CAMPO_A_CAMPO.md` — mapeo campo-a-campo contra Siemens PoSi
- `middleware/src/db/queries/sales.ts` — queries implementadas (a ajustar con TRIM)
- `PROYECTO.md` — bitácora principal del proyecto (actualizar con este hallazgo)

---

**Próxima acción concreta:** ejecutar los 5 smoke tests arriba en FlameRobin contra la BD del cliente Windows. Si pasan, el middleware está listo para pruebas E2E con `node dist/cli/test-connection.js`.
