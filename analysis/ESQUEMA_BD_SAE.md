# Esquema Base de Datos Aspel SAE 9.0

**Fecha:** 2026-07-20  
**Fuente:** Documentación oficial Aspel + Excel de Factor BI  
**Archivo BD:** SAE90EMPRE01.FDB (Firebird 2.5, ODS 11.2)

---

## Convenciones de Nomenclatura

- Las tablas tienen terminación **"01"** (número de empresa)
- Usuario por defecto: `SYSDBA` / `masterkey`
- Estructura encapsulada en un solo archivo `.fdb`

---

## Tablas Principales para Integración Siemens

### 📦 INVENTARIOS

#### **INVE01** - Catálogo de Productos/Inventarios
**Tipo:** Catálogo  
**Módulo:** Inventarios  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_ART` - Clave del artículo (PK, alfanumérico, 16 chars)
- `DESCR` - Descripción (alfanumérico, 40 chars)
- `LINE_PROD` - Línea de producto
- `STATUS` - Estatus (A=Activo, B=Baja, S=Suspendido)
- `TIPO_PROD` - Tipo de elemento (P=Producto, S=Servicio)
- `UNI_VEN` - Unidad de venta
- `UNI_COMP` - Unidad de compra
- `FACTOR_CONV` - Factor de conversión
- `EXIST` - Existencias (global si multialmacén)
- `STOCK_MIN` - Stock mínimo
- `STOCK_MAX` - Stock máximo
- `PUNTO_REORD` - Punto de reorden
- `METOD_COST` - Método de costeo
- `ULT_COSTO` - Último costo
- `COSTO_PROM` - Costo promedio
- `PRECIO1` a `PRECIO9` - Precios de venta
- `CVE_CLAS1` a `CVE_CLAS6` - Clasificaciones
- `CLAVE_SAT` - Clave SAT (8 dígitos)
- `UNI_SAT` - Clave unidad SAT (3 chars)

**Campos relacionados:**
- `INVE_CLIB01` - Campos libres del inventario (hasta 50 campos personalizables)
- `MULT01` - Stock por almacén (si multialmacén activo)
- `ALMACENES01` - Catálogo de almacenes
- `CVES_ALTER01` - Claves alternas de inventarios

---

#### **MINVE01** - Movimientos al Inventario
**Tipo:** Movimiento  
**Módulo:** Inventarios  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_ART` - Clave del artículo (FK a INVE01)
- `ALMACEN` - Almacén
- `CONCEPTO` - Concepto de movimiento (FK a CONM01)
- `FECHA` - Fecha del movimiento
- `TIPO_DOC` - Tipo de documento
- `DOCTO` - Número de documento
- `CVE_CLIE` / `CVE_PROV` - Cliente o proveedor
- `CANT` - Cantidad
- `COSTO` - Costo unitario
- `PRECIO` - Precio unitario
- `SIGNO` - Signo (+ entrada, - salida)

**Conceptos de movimiento estándar:**

**Entradas:**
- 1 - Compras
- 2 - Devoluciones de ventas
- 3 - Entradas a fábrica
- 4 - Cancelación de factura
- 5 - Canc. Devol. de compras
- 6 - Ajustes
- 7 - Entrada por traspaso
- 8 - Inventario inicial

**Salidas:**
- 51 - Ventas
- 52 - Devolución de compras
- 53 - Salida a fábrica
- 54 - Pérdidas
- 55 - Mermas
- 56 - Canc. Devol. de venta
- 57 - Cancelación de compra
- 58 - Salida por traspaso

---

#### **MULT01** - Stock por Almacén (Multialmacén)
**Tipo:** Resumen  
**Módulo:** Inventarios  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_ART` - Clave del artículo
- `ALMACEN` - Clave de almacén
- `EXIST` - Existencias en ese almacén
- `STOCK_MIN` - Stock mínimo por almacén
- `STOCK_MAX` - Stock máximo por almacén

---

#### **ALMACENES01** - Catálogo de Almacenes
**Tipo:** Catálogo  
**Módulo:** Inventarios  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_ALMACEN` - Clave de almacén (PK)
- `DESCR` - Descripción del almacén
- `STATUS` - Estatus

