# DOCUMENTO DE MAPEO CAMPO A CAMPO

## Aspel SAE 10 ↔ Siemens PoSi Portal

**ID Documento:** ARCH-20260720-03  
**Fecha:** 2026-07-20  
**Preparado por:** Ing. Frank Saavedra | Vcorp  
**Estado:** Discovery completado  
**Ambiente de referencia:** QUA (Quality)  
**Fuente del esquema:** Capturas Postman del cliente + validación API QUA

---

## 1. Resumen

Este documento define el mapeo campo a campo entre la base de datos de Aspel SAE 9.0 (estructura compatible con SAE 10) y los endpoints de Siemens PoSi Portal. El esquema completo fue obtenido de las capturas de Postman del cliente, que muestran el payload real esperado por la API.

**Fuentes de datos validadas:**

- Base de datos: `SAE90EMPRE01.FDB` (Firebird 2.5, ODS 11.2)
- 210 tablas de usuario, 30,635 productos, 46,430 facturas
- 7,788 productos Siemens en 15 líneas activas
- Esquema Siemens: capturas Postman del cliente (payloads completos)

---

## 2. FLUJO 1: INVENTARIO

### 2.1 Endpoint

```
POST https://api.pos.siemens.com/{env}/inventory/create_record
```

### 2.2 Esquema completo (captura Postman)

```json
[
  {
    "distributor_sender_id": "123456",
    "distributor_order_taking_branch_name": "London 1234",
    "distributor_order_taking_branch_id": "8778221",
    "distributor_inventory_date": "2025-05-14",
    "vendor_item_number": "1FL60941AC612LH1",
    "vendor_item_options": "12345",
    "quantity": 2,
    "quantity_unit_of_measure": "each",
    "upc_ean": 123456789012,
    "stock_item": "Y",
    "abc_segmentation": "A"
  }
]
```

### 2.3 Mapeo de campos

#### Campos requeridos (5) — confirmados vía API QUA

| #   | Campo Siemens                | Tipo            | Obligatorio | Tabla SAE | Campo SAE | Tipo SAE    | Transformación                                                                              |
| --- | ---------------------------- | --------------- | ----------- | --------- | --------- | ----------- | ------------------------------------------------------------------------------------------- |
| 1   | `distributor_sender_id`      | string          | ✅           | —         | —         | —           | Valor fijo: `"MX-REPRESENTACIONES"` (a confirmar con cliente)                               |
| 2   | `distributor_inventory_date` | date (ISO 8601) | ✅           | —         | —         | —           | Fecha de ejecución: `YYYY-MM-DD`                                                            |
| 3   | `vendor_item_number`         | string          | ✅           | INVE01    | `CVE_ART` | VARCHAR(16) | Directo. Clave del artículo                                                                 |
| 4   | `quantity`                   | number          | ✅           | INVE01    | `EXIST`   | DOUBLE      | Directo. Existencia global del producto                                                     |
| 5   | `quantity_unit_of_measure`   | string          | ✅           | INVE01    | `UNI_MED` | VARCHAR(10) | Directo. Ejemplo Postman: `"each"` → SAE: `"pz"`. Mapear a `"each"` o `"PZA"` según Siemens |

#### Campos opcionales (6) — del esquema Postman

| #   | Campo Siemens                          | Tipo   | Tabla SAE   | Campo SAE  | Tipo SAE    | Transformación                                               |
| --- | -------------------------------------- | ------ | ----------- | ---------- | ----------- | ------------------------------------------------------------ |
| 6   | `distributor_order_taking_branch_name` | string | ALMACENES01 | `DESCR`    | VARCHAR(50) | Nombre del almacén/sucursal                                  |
| 7   | `distributor_order_taking_branch_id`   | string | FACTF01     | `NUM_ALMA` | INTEGER     | Convertir a string. ID de almacén                            |
| 8   | `vendor_item_options`                  | string | INVE01      | `CVE_ART`  | VARCHAR(16) | Opciones del producto (si aplica). Puede ser vacío           |
| 9   | `upc_ean`                              | number | INVE_CLIB01 | —          | —           | Código de barras. Buscar en campos libres o dejar null       |
| 10  | `stock_item`                           | string | —           | —          | —           | Valor fijo: `"Y"` (todos los productos son stock)            |
| 11  | `abc_segmentation`                     | string | —           | —          | —           | Clasificación ABC. Valor fijo: `"A"` o calcular por rotación |

