# PROPUESTA TÉCNICA

## Integración Aspel SAE 10 ↔ Siemens PoSi Portal

**ID Documento:** ARCH-20260706-02  
**Fecha:** 2026-07-06  
**Preparado por:**  Ing. Frank Saavedra|Vcorp  

### Datos del Cliente

| Campo                 | Valor                            |
| --------------------- | -------------------------------- |
| **Cliente**           | Representaciones Aga de Saltillo |
| **Contacto técnico**  | Ing. Francisco Aguirre           |
| **Email de contacto** | fcoaguirre@repaga.com.mx         |
| **Teléfono**          | 844 160 6737                     |

### Datos del Proyecto

| Campo               | Valor                                               |
| ------------------- | --------------------------------------------------- |
| **Sistema origen**  | **Aspel SAE 10** (Firebird 5.0)                     |
| **Sistema destino** | Siemens PoSi Portal (Mendix Low-Code)               |
| **Alcance**         | 2 flujos: Envío de Inventario + Value Flow (Ventas) |
| **Modalidad**       | Proyecto llave en mano + soporte go-live            |

> **v1.3 ** Considera: Aspel SAE 10 con Firebird 5.0, middleware en la misma PC de SAE 10, solicitud directa de credenciales al portal Siemens (sin reunión), 12,000 productos del cliente (4 batches de inventario), UI local de administración, soporte post go-live por intervención con presupuesto previo.  

---

## 1. RESUMEN EJECUTIVO

Esta propuesta describe la integración técnica entre el sistema ERP/POS **Aspel SAE 10** del cliente y el portal **Siemens PoSi** de Siemens AG, para el envío automatizado de dos flujos de información:

| #   | Flujo                   | Datos                                     | Método en Siemens                  |
| --- | ----------------------- | ----------------------------------------- | ---------------------------------- |
| 1   | **Envío de Inventario** | Existencias actuales por producto/almacén | API REST (único método disponible) |
| 2   | **Value Flow (Ventas)** | Facturas y remisiones emitidas en periodo | API REST o SFTP (CSV)              |

**Objetivo:** Proveer a Siemens información de inventario y ventas de manera automatizada, confiable y trazable, cumpliendo con los esquemas técnicos definidos por Siemens y minimizando la intervención manual.

---

## 2. ALCANCE

### 2.1 Dentro del alcance

- ✅ Lectura automatizada de datos desde SAE 10 (base de datos Firebird 5.0)
- ✅ Transformación de datos al esquema técnico de Siemens (PoS e Inventory)
- ✅ Envío mediante **API REST** a Siemens PoSi Portal (ambientes QAS y PRD)
- ✅ Envío mediante **SFTP con CSV UTF-8 sin BOM** (solo para Value Flow, alternativo)
- ✅ Logging, monitoreo, manejo de errores y reintentos
- ✅ Procesos programados (batch diario)
- ✅ Documentación técnica y manual de operación
- ✅ Pruebas en ambiente QAS de Siemens
- ✅ Puesta en producción y soporte de go-live

### 2.2 Fuera del alcance

- ❌ Modificaciones al esquema de base de datos de SAE 10
- ❌ Compra de licencias adicionales de Aspel SAE 10
- ❌ Integración EDI estándar 867 (solo aplica por excepción regional)
- ❌ Desarrollo de UI para usuarios finales del cliente
- ❌ Procesos batch con periodicidad inferior a 1 hora (no requerido)

---

## 3. ARQUITECTURA DE LA SOLUCIÓN

### 3.4 Interfaz gráfica de administración (UI local)

El middleware expone una **UI web ligera** accesible únicamente en `http://localhost:4567` desde el navegador del propio equipo. No es accesible desde la red.

**Funcionalidades expuestas:**

| Sección               | Qué puede hacer el usuario                                                                                              |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Dashboard**         | Ver última ejecución OK/error de cada flujo, conteo de registros enviados, próxima ejecución programada                 |
| **Configuración**     | Cambiar frecuencia (diaria, cada N horas, días específicos), hora de ejecución, ambiente QAS/PRD, tamaño máximo de lote, **distributor_sender_id** |
| **Acciones manuales** | Botones "Ejecutar Inventario ahora" / "Ejecutar Ventas ahora"                                                           |
| **Logs**              | Ver logs recientes, filtrar por nivel (info/warn/error), descargar log completo                                         |
| **Diagnóstico**       | Test de conexión a Siemens (API ping), test de conexión a BD SAE 10                                                     |
| **Activación**        | Toggle on/off por flujo sin editar archivos                                                                             |

**Stack de la UI:**

- Backend: Express.js (mismo proceso Node del middleware)
- Frontend: HTML + HTMX + Tailwind CSS (sin React/Vue)
- Autenticación: HTTP Basic Auth con credenciales en `.env`
- Puerto: `localhost:4567` (firewall de Windows puede mantenerse bloqueando el exterior)

**¿Por qué una UI local y no archivos de configuración puros?**