---

### 👥 CLIENTES

#### **CLIE01** - Catálogo de Clientes
**Tipo:** Catálogo  
**Módulo:** Clientes  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_CLIE` - Clave del cliente (PK, alfanumérico, 10 chars)
- `NOMBRE` - Nombre/Razón social
- `RFC` - RFC
- `STATUS` - Estatus (A=Activo, M=Moroso, S=Suspendido, B=Baja)
- `CALLE` - Calle
- `NUM_EXT` - Número exterior
- `NUM_INT` - Número interior
- `COLONIA` - Colonia
- `CIUDAD` - Ciudad
- `ESTADO` - Estado
- `PAIS` - País
- `CP` - Código postal
- `TELEFONO` - Teléfono
- `EMAIL` - Correo electrónico
- `CURP` - CURP
- `LIMITE_CREDITO` - Límite de crédito
- `SALDO` - Saldo actual
- `DIAS_CREDITO` - Días de crédito
- `DESCUENTO` - Descuento aplicado
- `CVE_CLAS1` a `CVE_CLAS6` - Clasificaciones

**Campos relacionados:**
- `CLIE_CLIB01` - Campos libres del cliente
- `CONTAC01` - Contactos del cliente
- `CITAS01` - Citas del cliente

---

### 💰 VENTAS

#### **FACTF01** - Facturas
**Tipo:** Movimiento  
**Módulo:** Ventas  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_CLIE` - Clave del cliente (FK a CLIE01)
- `FECHA` - Fecha de factura
- `FECHA_APLI` - Fecha de aplicación
- `FECHA_VENC` - Fecha de vencimiento
- `REFER` - Referencia
- `DOCTO` - Número de documento
- `STATUS` - Estatus
- `SUBTOTAL` - Subtotal
- `IMPUESTO1` a `IMPUESTO8` - Impuestos
- `TOTAL` - Total
- `FORMA_PAGO` - Forma de pago
- `METODO_PAGO` - Método de pago
- `USO_CFDI` - Uso de CFDI
- `SERIE` - Serie fiscal
- `FOLIO` - Folio fiscal

**Campos relacionados:**
- `FACTF_CLIB01` - Campos libres de facturas
- `PARC01` - Partidas de la factura (detalle)
- `CFDI01` - Comprobante fiscal digital (XML)

---

