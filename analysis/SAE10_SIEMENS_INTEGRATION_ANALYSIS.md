# Integración SAE 10 ↔ Siemens PoSi - Análisis y Cotización

**Fecha:** 2026-07-06  
**Cliente:** Aspel SAE 10  
**Proveedor destino:** Siemens PoSi Portal (Mendix Low-Code)  
**Preparado por:** INTEGRA  

---

## 1. Análisis de la situación

### 1.1 Aspel SAE 10 - Lo que sabemos

**Aspel SAE 10** es un ERP/POS mexicano ampliamente usado en PyMEs. Características técnicas relevantes para esta integración:

| Aspecto | Detalle |
|---------|---------|
| Base de datos | **Firebird** (default) o **SQL Server** |
| Módulos clave | Inventarios, Clientes, Productos, Facturación, Cuentas por Cobrar |
| APIs nativas | **REST limitado** desde SAE 10.0+ (no cubre todo) |
| Exportación | CSV/Excel nativo en algunos módulos |
| Reporteador | "Generador de Reportes" propio de Aspel |
| Licenciamiento | Por usuario, perpetua o suscripción |

### 1.2 Los 2 flujos a integrar

| Flujo | Método en Siemens | Datos de SAE 10 |
|-------|-------------------|----------------|
| **Inventario** | **API únicamente** | Existencias actuales por producto/almacén |
| **Value Flow (Ventas)** | API / SFTP / EDI | Facturas/remisiones emitidas en periodo |

### 1.3 Brechas técnicas identificadas

1. **Mapeo de campos**: Los nombres técnicos de campos Siemens NO están documentados públicamente — vienen en una **plantilla entregada por el Data Steward regional** (requiere permisos elevados en el portal; tu usuario actual `frank@vcorp.mx` no parece tenerlos).
2. **Capítulos ocultos**: Existe un capítulo **"API errors"** referenciado pero no visible sin permisos elevados.
3. **Ejemplos de body**: Solo visibles con permisos elevados ("Inventory Example" y "PoS Example" son imágenes restringidas).

---

## 2. Mi opinión arquitectónica

### 2.1 Enfoque recomendado: **Middleware intermedio**

No recomiendo hacer la integración directa "SAE 10 → Siemens" porque:
- SAE 10 no soporta conectividad directa a SFTP desde su UI.
- El mapeo de campos Siemens es muy específico y requiere transformación.
- Necesitamos trazabilidad, reintentos y logging.

### 2.2 Arquitectura propuesta

```
┌──────────────┐         ┌──────────────────┐         ┌────────────────────┐
│   SAE 10      │ ──────▶ │  MIDDLEWARE      │ ──────▶ │  Siemens PoSi      │
│  (Firebird / │  Lee    │  (Servicio .NET/ │  POST   │  API: Inventory    │
│   SQL Server)│ ◀────── │   Node/Python)   │  o CSV  │  API / SFTP: PoS   │
└──────────────┘ Escribe  └──────────────────┘         └────────────────────┘
                              │
                              ├─▶ Logs (archivo/BD)
                              ├─▶ Retry queue
                              └─▶ Dashboard de status
```

**Stack sugerido para el middleware:**
- **Node.js + TypeScript** (rápido, ecosistema HTTP maduro) **o** **Python** (si el equipo lo domina).
- Conexión a SAE 10 vía **driver Firebird/SQL Server** (`node-firebird`, `mssql`, `pyodbc`).
- Cliente SFTP: `ssh2-sftp-client` (Node) o `pysftp` (Python).
- Cliente HTTP: `axios` o `requests`.
- Orquestación: **Windows Task Scheduler** o servicio systemd con cron.

### 2.3 Decisiones clave a tomar con el cliente

| Decisión | Opción A | Opción B |
|----------|----------|----------|
| Lectura de SAE 10 | **Base de datos directa** (más rápido, más invasivo) | **API REST de SAE** (limitada) + exports manuales |
| Value Flow | **API REST de Siemens** | **SFTP con CSV** |
| Frecuencia inventario | **Diario** | **Bajo demanda** |
| Frecuencia ventas | **Diario** (cierre D-1) | **Intradiario** |

### 2.4 Riesgos identificados

| Riesgo | Mitigación |
|--------|-----------|
| Cambios en el esquema Siemens | Validación de payload + alerta por diferencias |
| Credenciales vencidas | Renovación proactiva + alerta 30 días antes |
| Datos incompletos en SAE 10 | Validación previa al envío + cuarentena |
| Tamaño del batch >3000 | Particionar automáticamente |
| BOM en CSV (SFTP) | Validación + script de limpieza |
| Errores 4xx intermitentes | Cola de reintentos con backoff exponencial |

---

## 3. Propuesta económica (cotización sugerida)

