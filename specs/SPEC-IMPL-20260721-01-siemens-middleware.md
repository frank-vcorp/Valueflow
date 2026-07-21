# SPEC-IMPL-20260721-01 — Middleware SAE 10 ↔ Siemens PoSi

**ID:** SPEC-IMPL-20260721-01
**Padre:** [`repaga-siemens/PROYECTO.md`](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/PROYECTO.md) (ERP-INT-005)
**Documentos asociados:**
- [`repaga-siemens/PROPUESTA_TECNICA_SAE10_SIEMENS.md`](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/PROPUESTA_TECNICA_SAE10_SIEMENS.md) v1.3
- [`repaga-siemens/PROPUESTA_ECONOMICA_SAE10_SIEMENS.md`](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/PROPUESTA_ECONOMICA_SAE10_SIEMENS.md) v1.5
- [`repaga-siemens/MAPEO_CAMPO_A_CAMPO.md`](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/MAPEO_CAMPO_A_CAMPO.md)
- [`repaga-siemens/MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md`](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md)

**Fecha:** 2026-07-21
**Estado:** Listo para ejecución por SOFIA
**Agente ejecutor:** SOFIA (constructora determinista)
**Validación:** GEMINI (auditor de calidad)

---

## 1. Objetivo

Construir un **middleware Node.js + TypeScript** que automatice el envío de información de inventario y ventas desde Aspel SAE 10 hacia Siemens PoSi Portal, con los siguientes requisitos clave:

1. **Acceso directo a BD Firebird 5.0** de SAE 10 (NO reportes).
2. **Filtro de marca Siemens** por campo `LIN_PROD` (15 líneas válidas).
3. **Solo campos mínimos requeridos** enviados (5 inventario, 10 ventas); campos opcionales seleccionables desde UI.
4. **UI local de administración** en `http://localhost:4567` con logo Repaga + badge Approved Partner Siemens.
5. **Patrón de reintentos** robusto contra intermitencia del sandbox QUA.

---

## 2. Stack técnico confirmado

| Componente | Tecnología | Versión |
|-----------|-----------|---------|
| Runtime | Node.js | 20 LTS |
| Lenguaje | TypeScript | 5.x |
| Gestor de procesos | PM2 + `pm2-windows-startup` | latest |
| Driver BD Firebird | `node-firebird-native-api` | latest |
| Cliente HTTP | `axios` | ^1.6 |
| Logger | `winston` + `winston-daily-rotate-file` | latest |
| Scheduler | `node-cron` | ^3.0 |
| Framework web | Express.js | ^4.18 |
| Frontend UI | HTML + HTMX + Tailwind CSS (CDN) | latest |
| Variables de entorno | `dotenv` | ^16.3 |
| Manejo de config | JSON (`config.json`) | nativo |

**Decisión de UI:** Tailwind CSS vía CDN (sin build step). HTMX para interactividad sin JavaScript pesado. Esto minimiza dependencias de build y facilita el deploy en Windows.

---

## 3. Estructura del proyecto

```
C:\apps\siemens-middleware\
├── package.json
├── tsconfig.json
├── ecosystem.config.js          ← Configuración PM2
├── .env.example                 ← Plantilla de secretos
├── .env                         ← Secretos reales (NO en git)
├── config.json                  ← Config operativa (editable desde UI)
├── README.md
├── src/
│   ├── index.ts                 ← Entry point + bootstrap
│   ├── config/
│   │   ├── env.ts               ← Carga .env (secretos)
│   │   └── runtime.ts           ← Carga config.json (operativo)
│   ├── db/
│   │   ├── firebird.ts          ← Conexión Firebird nativa
│   │   ├── queries/
│   │   │   ├── inventory.ts     ← Query de inventario
│   │   │   └── sales.ts         ← Query de ventas
│   │   └── filter.ts            ← Filtro LIN_PROD
│   ├── siemens/
│   │   ├── api.ts               ← Cliente API REST Siemens
│   │   ├── inventory.ts         ← Transformador inventario
│   │   └── sales.ts             ← Transformador ventas
│   ├── scheduler/
│   │   └── cron.ts              ← node-cron jobs
│   ├── logger/
│   │   └── winston.ts           ← Configuración logger
│   ├── ui/
│   │   ├── server.ts            ← Express + rutas
│   │   ├── routes/
│   │   │   ├── dashboard.ts
│   │   │   ├── config.ts
│   │   │   ├── actions.ts
│   │   │   ├── logs.ts
│   │   │   └── diagnostics.ts
│   │   └── views/                ← Templates HTML
│   │       ├── layout.html
│   │       ├── dashboard.html
│   │       ├── config.html
│   │       ├── actions.html
│   │       └── logs.html
│   └── jobs/
│       ├── runInventory.ts      ← Job completo inventario
│       └── runSales.ts          ← Job completo ventas
├── public/
│   ├── logo_aga_letras_2.png    ← Logo del cliente
│   └── partner.png              ← Badge Approved Partner Siemens
├── logs/                        ← Generado por winston (gitignore)
└── dist/                        ← Build de TypeScript (gitignore)
```