- Permite al operador del cliente cambiar frecuencias, ejecutar manualmente y diagnosticar sin tocar archivos `.env`.
- Mantiene la operación simple sin requerir App de escritorio (Electron) ni acceso remoto.

**Configuraciones editables desde la UI (sin tocar código):**

| Parámetro | Justificación |
|-----------|---------------|
| `distributor_sender_id` | Identificador único del cliente en Siemens. Confirmado: `MX-REPRESENTACIONES`. Debe ser editable para escenarios de migración o cambio de razón social. |
| Ambiente (QAS / PRD) | Permite alternar entre sandbox y producción sin redeploy. |
| Frecuencia de ejecución | Cliente puede ajustar si cambia su volumen o política. |
| Hora de ejecución | Ajustar para evitar competencia con cierres de SAE 10. |
| Tamaño máximo de lote | Controlar fragmentación de batches (por defecto 3000). |
| **Toggles de campos opcionales** | Cada campo opcional de Siemens aparece en la UI como toggle ON/OFF. Default: OFF. El cliente puede activar selectivamente sin tocar código ni redeploy. |

**Principio de campos:** 
- **Requeridos** (mínimo viable): siempre se envían, no se pueden desactivar.
- **Opcionales** (extensión): listados y seleccionables desde la UI, default OFF. Si el cliente activa uno, debe proporcionar el dato o se omite silenciosamente.

**Almacenamiento de configuración:**
- **Secretos** (API Keys, passwords): en `.env` (no editable desde UI, requiere acceso al sistema de archivos).
- **Configuración operativa** (frecuencias, ambiente, toggles de campos): en `config.json` editable desde la UI.

#### 3.0.1 Acceso directo a BD (NO reportes de SAE)

El middleware se conectará **directamente a la base de datos Firebird de Aspel SAE 10** mediante conexión nativa. **NO se utilizarán los reportes integrados de Aspel** por las siguientes razones:

- Los reportes de Aspel exponen un conjunto limitado de campos y no permiten seleccionar los nombres técnicos exactos que requiere Siemens.
- Requieren intervención manual o un segundo automatismo dentro de SAE 10 para generarse y exportarse.
- Su rendimiento es limitado para los volúmenes esperados (hasta 3000 transacciones por batch).
- La trazabilidad queda fragmentada en dos lados (reporte + middleware).

**Buenas prácticas que aplicaremos:**

- Usuario de BD con permisos de **solo lectura** sobre las tablas necesarias.
- Conexión transaccional — apertura y cierre controlados en cada ejecución.
- Queries con `SELECT` explícito de columnas (nunca `SELECT *`).
- Validación de existencia de tablas y columnas al inicio de cada ejecución.
- Timeout en queries para no bloquear SAE 10 ante un cuelgue.
- **Nunca escritura** sobre la BD de SAE 10.

#### 3.0.2 Driver de conexión a Firebird 5.0

Aspel SAE 10 utiliza **Firebird 5.0** como motor de base de datos. Esto descarta el paquete clásico `node-firebird` (soporte limitado a Firebird 3.x).

**Driver seleccionado:** `node-firebird-native-api`

- Utiliza la librería nativa `fbclient.dll` que viene incluida con la instalación de Aspel SAE 10 (no requiere instalación adicional).
- Soporte oficial para Firebird 5.0.
- Mejor rendimiento que el driver clásico.
- Conexión por ruta directa al archivo `.fdb` o por `localhost/3050`.

**Conexión típica:**

```typescript
{
  host: 'localhost',
  port: 3050,
  database: 'C:/Program Files/Aspel/Aspel SAE 10.0/BD/SAE10.FDB', // ruta a confirmar en Fase 1
  user: '<usuario_solo_lectura>',
  password: '<password>',
  // WireCrypt: 'Disabled' si el cliente no lo requiere
}
```

**Driver alternativo (ODBC):** Si `node-firebird-native-api` presenta algún problema, fallback a **ODBC + Firebird ODBC Driver** + paquete `odbc` de npm. Más estándar pero ligeramente más lento.

### 3.1 Diagrama de componentes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AMBIENTE DEL CLIENTE                            │
│                                                                         │
│  ┌──────────────┐         ┌──────────────────────────────┐             │
│  │              │         │     MIDDLEWARE (Servicio)    │             │
│  │   SAE 10      │  READ  │                              │             │
│  │  (Firebird   │ ◀──────▶│  ┌──────────────────────┐    │             │
│  │  5.0)        │         │  │ Módulo Inventario    │    │             │
│  │              │         │  │ Módulo Value Flow    │    │             │
│  └──────────────┘         │  │ Transformador JSON   │    │             │
│                           │  │ Cliente API Siemens  │    │             │
│                           │  │ Cliente SFTP Siemens │    │             │
│                           │  │ Logger + Reintentos  │    │             │
│                           │  └──────────────────────┘    │             │
│                           │            │                 │             │
│                           │            ▼                 │             │
│                           │  ┌──────────────────────┐    │             │
│                           │  │  Logs / Auditoría    │    │             │
│                           │  │  Cola de reintentos  │    │             │
│                           │  └──────────────────────┘    │             │
│                           └──────────┬───────────────────┘             │
│                                      │                                  │
└──────────────────────────────────────┼──────────────────────────────────┘
                                       │
                  ┌────────────────────┴────────────────────┐
                  │                    │                    │
                  ▼                    ▼                    ▼
        ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
        │ Siemens QAS API  │  │ Siemens PRD API  │  │ Siemens SFTP     │
        │ /qua/inventory/  │  │ /prd/inventory/  │  │ sftp-public      │
        │ /qua/ (PoS)      │  │ /prd/ (PoS)      │  │ .dl2go.siemens   │
        └──────────────────┘  └──────────────────┘  │ .cloud:22        │
                                                    └──────────────────┘