#### **PARC01** - Partidas de Documentos
**Tipo:** Detalle  
**Módulo:** Ventas/Compras  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_ART` - Clave del artículo (FK a INVE01)
- `REFER` - Referencia del documento
- `DOCTO` - Número de documento
- `CVE_CLIE` / `CVE_PROV` - Cliente o proveedor
- `CANT` - Cantidad
- `PRECIO` - Precio unitario
- `COSTO` - Costo unitario
- `DESCUENTO` - Descuento
- `IMPUESTO1` a `IMPUESTO8` - Impuestos
- `TOTAL` - Total de la partida
- `UNIDAD` - Unidad de medida

---

#### **FACTR01** - Remisiones
**Tipo:** Movimiento  
**Módulo:** Ventas  
**Sync:** ✅ Sí

**Campos principales:**
- Similar a FACTF01 pero para remisiones
- Las remisiones son surtidos de pedidos
- Los pedidos quedan con status "PXS" hasta que se surta todo

---

#### **FACTP01** - Pedidos
**Tipo:** Movimiento  
**Módulo:** Ventas  
**Sync:** ✅ Sí

**Campos principales:**
- Similar a FACTF01 pero para pedidos
- Status: PXS (pendiente de surtir)

---

#### **FACTV01** - Notas de Venta
**Tipo:** Movimiento  
**Módulo:** Ventas  
**Sync:** ✅ Sí

**Campos principales:**
- Similar a FACTF01 pero para notas de venta
- TIP_DOC_SIG = Null

---

### 💳 CUENTAS POR COBRAR

#### **CUEN_M01** - Cuentas por Cobrar
**Tipo:** Movimiento  
**Módulo:** Por Cobrar  
**Sync:** ❌ No (solo lectura)

**Campos principales:**
- `CVE_CLIE` - Clave del cliente
- `REFER` - Referencia
- `DOCTO` - Número de documento
- `FECHA` - Fecha
- `FECHA_APLI` - Fecha de aplicación
- `FECHA_VENC` - Fecha de vencimiento
- `IMPORTE` - Importe
- `SIGNO` - Signo (+ cargo, - abono)
- `STATUS` - Estatus

---

#### **CUEN_DET01** - Detalle de Cuentas por Cobrar
**Tipo:** Detalle  
**Módulo:** Por Cobrar  
**Sync:** ❌ No

**Campos principales:**
- Similar a CUEN_M01 pero con más detalle
- Usado para movimientos específicos

---

### 🏭 COMPRAS

#### **COMPR01** - Recepciones de Compra
**Tipo:** Movimiento  
**Módulo:** Compras  
**Sync:** ❌ No

**Campos principales:**
- `CVE_PROV` - Clave del proveedor
- `FECHA` - Fecha de recepción
- `REFER` - Referencia
- `DOCTO` - Número de documento
- `STATUS` - Estatus
- `SUBTOTAL` - Subtotal
- `IMPUESTO1` a `IMPUESTO8` - Impuestos
- `TOTAL` - Total

**Campos relacionados:**
- `COMPR_CLIB01` - Campos libres de recepciones

---

### 📋 OTRAS TABLAS IMPORTANTES

#### **CONM01** - Conceptos de Movimientos al Inventario
**Tipo:** Maestro  
**Módulo:** Inventarios  
**Sync:** ❌ No

**Campos principales:**
- `CONCEPTO` - Número de concepto (PK)
- `DESCR` - Descripción del concepto
- `TIPO_MOV` - Tipo de movimiento (E=Entrada, S=Salida)
- `ASOCIADO` - Asociado a (C=Cliente, P=Proveedor, N=Ninguno)
- `CUENTA_CONT` - Cuenta contable (interfaz COI)

---

#### **CFDI01** - Comprobantes Fiscales Digitales
**Tipo:** Movimiento  
**Módulo:** Fiscal  
**Sync:** ❌ No

**Campos principales:**
- `REFER` - Referencia
- `DOCTO` - Número de documento
- `TIPO_DOC` - Tipo de documento
- `XML` - Contenido XML del CFDI
- `UUID` - Folio fiscal UUID
- `FECHA_TIMBRADO` - Fecha de timbrado

---

#### **PROV01** - Proveedores
**Tipo:** Catálogo  
**Módulo:** Proveedores  
**Sync:** ❌ No

**Campos principales:**
- `CVE_PROV` - Clave del proveedor (PK)
- `NOMBRE` - Nombre/Razón social
- `RFC` - RFC
- `STATUS` - Estatus
- Similar estructura a CLIE01

---

#### **LIN_PROD01** - Líneas de Producto
**Tipo:** Catálogo  
**Módulo:** Artículos  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_LINEA` - Clave de línea (PK)
- `DESCR` - Descripción de la línea

---

#### **MONED01** - Monedas
**Tipo:** Maestro  
**Módulo:** Contabilidad  
**Sync:** ✅ Sí

**Campos principales:**
- `CVE_MONEDA` - Clave de moneda (PK)
- `DESCR` - Descripción
- `TIPO_CAMBIO` - Tipo de cambio

---