---

## 4. Modelo de datos

### 4.1 Secretos — Estrategia híbrida

**Decisión arquitectónica:** Los secretos están **separados en dos lugares** según criticidad y necesidad de cambio:

| Secreto | Ubicación | Editable desde UI | Razón |
|---------|-----------|-------------------|-------|
| `SIEMENS_BASE_URL` | `config.json` | ✅ Sí | Rara vez cambia, pero debe poder cambiarse sin redeploy |
| `SIEMENS_API_KEY` | `config.json` | ✅ **Sí** | Necesita poder actualizarse desde UI sin tocar código |
| `FIREBIRD_DB_PATH` | `config.json` | ✅ Sí | Diferente entre QAS y PRD |
| `FIREBIRD_USER` | `config.json` | ✅ Sí | Diferentes ambientes |
| `FIREBIRD_PASSWORD` | `.env` | ❌ No (requiere reinicio) | Más sensible, raramente cambia |
| `UI_PORT` | `.env` | ❌ No | Cambio estructural |
| `UI_USERNAME` | `.env` | ❌ No | Cambio estructural |
| `UI_PASSWORD_HASH` | `.env` | ❌ No | Cambio estructural |

**Razón de la decisión sobre API Key:**
- ✅ La UI es **local-only** (localhost:4567), no accesible desde la red
- ✅ Solo usuarios autorizados pueden acceder a la UI (HTTP Basic Auth)
- ✅ Permite actualizar la API Key sin reiniciar el servicio ni editar archivos
- ✅ Cambio se refleja en la siguiente ejecución del job (no requiere restart)
- ⚠️ Mitigación: **nunca se loguea completa**, **nunca se muestra completa** en UI (solo enmascarada)

### 4.2 Config operativa (`config.json` — editable desde UI)

```json
{
  "siemens": {
    "base_url": "https://api.pos.siemens.com",
    "api_key": "I1kLfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv",
    "environment": "QUA",
    "distributor_sender_id": "MX-REPRESENTACIONES"
  },
  "firebird": {
    "db_path": "C:/Program Files/Aspel/Aspel SAE 10.0/BD/SAE10.FDB",
    "user": "readonly_siemens_user",
    "password_source": "env:FIREBIRD_PASSWORD"
  },
  "schedules": {
    "inventory": {
      "enabled": true,
      "cron": "0 2 * * *",
      "timezone": "America/Mexico_City"
    },
    "sales": {
      "enabled": true,
      "cron": "0 3 * * *",
      "timezone": "America/Mexico_City"
    }
  },
  "batch_size": 3000,
  "retry_policy": {
    "max_retries": 5,
    "initial_delay_ms": 2000,
    "backoff_multiplier": 2,
    "max_delay_ms": 60000
  },
  "siemens_line_filter": {
    "enabled": true,
    "lines": ["BAJA", "SINU", "SIMAT", "LP", "DRIVE", "MOTOR", "SINUM", "SERVI", "OBSO", "SENSO", "SERVO", "INSTR", "UPS", "SIMA", "ESPE"],
    "include_inactive_products": true
  },
  "optional_fields": {
    "inventory": {
      "distributor_order_taking_branch_name": false,
      "distributor_order_taking_branch_id": true,
      "vendor_item_options": false,
      "upc_ean": false,
      "stock_item": false,
      "abc_segmentation": false
    },
    "sales": {
      "product_description": false,
      "customer_name": false,
      "discount_amount": false,
      "tax_amount": false
    }
  }
}
```

### 4.3 Secretos fijos (`.env` — solo config estructural)

```bash
# Solo credenciales que requieren reinicio del servicio
FIREBIRD_PASSWORD=<password>
UI_PORT=4567
UI_USERNAME=admin
UI_PASSWORD_HASH=<bcrypt_hash>
LOG_LEVEL=info
LOG_DIR=C:/apps/siemens-middleware/logs
```
UI_PASSWORD_HASH=<bcrypt_hash>