```

### 3.2 Stack tecnológico propuesto

| Componente              | Tecnología                                                                                                                                  | Justificación                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Lenguaje del middleware | **Node.js 20 LTS + TypeScript**                                                                                                             | Ecosistema HTTP maduro, tipado fuerte, rápido para I/O     |
| Acceso a SAE 10         | **Driver nativo directo** a Firebird 5.0: `node-firebird-native-api` (usa `fbclient.dll` que viene con SAE 10) — **NO via reportes de SAE** | Lectura directa, alto rendimiento, control total de campos |
| Cliente HTTP            | **axios**                                                                                                                                   | Estable, manejo de timeouts e interceptores                |
| Cliente SFTP            | **ssh2-sftp-client**                                                                                                                        | Mantenido activamente, soporta clave privada               |
| Logger                  | **winston** + rotación diaria                                                                                                               | Trazabilidad operativa                                     |
| Scheduler               | **`node-cron` embebido** (02:00 inventario, 03:00 ventas)                                                                                   | Simple, embebido, sin depender de cron del sistema         |
| Configuración           | **dotenv** + variables de entorno                                                                                                           | Secretos fuera del código                                  |

### 3.3 Topología de despliegue

**Decisión confirmada:** El middleware se desplegará **en la misma PC Windows donde corre Aspel SAE 10**. Justificación: mínima latencia de acceso a la BD (localhost), cero complejidad de red/firewall y simplicidad operativa para esta escala.

#### 3.3.1 Infraestructura física/lógica

| Componente                      | Ubicación                | SO          | Software                                                        |
| ------------------------------- | ------------------------ | ----------- | --------------------------------------------------------------- |
| **SAE 10 + Middleware Siemens** | PC dedicada del cliente  | **Windows** | Aspel SAE 10 (Firebird 5.0) + Node.js 20 LTS + PM2 + Middleware |
| **Servidor repaga**             | Servidor Linux existente | Linux       | Apache + Node.js (sin cambios, sin middleware)                  |
| **Siemens destino**             | Nube                     | —           | API REST / SFTP                                                 |

#### 3.3.2 Recursos del servidor (PC Windows de SAE 10)

| Recurso               | Mínimo                                                        | Recomendado                    |
| --------------------- | ------------------------------------------------------------- | ------------------------------ |
| CPU                   | 2 vCPU                                                        | 4 vCPU (compartido con SAE 10) |
| RAM                   | 8 GB                                                          | 16 GB (SAE 10 + middleware)    |
| Disco adicional       | 5 GB para Node, binarios y logs                               | 10 GB                          |
| Red (salida)          | HTTPS 443 hacia `api.pos.siemens.cloud`                       | —                              |
| Red (salida, si SFTP) | SFTP 22 hacia `sftp-public.dl2go.siemens.cloud`               | —                              |
| Red (entrada)         | **No requerida** — el middleware accede a la BD por localhost |                                |

#### 3.3.3 Componentes del middleware en Windows

| Componente                    | Implementación                                                                                            |
| ----------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Runtime**                   | Node.js 20 LTS Windows (instalador `.msi` desde nodejs.org)                                               |
| **Directorio de instalación** | `C:\apps\siemens-middleware\` (recomendado)                                                               |
| **Gestor de procesos**        | **PM2** con plugin **`pm2-windows-startup`** (instala como Servicio Windows)                              |
| **Scheduler**                 | **`node-cron` embebido** en el proceso (02:00 inventario, 03:00 ventas)                                   |
| **Auto-arranque**             | Plugin `pm2-windows-startup` registra el proceso como Servicio de Windows (auto-inicia al arrancar la PC) |
| **Reinicio automático**       | PM2 reinicia el proceso si muere (configurado en `ecosystem.config.js`)                                   |
| **Logs**                      | `C:\apps\siemens-middleware\logs\` con rotación diaria (librería `winston` + `winston-daily-rotate-file`) |
| **Configuración**             | Archivo `.env` en el directorio de instalación                                                            |
| **Puerto HTTP (UI local)**    | **`localhost:4567`** — UI web de administración accesible solo desde el navegador de la propia PC         |

#### 3.3.4 Conectividad hacia SAE 10 (mismo equipo, localhost)

| Requisito                     | Detalle                                                                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Motor de BD de SAE 10         | **Firebird 5.0** (confirmar versión exacta en Fase 1)                                                                            |
| Driver en Node                | **`node-firebird-native-api`** (usa `fbclient.dll` incluida con SAE 10)                                                          |
| Driver alternativo (fallback) | ODBC + Firebird ODBC Driver + paquete `odbc` de npm                                                                              |
| Tipo de acceso                | **Conexión directa a BD (localhost) — NO reportes de Aspel**                                                                     |
| Conexión                      | **localhost:3050** o ruta directa al `.fdb`                                                                                      |
| Credenciales BD               | Usuario de **solo lectura** sobre tablas: `INVE`, `INVE_EXIST`, `MULT`, `FACTE`, `FACTT`, `CLIE`                                 |
| Forma de identificar el motor | Menú **Ayuda → Acerca de** en SAE 10, o revisar la carpeta de instalación buscando archivos `.fdb` (Firebird)                    |
| Verificación de esquema       | **Crítico:** SAE 10 puede tener tablas/campos diferentes a SAE 10. Confirmar nombres en Fase 1 con query a `RDB$RELATION_FIELDS` |

#### 3.3.5 Convivencia con SAE 10

| Aspecto                   | Cómo se gestiona                                                                              |
| ------------------------- | --------------------------------------------------------------------------------------------- |
| **Horarios de ejecución** | 02:00 inventario, 03:00 ventas — fuera de horario operativo de SAE 10                         |
| **Recursos**              | Monitoreo de CPU/RAM en horas batch; ajustar horario si hay competencia con cierres mensuales |
| **Mantenimiento Windows** | Reinicios por actualizaciones de Windows: PM2 auto-arranca con el Servicio                    |
| **Antivirus**             | Excluir directorio del middleware y `node.exe` del análisis en tiempo real                    |
| **Respaldos**             | Incluir `C:\apps\siemens-middleware\` en la política de backup del cliente                    |

#### 3.3.6 Procedimiento de instalación (resumen para Windows)

1. Instalar **Node.js 20 LTS** (Windows Installer `.msi`)
2. Crear directorio `C:\apps\siemens-middleware\`
3. Instalar **PM2** globalmente: `npm install -g pm2`
4. Instalar plugin de auto-arranque Windows: `npm install -g pm2-windows-startup`
5. Ejecutar `pm2-startup install` (instala como Servicio Windows)
6. Copiar el código del middleware al directorio
7. `npm install --production` dentro del directorio
8. Crear `.env` con credenciales
9. `pm2 start ecosystem.config.js`
10. `pm2 save`
11. Verificar primera ejecución manual y revisar logs
12. Reiniciar la PC y validar auto-arranque

#### 3.3.7 Trade-offs aceptados conscientemente

| Trade-off                                             | Mitigación                                                                      |
| ----------------------------------------------------- | ------------------------------------------------------------------------------- |
| Punto único de falla (SAE 10 PC cae → middleware cae) | Alertas de no-ejecución diarias; considerar redundancia en fase futura si crece |
| Mezcla de roles en una PC                             | Horarios no operativos; monitoreo de recursos                                   |
| Reinicios de Windows por actualizaciones              | PM2 auto-arranca; verificar después de updates mayores                          |

---

## 4. ESPECIFICACIÓN TÉCNICA — FLUJO 1: ENVÍO DE INVENTARIO

### 4.1 Objetivo

Enviar a Siemens las existencias actuales de productos del cliente de forma periódica, para alimentar los análisis de Value Flow de Siemens.

### 4.2 Fuente de datos en SAE 10

| Tabla SAE 10 (referencial)   | Campos utilizados                        |
| ---------------------------- | ---------------------------------------- |
| `INVE` / `Productos`         | Clave, descripción, unidad, línea        |
| `INVE_EXIST` / `Existencias` | Almacén, existencia actual, comprometido |
| `MULT` / `Almacenes`         | Código y nombre de almacén               |

**Filtro de línea Siemens (clave):** Para que **solo se reporten a Siemens los productos de su marca**, se aplica el filtro por el campo `LIN_PROD` (línea de producto) de la tabla `INVE`. Las **15 líneas activas** consideradas como Siemens son:

| Código | Descripción              | Productos |
|--------|--------------------------|-----------|
| `BAJA` | Siemens (baja rotación)  | 2,687     |
| `SINU` | Siemens (sinamics)       | 1,657     |
| `SIMAT`| Siemens (simatic)        | 1,630     |
| `LP`   | Siemens (línea principal)| 1,132     |
| `DRIVE`| Siemens (drives)         | 272       |
| `MOTOR`| Siemens (motores)        | 212       |
| `SINUM`| Siemens (sinumerik)      | 73        |
| `SERVI`| Siemens (servicios)      | 34        |
| `OBSO` | Siemens (obsoletos)      | 28        |
| `SENSO`| Siemens (sensores)       | 22        |
| `SERVO`| Siemens (servos)         | 20        |
| `INSTR`| Siemens (instrumentación)| 18        |
| `UPS`  | Siemens (UPS)            | 1         |
| `SIMA` | Siemens (simatic)        | 1         |
| `ESPE` | Siemens (especial)       | 1         |
| **TOTAL** |                      | **7,788** |

**Configuración del filtro:** La lista de líneas válidas se almacena en `config.json` (editable desde UI). Si en el futuro se agrega una nueva línea Siemens al catálogo de SAE 10, basta con agregarla al config sin tocar código.

**Nota:** Los nombres exactos de tablas y campos requieren validación contra la versión específica de SAE 10 del cliente durante Fase 1.

### 4.3 Endpoint destino

| Ambiente             | URL                                                       | Uso        |
| -------------------- | --------------------------------------------------------- | ---------- |
| **QAS (calidad)**    | `https://api.pos.siemens.com/qua/inventory/create_record` | Pruebas    |
| **PRD (producción)** | `https://api.pos.siemens.com/prd/inventory/create_record` | Producción |