### Fase 1 - Discovery & Credenciales
| Actividad | Horas |
|-----------|-------|
| Reunión con Siemens Data Steward para solicitar API keys + plantillas | 2 |
| Análisis de BD SAE 10 y modelo de datos | 4 |
| Mapeo campo a campo (SAE 10 ↔ Siemens) | 8 |
| Documento de mapeo aprobado por cliente | 4 |
| **Subtotal Fase 1** | **18 h** |

### Fase 2 - Desarrollo del Middleware
| Actividad | Horas |
|-----------|-------|
| Configuración de proyecto + conexión a SAE 10 | 6 |
| Módulo de lectura de Inventario SAE 10 | 8 |
| Módulo de lectura de Ventas SAE 10 | 10 |
| Transformador a formato Siemens (JSON/CSV) | 12 |
| Cliente API Siemens (con reintentos y logging) | 8 |
| Cliente SFTP Siemens (si aplica) | 6 |
| **Subtotal Fase 2** | **50 h** |

### Fase 3 - Pruebas & Go-Live
| Actividad | Horas |
|-----------|-------|
| Pruebas unitarias y de integración | 10 |
| Pruebas en ambiente QAS de Siemens | 8 |
| UAT con usuario final | 6 |
| Despliegue a producción + monitoreo 1ra semana | 8 |
| Documentación técnica + manual de operación | 6 |
| **Subtotal Fase 3** | **38 h** |

### Fase 4 - Operación (mensual opcional)
| Actividad | Horas/mes |
|-----------|-----------|
| Monitoreo de procesos | 4 |
| Resolución de incidencias | 4-8 |
| Actualizaciones por cambios Siemens/SAE | 2-4 |

---

## 4. Estructura de cotización recomendada

| Concepto | Horas | Precio unitario sugerido* | Subtotal |
|----------|-------|---------------------------|----------|
| Fase 1: Discovery | 18 | $X MXN/h | $XX,XXX |
| Fase 2: Desarrollo | 50 | $X MXN/h | $XX,XXX |
| Fase 3: Pruebas & Go-Live | 38 | $X MXN/h | $XX,XXX |
| **Total Proyecto** | **106** | | **$XXX,XXX** |
| Mantenimiento mensual (opcional) | 12 | $X MXN/h | $X,XXX/mes |

*Precio unitario según tarifa del despacho. Sugerido: $1,500-$2,500 MXN/h para este tipo de integración.

**Esquema de pagos recomendado:**
- 30% aprobación de cotización
- 40% entrega Fase 2 (middleware funcional)
- 30% Go-live exitoso

---

## 5. Lo que falta conseguir del lado Siemens

Antes de poder cotizar con precisión o arrancar Fase 2, se requiere:

- [ ] **Permisos elevados en el portal** para ver los capítulos "API errors" y los ejemplos de body (Inventory y PoS). Solicitar a Siemens Data Admin de la empresa.
- [ ] **API Key de QAS y PRD** (Inventario y PoS). Solicitar al Data Steward.
- [ ] **Plantilla con nombres técnicos de campos** (Inventory y PoS). Solicitar al Data Steward.
- [ ] **Credenciales SFTP** (usuario + clave privada) si se elige SFTP para Value Flow.

---

## 6. Otros elementos en la documentación del portal

Durante la exploración encontré:

| Sección | Contenido | Relevancia |
|---------|-----------|------------|
| **Introduction** | Bienvenida y resumen PoSi | Bajo |
| **D&B Search** | Lookup de DUNS numbers en PoSi | Bajo (solo si necesitamos enriquecer datos de clientes) |
| **API Technical Documentation** | Endpoints, headers, body, responses, errors | **Crítico** |
| **SFTP Technical Documentation** | Conexión, carpetas, formato CSV, advertencias (BOM, timestamps) | **Crítico si elegimos SFTP** |
| **EDI Technical Documentation** | Estándar 867, "solo por excepción" | **No aplica** |

**Particularidades operativas críticas que la documentación enfatiza:**
- ⚠️ BOM en CSV causa errores en SFTP
- ⚠️ Preserve Timestamp en WinSCP debe estar deshabilitado
- ⚠️ Campos numéricos NO deben ir entrecomillados en CSV
- ⚠️ ≤3000 transacciones por batch API
- ⚠️ Fechas en ISO 8601 estricto

---

## 7. Próximos pasos sugeridos

1. **Decidir hoy**: ¿API o SFTP para Value Flow? (Recomiendo API por simplicidad operativa)
2. **Solicitar esta semana**: Permisos elevados + credenciales al Data Steward de Siemens.
3. **Agendar Fase 1**: Reunión de discovery (4-6 horas) en cuanto se tengan las plantillas.
4. **Levantar ORDER #1**: Cotización formal al cliente con el alcance y precio.

---

*Documento preparado por INTEGRA - ID: ARCH-20260706-01*  
*Pendiente OK del usuario para proceder a generar cotización formal y delegar Fase 1 a SOFIA.*