# ===== LOGGING =====
LOG_LEVEL=info
LOG_DIR=C:/apps/siemens-middleware/logs
```

### 4.2 Config operativa (`config.json` — editable desde UI)

```json
{
  "distributor_sender_id": "MX-REPRESENTACIONES",
  "environment": "QUA",
  "schedules": {
    "inventory": {
      "enabled": true,
      "cron": "0 2 * * *",
      "timezone": "America/Mexico_City"
    },
    "sales": {
      "enabled": true,
      "cron": "0 3 * * *",
      "timezone": "America/Mexico_City"
    }
  },
  "batch_size": 3000,
  "retry_policy": {
    "max_retries": 5,
    "initial_delay_ms": 2000,
    "backoff_multiplier": 2,
    "max_delay_ms": 60000
  },
  "siemens_line_filter": {
    "enabled": true,
    "lines": ["BAJA", "SINU", "SIMAT", "LP", "DRIVE", "MOTOR", "SINUM", "SERVI", "OBSO", "SENSO", "SERVO", "INSTR", "UPS", "SIMA", "ESPE"],
    "include_inactive_products": true
  },
  "optional_fields": {
    "inventory": {
      "distributor_order_taking_branch_name": false,
      "distributor_order_taking_branch_id": true,
      "vendor_item_options": false,
      "upc_ean": false,
      "stock_item": false,
      "abc_segmentation": false
    },
    "sales": {
      "product_description": false,
      "customer_name": false,
      "discount_amount": false,
      "tax_amount": false
    }
  }
}
```

---

## 5. Requisitos funcionales

### RF-1: Conexión a Firebird 5.0

**Implementación:** `src/db/firebird.ts`

```typescript
import Firebird from 'node-firebird-native-api';