### 2.4 Query de extracción

```sql
SELECT
  i.CVE_ART,
  i.EXIST,
  i.UNI_MED,
  a.DESCR AS ALMACEN_NOMBRE,
  i.LIN_PROD
FROM INVE01 i
LEFT JOIN ALMACENES01 a ON 1=1  -- Si multialmacén, usar MULT01
WHERE i.STATUS = 'A'
  AND i.LIN_PROD IN (
    'SINU','SIMAT','SERVI','LP','BAJA','UPS','MOTOR','CURSO',
    'DRIVE','INSTR','REDES','SIMA','OBSO','SINUM','FA300',
    '6ES5','SENSO','ESPE','FSINU','SERVO'
  )
ORDER BY i.CVE_ART
```

### 2.5 Volumen esperado

| Métrica                              | Valor        |
| ------------------------------------ | ------------ |
| Productos Siemens totales            | 7,788        |
| Con stock > 0                        | 1,758        |
| Batches necesarios (máx 3,000/batch) | 3            |
| Tiempo estimado de envío             | ~2-3 minutos |

### 2.6 Ejemplo de payload real

```json
[
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_inventory_date": "2026-07-20",
    "vendor_item_number": "6SE64402UD230BA1",
    "vendor_item_options": "",
    "quantity": 3,
    "quantity_unit_of_measure": "each",
    "upc_ean": null,
    "stock_item": "Y",
    "abc_segmentation": "A"
  },
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_inventory_date": "2026-07-20",
    "vendor_item_number": "3SU11502BF603MA0",
    "vendor_item_options": "",
    "quantity": 0,
    "quantity_unit_of_measure": "each",
    "upc_ean": null,
    "stock_item": "Y",
    "abc_segmentation": "A"
  }
]
```

### 2.7 Notas de implementación

- **`quantity_unit_of_measure`**: El ejemplo Postman usa `"each"`. SAE tiene `"pz"`. **Decisión crítica**: ¿mapear `"pz"` → `"each"` o enviar `"pz"`? Confirmar con Siemens.
- Se envían **todos los productos Siemens activos**, incluyendo los que tienen `EXIST = 0`.
- El campo `LIN_PROD` se usa como filtro para enviar solo productos Siemens.
- Si el cliente activa multialmacén, se debe usar la tabla `MULT01` en lugar de `INVE01.EXIST` y generar un registro por almacén.
- **`upc_ean`**: No existe en SAE estándar. Buscar en `INVE_CLIB01` (campos libres) o enviar `null`.
- **`abc_segmentation`**: No existe en SAE. Asignar `"A"` como valor fijo o calcular por rotación de ventas.

---

## 3. FLUJO 2: VALUE FLOW (VENTAS)

### 3.1 Endpoint

```
POST https://api.pos.siemens.com/{env}/create_record
```

### 3.2 Esquema completo (captura Postman)

```json
[
  {
    "distributor_order_taking_branch_name": "Branch Location Name",
    "distributor_order_taking_branch_id": "21",
    "distributor_ship_from_branch_name": "Branch Location Name",
    "distributor_ship_from_branch_id": "11",
    "distributor_ship_from_address": "890 Fifth Avenue",
    "distributor_ship_from_city": "Manhattan",
    "distributor_ship_from_state": "NY",
    "distributor_ship_from_zip": "10021",
    "distributor_ship_from_country": "US",
    "distributor_ship_date": "2022-09-27",
    "distributor_invoice_date": "2022-09-27",
    "distributor_invoice_number": "2345678",
    "distributor_invoice_line_item": "1",
    "bill_to_customer_record_id": "2094567",
    "bill_to_customer_duns_number": "123456789",
    "bill_to_customer_name": "Oscorp Industries",
    "bill_to_customer_billing_address1": "Oscorp Tower",
    "bill_to_customer_billing_address2": "Suite 93",
    "bill_to_customer_city": "New York",
    "bill_to_customer_state": "NY",
    "bill_to_customer_zip": "10017",
    "bill_to_customer_country": "US",
    "bill_to_customer_phone_number": "5555555555",
    "bill_to_customer_domain_name_email_address": "oscorp-industries.com",
    "ship_to_customer_record_id": "20912345",
    "ship_to_customer_duns_number": "123456789",
    "ship_to_customer_name": "Oscorp Industries",
    "ship_to_customer_shipping_address1": "Oscorp Tower",
    "ship_to_customer_shipping_address2": "Suite 93",
    "ship_to_customer_city": "New York",
    "ship_to_customer_state": "NY",
    "ship_to_customer_zip": "10017",
    "ship_to_customer_country": "US",
    "ship_to_customer_phone_number": "5555555555",
    "ship_to_customer_domain_name_email_address": "oscorp-industries.com",
    "vendor_item_number": "SKU-001",
    "vendor_item_options": "12345",
    "quantity": 2,
    "quantity_unit_of_measure": "each",
    "unit_cost": 1500.00,
    "extended_cost_of_goods_sold": 3000.00,
    "currency_code": "USD",
    "distributor_sender_id": "123456"
  }
]
```