### 4.4 Método HTTP y headers

```http
POST /qua/inventory/create_record HTTP/1.1
Host: api.pos.siemens.com
Content-Type: application/json
X-API-KEY: <credencial_asignada_por_siemens>
```

### 4.5 Cuerpo de la petición (esquema)

El esquema exacto será confirmado una vez que el cliente obtenga la **plantilla de campos** del Siemens Data Steward. Estructura esperada:

```json
{
  "distributor_sender_ID": "<ID_del_cliente_en_Siemens>",
  "inventory_date": "2026-07-06",
  "records": [
    {
      "product_id": "<SKU_cliente>",
      "product_description": "<descripción>",
      "warehouse_id": "<código_almacén>",
      "quantity_on_hand": 125,
      "unit_of_measure": "PZA",
      "...": "<otros campos de plantilla Siemens>"
    }
  ]
}
```

**Reglas de transformación:**

- Fechas en formato **ISO 8601**: `YYYY-MM-DD`
- Cantidades como números (sin comillas)
- Límite recomendado por Siemens: **≤3000 transacciones por batch**
- Todos los campos requeridos por Siemens son obligatorios (validación previa al envío)

### 4.6 Frecuencia y ventana de ejecución

| Aspecto          | Valor propuesto                            |
| ---------------- | ------------------------------------------ |
| Frecuencia       | **Diaria** (1 vez al día)                  |
| Hora             | 02:00 hrs tiempo del centro (configurable) |
| Ventana de datos | Snapshot actual al momento de ejecución    |
| Modo             | Inventario completo (full snapshot)        |