// Singleton connection pool
const pool = new Firebird.pool({
  host: 'localhost',
  port: 3050,
  database: process.env.FIREBIRD_DB_PATH,
  user: process.env.FIREBIRD_USER,
  password: process.env.FIREBIRD_PASSWORD,
  minConnections: 1,
  maxConnections: 5,
  timeout: 30000
});
```

**Requisitos:**
- Conexión por `fbclient.dll` (incluida con SAE 10)
- Pool de conexiones con 1-5 conexiones concurrentes
- Timeout de 30s por query
- Reconexión automática si la conexión se cae
- Logs de queries lentas (>5s) con WARN level

### RF-2: Query de Inventario

**Implementación:** `src/db/queries/inventory.ts`

```typescript
export async function fetchInventorySnapshot(): Promise<InventoryRecord[]> {
  const lines = config.siemens_line_filter.lines;
  const placeholders = lines.map((_, i) => `?`).join(',');

  const sql = `
    SELECT
      TRIM(CVE_ART) AS vendor_item_number,
      TRIM(DESCR) AS product_description,
      TRIM(LIN_PROD) AS line,
      TRIM(UNI_MED) AS unit_of_measure,
      EXIST AS quantity_on_hand
    FROM INVE01
    WHERE TRIM(LIN_PROD) IN (${placeholders})
      ${config.siemens_line_filter.include_inactive_products ? '' : "AND STATUS = 'A'"}
      AND EXIST IS NOT NULL
    ORDER BY CVE_ART
  `;

  return await pool.query(sql, lines);
}
```

**Notas:**
- Para SAE 10 los nombres pueden ser `INVE` en lugar de `INVE01` — ajustar según resultado de Fase 1.
- La BD actual es SAE 9.0 con `INVE01`; al migrar a SAE 10 verificar el nombre.

### RF-3: Query de Ventas (con filtro de marca)

**Implementación:** `src/db/queries/sales.ts`

```typescript
export async function fetchSalesByDate(date: Date): Promise<SalesRecord[]> {
  const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD
  const lines = config.siemens_line_filter.lines;
  const placeholders = lines.map((_, i) => `?`).join(',');

  const sql = `
    SELECT
      TRIM(f.CVE_DOC) AS invoice_number,
      f.FECHA_DOC AS invoice_date,
      d.NUM_PAR AS line_item,
      TRIM(d.CVE_ART) AS vendor_item_number,
      i.DESCR AS product_description,
      d.CANT AS quantity,
      d.PREC AS unit_price,
      d.IMPU1 AS extended_cost,
      COALESCE(d.NUM_ALM, f.NUM_ALMA, 1) AS branch_id
    FROM FACTF01 f
    INNER JOIN PAR_FACTF01 d ON d.CVE_DOC = f.CVE_DOC
    INNER JOIN INVE01 i ON i.CVE_ART = d.CVE_ART
    WHERE f.FECHA_DOC = ?
      AND f.STATUS <> 'C'
      AND TRIM(i.LIN_PROD) IN (${placeholders})
    ORDER BY f.CVE_DOC, d.NUM_PAR
  `;

  return await pool.query(sql, [dateStr, ...lines]);
}
```

**Lógica de filtrado de factura:**
1. Lee todas las líneas de la factura con JOIN a INVE
2. Filtra solo las líneas con `LIN_PROD` en la lista Siemens
3. Si la factura tiene 0 líneas tras el filtro → se omite completa
4. Si tiene ≥1 línea → se envía solo con esas líneas

### RF-4: Transformador a esquema Siemens

**Implementación:** `src/siemens/inventory.ts` y `src/siemens/sales.ts`

**Inventario (5 campos requeridos):**
```typescript
function mapInventoryRecord(rec: InventoryRecord): SiemensInventoryRecord {
  return {
    distributor_sender_id: config.distributor_sender_id,
    distributor_inventory_date: today(),
    vendor_item_number: rec.vendor_item_number,
    quantity: rec.quantity_on_hand,
    quantity_unit_of_measure: mapUnitOfMeasure(rec.unit_of_measure)
  };
  // Campos opcionales según config.optional_fields.inventory
}
```

**Ventas (10 campos requeridos):**
```typescript
function mapSalesRecord(rec: SalesRecord): SiemensSalesRecord {
  return {
    distributor_sender_id: config.distributor_sender_id,
    distributor_invoice_number: rec.invoice_number,
    distributor_invoice_line_item: String(rec.line_item),
    distributor_invoice_date: rec.invoice_date,
    distributor_order_taking_branch_id: String(rec.branch_id),
    vendor_item_number: rec.vendor_item_number,
    quantity: rec.quantity,
    unit_cost: rec.extended_cost / rec.quantity,  // calculado
    extended_cost_of_goods_sold: rec.extended_cost,
    currency_code: "MXN"
  };
}
```

**Mapeo de unidad de medida** (importante — documentado en MAPEO_CAMPO_A_CAMPO):
```typescript
function mapUnitOfMeasure(uni: string): string {
  // SAE guarda "pz" (piezas). Siemens ejemplo usa "each".
  // Por defecto mantener "pz". Si el cliente confirma cambio, actualizar.
  return uni || "PZA";
}
```

### RF-5: Cliente API Siemens con reintentos

**Implementación:** `src/siemens/api.ts`

**Cambio importante:** La API Key se lee desde `config.json` (no `.env`) para permitir actualización desde UI sin reinicio.

```typescript
async function sendBatch(payload: any[], endpoint: string): Promise<{status: number, body: string}> {
  // Leer config en vivo (no cachear la key, leer siempre fresh)
  const config = readRuntimeConfig();
  const apiKey = config.siemens.api_key;
  const baseUrl = config.siemens.base_url;
  const env = config.siemens.environment;

  if (!apiKey) throw new Error('API Key no configurada. Configurar desde UI.');

  const url = `${baseUrl}/${env}${endpoint}`;
  const maxRetries = config.retry_policy.max_retries;
  let delay = config.retry_policy.initial_delay_ms;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await axios.post(url, payload, {
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey  // ← desde config.json, no .env
        },
        timeout: 15000
      });
      logger.info(`✓ HTTP ${response.status} | ${payload.length} registros | key=${maskApiKey(apiKey)}`);
      return {status: response.status, body: JSON.stringify(response.data)};
    } catch (error) {
      if (attempt === maxRetries) throw error;
      if (error.response?.status >= 400 && error.response?.status < 500) {
        // 4xx — no reintentar, alerta inmediata
        logger.error(`✗ HTTP ${error.response.status} | No retry (4xx) | key=${maskApiKey(apiKey)}`);
        throw error;
      }
      logger.warn(`⚠ HTTP ${error.response?.status || 'TIMEOUT'} | intento ${attempt}/${maxRetries}, retry en ${delay}ms`);
      await sleep(delay);
      delay = Math.min(delay * config.retry_policy.backoff_multiplier, config.retry_policy.max_delay_ms);
    }
  }
}
```

### RF-6: Scheduler con node-cron — INDEPENDIENTES

**Implementación:** `src/scheduler/cron.ts`

**Principio clave:** Los dos jobs (inventario y ventas) son **completamente independientes** entre sí. Un fallo en uno NO afecta al otro. Cada uno tiene:
- Su propio schedule
- Su propio try/catch (errores no se propagan)
- Su propio contexto de logging
- Su propio estado en BD
- Su propio toggle ON/OFF

```typescript
import cron from 'node-cron';
import { runInventoryJob } from '../jobs/runInventory';
import { runSalesJob } from '../jobs/runSales';
import { logger } from '../logger/winston';

interface JobExecution {
  job_name: string;
  start_time: Date;
  end_time?: Date;
  status: 'running' | 'success' | 'failed' | 'skipped';
  records_sent?: number;
  error_message?: string;
}

// Estado en memoria (también persistido a JSON para visibilidad)
const executionHistory: JobExecution[] = [];

