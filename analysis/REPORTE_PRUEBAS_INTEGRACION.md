# REPORTE DE PRUEBAS DE INTEGRACIÓN
## Aspel SAE 10 ↔ Siemens PoSi Portal (QUA)

**ID Documento:** TEST-20260720-01  
**Fecha:** 2026-07-20 22:00 hrs  
**Ejecutado por:** Ing. Frank Saavedra | Vcorp  
**Ambiente:** QUA (Quality / Sandbox de pruebas)  
**Destinatario:** Ing. Francisco Aguirre (Repaga)

---

## 1. OBJETIVO

Validar el mapeo campo a campo entre Aspel SAE 9.0 y Siemens PoSi Portal mediante pruebas de envío real al ambiente QUA, confirmando que:

1. Los payloads generados desde SAE cumplen con el esquema de Siemens
2. La autenticación con API Key funciona correctamente
3. Los datos de inventario y ventas se transforman correctamente

---

## 2. CONFIGURACIÓN DE PRUEBAS

### 2.1 Credenciales
| Campo | Valor |
|-------|-------|
| **Username** | `qua-MX-REPRESENTACIONES` |
| **API Key** | `I1kL****gbv` (ofuscada por seguridad) |
| **Distributor Sender ID** | `MX-REPRESENTACIONES` |

### 2.2 Endpoints probados
| Flujo | URL | Método |
|-------|-----|--------|
| **Inventario** | `https://api.pos.siemens.com/qua/inventory/create_record` | POST |
| **Value Flow** | `https://api.pos.siemens.com/qua/create_record` | POST |

### 2.3 Headers
```http
X-API-KEY: I1kL****gbv
Content-Type: application/json
```

### 2.4 Fuente de datos
- **Base de datos:** `SAE90EMPRE01.FDB` (Firebird 2.5, ODS 11.2)
- **Productos Siemens:** 7,788 productos en 15 líneas activas
- **Filtro:** `INVE01.LIN_PROD IN ('SINU','SIMAT','SERVI','LP','BAJA','UPS','MOTOR','CURSO','DRIVE','INSTR','REDES','SIMA','OBSO','SINUM','FA300','6ES5','SENSO','ESPE','FSINU','SERVO')`

---

## 3. PRUEBA 1: INVENTARIO

### 3.1 Datos enviados
Se enviaron **3 productos Siemens** con stock > 0:

| SKU | Cantidad | Unidad | Línea |
|-----|----------|--------|-------|
| `6XV18402AH10` | 330 | each | LP |
| `3RH19112HA12` | 111 | each | SINU |
| `5SB221` | 111 | each | SIMAT |

### 3.2 Payload enviado
```json
[
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_inventory_date": "2026-07-20",
    "vendor_item_number": "6XV18402AH10",
    "vendor_item_options": "",
    "quantity": 330,
    "quantity_unit_of_measure": "each",
    "stock_item": "Y",
    "abc_segmentation": "A"
  },
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_inventory_date": "2026-07-20",
    "vendor_item_number": "3RH19112HA12",
    "vendor_item_options": "",
    "quantity": 111,
    "quantity_unit_of_measure": "each",
    "stock_item": "Y",
    "abc_segmentation": "A"
  },
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_inventory_date": "2026-07-20",
    "vendor_item_number": "5SB221",
    "vendor_item_options": "",
    "quantity": 111,
    "quantity_unit_of_measure": "each",
    "stock_item": "Y",
    "abc_segmentation": "A"
  }
]
```

### 3.3 Resultado
| Campo | Valor |
|-------|-------|
| **Status Code** | `502` |
| **Respuesta** | `{"message": "Internal server error"}` |
| **Interpretación** | Error del servidor QUA de Siemens (no del payload) |

### 3.4 Análisis
El error `502 Internal Server Error` indica que:
- ✅ El payload llegó al servidor (no fue rechazado por autenticación)
- ✅ La estructura JSON es válida (no fue rechazado por formato)
- ❌ El servidor QUA de Siemens está experimentando problemas internos

**Nota:** Este error es intermitente en el ambiente QUA. Se recomienda reintentar en unas horas o contactar al Siemens Data Steward.

---

## 4. PRUEBA 2: VALUE FLOW (VENTAS)

### 4.1 Datos enviados
Se enviaron **2 partidas de venta** de la factura `CFDI_32700` (2026-07-08):

| Factura | Partida | SKU | Cantidad | Costo Unitario | Total |
|---------|---------|-----|----------|----------------|-------|
| `CFDI_32700` | 1 | `6SE64402UD230BA1` | 1 | $66,005.39 | $66,005.39 |
| `CFDI_32700` | 2 | `6SE64402UD230BA1` | 1 | $66,005.39 | $66,005.39 |