### 4.7 Validaciones previas al envío

- [ ] Todos los productos tienen `SKU` no nulo
- [ ] Cantidades son numéricas ≥ 0
- [ ] No exceder 3000 registros (si excede, particionar)
- [ ] Headers HTTP completos
- [ ] Credenciales vigentes

**Principio de campos:**

- **Campos requeridos** (siempre se envían, no configurables): 5 confirmados — `distributor_sender_id`, `distributor_inventory_date`, `vendor_item_number`, `quantity`, `quantity_unit_of_measure`.
- **Campos opcionales** (default OFF, seleccionables desde UI): Ejemplos candidatos — `product_description`, `warehouse_description`, `batch_number`, `expiry_date`, `cost_price`. El cliente activa selectivamente cada uno según su necesidad sin tocar código.
- Si un opcional está activado pero el dato viene vacío/null en SAE 10, se omite silenciosamente (no se envía el campo).

---

## 5. ESPECIFICACIÓN TÉCNICA — FLUJO 2: VALUE FLOW (VENTAS)

### 5.1 Objetivo

Enviar a Siemens el detalle de las transacciones de venta (facturas y remisiones) emitidas en un periodo, para sus análisis de market intelligence.

### 5.2 Fuente de datos en SAE 10

| Tabla SAE 10 (referencial)     | Campos utilizados                            |
| ------------------------------ | -------------------------------------------- |
| `FACTE` / `Encabezado Factura` | Folio, fecha, cliente, tipo documento, total |
| `FACTT` / `Detalle Factura`    | Producto, cantidad, precio unitario, importe |
| `CLIE` / `Clientes`            | Código, RFC, razón social                    |
| `INVE` / `Productos`           | SKU, descripción, **línea (`LIN_PROD`)**     |

**Filtro de línea Siemens (clave — confirmación Ing. Paco):** El Ing. Paco confirmó que **solo se deben compartir con Siemens los datos correspondientes a sus productos**, omitiendo las "corridas" adicionales u otros productos no-Siemens que aparezcan en las mismas facturas.

**Lógica del filtro:**
1. La factura se lee **completa** desde `FACTE` + `FACTT`.
2. Cada línea de detalle (`FACTT`) se une con `INVE` por SKU para obtener `LIN_PROD`.
3. **Se descartan** las líneas cuyo `LIN_PROD` no esté en la lista de líneas Siemens válidas.
4. Si la factura **pierde todas sus líneas** tras el filtro, **no se envía** (se omite completa).
5. Si la factura **conserva al menos una línea** Siemens, se envía solo con esas líneas (las otras se omiten del payload).