## Flujo de Datos para Integración Siemens

### **Value Flow (Ventas)**

```
FACTF01 (Facturas)
  ├─> PARC01 (Partidas con CVE_ART, CANT, PRECIO)
  ├─> INVE01 (Datos del producto)
  └─> CLIE01 (Datos del cliente)
```

**Mapeo a Siemens PoSi API:**
- `transaction_id` ← FACTF01.REFER + FACTF01.DOCTO
- `timestamp` ← FACTF01.FECHA
- `items[]` ← PARC01 (iterar por partida)
  - `sku` ← PARC01.CVE_ART
  - `quantity` ← PARC01.CANT
  - `unit_price` ← PARC01.PRECIO
- `customer_id` ← FACTF01.CVE_CLIE
- `total_amount` ← FACTF01.TOTAL

---

### **Inventory (Inventario)**

```
INVE01 (Catálogo)
  ├─> Si multialmacén: MULT01 (Stock por almacén)
  └─> Si no multialmacén: INVE01.EXIST (Stock global)
```

**Mapeo a Siemens PoSi API:**
- `sku` ← INVE01.CVE_ART
- `quantity` ← INVE01.EXIST o SUM(MULT01.EXIST)
- `warehouse_id` ← MULT01.ALMACEN (si multialmacén)
- `last_updated` ← MAX(MINVE01.FECHA) WHERE CVE_ART = INVE01.CVE_ART

---

## Queries de Ejemplo

### Obtener todas las ventas de un día
```sql
SELECT 
  f.REFER, f.DOCTO, f.FECHA, f.CVE_CLIE, f.TOTAL,
  p.CVE_ART, p.CANT, p.PRECIO
FROM FACTF01 f
JOIN PARC01 p ON f.REFER = p.REFER AND f.DOCTO = p.DOCTO
WHERE f.FECHA = '2026-07-20'
  AND f.STATUS = 'A'
ORDER BY f.FECHA, f.DOCTO
```

### Obtener inventario actual
```sql
SELECT 
  i.CVE_ART, i.DESCR, i.EXIST, i.COSTO_PROM,
  l.DESCR AS LINEA
FROM INVE01 i
LEFT JOIN LIN_PROD01 l ON i.LINE_PROD = l.CVE_LINEA
WHERE i.STATUS = 'A'
ORDER BY i.CVE_ART
```

### Obtener inventario por almacén (multialmacén)
```sql
SELECT 
  m.CVE_ART, m.ALMACEN, m.EXIST,
  a.DESCR AS ALMACEN_NOMBRE,
  i.DESCR AS PRODUCTO_NOMBRE
FROM MULT01 m
JOIN ALMACENES01 a ON m.ALMACEN = a.CVE_ALMACEN
JOIN INVE01 i ON m.CVE_ART = i.CVE_ART
WHERE m.EXIST > 0
ORDER BY m.CVE_ART, m.ALMACEN
```

---

## Consideraciones Técnicas

1. **Terminación de tablas:** Cambiar "01" según el número de empresa
2. **Campos libres:** Las tablas `*_CLIB01` contienen campos personalizables
3. **Multialmacén:** Si está activo, usar `MULT01` en lugar de `INVE01.EXIST`
4. **Status:** Filtrar siempre por `STATUS = 'A'` (activo)
5. **Fechas:** Formato Firebird `YYYY-MM-DD` o `DD-MM-YYYY`
6. **Decimales:** Revisar precisión de cantidades y precios
7. **Índices:** Las tablas tienen índices por clave primaria y campos de búsqueda comunes

---

## Próximos Pasos

- [ ] Instalar Firebird 2.5 para acceder directamente a la BD
- [ ] Validar estructura con queries reales
- [ ] Identificar campos específicos necesarios para Siemens
- [ ] Definir estrategia de extracción (batch vs tiempo real)
- [ ] Documentar mapeo completo de campos SAE → Siemens