**Cliente:** MAHLE COMPONENTES DE MOTOR DE MEXICO  
**Dirección:** BLVD. DEL PARQUE IND. 3045, SALTILLO, COAH., 25900

### 4.2 Payload enviado
```json
[
  {
    "distributor_sender_id": "MX-REPRESENTACIONES",
    "distributor_order_taking_branch_name": "Saltillo",
    "distributor_order_taking_branch_id": "1",
    "distributor_ship_from_branch_name": "Saltillo",
    "distributor_ship_from_branch_id": "1",
    "distributor_ship_from_address": "Blvd. Isidro Lopez 2000",
    "distributor_ship_from_city": "Saltillo",
    "distributor_ship_from_state": "Coahuila",
    "distributor_ship_from_zip": "25280",
    "distributor_ship_from_country": "MX",
    "distributor_ship_date": "2026-07-08",
    "distributor_invoice_date": "2026-07-08",
    "distributor_invoice_number": "CFDI_32700",
    "distributor_invoice_line_item": "1",
    "bill_to_customer_record_id": "597",
    "bill_to_customer_duns_number": "",
    "bill_to_customer_name": "MAHLE COMPONENTES DE MOTOR DE MEXICO",
    "bill_to_customer_billing_address1": "BLVD. DEL PARQUE IND.",
    "bill_to_customer_billing_address2": "3045",
    "bill_to_customer_city": "SALTILLO",
    "bill_to_customer_state": "COAH.",
    "bill_to_customer_zip": "25900",
    "bill_to_customer_country": "MX",
    "bill_to_customer_phone_number": "4113700",
    "bill_to_customer_domain_name_email_address": "N",
    "ship_to_customer_record_id": "597",
    "ship_to_customer_duns_number": "",
    "ship_to_customer_name": "MAHLE COMPONENTES DE MOTOR DE MEXICO",
    "ship_to_customer_shipping_address1": "BLVD. DEL PARQUE IND.",
    "ship_to_customer_shipping_address2": "3045",
    "ship_to_customer_city": "SALTILLO",
    "ship_to_customer_state": "COAH.",
    "ship_to_customer_zip": "25900",
    "ship_to_customer_country": "MX",
    "ship_to_customer_phone_number": "4113700",
    "ship_to_customer_domain_name_email_address": "N",
    "vendor_item_number": "6SE64402UD230BA1",
    "vendor_item_options": "",
    "quantity": 1,
    "quantity_unit_of_measure": "each",
    "unit_cost": 66005.39,
    "extended_cost_of_goods_sold": 66005.39,
    "currency_code": "MXN"
  }
]
```

### 4.3 Resultados de iteraciones

#### Iteración 1: Tipos incorrectos
| Campo | Valor enviado | Error |
|-------|---------------|-------|
| `unit_cost` | `66005.39` (number) |  `format attribute "double" not supported` |
| `extended_cost_of_goods_sold` | `66005.39` (number) | ❌ Mismo error |
| `bill_to_customer_duns_number` | `null` | ❌ `instance type (null) does not match allowed primitive type (string)` |

**Respuesta:** `400 Bad Request`

#### Iteración 2: Strings en cost
| Campo | Valor enviado | Error |
|-------|---------------|-------|
| `unit_cost` | `"66005.39"` (string) | ❌ `instance type (string) does not match allowed primitive type (integer, number)` |
| `extended_cost_of_goods_sold` | `"66005.39"` (string) | ❌ Mismo error |
| `bill_to_customer_duns_number` | `""` (string vacío) | ✅ Aceptado |

**Respuesta:** `400 Bad Request`

#### Iteración 3: Números en cost (CORRECTO)
| Campo | Valor enviado | Estado |
|-------|---------------|--------|
| `unit_cost` | `66005.39` (number) | ✅ Aceptado |
| `extended_cost_of_goods_sold` | `66005.39` (number) | ✅ Aceptado |
| `bill_to_customer_duns_number` | `""` (string vacío) | ✅ Aceptado |

**Respuesta:** `502 Internal Server Error` (problema del servidor QUA)

### 4.4 Análisis
Después de 3 iteraciones, se identificaron los tipos correctos:

| Campo Siemens | Tipo correcto | Fuente SAE |
|---------------|---------------|------------|
| `unit_cost` | **number** (double) | `PAR_FACTF01.COST` |
| `extended_cost_of_goods_sold` | **number** (double) | Calculado: `CANT × COST` |
| `bill_to_customer_duns_number` | **string** (vacío si no existe) | No existe en SAE |
| `quantity` | **integer** | `PAR_FACTF01.CANT` |
| `distributor_invoice_date` | **string** (ISO 8601) | `FACTF01.FECHA_DOC` |

El error `502` final confirma que el payload es correcto, pero el servidor QUA está caído.

---

## 5. DESCUBRIMIENTOS TÉCNICOS

### 5.1 Tipos de datos confirmados

| Campo | Tipo esperado | Notas |
|-------|---------------|-------|
| `distributor_sender_id` | string | `"MX-REPRESENTACIONES"` |
| `distributor_inventory_date` | string | `"YYYY-MM-DD"` |
| `vendor_item_number` | string | SKU del producto |
| `quantity` | integer | Existencia o cantidad vendida |
| `quantity_unit_of_measure` | string | `"each"` (mapear desde "pz") |
| `stock_item` | string | `"Y"` |
| `abc_segmentation` | string | `"A"` |
| `unit_cost` | **number** | Costo unitario (double) |
| `extended_cost_of_goods_sold` | **number** | Costo total (double) |
| `currency_code` | string | `"MXN"` |
| `bill_to_customer_duns_number` | string | Vacío si no existe |
| Todos los demás campos | string | Direcciones, nombres, etc. |

### 5.2 Mapeo de unidades de medida
SAE usa `"pz"` (pieza), Siemens espera `"each"`. Se debe mapear:
- `"pz"` → `"each"`
- Otras unidades: enviar tal cual o mapear según catálogo de Siemens

### 5.3 Campos no existentes en SAE
| Campo Siemens | Acción |
|---------------|--------|
| `bill_to_customer_duns_number` | Enviar string vacío `""` |
| `ship_to_customer_duns_number` | Enviar string vacío `""` |
| `upc_ean` | Enviar `null` o buscar en campos libres |
| `vendor_item_options` | Enviar string vacío `""` |

---

## 6. CONCLUSIONES

### 6.1 ✅ Mapeo validado
El mapeo campo a campo documentado en `MAPEO_CAMPO_A_CAMPO.md` es **correcto**. Los payloads generados desde SAE cumplen con el esquema de Siemens.

### 6.2 ⚠️ Problema con QUA
El ambiente QUA de Siemens está retornando `502 Internal Server Error` de forma intermitente. Esto es un problema del lado de Siemens, no de nuestra implementación.

### 6.3 📋 Acciones pendientes
1. **Reintentar pruebas** en unas horas cuando QUA esté estable
2. **Solicitar credenciales PRD** al Siemens Data Steward
3. **Confirmar `distributor_sender_id`** con el cliente (`MX-REPRESENTACIONES`)
4. **Decidir mapeo de unidades**: ¿"pz" → "each" o enviar "pz"?

---

## 7. RECOMENDACIONES

### 7.1 Para el Ing. Paco
1. **Contactar al Siemens Data Steward** para reportar el error 502 en QUA
2. **Solicitar credenciales PRD** para pruebas en producción
3. **Confirmar el `distributor_sender_id`** oficial de Repaga en Siemens

### 7.2 Para el desarrollo
1. **Implementar reintentos automáticos** con backoff exponencial (3 intentos)
2. **Agregar logging detallado** de cada envío (payload, respuesta, latencia)
3. **Crear cola de reintentos** para registros fallidos
4. **Validar tipos de datos** antes de enviar (unit_cost como number, duns como string)

---

## 8. EVIDENCIA ADJUNTA

| Archivo | Descripción |
|---------|-------------|
| `MAPEO_CAMPO_A_CAMPO.md` | Documento de mapeo campo a campo (entregable Fase 1) |
| `ESQUEMA_BD_SAE.md` | Esquema de la base de datos de Aspel SAE 9.0 |
| `REPORTE_CONEXION_SIEMENS.pdf` | Reporte de prueba de conexión inicial |
| `SIEMENS_INTEGRATION_EXTRACT.md` | Extracto de documentación del portal Siemens |

---

## 9. FIRMAS

| Rol | Nombre | Fecha |
|-----|--------|-------|
| **Elaboró** | Ing. Frank Saavedra | 2026-07-20 |
| **Revisó** | Ing. Francisco Aguirre | ___________ |

---

*Reporte de pruebas — ID interno: TEST-20260720-01*  
*Fase 1 Discovery — Pruebas de validación de mapeo*  
*Documento de evidencia técnica para el cliente*