**Resultado esperado:**

```
Factura F-001234 (cliente ACME, fecha 2026-07-20)
├─ Línea 1: SKU-001 / LIN_PROD=SIMAT  (Siemens)  → ✅ SE ENVÍA
├─ Línea 2: SKU-002 / LIN_PROD=DRIVE  (Siemens)  → ✅ SE ENVÍA
├─ Línea 3: SKU-003 / LIN_PROD=CORRIDA (ajena)   → ❌ SE OMITE
└─ Línea 4: SKU-004 / LIN_PROD=ACCESORIO (ajena)  → ❌ SE OMITE

→ Payload final enviado a Siemens: solo líneas 1 y 2
```

Las 15 líneas Siemens válidas y la configuración del filtro se documentan en la sección **4.2** de Inventario (mismo filtro aplica para ambos flujos).

### 5.3 Método de envío (decisión recomendada: **API REST**)

| Ambiente             | URL                                             | Uso        |
| -------------------- | ----------------------------------------------- | ---------- |
| **QAS (calidad)**    | `https://api.pos.siemens.com/qua/create_record` | Pruebas    |
| **PRD (producción)** | `https://api.pos.siemens.com/prd/create_record` | Producción |

### 5.4 Headers y cuerpo

Idénticos a Inventario, pero apuntando a `/create_record` (sin sufijo `/inventory/`).

```json
{
  "distributor_sender_ID": "<ID_del_cliente_en_Siemens>",
  "transaction_date": "2026-07-05",
  "records": [
    {
      "invoice_number": "F-001234",
      "invoice_date": "2026-07-05",
      "customer_id": "<RFC_o_cliente_id>",
      "line_items": [
        {
          "product_id": "<SKU>",
          "quantity": 2,
          "unit_price": 1500.00,
          "total": 3000.00
        }
      ]
    }
  ]
}
```

### 5.5 Método alternativo: SFTP (CSV)

Si el cliente elige SFTP, el flujo es:

| Parámetro          | Valor                                    |
| ------------------ | ---------------------------------------- |
| Host               | `sftp-public.dl2go.siemens.cloud`        |
| Puerto             | `22`                                     |
| Autenticación      | Usuario + archivo de clave privada (PKI) |
| Carpeta de subida  | `/inbound/`                              |
| Encoding           | UTF-8 **sin BOM**                        |
| Delimitador        | Coma                                     |
| Nombre del archivo | `<distributor_sender_ID>_<YYYYMMDD>.csv` |

**Estructura del CSV (header row obligatorio con nombres técnicos Siemens):**

```csv
distributor_sender_ID,invoice_number,invoice_date,customer_id,product_id,quantity,unit_price,total
MX123,F-001234,2026-07-05,XAX010101000,SKU-001,2,1500.00,3000.00
```

**Validaciones críticas:**

- ⚠️ Sin BOM (Byte Order Mark) — Excel lo agrega al guardar; limpiar antes
- ⚠️ Campos numéricos NO entrecomillados
- ⚠️ Celdas con comas → encerrar entre comillas dobles
- ⚠️ Header con nombres técnicos exactos de Siemens (recibidos del Data Steward)

### 5.6 Frecuencia y ventana de ejecución

| Aspecto          | Valor propuesto                                              |
| ---------------- | ------------------------------------------------------------ |
| Frecuencia       | **Diaria**                                                   |
| Hora             | 03:00 hrs (1 hora después del inventario)                    |
| Ventana de datos | Día anterior completo (D-1, 00:00:00 a 23:59:59)             |
| Idempotencia     | Cada factura se identifica unívocamente por `invoice_number` |

### 5.7 Validaciones previas al envío

- [ ] Solo facturas/remisiones con estatus válido (no canceladas)
- [ ] Montos y cantidades son numéricos
- [ ] Fechas en ISO 8601
- [ ] No exceder 3000 transacciones por batch (si excede, particionar)
- [ ] Si CSV: encoding verificado, BOM ausente

**Principio de campos:**

- **Campos requeridos** (siempre se envían, no configurables): 10 confirmados — `distributor_sender_id`, `distributor_invoice_number`, `distributor_invoice_line_item`, `distributor_invoice_date`, `distributor_order_taking_branch_id`, `vendor_item_number`, `quantity`, `unit_cost`, `extended_cost_of_goods_sold`, `currency_code`.
- **Campos opcionales** (default OFF, seleccionables desde UI): Ejemplos candidatos — `product_description`, `customer_name`/`customer_id` (RFC), `discount_amount`, `tax_amount`, `line_number`, `serial_number`. El cliente activa selectivamente cada uno según su necesidad sin tocar código.
- Si un opcional está activado pero el dato viene vacío/null en SAE 10, se omite silenciosamente (no se envía el campo).