### 3.3 Mapeo de campos

#### Campos de identificación del documento (4)

| #   | Campo Siemens                   | Tipo   | Tabla SAE   | Campo SAE   | Tipo SAE    | Transformación                      |
| --- | ------------------------------- | ------ | ----------- | ----------- | ----------- | ----------------------------------- |
| 1   | `distributor_sender_id`         | string | —           | —           | —           | Valor fijo: `"MX-REPRESENTACIONES"` |
| 2   | `distributor_invoice_number`    | string | FACTF01     | `CVE_DOC`   | VARCHAR(20) | Directo. Ej: `"CFDI_32699"`         |
| 3   | `distributor_invoice_line_item` | string | PAR_FACTF01 | `NUM_PAR`   | INTEGER     | Convertir a string                  |
| 4   | `distributor_invoice_date`      | date   | FACTF01     | `FECHA_DOC` | TIMESTAMP   | Extraer fecha: `YYYY-MM-DD`         |

#### Campos de sucursal/rama (2)

| #   | Campo Siemens                          | Tipo   | Tabla SAE   | Campo SAE  | Tipo SAE    | Transformación                                 |
| --- | -------------------------------------- | ------ | ----------- | ---------- | ----------- | ---------------------------------------------- |
| 5   | `distributor_order_taking_branch_id`   | string | FACTF01     | `NUM_ALMA` | INTEGER     | Convertir a string. Almacén que tomó el pedido |
| 6   | `distributor_order_taking_branch_name` | string | ALMACENES01 | `DESCR`    | VARCHAR(50) | Nombre del almacén                             |

#### Campos de envío (ship_from) — 7 campos

| #   | Campo Siemens                       | Tipo   | Tabla SAE        | Campo SAE  | Tipo SAE     | Transformación                           |
| --- | ----------------------------------- | ------ | ---------------- | ---------- | ------------ | ---------------------------------------- |
| 7   | `distributor_ship_from_branch_id`   | string | FACTF01          | `NUM_ALMA` | INTEGER      | Mismo que order_taking_branch_id         |
| 8   | `distributor_ship_from_branch_name` | string | ALMACENES01      | `DESCR`    | VARCHAR(50)  | Mismo que order_taking_branch_name       |
| 9   | `distributor_ship_from_address`     | string | PARAM_DATOSEMP01 | `CALLE`    | VARCHAR(100) | Dirección de la empresa (datos fiscales) |
| 10  | `distributor_ship_from_city`        | string | PARAM_DATOSEMP01 | `CIUDAD`   | VARCHAR(50)  | Ciudad de la empresa                     |
| 11  | `distributor_ship_from_state`       | string | PARAM_DATOSEMP01 | `ESTADO`   | VARCHAR(50)  | Estado de la empresa                     |
| 12  | `distributor_ship_from_zip`         | string | PARAM_DATOSEMP01 | `CP`       | VARCHAR(10)  | Código postal de la empresa              |
| 13  | `distributor_ship_from_country`     | string | —                | —          | —            | Valor fijo: `"MX"`                       |

#### Campos de fecha de envío (1)

