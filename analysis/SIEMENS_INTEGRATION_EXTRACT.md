# Siemens PoSi Portal - Resumen para Integraciones

**Portal:** https://pos.mx.lowcode.siemens.cloud/
**Usuario:** frank@vcorp.mx
**Plataforma:** Mendix Low-Code (Siemens)
**Última actualización documentación:** Octubre 2025

---

## 🎯 Contexto General

El portal **Siemens PoSi Portal** (Point of Sales and Inventory) permite a partners/distribuidores enviar a Siemens dos tipos de información:

1. **Inventario (Inventory)** → Disponible **únicamente vía API**
2. **Ventas (Point of Sales / Value Flow)** → Disponible vía **API, SFTP o EDI**

El portal incluye un módulo de **D&B Search** para consulta de DUNS numbers.

---

## 📦 INTEGRACIÓN 1: ENVÍO DE INVENTARIO A SIEMENS

### Método disponible
**SOLO API** (no SFTP, no EDI)

### Endpoints de Inventario
| Ambiente | URL |
|----------|-----|
| **Quality (QAS)** | `https://api.pos.siemens.com/qua/inventory/` |
| **Production (PRD)** | `https://api.pos.siemens.com/prd/inventory/` |

### Método HTTP
- **POST** al endpoint `/create_record`
- Ejemplo: `POST https://api.pos.siemens.com/qua/inventory/create_record`

### Headers Requeridos
| Header | Valor | Notas |
|--------|-------|-------|
| `X-API-KEY` | `<credencial asignada>` | Otorgada por el equipo Siemens PoS (única por organización/endpoint) |
| `CONTENT-TYPE` | `application/json` | |

### Body
- Formato: **JSON**
- Recomendación: no exceder **3000 transacciones por lote**
- Campos en formato **ISO 8601** para fechas: `YYYY-MM-DD`
- Si faltan campos requeridos → respuesta `400 Bad Request`

### Autenticación
- API Key única por organización, proporcionada por Siemens PoS team.
- Para obtenerla: solicitar al Siemens PoS Data Steward regional.

---

## 💰 INTEGRACIÓN 2: VALUE FLOW (ENVÍO DE VENTAS/EXTRACTO DE VENTAS)

Tres métodos disponibles:

### Opción A: API (Recomendada)

**Endpoints de Point of Sales:**
| Ambiente | URL |
|----------|-----|
| **Quality (QAS)** | `https://api.pos.siemens.com/qua/` |
| **Production (PRD)** | `https://api.pos.siemens.com/prd/` |

- **POST** a `/create_record`
- Ejemplo QAS: `POST https://api.pos.siemens.com/qua/create_record`
- Headers: `X-API-KEY` + `CONTENT-TYPE: application/json`
- Body en JSON (mismo esquema que Inventory)
- Recomendación: ≤3000 transacciones por batch

### Opción B: SFTP

| Parámetro | Valor |
|-----------|-------|
| **Host** | `sftp-public.dl2go.siemens.cloud` |
| **Puerto** | `22` |
| **Autenticación** | Usuario + archivo de clave privada (PKI) |
| **Formato archivo** | CSV UTF-8 (comma delimited) **sin BOM** |
| **Encoding** | UTF-8 |

**Estructura de carpetas:**
- `inbound/` → Aquí se deposita el CSV
- `processed/` → Archivos procesados con éxito
- `error/` → Logs de errores

**Configuraciones importantes del cliente SFTP (WinSCP recomendado):**
1. **Disable "Preserve Timestamp"** (Options → Preferences → Transfer → Default → Edit)
2. Authentication: usar archivo de clave privada (no password)
3. Path: Edit → Advanced → Authentication → Save key file

**Notas críticas del CSV:**
- ⚠️ **SIN BOM** (Byte Order Mark). Excel agrega BOM al guardar como UTF-8; abrir en Notepad y guardar como UTF-8 sin BOM.
- Celdas con comas → encerrar entre comillas dobles
- Campos numéricos → NO encerrar entre comillas
- Header row obligatorio con nombres técnicos exactos de campos Siemens
- Orden de columnas libre (se procesa por nombre)

**Software sugerido:** WinSCP (https://winscp.net/)

### Opción C: EDI (Solo por excepción)

- Estándar **EDI 867**
- ⚠️ **Restringido a regiones que ya usan EDI con Siemens**
- No aplica para nuevas integraciones estándar

---

## 🔑 Credenciales Necesarias

Para cualquiera de las dos integraciones se requiere:

| Recurso | Cómo obtenerlo |
|---------|----------------|
| **API Key** (Inventory y/o PoS) | Solicitar al Siemens PoS Data Steward regional |
| **Credenciales SFTP** (usuario + clave privada) | Proporcionadas por Siemens Point of Sales team tras solicitud del Data Steward |
| **Plantillas con nombres de campos** | Solicitar al Data Steward regional (requiere permisos elevados) |

---

## 📋 Resumen de Decisión

| Criterio | API | SFTP | EDI |
|----------|-----|------|-----|
| Inventario | ✅ | ❌ | ❌ |
| PoS / Ventas | ✅ | ✅ | ⚠️ Solo excepción |
| Tiempo real | ✅ (cercano) | ❌ (batch) | ❌ (batch) |
| Complejidad | Media | Baja | Alta |
| Recomendado para producción | ✅ Sí | ✅ Sí | ❌ No |

**Recomendación:**
- **Inventario:** API obligatorio
- **Value Flow (Ventas):** API o SFTP según volumen y periodicidad. API para integraciones modernas; SFTP para procesos batch diarios con archivos CSV.

---

## 📞 Contactos

- **Siemens PoS Data Steward regional** → Alta de credenciales y plantillas
- **Siemens Data Protection Organization** → `datenschutz@siemens.com`

---

*Documento generado a partir de la navegación en vivo del portal Siemens PoSi el 2026-07-06.*