---

## 6. SEGURIDAD Y MANEJO DE CREDENCIALES

### 6.1 Credenciales requeridas

| Credencial                   | Proveedor            | Almacenamiento                  |
| ---------------------------- | -------------------- | ------------------------------- |
| API Key Inventario (QAS/PRD) | Siemens Data Steward | Variable de entorno cifrada     |
| API Key PoS (QAS/PRD)        | Siemens Data Steward | Variable de entorno cifrada     |
| Usuario SFTP                 | Siemens PoS team     | Variable de entorno             |
| Clave privada SFTP           | Siemens PoS team     | Archivo `.pem` con permisos 600 |
| Cadena de conexión SAE 10    | Cliente (BD)         | Variable de entorno cifrada     |

### 6.2 Buenas prácticas aplicadas

- Ningún secreto en código fuente ni en logs.
- Variables de entorno cargadas desde archivo `.env` excluido de control de versiones.
- Logs ofuscados: nunca se loguean API keys completas ni datos personales completos.
- Transporte TLS 1.2+ hacia Siemens.

---

## 7. LOGGING, MONITOREO Y REINTENTOS

### 7.1 Logging

Cada ejecución genera archivo de log con:

- Timestamp de inicio y fin
- Registros leídos de SAE 10
- Registros enviados a Siemens
- Status HTTP recibido
- Errores con detalle y stack trace
- ID de correlación para troubleshooting

**Retención:** 90 días en disco, después rotación a archivo comprimido.

### 7.2 Manejo de errores y reintentos

| Tipo de error               | Acción                                                   |
| --------------------------- | -------------------------------------------------------- |
| Timeout de red              | Reintento con backoff exponencial (3 intentos)           |
| HTTP 4xx (validación)       | NO reintentar — alerta inmediata, registro en cuarentena |
| HTTP 5xx (servidor Siemens) | Reintento con backoff exponencial hasta 5 intentos       |
| Error de conexión a SAE 10  | Reintento 3 veces, alerta si persistente                 |
| Archivo CSV con BOM         | Auto-limpieza y reintento                                |

### 7.3 Notificaciones

- Email o webhook al equipo de TI del cliente en caso de:
  - 3 fallos consecutivos del mismo flujo
  - Cualquier error 4xx (validación)
  - Archivo de log con tamaño inusual

---

## 8. ENTREGABLES

| #   | Entregable                                          | Formato               |
| --- | --------------------------------------------------- | --------------------- |
| 1   | Documento de mapeo campo a campo (SAE 10 ↔ Siemens) | `.xlsx` + `.pdf`      |
| 2   | Código fuente del middleware                        | Repositorio Git       |
| 3   | Binarios compilados / instrucciones de despliegue   | `README.md` + scripts |
| 4   | Manual de operación y troubleshooting               | `.pdf`                |
| 5   | Manual de instalación paso a paso                   | `.pdf` + `.md`        |
| 6   | Plan de pruebas y resultados                        | `.xlsx`               |
| 7   | Acta de aceptación de pruebas UAT                   | `.pdf` firmado        |
| 8   | Credenciales y configuración de producción          | `.env.example` + guía |

---

## 9. FASES DE IMPLEMENTACIÓN

### Fase 1 — Discovery & Credenciales (≈10 h)

1. Solicitud directa al portal Siemens para obtener:
   - API Keys (QAS y PRD, Inventory y PoS)
   - Plantilla con nombres técnicos de campos
   - Credenciales SFTP (si aplica)
   - Permisos elevados en el portal
2. Análisis del modelo de datos de SAE 10 del cliente
3. Mapeo campo a campo SAE 10 ↔ Siemens
4. Documento de mapeo aprobado

### Fase 2 — Desarrollo del Middleware (≈14 h humano)

1. Configuración del proyecto y conexión a SAE 10 (Firebird 5.0)
2. Módulo de lectura de Inventario (queries Firebird optimizadas para ~12,000 productos con particionamiento en 4 batches)
3. Módulo de lectura de Ventas (Value Flow)
4. Transformador al esquema Siemens (JSON / CSV sin BOM)
5. Cliente API Siemens con reintentos, logging, timeouts
6. Cliente SFTP Siemens (si aplica)
7. UI local de administración (Express + HTMX)
8. Scheduler y manejo de configuración

### Fase 3 — Pruebas & Go-Live (≈12 h humano)

1. Pruebas unitarias y de integración
2. Pruebas en ambiente QAS de Siemens
3. Pruebas de carga (validar particionamiento de 4 batches de inventario)
4. UAT con usuario final del cliente
5. Despliegue a producción + configuración PM2 como Servicio Windows
6. Monitoreo intensivo primera semana
7. Documentación técnica + manual de operación

### Consideración de volumen del cliente

El cliente maneja aproximadamente **12,000 productos** en su catálogo. Implicaciones técnicas:

- **Inventario** (snapshot diario): se requieren **4 batches de ~3,000 registros** para respetar el límite recomendado por Siemens.
- El middleware implementará **particionamiento automático** del inventario y manejo de múltiples llamadas API con control de orden.
- **Ventas** (filtrado por día): volumen típico mucho menor (decenas a centenas), un solo batch es suficiente.
- El tiempo total de envío en cada ejecución: ~5-10 minutos dependiendo de latencia.

### Fase 4 — Operación (mensual, opcional)

1. Monitoreo de ejecuciones diarias
2. Resolución de incidencias
3. Actualizaciones por cambios en SAE 10 o Siemens
4. Renovación proactiva de credenciales

---

## 10. CRITERIOS DE ACEPTACIÓN

El proyecto se considerará aceptado cuando:

- [ ] Inventario diario se ejecuta sin errores en producción por **5 días consecutivos**
- [ ] Value Flow diario se ejecuta sin errores en producción por **5 días consecutivos**
- [ ] Todos los registros enviados son aceptados por Siemens (HTTP 200) o enviados al folder `processed/` (SFTP)
- [ ] Los logs están completos y la trazabilidad es verificable
- [ ] Documentación técnica y manual de operación entregados y aprobados
- [ ] UAT firmada por el usuario final del cliente

---

## 11. RIESGOS Y MITIGACIONES

| #   | Riesgo                                 | Probabilidad | Impacto | Mitigación                           |
| --- | -------------------------------------- | ------------ | ------- | ------------------------------------ |
| 1   | Cambios en esquema Siemens sin aviso   | Media        | Alto    | Monitoreo de respuestas 4xx + alerta |
| 2   | Credenciales vencidas                  | Media        | Alto    | Alerta 30 días antes del vencimiento |
| 3   | Datos incompletos en SAE 10            | Baja         | Medio   | Validación previa + cuarentena       |
| 4   | Exceder límite de 3000 registros/batch | Media        | Medio   | Particionamiento automático          |
| 5   | BOM en CSV (SFTP)                      | Alta         | Alto    | Validación + script de limpieza      |
| 6   | Indisponibilidad de Siemens            | Baja         | Medio   | Reintentos + alerta al equipo        |
| 7   | Versión de SAE 10 incompatible         | Baja         | Alto    | Discovery en Fase 1 confirma versión |

---

## 12. PRE-REQUISITOS DEL CLIENTE

Para iniciar la Fase 1 se requiere:

1. **Acceso de lectura (localhost)** a la base de datos de SAE 10 con usuario de solo lectura
2. **Versión específica** de SAE 10 instalada y productiva (para confirmar versión exacta de Firebird: 5.0+)
3. **Usuario con permisos elevados** en Siemens PoSi Portal, o solicitud formal al Siemens Data Admin
4. **API Keys y plantillas** de campos (solicitadas por el cliente al Data Steward regional)
5. **Permisos de administrador** en la PC Windows de SAE 10 para instalar Node.js, PM2 y crear directorios
6. **Permisos del antivirus** para excluir el directorio del middleware y `node.exe`
7. **Credenciales SFTP** (si se elige ese método para Value Flow)

---

## 13. SUPUESTOS

- El cliente tiene contrato vigente con Siemens y autorización para enviar datos PoS/Inventory.
- La PC Windows de SAE 10 tiene recursos suficientes (CPU/RAM) para correr SAE 10 + el middleware simultáneamente.
- La red del cliente permite salida HTTPS (443) y SFTP (22) hacia los endpoints de Siemens desde la PC de SAE 10.
- El cliente proveerá un usuario de BD con permisos de **solo lectura** sobre las tablas necesarias (acceso localhost).
- El cliente puede instalar Node.js 20 LTS y configurar PM2 como Servicio Windows en la PC de SAE 10.
- El antivirus de la PC de SAE 10 puede excluir el directorio del middleware del análisis en tiempo real.
- Las plantillas de campos de Siemens serán provistas por el Data Steward durante Fase 1.
- Las credenciales SFTP son responsabilidad del cliente gestionarlas ante Siemens.

**Asunción técnica principal:** Se asume que la instalación de **Aspel SAE 10 del cliente corre sobre Firebird 5.0** (default de fábrica, incluido sin costo adicional). Esta asunción se validará en Fase 1 mediante query directa al catálogo de Firebird (`RDB$RELATION_FIELDS` y `RDB$GET_CONTEXT('SYSTEM', 'ENGINE_VERSION')`). Si por alguna razón la instalación utiliza SQL Server, el cambio de driver es de bajo impacto gracias a la capa de abstracción propuesta en la arquitectura (solo cambia la implementación del conector de BD).

---

## 14. PRÓXIMOS PASOS

1. ✅ **Aprobación de esta propuesta técnica**
2. ✅ **Solicitud formal** al Siemens Data Steward de credenciales y plantillas
3. ✅ **Reunión de kick-off** para alinear Fase 1
4. ✅ **Inicio de Fase 1** (Discovery)

---

*Documento preparado por Ing. Frank Saavedra | Vcorp — ID interno: ARCH-20260706-02*  