| #   | Campo Siemens           | Tipo | Tabla SAE | Campo SAE   | Tipo SAE  | Transformación                                                 |
| --- | ----------------------- | ---- | --------- | ----------- | --------- | -------------------------------------------------------------- |
| 14  | `distributor_ship_date` | date | FACTF01   | `FECHA_DOC` | TIMESTAMP | Mismo que invoice_date (no hay fecha de envío separada en SAE) |

#### Campos del producto (3)

| #   | Campo Siemens              | Tipo   | Tabla SAE   | Campo SAE   | Tipo SAE    | Transformación                               |
| --- | -------------------------- | ------ | ----------- | ----------- | ----------- | -------------------------------------------- |
| 15  | `vendor_item_number`       | string | PAR_FACTF01 | `CVE_ART`   | VARCHAR(16) | Directo. SKU del producto                    |
| 16  | `vendor_item_options`      | string | —           | —           | —           | Opciones del producto. Puede ser vacío       |
| 17  | `quantity_unit_of_measure` | string | PAR_FACTF01 | `UNI_VENTA` | VARCHAR(10) | Unidad de venta. Mapear a `"each"` si aplica |

#### Campos de cantidad y costo (3)

| #   | Campo Siemens                 | Tipo   | Tabla SAE   | Campo SAE | Tipo SAE | Transformación            |
| --- | ----------------------------- | ------ | ----------- | --------- | -------- | ------------------------- |
| 18  | `quantity`                    | number | PAR_FACTF01 | `CANT`    | DOUBLE   | Directo. Cantidad vendida |
| 19  | `unit_cost`                   | double | PAR_FACTF01 | `COST`    | DOUBLE   | Directo. Costo unitario   |
| 20  | `extended_cost_of_goods_sold` | double | —           | —         | —        | Calculado: `CANT × COST`  |

#### Campos de moneda (1)

| #   | Campo Siemens   | Tipo   | Tabla SAE | Campo SAE | Tipo SAE | Transformación                                         |
| --- | --------------- | ------ | --------- | --------- | -------- | ------------------------------------------------------ |
| 21  | `currency_code` | string | —         | —         | —        | Valor fijo: `"MXN"` (o desde MONED01 si multicurrency) |

#### Campos del cliente facturador (bill_to) — 10 campos

| #   | Campo Siemens                                | Tipo   | Tabla SAE | Campo SAE  | Tipo SAE     | Transformación                                     |
| --- | -------------------------------------------- | ------ | --------- | ---------- | ------------ | -------------------------------------------------- |
| 22  | `bill_to_customer_record_id`                 | string | FACTF01   | `CVE_CLPV` | VARCHAR(10)  | Clave del cliente                                  |
| 23  | `bill_to_customer_duns_number`               | string | CLIE01    | —          | —            | DUNS number. No existe en SAE. Enviar vacío o null |
| 24  | `bill_to_customer_name`                      | string | CLIE01    | `NOMBRE`   | VARCHAR(100) | Razón social del cliente                           |
| 25  | `bill_to_customer_billing_address1`          | string | CLIE01    | `CALLE`    | VARCHAR(100) | Calle del cliente                                  |
| 26  | `bill_to_customer_billing_address2`          | string | CLIE01    | `NUM_EXT`  | VARCHAR(20)  | Número exterior + interior                         |
| 27  | `bill_to_customer_city`                      | string | CLIE01    | `CIUDAD`   | VARCHAR(50)  | Ciudad del cliente                                 |
| 28  | `bill_to_customer_state`                     | string | CLIE01    | `ESTADO`   | VARCHAR(50)  | Estado del cliente                                 |
| 29  | `bill_to_customer_zip`                       | string | CLIE01    | `CP`       | VARCHAR(10)  | Código postal del cliente                          |
| 30  | `bill_to_customer_country`                   | string | CLIE01    | `PAIS`     | VARCHAR(50)  | País del cliente. Mapear a `"MX"`                  |
| 31  | `bill_to_customer_phone_number`              | string | CLIE01    | `TELEFONO` | VARCHAR(20)  | Teléfono del cliente                               |
| 32  | `bill_to_customer_domain_name_email_address` | string | CLIE01    | `EMAIL`    | VARCHAR(100) | Email del cliente                                  |

#### Campos del cliente de envío (ship_to) — 10 campos

