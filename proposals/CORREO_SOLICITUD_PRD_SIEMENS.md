# Correo Formal: Solicitud de Credenciales PRD + Validación QUA

**Para:** Siemens Data Steward Regional / Soporte PoSi Portal
**Asunto:** Valueflow Middleware - Validación QUA completada + Solicitud credenciales PRD
**Adjuntos:** Este correo

---

Estimado equipo de soporte de Siemens PoSi Portal,

## 📋 Resumen

Les escribimos desde **VCorp / Representaciones Aga de Saltillo** para confirmar que la integración técnica entre nuestro sistema **Aspel SAE 10** y el portal **Siemens PoSi** está funcionando correctamente en el ambiente **QUA**, y para solicitar formalmente las credenciales de **Producción (PRD)**.

## ✅ Pruebas completadas en QUA

Hemos validado exitosamente los siguientes endpoints con la API Key QUA (`I1k****gbv`):

### 1. Endpoint de Inventario
- **URL:** `https://api.pos.siemens.com/qua/inventory/create_record`
- **Método:** POST
- **Payload enviado:** 3 SKUs reales de Siemens (formato correcto)
- **Resultado:** ✅ **HTTP 201 Created**
- **Tiempo de respuesta:** ~1.5s

### 2. Endpoint de Ventas / Value Flow
- **URL:** `https://api.pos.siemens.com/qua/create_record`
- **Método:** POST
- **Payload enviado:** 2 facturas con 3 líneas en total
- **Resultado:** ✅ **HTTP 201 Created**
- **Tiempo de respuesta:** ~2.2s

### 3. Headers HTTP validados
```
Content-Type: application/json
X-API-KEY: <nuestra-clave-qua>
```

## 📦 SKUs enviados como demo

Para que puedan validar que el formato es correcto, les informamos los SKUs que usamos en el envío:

| SKU | Descripción |
|-----|-------------|
| `3RV2011-1KA10` | Motor Circuit Breaker Sirius 3RV |
| `6EP1332-1SH71` | Sitop PSU100 24V/2.5A |
| `3RT2026-1BB40` | Contactor Sirius 3RT AC-3 11kW |

Si pueden revisar en su log/backend si estos registros fueron recibidos,，我们会 saber que:
- ✅ El formato es correcto
- ✅ La autenticación funciona
- ✅ Estamos listos para producción

## 🎯 Solicitud de credenciales de Producción (PRD)

Una vez que confirmen que los datos demo fueron recibidos correctamente en QUA, les solicitamos:

1. **API Key de Producción (PRD)** — credencial real para envío a `https://api.pos.siemens.com/prd/`
2. **Confirmación de credenciales SFTP** (si aplica para nuestro caso de uso)
3. **Plantilla oficial de campos** — para que podamos validar la coincidencia entre el esquema de QUA y el de PRD (en caso de que difieran en campos opcionales o reglas de validación)
4. **Calendario de renovación** de las credenciales (cuándo se vence y cómo se renueva)
5. **Contactos de escalación** en caso de incidentes (en lugar del portal)

## 📞 Información de contacto

**Cliente:**
- Representaciones Aga de Saltillo, S.A. de C.V.
- Contacto técnico: Ing. Francisco Aguirre
- Email: fcoaguirre@repaga.com.mx
- Teléfono: 844 160 6737

**Proveedor técnico (VCorp):**
- Frank Saavedra
- Email: frank@vcorp.mx

**distributor_sender_id:** `MX-REPRESENTACIONES`
**Ambiente actual:** QUA (testing) — `environment: "qua"` (lowercase confirmado)

## 🔧 Stack técnico del middleware

- **Sistema origen:** Aspel SAE 10 (Firebird 5.0 local)
- **Tecnología:** Node.js 20 LTS + TypeScript + Express
- **Arquitectura:** Acceso directo a BD Firebird (read-only) + API REST a Siemens
- **Filtro de marca:** 15 líneas Siemens validadas en `LIN_PROD`
- **Volumen:** ~12,000 productos en catálogo, ~28,000 facturas históricas
- **Frecuencia:** Inventario diario 02:00 AM, Ventas diarias 03:00 AM (hora centro México)
- **Repositorio:** https://github.com/frank-vcorp/Valueflow (público para referencia técnica)

## 📅 Timeline propuesto

| Fecha | Actividad |
|-------|-----------|
| Esta semana | Validación QUA (en curso, este correo) |
| Próxima semana | Solicitud y recepción de credenciales PRD |
| Semana siguiente | Configuración de ambiente PRD en nuestro middleware |
| Semana 4 | UAT en PRD con datos reales (1 semana de ejecución) |
| Semana 5 | Go-live a PRD (transición de QUA a producción) |

Quedamos atentos a su confirmación sobre los datos demo recibidos y a la generación de las credenciales PRD.

Agradecemos su atención y soporte.

Atentamente,

**Frank Saavedra**
VCorp
frank@vcorp.mx

---

*Correo preparado el 2026-08-04 tras validación completa de QUA con HTTP 201 en todos los endpoints*