// ===== JOB DE INVENTARIO (completamente independiente) =====
async function executeInventoryJob(): Promise<void> {
  const execution: JobExecution = {
    job_name: 'inventory',
    start_time: new Date(),
    status: 'running'
  };
  executionHistory.unshift(execution);

  const jobLogger = logger.child({ job: 'inventory', execution_id: execution.start_time.getTime() });

  try {
    if (!config.schedules.inventory.enabled) {
      execution.status = 'skipped';
      execution.end_time = new Date();
      jobLogger.info('Job de inventario desactivado, saltando');
      return;
    }

    jobLogger.info('Iniciando job de inventario');
    const result = await runInventoryJob();
    execution.status = 'success';
    execution.records_sent = result.totalSent;
    execution.end_time = new Date();
    jobLogger.info(`Inventario completado: ${result.totalSent} registros en ${result.durationMs}ms`);
  } catch (error) {
    // ⚠️ CRÍTICO: catch aquí aísla el error. El job de ventas sigue funcionando.
    execution.status = 'failed';
    execution.error_message = String(error);
    execution.end_time = new Date();
    jobLogger.error(`Fallo en inventario: ${error}`);
    // NO relanzamos el error — el scheduler sigue vivo
  }
}

// ===== JOB DE VENTAS (completamente independiente) =====
async function executeSalesJob(): Promise<void> {
  const execution: JobExecution = {
    job_name: 'sales',
    start_time: new Date(),
    status: 'running'
  };
  executionHistory.unshift(execution);

  const jobLogger = logger.child({ job: 'sales', execution_id: execution.start_time.getTime() });

  try {
    if (!config.schedules.sales.enabled) {
      execution.status = 'skipped';
      execution.end_time = new Date();
      jobLogger.info('Job de ventas desactivado, saltando');
      return;
    }

    jobLogger.info('Iniciando job de ventas');
    const result = await runSalesJob();
    execution.status = 'success';
    execution.records_sent = result.totalSent;
    execution.end_time = new Date();
    jobLogger.info(`Ventas completadas: ${result.totalSent} registros en ${result.durationMs}ms`);
  } catch (error) {
    // ⚠️ CRÍTICO: catch aquí aísla el error.
    execution.status = 'failed';
    execution.error_message = String(error);
    execution.end_time = new Date();
    jobLogger.error(`Fallo en ventas: ${error}`);
  }
}

// ===== REGISTRO DE CRONS (independientes) =====
export function startSchedulers(): void {
  // Inventario — su propio cron, no afecta al otro
  cron.schedule(config.schedules.inventory.cron, () => {
    executeInventoryJob().catch(err =>
      logger.error(`Error no capturado en executeInventoryJob: ${err}`)
    );
  }, { timezone: config.schedules.inventory.timezone });

  // Ventas — su propio cron, no afecta al otro
  cron.schedule(config.schedules.sales.cron, () => {
    executeSalesJob().catch(err =>
      logger.error(`Error no capturado en executeSalesJob: ${err}`)
    );
  }, { timezone: config.schedules.sales.timezone });

  logger.info(`Schedulers iniciados: inventario=${config.schedules.inventory.cron}, ventas=${config.schedules.sales.cron}`);
}