| #   | Campo Siemens                                | Tipo   | Tabla SAE | Campo SAE  | Tipo SAE     | Transformación                                                |
| --- | -------------------------------------------- | ------ | --------- | ---------- | ------------ | ------------------------------------------------------------- |
| 33  | `ship_to_customer_record_id`                 | string | FACTF01   | `CVE_CLPV` | VARCHAR(10)  | Mismo que bill_to (en SAE no hay dirección de envío separada) |
| 34  | `ship_to_customer_duns_number`               | string | CLIE01    | —          | —            | Mismo que bill_to                                             |
| 35  | `ship_to_customer_name`                      | string | CLIE01    | `NOMBRE`   | VARCHAR(100) | Mismo que bill_to                                             |
| 36  | `ship_to_customer_shipping_address1`         | string | CLIE01    | `CALLE`    | VARCHAR(100) | Mismo que bill_to                                             |
| 37  | `ship_to_customer_shipping_address2`         | string | CLIE01    | `NUM_EXT`  | VARCHAR(20)  | Mismo que bill_to                                             |
| 38  | `ship_to_customer_city`                      | string | CLIE01    | `CIUDAD`   | VARCHAR(50)  | Mismo que bill_to                                             |
| 39  | `ship_to_customer_state`                     | string | CLIE01    | `ESTADO`   | VARCHAR(50)  | Mismo que bill_to                                             |
| 40  | `ship_to_customer_zip`                       | string | CLIE01    | `CP`       | VARCHAR(10)  | Mismo que bill_to                                             |
| 41  | `ship_to_customer_country`                   | string | CLIE01    | `PAIS`     | VARCHAR(50)  | Mismo que bill_to                                             |
| 42  | `ship_to_customer_phone_number`              | string | CLIE01    | `TELEFONO` | VARCHAR(20)  | Mismo que bill_to                                             |
| 43  | `ship_to_customer_domain_name_email_address` | string | CLIE01    | `EMAIL`    | VARCHAR(100) | Mismo que bill_to                                             |

### 3.4 Query de extracción

```sql
SELECT
  f.CVE_DOC,
  CAST(p.NUM_PAR AS VARCHAR(10)) AS LINE_ITEM,
  f.FECHA_DOC,
  CAST(f.NUM_ALMA AS VARCHAR(10)) AS BRANCH_ID,
  a.DESCR AS BRANCH_NAME,
  p.CVE_ART,
  p.CANT,
  p.COST,
  (p.CANT * p.COST) AS COGS,
  p.UNI_VENTA,
  f.CVE_CLPV,
  c.NOMBRE AS CLIENTE_NOMBRE,
  c.CALLE AS CLIENTE_CALLE,
  c.NUM_EXT AS CLIENTE_NUM_EXT,
  c.NUM_INT AS CLIENTE_NUM_INT,
  c.CIUDAD AS CLIENTE_CIUDAD,
  c.ESTADO AS CLIENTE_ESTADO,
  c.CP AS CLIENTE_CP,
  c.PAIS AS CLIENTE_PAIS,
  c.TELEFONO AS CLIENTE_TELEFONO,
  c.EMAIL AS CLIENTE_EMAIL
FROM FACTF01 f
JOIN PAR_FACTF01 p ON f.CVE_DOC = p.CVE_DOC
JOIN INVE01 i ON p.CVE_ART = i.CVE_ART
JOIN CLIE01 c ON f.CVE_CLPV = c.CVE_CLIE
LEFT JOIN ALMACENES01 a ON f.NUM_ALMA = a.CVE_ALMACEN
WHERE f.FECHA_DOC >= :fecha_inicio   -- D-1 00:00:00
  AND f.FECHA_DOC < :fecha_fin       -- D-0 00:00:00
  AND f.STATUS = 'E'                  -- Emitidas (no canceladas)
  AND i.LIN_PROD IN (
    'SINU','SIMAT','SERVI','LP','BAJA','UPS','MOTOR','CURSO',
    'DRIVE','INSTR','REDES','SIMA','OBSO','SINUM','FA300',
    '6ES5','SENSO','ESPE','FSINU','SERVO'
  )
ORDER BY f.CVE_DOC, p.NUM_PAR
```

### 3.5 Volumen esperado