export function getExecutionHistory(): JobExecution[] {
  return executionHistory.slice(0, 50); // Últimas 50 ejecuciones
}
```

**Características de independencia:**

| Aspecto | Inventario | Ventas |
|---------|-----------|--------|
| **Schedule propio** | `config.schedules.inventory.cron` | `config.schedules.sales.cron` |
| **Toggle ON/OFF** | `config.schedules.inventory.enabled` | `config.schedules.sales.enabled` |
| **Try/catch aislado** | Sí — error no se propaga | Sí — error no se propaga |
| **Logger contextual** | `logger.child({ job: 'inventory' })` | `logger.child({ job: 'sales' })` |
| **Estado independiente** | Tabla `executions` filtrable | Tabla `executions` filtrable |
| **Pool de conexiones DB** | Comparte con ventas (pool: 5) | Comparte con inventario (pool: 5) |
| **Ejecución concurrente** | ✅ Sí (pueden solaparse) | ✅ Sí (pueden solaparse) |

**Default sugerido:**
- Inventario: `0 2 * * *` (02:00 AM)
- Ventas: `0 3 * * *` (03:00 AM)
- Diferencia de 1 hora para evitar competencia por recursos

**Garantías de aislamiento:**
1. Si el job de inventario falla a las 02:00, el job de ventas a las 03:00 se ejecuta normalmente
2. Si el job de ventas falla, el siguiente inventario se ejecuta normalmente
3. Si ambos están configurados a la misma hora, ambos corren en paralelo (pool de DB lo soporta)
4. PM2 mantiene el proceso vivo aunque un job crashee (gracias al try/catch interno)

**Visibilidad en UI:**
- Dashboard muestra estado separado por job (✓ verde o ⚠ rojo)
- Historial filtrable por job (dropdown "Inventario" / "Ventas" / "Todos")
- Cada ejecución tiene su propia fila con timestamp, duración, status, registros

### RF-7: UI Local con Logo Repaga + Badge Approved Partner

**Implementación:** `src/ui/server.ts` + `src/ui/views/*.html`

**Diseño de seguridad para campos sensibles (API Key, password BD):**

- 🔒 **Enmascaramiento**: API Key se muestra como `I1kL****gbv` (primeros 3 + asteriscos + últimos 3)
- 🔒 **Campo password**: siempre tipo `password` (oculto)
- 🔒 **Botón "Mostrar/ocultar"**: el usuario puede revelar la key temporalmente para copiarla
- 🔒 **No se loguea NUNCA la key completa** ni en logs normales ni en errores
- 🔒 **Validación al guardar**: longitud mínima (32+ chars), formato esperado
- 🔒 **Indicador visual**: "Última actualización: 2026-07-21 14:30"

**Endpoint para actualizar secretos vía UI:**
```typescript
// src/ui/routes/config.ts
app.post('/api/config/siemens-key', basicAuth, async (req, res) => {
  const { api_key } = req.body;

  // Validar formato
  if (!api_key || api_key.length < 32) {
    return res.status(400).json({ error: 'API Key inválida (mínimo 32 caracteres)' });
  }

  // Actualizar config.json sin reiniciar
  const config = readConfig();
  config.siemens.api_key = api_key;
  writeConfig(config);

  // ⚠️ NO loguear la key, solo confirmar la acción
  logger.info('API Key actualizada por usuario', {
    key_last4: api_key.slice(-4),
    updated_by: req.auth?.user
  });

  res.json({
    success: true,
    key_preview: `${api_key.slice(0, 3)}****${api_key.slice(-3)}`,
    next_execution_will_use_new_key: true
  });
});
```

**Header de la UI (todas las páginas):**

```html
<!-- public/images/logo_aga_letras_2.png (472x382) -->
<!-- public/images/partner.png (496x241) -->
<header class="bg-white border-b border-gray-200 px-6 py-4">
  <div class="flex items-center justify-between max-w-7xl mx-auto">
    <div class="flex items-center gap-4">
      <img src="/images/logo_aga_letras_2.png"
           alt="Representaciones Aga de Saltillo"
           class="h-12 w-auto">
      <div class="text-sm text-gray-600">
        <div class="font-semibold">Middleware Siemens PoSi</div>
        <div class="text-xs">Repaga × Siemens — v1.0</div>
      </div>
    </div>
    <div class="flex items-center gap-3">
      <span class="text-xs text-gray-500">Ambiente: <span class="font-mono font-bold" id="current-env">QUA</span></span>
      <img src="/images/partner.png"
           alt="Siemens Approved Partner — Value Added Reseller"
           class="h-10 w-auto">
    </div>
  </div>
</header>
```

**Páginas UI:**

#### `/` — Dashboard
- Tarjetas con última ejecución (Inventario, Ventas)
- Conteo de registros enviados
- Próxima ejecución programada
- Botones de acción rápida

#### `/config` — Configuración
- Lista de las 15 líneas Siemens (editables: agregar/quitar)
- Toggle por campo opcional
- Configuración de horarios
- Botón "Guardar" (escribe a `config.json`)

#### `/actions` — Acciones manuales
- Botón "Ejecutar Inventario ahora"
- Botón "Ejecutar Ventas ahora"
- Botón "Test conexión Siemens"
- Botón "Test conexión SAE"

#### `/logs` — Visor de logs
- Lista de archivos de log
- Filtrar por nivel (info/warn/error)
- Botón "Descargar log completo"

#### `/diagnostics` — Diagnóstico
- Estado de conexión a Firebird
- Estado de última request a Siemens
- Versión de node-firebird-native-api
- Variables de entorno (ocultando secretos)

**Estilos:** Tailwind CSS vía CDN.

**Layout responsive** — debe verse bien en 1280px y 1920px (cliente usa Windows en su PC).

### RF-8: Logging estructurado

**Implementación:** `src/logger/winston.ts`

**Reglas estrictas sobre secretos en logs:**

```typescript
// Helper para enmascarar API Key
export function maskApiKey(key: string | undefined): string {
  if (!key) return '[NOT SET]';
  if (key.length <= 6) return '****';
  return `${key.slice(0, 3)}****${key.slice(-3)}`;
}

// Uso en cualquier log que mencione la API Key:
logger.info('Iniciando job con credenciales', {
  api_key_preview: maskApiKey(config.siemens.api_key),  // NUNCA la key completa
  environment: config.siemens.environment
});
```

**Lo que NUNCA se loguea:**
- ❌ API Key completa (ni en logs normales, ni en errores, ni en stack traces)
- ❌ Password de BD (ni completa ni hasheada)
- ❌ Tokens de sesión de UI
- ❌ Datos personales completos de clientes (RFC, razón social)

**Lo que SÍ se puede loguear (enmascarado):**
- ✅ `maskApiKey()` → solo primeros 3 + asteriscos + últimos 3
- ✅ Hostname y puerto de BD
- ✅ Conteos y métricas
- ✅ Fechas, duraciones, status codes HTTP

```typescript
import winston from 'winston';
import 'winston-daily-rotate-file';

const transport = new winston.transports.DailyRotateFile({
  filename: `${process.env.LOG_DIR}/%DATE%-middleware.log`,
  datePattern: 'YYYY-MM-DD',
  maxFiles: '90d',        // Retención 90 días
  maxSize: '20m',
  zippedArchive: true
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'siemens-middleware' },
  transports: [transport, new winston.transports.Console()]
});
```

---

## 6. Manejo de errores y alertas

**Principio clave:** Aislamiento total entre jobs. El error de un job NO afecta al otro.

| Escenario | Acción | ¿Afecta al otro job? |
|-----------|--------|----------------------|
| HTTP 5xx de Siemens (en job inventario) | Reintentar con backoff (5 intentos) | ❌ NO |
| HTTP 5xx de Siemens (en job ventas) | Reintentar con backoff (5 intentos) | ❌ NO |
| HTTP 4xx de Siemens | NO reintentar — log + alerta | ❌ NO |
| Timeout DB Firebird (en job inventario) | Reintentar 3 veces, alerta | ❌ NO |
| Timeout DB Firebird (en job ventas) | Reintentar 3 veces, alerta | ❌ NO |
| BD Firebird no accesible | Alerta inmediata + skip ejecución del job afectado | ❌ NO (solo ese job) |
| Crashes no capturados en job inventario | Catch interno + log | ❌ NO |
| Crashes no capturados en job ventas | Catch interno + log | ❌ NO |
| Inventario >5000 registros | Alerta informativa (debería partirse) | ❌ NO |
| Factura sin líneas Siemens tras filtro | Log a nivel debug (normal) | N/A |
| >10 fallos consecutivos (de un job específico) | Alerta crítica solo de ese job | ❌ NO |

**Aislamiento por capas:**

1. **Try/catch en cada job** (RF-6): Ningún error se propaga al scheduler
2. **Pool de DB compartido** (5 conexiones): Si un job satura el pool, el otro espera (no falla)
3. **Loggers con contexto** (`logger.child({ job: 'X' })`): Permite filtrar por job en logs
4. **Estado independiente**: Tabla de ejecuciones con `job_name` permite ver historial aislado
5. **PM2 externo**: Si TODO el proceso muere, PM2 lo reinicia (protección de segundo nivel)

**Notificaciones:** Por ahora solo a logs. Email/webhook se cotiza aparte (sección 3 propuesta económica).

---

## 7. Procedimiento de instalación (Windows)

```powershell
# 1. Crear directorio
mkdir C:\apps\siemens-middleware
cd C:\apps\siemens-middleware

# 2. Instalar Node.js 20 LTS (si no está)
# Descargar de https://nodejs.org

# 3. Copiar archivos del proyecto
# (repositorio Git o archivos generados)

# 4. Instalar dependencias
npm install --production

# 5. Compilar TypeScript
npm run build

# 6. Copiar .env.example a .env y llenar secretos
copy .env.example .env
notepad .env

# 7. Copiar config.json.example a config.json
copy config.json.example config.json

# 8. Instalar PM2 + plugin Windows
npm install -g pm2
npm install -g pm2-windows-startup

# 9. Registrar como Servicio Windows
pm2-startup install
pm2 start ecosystem.config.js
pm2 save

# 10. Verificar
pm2 status
pm2 logs siemens-middleware --lines 50

# 11. Abrir UI en navegador
start http://localhost:4567
```

---

## 8. Validación previa al go-live (gates SOFIA + GEMINI)

### 8.1 Gates de SOFIA (self-review)

Antes de reportar la implementación como lista:

```markdown
## Self-Review Checklist (SOFIA)

### Funcionalidad
- [ ] El middleware inicia correctamente sin errores
- [ ] Conexión a Firebird funciona contra BD real
- [ ] Query de inventario retorna ~21,805 productos (con filtro LIN_PROD)
- [ ] Query de ventas filtra correctamente (ejecutar con factura CFDI_32670 y verificar 4 de 6 líneas)
- [ ] Cliente API acepta HTTP 201 con payload sintético
- [ ] Reintentos funcionan ante 5xx (verificar con logs)
- [ ] UI carga en localhost:4567 con logo y badge visibles
- [ ] Botones de acción manual funcionan
- [ ] Configuración editable persiste en config.json
- [ ] node-cron dispara a la hora programada (verificar con log)

### Calidad de código
- [ ] No hay `any` types sin justificación
- [ ] TypeScript compila sin errores ni warnings
- [ ] ESLint pasa sin errores
- [ ] Tests unitarios pasan (mínimo 70% coverage)
- [ ] Logs estructurados en formato JSON
- [ ] No hay secretos en código
- [ ] .env.example está completo y documentado

### Performance
- [ ] Inventario se ejecuta en <5 minutos para 21,805 productos
- [ ] Ventas diarias se ejecutan en <2 minutos
- [ ] UI responde en <500ms

### Seguridad
- [ ] UI requiere autenticación (HTTP Basic Auth)
- [ ] API Keys nunca se loguean
- [ ] Conexión a Firebird es solo lectura (validar en DB)
- [ ] Logs no contienen datos personales completos
```

### 8.2 Gates de GEMINI (auditoría de calidad)

GEMINI validará como **segunda mano** antes de marcar como listo para commit:

1. ¿El código refleja la SPEC?
2. ¿Hay code smells evidentes?
3. ¿Los tests cubren los edge cases listados?
4. ¿Algún riesgo de regresión?

**Plantilla de handoff a SOFIA (según instrucciones globales):**

```
Validaciones obligatorias antes de cerrar:
  1. npx tsc --noEmit (typecheck)
  2. npm test
  3. npx eslint . (si existe)
Antes de reportar como listo, NO pidas qodo (está sunset).
En su lugar, incluye en el reporte final un self-review manual:
  - ¿El código refleja la SPEC?
  - ¿Hay code smells evidentes?
  - ¿Los tests cubren los edge cases listados en la SPEC?
  - ¿Algún riesgo de regresión?
```

---

## 9. Estructura de entregables

```
C:\apps\siemens-middleware\
├── package.json
├── tsconfig.json
├── ecosystem.config.js
├── .env.example
├── config.json.example
├── README.md                       ← Manual de instalación y operación
├── MANUAL_OPERACION.pdf            ← Manual de usuario final
├── src/                            ← Código fuente
├── public/                         ← Assets UI
│   ├── logo_aga_letras_2.png
│   └── partner.png
├── logs/                           ← Generado runtime
└── tests/                          ← Tests unitarios
```

**Entregables adicionales:**
- `README.md` con instrucciones paso a paso
- `MANUAL_OPERACION.pdf` para el Ing. Paco (4-6 páginas)
- `PLAN_PRUEBAS.md` con casos de prueba documentados

---

## 10. Riesgos conocidos y mitigaciones

| Riesgo | Mitigación |
|--------|-----------|
| Sandbox QUA intermitente (502) | Reintentos con backoff; ir directo a PRD para go-live |
| Esquema SAE 10 distinto a SAE 9 | Queries parametrizadas; verificar nombres de tablas en Fase 1 |
| Cambio de líneas Siemens en catálogo | Lista editable desde UI (config.json) |
| Antivirus bloquea Node.js | Excluir `node.exe` y `C:\apps\siemens-middleware\` del antivirus |
| Reinicios de Windows Update | PM2 + `pm2-windows-startup` reinicia automáticamente |
| Credenciales QUA expiran | Alertas 30 días antes + manual de renovación |

---

## 11. Definición de Done (DoD)

- [ ] Código compila sin errores TypeScript
- [ ] Tests unitarios pasan con >70% coverage
- [ ] Self-review de SOFIA completado y aprobado
- [ ] GEMINI (auditoría) aprobó sin issues críticos
- [ ] Inventario diario se ejecuta sin errores en QUA por **5 días consecutivos**
- [ ] Ventas diarias se ejecutan sin errores en QUA por **5 días consecutivos**
- [ ] UI accesible y funcional con logos correctos
- [ ] Documentación (README + Manual) entregada
- [ ] Instalación verificada en PC Windows real (no solo dev)

---

## 12. Próximos pasos post-implementación

1. **Fase 3:** UAT con Ing. Paco (el cliente prueba con datos reales)
2. **Solicitar credenciales PRD** al Siemens Data Steward
3. **Configurar ambiente PRD** en `config.json` (`environment: "PRD"`)
4. **Ejecutar primer envío real a PRD** con monitoreo intensivo
5. **Cerrar Fase 3** y entregar al cliente
6. **Facturación** del hito final (30% = $18,000 + IVA)

---

## 13. Referencias técnicas (no implementar sin leer)

- `repaga-siemens/PROPUESTA_TECNICA_SAE10_SIEMENS.md` — Arquitectura completa
- `repaga-siemens/MAPEO_CAMPO_A_CAMPO.md` — Mapeo de campos validado contra API
- `repaga-siemens/MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md` — Patrón 502 conocido
- Documentación Siemens PoSi: https://pos.mx.lowcode.siemens.cloud/

---

*SPEC preparada por INTEGRA — ID: SPEC-IMPL-20260721-01*
*Lista para delegación a SOFIA en cuanto se apruebe la propuesta y llegue la OC del cliente.*