| Métrica                         | Valor      |
| ------------------------------- | ---------- |
| Facturas Siemens/día (estimado) | 15-30      |
| Partidas/día (estimado)         | 30-80      |
| Batches necesarios              | 1          |
| Tiempo estimado de envío        | < 1 minuto |

### 3.6 Ejemplo de payload real

```json
[
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_ship_from_branch_name": "Saltillo",
    "distributor_ship_from_branch_id": "1",
    "distributor_ship_from_address": "Blvd. Isidro López 2000",
    "distributor_ship_from_city": "Saltillo",
    "distributor_ship_from_state": "Coahuila",
    "distributor_ship_from_zip": "25280",
    "distributor_ship_from_country": "MX",
    "distributor_ship_date": "2026-07-08",
    "distributor_invoice_date": "2026-07-08",
    "distributor_invoice_number": "CFDI_32699",
    "distributor_invoice_line_item": "1",
    "bill_to_customer_record_id": "1150",
    "bill_to_customer_duns_number": null,
    "bill_to_customer_name": "CLIENTE EJEMPLO SA DE CV",
    "bill_to_customer_billing_address1": "AV INSURGENTES 123",
    "bill_to_customer_billing_address2": "INT 5",
    "bill_to_customer_city": "MONTERREY",
    "bill_to_customer_state": "NUEVO LEON",
    "bill_to_customer_zip": "64000",
    "bill_to_customer_country": "MX",
    "bill_to_customer_phone_number": "8112345678",
    "bill_to_customer_domain_name_email_address": "cliente@ejemplo.com",
    "ship_to_customer_record_id": "1150",
    "ship_to_customer_duns_number": null,
    "ship_to_customer_name": "CLIENTE EJEMPLO SA DE CV",
    "ship_to_customer_shipping_address1": "AV INSURGENTES 123",
    "ship_to_customer_shipping_address2": "INT 5",
    "ship_to_customer_city": "MONTERREY",
    "ship_to_customer_state": "NUEVO LEON",
    "ship_to_customer_zip": "64000",
    "ship_to_customer_country": "MX",
    "ship_to_customer_phone_number": "8112345678",
    "ship_to_customer_domain_name_email_address": "cliente@ejemplo.com",
    "vendor_item_number": "3SU11502BF603MA0",
    "vendor_item_options": "",
    "quantity": 1,
    "quantity_unit_of_measure": "each",
    "unit_cost": 620.64,
    "extended_cost_of_goods_sold": 620.64,
    "currency_code": "MXN"
  }
]
```

### 3.7 Notas de implementación

- **`distributor_invoice_number`**: SAE usa formato `CFDI_XXXXX` (ej: `CFDI_32699`). Siemens acepta strings.
- **`distributor_invoice_line_item`**: SAE usa `NUM_PAR` (INTEGER). Siemens espera string.
- **`distributor_order_taking_branch_id`**: SAE usa `NUM_ALMA` (INTEGER). Si el cliente maneja una sola sucursal, siempre será `"1"`.
- **`distributor_ship_from_*`**: Datos de la empresa (dirección fiscal). Se obtienen de `PARAM_DATOSEMP01` o se configuran como valores fijos en el middleware.
- **`bill_to_*` y `ship_to_*`**: En SAE no hay dirección de envío separada. Se usa la misma dirección del cliente para ambos.
- **`bill_to_customer_duns_number`**: No existe en SAE. Enviar `null` o vacío.
- **`extended_cost_of_goods_sold`**: Se calcula como `CANT × COST` en el middleware.
- **`currency_code`**: SAE maneja moneda en `FACTF01.NUM_MONED` (FK a MONED01). Para simplificar, se usa `"MXN"` como valor fijo.
- **Filtro de líneas Siemens**: Se aplica vía `JOIN` con `INVE01.LIN_PROD`.
- **Status `E`**: Solo facturas emitidas. Status `C` = canceladas, `O` = otros. Se excluyen deliberadamente.
- **`quantity_unit_of_measure`**: El ejemplo Postman usa `"each"`. SAE tiene `"pz"`. **Decisión crítica**: ¿mapear `"pz"` → `"each"` o enviar `"pz"`? Confirmar con Siemens.

---

## 4. LÍNEAS DE PRODUCTO SIEMENS (Filtro)

Las siguientes líneas en `INVE01.LIN_PROD` se consideran productos Siemens:

| Código Línea | Descripción                 | Productos | Con Stock |
| ------------ | --------------------------- | --------- | --------- |
| BAJA         | Siemens (baja rotación)     | 2,687     | 657       |
| SINU         | Siemens (sinamics/simotics) | 1,657     | 297       |
| SIMAT        | Siemens (simatic)           | 1,630     | 429       |
| LP           | Siemens (linea principal)   | 1,132     | 293       |
| DRIVE        | Siemens (drives)            | 272       | 44        |
| MOTOR        | Siemens (motores)           | 212       | 4         |
| SINUM        | Siemens (sinumerik)         | 73        | 10        |
| SERVI        | Siemens (servicios)         | 34        | 2         |
| OBSO         | Siemens (obsoletos)         | 28        | 7         |
| SENSO        | Siemens (sensores)          | 22        | 4         |
| SERVO        | Siemens (servos)            | 20        | 0         |
| INSTR        | Siemens (instrumentación)   | 18        | 0         |
| UPS          | Siemens (UPS)               | 1         | 0         |
| SIMA         | Siemens (simatic)           | 1         | 1         |
| ESPE         | Siemens (especial)          | 1         | 0         |
| **TOTAL**    |                             | **7,788** | **1,758** |

---

## 5. DECISIONES PENDIENTES

| #   | Decisión                                                               | Impacto                                    | Prioridad |
| --- | ---------------------------------------------------------------------- | ------------------------------------------ | --------- |
| 1   | Confirmar `distributor_sender_id` con cliente                          | Crítico — sin esto no se puede enviar nada | P0        |
| 2   | Mapeo de `quantity_unit_of_measure`: ¿"pz" → "each" o enviar "pz"?     | Crítico — afecta ambos flujos              | P0        |
| 3   | Credenciales PRD de Siemens                                            | Necesario para go-live                     | P1        |
| 4   | ¿Enviar productos con stock=0?                                         | Decisión de negocio con Siemens            | P2        |
| 5   | Confirmar moneda (¿solo MXN o multicurrency?)                          | Afecta `currency_code`                     | P2        |
| 6   | Diferencias de esquema SAE 9.0 → SAE 10                                | El cliente debe actualizar a SAE 10        | P1        |
| 7   | `upc_ean`: ¿buscar en campos libres o enviar null?                     | Afecta flujo de inventario                 | P2        |
| 8   | `abc_segmentation`: ¿valor fijo "A" o calcular por rotación?           | Afecta flujo de inventario                 | P2        |
| 9   | `distributor_ship_from_*`: ¿datos de PARAM_DATOSEMP01 o valores fijos? | Afecta flujo de ventas                     | P2        |

---

## 6. VALIDACIÓN CONTRA API QUA

### 6.1 Prueba de inventario (exitosa)

```
POST https://api.pos.siemens.com/qua/inventory/create_record
Response: 400 Bad Request
Body: {
  "message": "Invalid request body",
  "description": [
    "object has missing required properties",
    ["distributor_inventory_date","distributor_sender_id","quantity","quantity_unit_of_measure","vendor_item_number"]
  ]
}
```

✅ Los 5 campos requeridos confirmados.

### 6.2 Prueba de Value Flow (exitosa)

```
POST https://api.pos.siemens.com/qua/create_record
Response: 400 Bad Request
Body: {
  "message": "Invalid request body",
  "description": "Validación de tipos en esquema"
}
```

✅ Autenticación válida. Los campos fueron aceptados en estructura (error fue de tipos, no de campos faltantes).

---

## 7. RESUMEN DE CAMPOS

| Flujo          | Campos totales | Requeridos                         | Opcionales |
| -------------- | -------------- | ---------------------------------- | ---------- |
| **Inventario** | 11             | 5                                  | 6          |
| **Value Flow** | 43             | 5 (mismos de inventario + invoice) | 38         |

---

*Documento de mapeo — ID interno: ARCH-20260720-03*  
*Fase 1 Discovery — ENTREGABLE COMPLETADO*  
*Esquema basado en capturas Postman del cliente + validación API QUA*
